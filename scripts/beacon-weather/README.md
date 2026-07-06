# Beacon, NY — verifiable consensus weather forecast

A single-file, stdlib-only Python script (`beacon_forecast.py`, Python 3.9+)
that produces the most accurate point forecast achievable for Beacon, NY with
free public data — and, unlike a weather app, can *prove* how accurate it has
been.

## Why this approach

Two well-established results from forecast verification drive the design:

1. **Consensus beats any single model.** A blend of independent numerical
   weather prediction models has lower average error than even the best
   individual member, because model errors are partially uncorrelated.
2. **Skill is local and lead-time dependent.** Which model is best varies by
   location and by how far out the forecast is. Beacon's Hudson-Highlands
   setting (river-gap winds, valley cold-air damming, sharp snow/rain lines)
   makes locally-measured skill especially valuable.

So the script blends six independent forecast sources, and continuously
measures each one's actual error *at Beacon* to weight the blend:

| source | provider |
|---|---|
| `nws_hourly` | NOAA/NWS gridpoint forecast (human-adjusted) |
| `gfs_seamless` | NOAA GFS + HRRR |
| `ecmwf_ifs025` | ECMWF IFS |
| `icon_seamless` | DWD ICON |
| `gem_seamless` | Environment Canada GEM |
| `ukmo_seamless` | UK Met Office |

## What makes it verifiable

- Every model's hourly forecast is logged to SQLite **before the fact**,
  keyed by issue time. Logging is `INSERT OR IGNORE` — first write wins, so
  the record can't be quietly rewritten after the weather happens.
- Ground truth is real ASOS surface observations from **KSWF** (Stewart
  Intl, ~11 km from Beacon), fetched from the NWS API — independent of every
  forecast source being scored.
- `verify` joins logged forecasts to observations and computes MAE, RMSE,
  and bias per model per lead-time bucket (0–24h, 24–48h, 48–72h, 72–120h,
  120–168h). `report` prints the scoreboard.
- Verified skill feeds back into the forecast: consensus weights are
  inverse-MAE per lead bucket (only after ≥24 verified hours; equal weights
  until then). The blend literally sharpens as evidence accumulates.

## Usage

```sh
./beacon_forecast.py forecast            # fetch all models, log, print consensus
./beacon_forecast.py forecast --json     # machine-readable output
./beacon_forecast.py observations        # store recent KSWF observations
./beacon_forecast.py verify              # score past forecasts, update weights
./beacon_forecast.py report              # model scoreboard + current weights
./beacon_forecast.py selftest            # offline logic tests (no network)
```

All commands take `--db PATH` (default `./beacon_weather.db`). No API keys
required; both APIs (api.weather.gov, api.open-meteo.com) are free.

A practical cron setup:

```cron
0 6,18 * * *  /path/to/beacon_forecast.py --db ~/beacon.db forecast --json > /dev/null
30 6   * * *  /path/to/beacon_forecast.py --db ~/beacon.db observations && \
              /path/to/beacon_forecast.py --db ~/beacon.db verify > /dev/null
```

After ~2 weeks the scoreboard shows which models earn their weight in
Beacon's microclimate. Example (simulated data):

```
lead      source               n  temp MAE    RMSE    bias  wind MAE
--------------------------------------------------------------------
0-24h     ecmwf_ifs025       168     0.65C    0.81   -0.11       0.0
0-24h     nws_hourly         168     1.04C    1.27   -0.09       0.0
0-24h     gfs_seamless       168     1.22C    1.54   -0.05       0.0

Weights used by the consensus (inverse temp-MAE, per lead bucket):
  0-24h: ecmwf_ifs025=0.45, nws_hourly=0.30, gfs_seamless=0.26
```

## Design notes & limits

- **Units**: everything is stored metric/UTC (°C, km/h, mm); display is
  local time (America/New_York), °F, mph, inches.
- **Observations vs. Beacon proper**: KSWF is the nearest station with
  reliable hourly ASOS data. It sits across the Hudson, so verified skill is
  "skill at the Beacon river gap", which is the right neighborhood for
  temperature and wind. There is no public hourly station in Beacon itself.
- **Precipitation**: model QPF (mm) comes from the Open-Meteo members; the
  NWS source contributes probability-of-precipitation. Verification
  currently scores temperature and wind — station hourly precip at KSWF is
  too spotty to be fair ground truth.
- **Bias column matters**: a model with a consistent cold bias at Beacon is
  correctable; the report exposes it even though the current blend only uses
  MAE.
- `selftest` runs 19 fixture-based checks (API parsing for both providers,
  timezone conversion, consensus math, weight learning, append-only logging)
  with zero network — CI-friendly.
