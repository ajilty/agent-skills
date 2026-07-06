#!/usr/bin/env python3
"""Verifiable multi-model consensus weather forecast for Beacon, NY.

Approach
--------
No single weather model is the most accurate; decades of forecast
verification show a consensus (blend) of independent NWP models beats any
individual member at point-forecast accuracy. This script:

  1. Pulls hourly forecasts from independent sources in one run:
     - NOAA/NWS gridpoint forecast for Beacon (the human-adjusted forecast)
     - Open-Meteo per-model output: GFS (NOAA), ECMWF IFS, ICON (DWD),
       GEM (Canada), UKMO (UK Met Office)
  2. Logs every model's forecast to SQLite *before the fact* (append-only,
     keyed by issue time), so accuracy claims are auditable later.
  3. Fetches real surface observations from the nearest ASOS station
     (KSWF, Stewart Intl, ~11 km WSW of Beacon across the Hudson) and
     scores every logged forecast against them: MAE / RMSE / bias per
     model per lead-time bucket.
  4. Turns those verified skill scores into inverse-MAE weights, so the
     consensus automatically leans toward whichever models have actually
     been most accurate *for Beacon specifically* at each lead time.

Until verification history accumulates, the consensus is an equal-weight
blend (already better than any single model on average); it then sharpens
itself as `verify` runs accumulate evidence.

Usage
-----
  beacon_forecast.py forecast [--days N] [--json]   fetch, log, print consensus
  beacon_forecast.py observations                   fetch & store station obs
  beacon_forecast.py verify                         score logged forecasts vs obs
  beacon_forecast.py report                         print the model scoreboard
  beacon_forecast.py selftest                       offline tests (no network)

All commands accept --db PATH (default: ./beacon_weather.db).

A practical loop: run `forecast` once or twice a day (cron), and
`observations` + `verify` daily. Within a couple of weeks the scoreboard
shows which models earn their weight in Beacon's Hudson-Highlands
microclimate, and the blend reflects it.

Stdlib only; requires Python 3.9+.
"""

from __future__ import annotations

import argparse
import json
import math
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Optional

try:
    from zoneinfo import ZoneInfo
    LOCAL_TZ = ZoneInfo("America/New_York")
except Exception:  # pragma: no cover - tzdata missing
    LOCAL_TZ = timezone(timedelta(hours=-5))

# ---------------------------------------------------------------- constants

LAT, LON = 41.5048, -73.9696          # Beacon, NY
OBS_STATION = "KSWF"                   # Stewart Intl ASOS, nearest hourly obs
USER_AGENT = "beacon-forecast/1.0 (github.com/ajilty/agent-skills)"

OPEN_METEO_MODELS = [
    "gfs_seamless",     # NOAA GFS + HRRR blend
    "ecmwf_ifs025",     # ECMWF IFS 0.25deg
    "icon_seamless",    # DWD ICON global + EU nests
    "gem_seamless",     # Environment Canada GEM
    "ukmo_seamless",    # UK Met Office
]
NWS_SOURCE = "nws_hourly"
ALL_SOURCES = [NWS_SOURCE] + OPEN_METEO_MODELS

# Lead-time buckets (hours) for skill scoring: forecasts degrade with lead
# time, so a model good at 12h may be mediocre at 96h.
LEAD_BUCKETS = [(0, 24), (24, 48), (48, 72), (72, 120), (120, 168)]

WEIGHT_EPS = 0.1       # deg C floor when inverting MAE into weights
MIN_SAMPLES = 24       # hours of verified data before a weight is trusted

SCHEMA = """
CREATE TABLE IF NOT EXISTS forecasts (
    issued_at   TEXT NOT NULL,   -- UTC ISO, when the forecast was fetched
    source      TEXT NOT NULL,
    valid_time  TEXT NOT NULL,   -- UTC ISO, hour the forecast is for
    temp_c      REAL,
    wind_kmh    REAL,
    precip_mm   REAL,
    precip_prob REAL,
    PRIMARY KEY (issued_at, source, valid_time)
);
CREATE TABLE IF NOT EXISTS observations (
    valid_time  TEXT PRIMARY KEY,  -- UTC ISO, top of hour
    temp_c      REAL,
    wind_kmh    REAL,
    precip_mm   REAL,
    station     TEXT
);
CREATE TABLE IF NOT EXISTS skill (
    source      TEXT NOT NULL,
    lead_lo     INTEGER NOT NULL,
    lead_hi     INTEGER NOT NULL,
    n           INTEGER NOT NULL,
    temp_mae    REAL,
    temp_rmse   REAL,
    temp_bias   REAL,
    wind_mae    REAL,
    updated_at  TEXT NOT NULL,
    PRIMARY KEY (source, lead_lo, lead_hi)
);
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT
);
"""

# ------------------------------------------------------------------ helpers


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s: str) -> datetime:
    """Parse ISO timestamps from all three APIs into aware UTC datetimes."""
    s = s.replace("Z", "+00:00")
    dt = datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def c_to_f(c: float) -> float:
    return c * 9 / 5 + 32


def http_get_json(url: str, retries: int = 3) -> dict:
    last_err: Optional[Exception] = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            last_err = e
            if attempt < retries - 1:
                time.sleep(2 ** (attempt + 1))
    raise RuntimeError(f"GET {url} failed after {retries} attempts: {last_err}")


def open_db(path: str) -> sqlite3.Connection:
    db = sqlite3.connect(path)
    db.executescript(SCHEMA)
    return db


# ----------------------------------------------------------------- fetching


def fetch_open_meteo(days: int) -> dict[str, dict[str, dict]]:
    """Return {source: {valid_time_iso: row}} for each Open-Meteo model."""
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={LAT}&longitude={LON}"
        "&hourly=temperature_2m,precipitation,wind_speed_10m"
        f"&models={','.join(OPEN_METEO_MODELS)}"
        f"&forecast_days={days}&timezone=UTC&wind_speed_unit=kmh"
    )
    return parse_open_meteo(http_get_json(url))


def parse_open_meteo(data: dict) -> dict[str, dict[str, dict]]:
    hourly = data["hourly"]
    times = [iso_utc(parse_iso(t)) for t in hourly["time"]]
    out: dict[str, dict[str, dict]] = {}
    for model in OPEN_METEO_MODELS:
        # multi-model responses suffix each variable with the model name;
        # single-model responses don't. Handle both.
        def col(var: str, model: str = model) -> Optional[list]:
            return hourly.get(f"{var}_{model}") or (
                hourly.get(var) if len(OPEN_METEO_MODELS) == 1 else None
            )

        temps, precs, winds = (
            col("temperature_2m"), col("precipitation"), col("wind_speed_10m"),
        )
        if temps is None:
            continue
        rows = {}
        for i, t in enumerate(times):
            if temps[i] is None:
                continue  # beyond this model's horizon
            rows[t] = {
                "temp_c": temps[i],
                "precip_mm": precs[i] if precs else None,
                "wind_kmh": winds[i] if winds else None,
                "precip_prob": None,
            }
        out[model] = rows
    return out


def nws_hourly_url(db: sqlite3.Connection) -> str:
    row = db.execute(
        "SELECT value FROM meta WHERE key='nws_hourly_url'"
    ).fetchone()
    if row:
        return row[0]
    points = http_get_json(f"https://api.weather.gov/points/{LAT},{LON}")
    url = points["properties"]["forecastHourly"]
    db.execute(
        "INSERT OR REPLACE INTO meta (key, value) VALUES ('nws_hourly_url', ?)",
        (url,),
    )
    db.commit()
    return url


def fetch_nws(db: sqlite3.Connection) -> dict[str, dict]:
    return parse_nws(http_get_json(nws_hourly_url(db)))


def parse_nws(data: dict) -> dict[str, dict]:
    rows: dict[str, dict] = {}
    for p in data["properties"]["periods"]:
        t = iso_utc(parse_iso(p["startTime"]))
        temp = p.get("temperature")
        if p.get("temperatureUnit") == "F" and temp is not None:
            temp = (temp - 32) * 5 / 9
        wind = None
        ws = p.get("windSpeed") or ""
        try:  # "10 mph" or "10 to 15 mph" -> take the max, convert to km/h
            nums = [float(w) for w in ws.replace("to", " ").split() if
                    w.replace(".", "", 1).isdigit()]
            if nums:
                wind = max(nums) * 1.609344
        except ValueError:
            pass
        pop = (p.get("probabilityOfPrecipitation") or {}).get("value")
        rows[t] = {
            "temp_c": temp,
            "wind_kmh": wind,
            "precip_mm": None,  # NWS hourly periods carry PoP, not QPF
            "precip_prob": pop,
        }
    return rows


def store_forecasts(
    db: sqlite3.Connection, issued_at: str, by_source: dict[str, dict[str, dict]]
) -> int:
    n = 0
    for source, rows in by_source.items():
        for valid_time, r in rows.items():
            db.execute(
                "INSERT OR IGNORE INTO forecasts VALUES (?,?,?,?,?,?,?)",
                (issued_at, source, valid_time, r.get("temp_c"),
                 r.get("wind_kmh"), r.get("precip_mm"), r.get("precip_prob")),
            )
            n += 1
    db.commit()
    return n


def fetch_observations(db: sqlite3.Connection, days_back: int = 7) -> int:
    end = utc_now()
    start = end - timedelta(days=days_back)
    url = (
        f"https://api.weather.gov/stations/{OBS_STATION}/observations"
        f"?start={iso_utc(start)}&end={iso_utc(end)}"
    )
    return store_observations(db, parse_nws_observations(http_get_json(url)))


def parse_nws_observations(data: dict) -> dict[str, dict]:
    """Keep, per top-of-hour, the reading closest to the top of the hour."""
    best: dict[str, tuple[float, dict]] = {}
    for f in data.get("features", []):
        p = f["properties"]
        ts = parse_iso(p["timestamp"])
        hour = ts.replace(minute=0, second=0, microsecond=0)
        # distance to nearest top-of-hour
        dist = min(abs((ts - hour).total_seconds()),
                   abs((ts - (hour + timedelta(hours=1))).total_seconds()))
        target = hour if abs((ts - hour).total_seconds()) <= 1800 else hour + timedelta(hours=1)
        key = iso_utc(target)
        temp = (p.get("temperature") or {}).get("value")
        if temp is None:
            continue
        row = {
            "temp_c": temp,
            "wind_kmh": (p.get("windSpeed") or {}).get("value"),
            "precip_mm": (p.get("precipitationLastHour") or {}).get("value"),
        }
        if key not in best or dist < best[key][0]:
            best[key] = (dist, row)
    return {k: v[1] for k, v in best.items()}


def store_observations(db: sqlite3.Connection, rows: dict[str, dict]) -> int:
    for valid_time, r in rows.items():
        db.execute(
            "INSERT OR REPLACE INTO observations VALUES (?,?,?,?,?)",
            (valid_time, r.get("temp_c"), r.get("wind_kmh"),
             r.get("precip_mm"), OBS_STATION),
        )
    db.commit()
    return len(rows)


# ------------------------------------------------------------- verification


def lead_bucket(hours: float) -> Optional[tuple[int, int]]:
    for lo, hi in LEAD_BUCKETS:
        if lo <= hours < hi:
            return (lo, hi)
    return None


def run_verification(db: sqlite3.Connection) -> list[dict]:
    """Score every stored forecast that now has a matching observation."""
    pairs = db.execute(
        """
        SELECT f.source, f.issued_at, f.valid_time,
               f.temp_c, f.wind_kmh, o.temp_c, o.wind_kmh
        FROM forecasts f JOIN observations o ON o.valid_time = f.valid_time
        WHERE f.temp_c IS NOT NULL AND o.temp_c IS NOT NULL
        """
    ).fetchall()

    acc: dict[tuple[str, int, int], dict] = {}
    for src, issued, valid, ft, fw, ot, ow in pairs:
        lead_h = (parse_iso(valid) - parse_iso(issued)).total_seconds() / 3600
        if lead_h < 0:
            continue
        b = lead_bucket(lead_h)
        if b is None:
            continue
        a = acc.setdefault((src, *b), {
            "n": 0, "abs_t": 0.0, "sq_t": 0.0, "sum_t": 0.0,
            "n_w": 0, "abs_w": 0.0,
        })
        err = ft - ot
        a["n"] += 1
        a["abs_t"] += abs(err)
        a["sq_t"] += err * err
        a["sum_t"] += err
        if fw is not None and ow is not None:
            a["n_w"] += 1
            a["abs_w"] += abs(fw - ow)

    now = iso_utc(utc_now())
    results = []
    for (src, lo, hi), a in sorted(acc.items()):
        n = a["n"]
        rec = {
            "source": src, "lead_lo": lo, "lead_hi": hi, "n": n,
            "temp_mae": a["abs_t"] / n,
            "temp_rmse": math.sqrt(a["sq_t"] / n),
            "temp_bias": a["sum_t"] / n,
            "wind_mae": (a["abs_w"] / a["n_w"]) if a["n_w"] else None,
        }
        db.execute(
            "INSERT OR REPLACE INTO skill VALUES (?,?,?,?,?,?,?,?,?)",
            (src, lo, hi, n, rec["temp_mae"], rec["temp_rmse"],
             rec["temp_bias"], rec["wind_mae"], now),
        )
        results.append(rec)
    db.commit()
    return results


def load_weights(db: sqlite3.Connection) -> dict[tuple[int, int], dict[str, float]]:
    """Inverse-MAE weights per lead bucket, normalized; {} until enough data."""
    weights: dict[tuple[int, int], dict[str, float]] = {}
    rows = db.execute(
        "SELECT source, lead_lo, lead_hi, n, temp_mae FROM skill"
    ).fetchall()
    for src, lo, hi, n, mae in rows:
        if n < MIN_SAMPLES or mae is None:
            continue
        weights.setdefault((lo, hi), {})[src] = 1.0 / (mae + WEIGHT_EPS)
    for b, w in weights.items():
        total = sum(w.values())
        weights[b] = {s: v / total for s, v in w.items()}
    return weights


# ---------------------------------------------------------------- consensus


def build_consensus(
    by_source: dict[str, dict[str, dict]],
    weights: dict[tuple[int, int], dict[str, float]],
    issued_at: datetime,
) -> list[dict]:
    times = sorted({t for rows in by_source.values() for t in rows})
    out = []
    for t in times:
        lead_h = (parse_iso(t) - issued_at).total_seconds() / 3600
        bucket = lead_bucket(lead_h)
        bw = weights.get(bucket, {}) if bucket else {}

        def blend(field: str) -> Optional[float]:
            vals = [(src, rows[t][field]) for src, rows in by_source.items()
                    if t in rows and rows[t].get(field) is not None]
            if not vals:
                return None
            # skill weights when any reporting source has one; otherwise
            # fall back to an equal-weight mean of whoever reports the field
            if any(bw.get(s, 0.0) > 0 for s, _ in vals):
                num = sum(bw[s] * v for s, v in vals if bw.get(s, 0.0) > 0)
                den = sum(bw[s] for s, _ in vals if bw.get(s, 0.0) > 0)
            else:
                num, den = sum(v for _, v in vals), float(len(vals))
            return num / den

        members = sum(1 for rows in by_source.values() if t in rows)
        out.append({
            "valid_time": t,
            "temp_c": blend("temp_c"),
            "wind_kmh": blend("wind_kmh"),
            "precip_mm": blend("precip_mm"),
            "precip_prob": blend("precip_prob"),
            "members": members,
            "weighted": bool(bw),
        })
    return out


def print_consensus(consensus: list[dict], by_source: dict[str, dict[str, dict]]) -> None:
    print(f"\nBeacon, NY consensus forecast "
          f"({len(by_source)} models: {', '.join(sorted(by_source))})")
    print(f"{'local time':<17}{'temp':>7}{'wind':>10}{'precip':>9}"
          f"{'PoP':>6}{'models':>8}{'blend':>10}")
    for row in consensus:
        dt_local = parse_iso(row["valid_time"]).astimezone(LOCAL_TZ)
        if dt_local.hour % 3 != 0:
            continue
        t = f"{c_to_f(row['temp_c']):.0f}F" if row["temp_c"] is not None else "-"
        w = f"{row['wind_kmh'] * 0.621371:.0f} mph" if row["wind_kmh"] is not None else "-"
        p = f"{row['precip_mm'] / 25.4:.2f}in" if row["precip_mm"] else "0.00in" \
            if row["precip_mm"] is not None else "-"
        pop = f"{row['precip_prob']:.0f}%" if row["precip_prob"] is not None else "-"
        blend = "skill-wtd" if row["weighted"] else "equal"
        print(f"{dt_local.strftime('%a %m-%d %H:%M'):<17}{t:>7}{w:>10}"
              f"{p:>9}{pop:>6}{row['members']:>8}{blend:>10}")

    # daily hi/lo summary
    days: dict[str, list[float]] = {}
    for row in consensus:
        if row["temp_c"] is None:
            continue
        d = parse_iso(row["valid_time"]).astimezone(LOCAL_TZ).strftime("%a %m-%d")
        days.setdefault(d, []).append(row["temp_c"])
    print("\ndaily:  " + "   ".join(
        f"{d} {c_to_f(max(v)):.0f}/{c_to_f(min(v)):.0f}F"
        for d, v in days.items() if len(v) >= 8))


def print_report(db: sqlite3.Connection) -> None:
    rows = db.execute(
        """SELECT source, lead_lo, lead_hi, n, temp_mae, temp_rmse,
                  temp_bias, wind_mae FROM skill
           ORDER BY lead_lo, temp_mae"""
    ).fetchall()
    if not rows:
        print("No verification data yet. Run `observations` then `verify` "
              "after forecasts have had time to come true.")
        return
    nf = db.execute("SELECT COUNT(*), COUNT(DISTINCT issued_at) FROM forecasts").fetchone()
    no = db.execute("SELECT COUNT(*) FROM observations").fetchone()
    print(f"\nModel scoreboard vs {OBS_STATION} observations "
          f"({nf[0]} forecast rows from {nf[1]} runs, {no[0]} obs hours)")
    print(f"{'lead':<10}{'source':<16}{'n':>6}{'temp MAE':>10}{'RMSE':>8}"
          f"{'bias':>8}{'wind MAE':>10}")
    current = None
    for src, lo, hi, n, mae, rmse, bias, wmae in rows:
        lead = f"{lo}-{hi}h"
        if lead != current:
            current = lead
            print("-" * 68)
        wm = f"{wmae:.1f}" if wmae is not None else "-"
        flag = "" if n >= MIN_SAMPLES else "  (low n)"
        print(f"{lead:<10}{src:<16}{n:>6}{mae:>9.2f}C{rmse:>8.2f}"
              f"{bias:>+8.2f}{wm:>10}{flag}")
    print("\nWeights used by the consensus (inverse temp-MAE, per lead bucket):")
    for bucket, w in sorted(load_weights(db).items()):
        parts = ", ".join(f"{s}={v:.2f}" for s, v in
                          sorted(w.items(), key=lambda kv: -kv[1]))
        print(f"  {bucket[0]}-{bucket[1]}h: {parts}")


# ----------------------------------------------------------------- commands


def cmd_forecast(args: argparse.Namespace) -> int:
    db = open_db(args.db)
    issued = utc_now()
    issued_iso = iso_utc(issued)
    by_source: dict[str, dict[str, dict]] = {}
    errors = []
    try:
        by_source.update(fetch_open_meteo(args.days))
    except Exception as e:
        errors.append(f"open-meteo: {e}")
    try:
        by_source[NWS_SOURCE] = fetch_nws(db)
    except Exception as e:
        errors.append(f"nws: {e}")
    for err in errors:
        print(f"warning: {err}", file=sys.stderr)
    if not by_source:
        print("error: no forecast source reachable", file=sys.stderr)
        return 1
    n = store_forecasts(db, issued_iso, by_source)
    consensus = build_consensus(by_source, load_weights(db), issued)
    if args.json:
        print(json.dumps({"issued_at": issued_iso, "location": "Beacon, NY",
                          "consensus": consensus}, indent=2))
    else:
        print_consensus(consensus, by_source)
        print(f"\nlogged {n} forecast rows at {issued_iso} -> {args.db}")
    return 0


def cmd_observations(args: argparse.Namespace) -> int:
    db = open_db(args.db)
    n = fetch_observations(db, args.days_back)
    print(f"stored {n} hourly observations from {OBS_STATION} -> {args.db}")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    db = open_db(args.db)
    results = run_verification(db)
    if not results:
        print("Nothing to verify yet: need stored forecasts whose valid "
              "times now have observations (run `observations` first).")
        return 0
    print(f"verified {sum(r['n'] for r in results)} forecast/observation pairs")
    print_report(db)
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    print_report(open_db(args.db))
    return 0


# ----------------------------------------------------------------- selftest


def selftest() -> int:
    """Offline tests over canned API fixtures - no network required."""
    failures = []

    def check(name: str, cond: bool, detail: str = "") -> None:
        status = "ok" if cond else "FAIL"
        print(f"  [{status}] {name}" + (f" - {detail}" if detail and not cond else ""))
        if not cond:
            failures.append(name)

    print("parse_open_meteo (multi-model suffixed response):")
    om_fixture = {
        "hourly": {
            "time": ["2026-07-06T00:00", "2026-07-06T01:00"],
            "temperature_2m_gfs_seamless": [20.0, 21.0],
            "precipitation_gfs_seamless": [0.0, 0.5],
            "wind_speed_10m_gfs_seamless": [10.0, 12.0],
            "temperature_2m_ecmwf_ifs025": [22.0, None],  # shorter horizon
            "precipitation_ecmwf_ifs025": [0.2, None],
            "wind_speed_10m_ecmwf_ifs025": [14.0, None],
        }
    }
    om = parse_open_meteo(om_fixture)
    check("two models parsed", set(om) == {"gfs_seamless", "ecmwf_ifs025"})
    check("gfs temp", om["gfs_seamless"]["2026-07-06T00:00:00Z"]["temp_c"] == 20.0)
    check("null horizon rows dropped", len(om["ecmwf_ifs025"]) == 1)

    print("parse_nws (hourly periods):")
    nws_fixture = {"properties": {"periods": [{
        "startTime": "2026-07-05T20:00:00-04:00",
        "temperature": 68, "temperatureUnit": "F",
        "windSpeed": "5 to 10 mph",
        "probabilityOfPrecipitation": {"value": 30},
    }]}}
    nws = parse_nws(nws_fixture)
    key = "2026-07-06T00:00:00Z"  # EDT -> UTC conversion
    check("EDT converted to UTC", key in nws, f"keys={list(nws)}")
    check("F converted to C", abs(nws[key]["temp_c"] - 20.0) < 0.01)
    check("wind range takes max, mph->kmh",
          abs(nws[key]["wind_kmh"] - 16.09344) < 0.01)
    check("PoP captured", nws[key]["precip_prob"] == 30)

    print("parse_nws_observations (nearest-to-hour dedup):")
    obs_fixture = {"features": [
        {"properties": {"timestamp": "2026-07-06T00:56:00+00:00",
                        "temperature": {"value": 19.0},
                        "windSpeed": {"value": 9.0},
                        "precipitationLastHour": {"value": None}}},
        {"properties": {"timestamp": "2026-07-06T01:10:00+00:00",
                        "temperature": {"value": 18.5},
                        "windSpeed": {"value": 8.0},
                        "precipitationLastHour": {"value": 0.3}}},
    ]}
    obs = parse_nws_observations(obs_fixture)
    check("both round to 01Z, closer reading wins",
          list(obs) == ["2026-07-06T01:00:00Z"]
          and obs["2026-07-06T01:00:00Z"]["temp_c"] == 19.0,
          f"got {obs}")

    print("consensus blend:")
    issued = parse_iso("2026-07-06T00:00:00Z")
    by_source = {
        "a": {"2026-07-06T06:00:00Z": {"temp_c": 20.0, "wind_kmh": 10.0,
                                       "precip_mm": 0.0, "precip_prob": None}},
        "b": {"2026-07-06T06:00:00Z": {"temp_c": 24.0, "wind_kmh": 20.0,
                                       "precip_mm": 1.0, "precip_prob": None}},
    }
    eq = build_consensus(by_source, {}, issued)
    check("equal-weight mean", eq[0]["temp_c"] == 22.0 and not eq[0]["weighted"])
    wtd = build_consensus(by_source, {(0, 24): {"a": 0.75, "b": 0.25}}, issued)
    check("skill-weighted mean", wtd[0]["temp_c"] == 21.0 and wtd[0]["weighted"])
    check("missing-field blend is None", eq[0]["precip_prob"] is None)
    # field reported only by a source with no skill weight falls back to
    # equal-weight mean instead of vanishing
    by_source["c"] = {"2026-07-06T06:00:00Z": {"temp_c": None, "wind_kmh": None,
                                               "precip_mm": None,
                                               "precip_prob": 40.0}}
    wtd2 = build_consensus(by_source, {(0, 24): {"a": 0.75, "b": 0.25}}, issued)
    check("unweighted-source-only field falls back to equal mean",
          wtd2[0]["precip_prob"] == 40.0 and wtd2[0]["temp_c"] == 21.0)

    print("verification + weight learning round trip (temp DB):")
    db = sqlite3.connect(":memory:")
    db.executescript(SCHEMA)
    issued_iso = "2026-07-01T00:00:00Z"
    # model 'good' is off by +1C every hour, 'bad' by +3C, across 30 hours
    for h in range(30):
        vt = iso_utc(parse_iso(issued_iso) + timedelta(hours=h))
        truth = 15.0
        db.execute("INSERT INTO forecasts VALUES (?,?,?,?,?,?,?)",
                   (issued_iso, "good", vt, truth + 1.0, None, None, None))
        db.execute("INSERT INTO forecasts VALUES (?,?,?,?,?,?,?)",
                   (issued_iso, "bad", vt, truth + 3.0, None, None, None))
        db.execute("INSERT INTO observations VALUES (?,?,?,?,?)",
                   (vt, truth, None, None, "TEST"))
    results = run_verification(db)
    by_key = {(r["source"], r["lead_lo"]): r for r in results}
    check("MAE computed per bucket",
          abs(by_key[("good", 0)]["temp_mae"] - 1.0) < 1e-9
          and abs(by_key[("bad", 0)]["temp_mae"] - 3.0) < 1e-9)
    check("bias sign correct", by_key[("bad", 0)]["temp_bias"] > 0)
    w = load_weights(db)
    check("0-24h bucket has trusted weights (n>=MIN_SAMPLES)", (0, 24) in w)
    check("24-48h bucket excluded (only 6 samples)", (24, 48) not in w)
    if (0, 24) in w:
        check("better model gets more weight",
              w[(0, 24)]["good"] > w[(0, 24)]["bad"])
        check("weights normalized",
              abs(sum(w[(0, 24)].values()) - 1.0) < 1e-9)

    print("forecast storage idempotence:")
    n1 = store_forecasts(db, "2026-07-02T00:00:00Z",
                         {"a": {"2026-07-02T06:00:00Z": {"temp_c": 1.0}}})
    store_forecasts(db, "2026-07-02T00:00:00Z",
                    {"a": {"2026-07-02T06:00:00Z": {"temp_c": 99.0}}})
    row = db.execute(
        "SELECT temp_c FROM forecasts WHERE issued_at='2026-07-02T00:00:00Z'"
    ).fetchone()
    check("INSERT OR IGNORE keeps first-logged value (auditability)",
          n1 == 1 and row[0] == 1.0)

    print()
    if failures:
        print(f"selftest FAILED: {len(failures)} failing check(s): {failures}")
        return 1
    print("selftest passed: all checks ok")
    return 0


# --------------------------------------------------------------------- main


def main(argv: Optional[list[str]] = None) -> int:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--db", default="beacon_weather.db",
                        help="SQLite path (default: ./beacon_weather.db)")
    ap = argparse.ArgumentParser(
        description="Verifiable multi-model consensus forecast for Beacon, NY")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("forecast", parents=[common],
                       help="fetch all models, log, print consensus")
    p.add_argument("--days", type=int, default=7, choices=range(1, 8))
    p.add_argument("--json", action="store_true")
    p.set_defaults(fn=cmd_forecast)

    p = sub.add_parser("observations", parents=[common],
                       help="fetch & store station observations")
    p.add_argument("--days-back", type=int, default=7)
    p.set_defaults(fn=cmd_observations)

    p = sub.add_parser("verify", parents=[common],
                       help="score logged forecasts against obs")
    p.set_defaults(fn=cmd_verify)

    p = sub.add_parser("report", parents=[common],
                       help="print model scoreboard & weights")
    p.set_defaults(fn=cmd_report)

    p = sub.add_parser("selftest", help="offline logic tests, no network")
    p.set_defaults(fn=lambda a: selftest())

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
