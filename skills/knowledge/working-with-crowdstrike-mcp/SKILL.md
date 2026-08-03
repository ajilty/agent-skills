---
name: working-with-crowdstrike-mcp
description: Sharp edges and efficiency patterns for the CrowdStrike Falcon MCP (falcon-mcp), especially falcon_search_ngsiem (CQL/LogScale queries) and the search_* FQL tools. Use when querying CrowdStrike NG-SIEM, Falcon detections/hosts/incidents, or ingested third-party logs via any falcon_* tool — to avoid wasted round-trips, empty result sets from wrong field names, silently-truncated groupBy aggregations, and slow or timed-out queries.
---

# Working with the CrowdStrike Falcon MCP — sharp edges

How to drive `falcon-mcp` efficiently and correctly. This is about operating the tool; what
specific log fields *mean* belongs in your own per-source notes.

## falcon_search_ngsiem (CQL / LogScale dialect)

**The tool runs CQL; it does not help you write it.** You must supply a complete, valid query.
There is no query-builder assist — a malformed query just fails or returns nothing.

### Discover the schema before you aggregate

Field names vary by parser version and data source — **never assume them**. Sample first:

```
<filter> | head(3)
```

Read the real field names off a couple of records, *then* write the `count()`/`top()`. A
`top(some_field)` against a field that doesn't exist returns **empty with no error**, which looks
like "no data" and wastes a round-trip.

Also check for sampling: some sources (e.g. Cloudflare Magic Firewall, `#Vendor=cloudflare`)
carry a `SampleInterval` — logged event counts understate actual rates by that factor; say so
when reporting rates.

### Filter on indexed tags, not free text

Tag fields are in the segment index; raw-payload free text is not. Prefer
`#repo=<repo> #event.dataset=<ds> event.action=blocked` over a bare free-text token. Common
tags: `#repo`, `#Vendor`, `#type`, `#event.dataset`, `#event.module`, `#event.kind`.

### Pick the right repository

The `repository` param scopes the search and speeds it up: `search-all` (default, slowest),
`third-party` (ingested feeds — proxy, SaaS, cloud audit connectors; contents vary by estate),
`investigate_view` (endpoint events), `falcon_for_it_view`, `forensics_view`. Learn what your
estate routes into `third-party` — connector-fed audit logs there (e.g. GitHub enterprise) can
give enterprise-wide visibility that per-API queries can't.

### Time + timeout

- `start` is **required**, ISO-8601 (`2026-05-25T00:00:00Z`). `end` defaults to now.
- Searches time out at `FALCON_MCP_NGSIEM_TIMEOUT` (default **300s**). Narrow the window and add
  filters before widening; don't open a 30-day `search-all` as a first move.

### Aggregation idioms that pay off

- `top(field, limit=N)` → ranked frequency table with an auto `_count` column. The fastest way
  to find outliers.
- `groupBy([f1, f2], function=count())` → cross-tab over multiple fields.
- **`groupBy(field, limit=N)` does NOT keep the top-N by count — it keeps the
  lexicographically-first N groups, and a trailing `sort()` only ranks that already-truncated
  subset.** So `groupBy(user.name, limit=25) | sort(_count, order=desc)` on a high-cardinality
  field silently drops every group after the first 25 *alphabetically* — the real highest-count
  value never enters the candidate set, and the result looks plausible but is wrong. For
  "who/what has the most," use `top(field, limit=N)`. Reserve `groupBy(…limit…)` for when you
  want *all* groups — set the limit above the true cardinality.
- `timechart(span=1h, series=field)` → time buckets (`_bucket` is epoch-ms). A flat overnight
  floor vs a diurnal shape distinguishes automation from human activity; a clean step-and-hold
  cliff is a *config* change while a human tapers raggedly — the **shape of the transition is
  itself evidence of the cause**.
- `sum(field, as=name)` → totals (e.g. bandwidth from a transaction-size field).
- Always cap exploration with `head()`; aggregate rather than dumping raw rows.

### Result-shape gotchas

- **Numbers come back as strings** (`"_count": "2773932"`). Cast before doing math.
- **Large spilled results carry no `total` field** — a spill file's record count is not the
  query's total; re-run with an in-query `count()` if the total matters.
- A single-row `top()` when you expected a distribution is **signal, not failure**: the behavior
  is entity-specific (one host/user), which redirects the investigation.
- Empty output ≠ no data — first suspect a wrong field name or wrong `repository`.
- **A raw record dump overflows the token cap and spills to a file.** `<filter> | head(N)` for
  more than a handful of wide records blows past the MCP's max-token guard; the tool writes the
  full result to a `tool-results/*.txt` path and hands you the path, not the data. Two
  consequences: (1) **aggregate in-query** (`groupBy`/`top`/`count` on the few fields you need)
  instead of dumping full records; (2) when you *do* parse a spilled file, **the elements are
  not uniformly one-JSON-object-per-line** — a `jq -s '.[].text | fromjson'` pass dies because
  some `.text` elements are bare fragment lines (`"@id": …`), not whole objects. Guard each
  parse (`try fromjson`, or a `try/except json.loads` loop).

### CQL construction gotchas

- **`OR` across two `regex()` calls → HTTP 400.** Reformulate as field-match alternation
  (`field=/.../i or field=/.../i`) rather than chaining `regex(...)` OR `regex(...)`.
- **`falcon_search_detections` ignores its free-text `q` param** (resolves to a null filter).
  Use explicit FQL field filters (`cmdline:`, `sha256:`, `device.hostname:`).
- **CVE FQL is dotted: `cve.id:'…'`, not bare `cve:'…'`** — the bare form returns HTTP 400
  across the vuln/intel tools.
- **A clean-empty result for a fresh CVE is the CORRECT answer, not an error.** Differentiate by
  **response shape**: a well-formed query returns an empty set (HTTP 200, empty array); a wrong
  field name or bad syntax returns a 400. Don't retry an empty-but-valid result as if it failed.
- **Anchor regexes when a substring can collide.** A case-insensitive `useragent=/iOS/i` matches
  `axios/1.15.2` and silently pulls the wrong platform into the filter. Use an exact-value pivot
  or anchor the pattern (`/^iOS\//`).
- **Render times with the tz database, sort on the raw field:**
  `formatTime(@timestamp, timezone="<your tz>")`, and **sort on `@timestamp`, not the formatted
  string** — this delegates DST handling instead of hardcoding an offset.

### Parallelize independent queries

Independent breakdowns (by action, by destination, a timechart) have no dependencies — issue
them as **multiple tool calls in one message**. Only serialize when a later query needs an
earlier one's output (e.g. `head(3)` to learn field names before `top()`).

## search_* FQL tools (detections, hosts, incidents, cases, ...)

- These take **FQL**, not CQL — different syntax. Many have a companion FQL guide resource
  (`falcon://<domain>/.../fql-guide`); consult it before composing non-trivial filters.
- FQL combines predicates with `+` (AND), e.g. `status:'new'+severity:>70`.
- `sort` accepts both `field.desc` and `field|desc`; sort `severity.desc` to surface the worst
  first.

## Write path and console deep-links

- **Console deep-link: use the detection's own `falcon_host_link` field, verbatim** (shape
  `https://falcon.crowdstrike.com/unified-detections/<composite_id>?_cid=<code>`). Do **not**
  hand-build a `…/unified-detections/?filter=…&info=<id>` URL — it renders an **unfiltered**
  detections page, not the target detection.
- **`falcon_update_detections` (status / resolution tag / comment / assignment)** works and is
  batchable (many `ids` per call). Gotchas:
  - The top-level **`comment` rollup field returns word-scrambled** — read the structured
    **`comments[]` array** instead (each entry has `falcon_user_id`, `timestamp`, `value`).
  - Comments post under the **API-client identity**, not the human — name the human in the
    comment text if attribution matters. (A secrets-manager-fronted credential may even render
    the author as concealed.)
  - Resolution is **tag-based**: apply `true_positive` / `false_positive` / `ignored` to
    populate the console's Resolution column; `status:closed` alone does not.

## Common third-party correlation edges (if your estate ingests these sources)

- **Microsoft 365 / Exchange audit in NG-SIEM:** Defender-passthrough detections in Falcon carry
  no target mailbox or operation — the NG-SIEM pivot into the M365 audit rows is mandatory, not
  an enrichment. Admin-account actor UPNs in Exchange audit use the tenant's
  `<tenant>.onmicrosoft.com` domain — a primary-domain filter silently misses them. Subjects are
  nested (`Vendor.Folders[N].FolderItems[M].Subject`), not flat — `head(3)` first.
- **Mail-flow count inflation is the norm; dedupe before reporting.** One logical message
  produces many rows: one Message Trace `Delivered` per recipient leg, a duplicate for any
  journaling/archiving compliance fork, a multi-stage gateway pipeline (receipt → spam → process
  → delivery), plus one `MailItemsAccessed` per open. Dedupe on message-ID + recipient; expect
  2-3x raw inflation. `Status: Expanded` marks distribution-list fan-out, not a delivery.
- **Tenant boundary:** the SIEM sees only legs that touch your tenant — an external
  participant's intra-external hops are invisible. `MailItemsAccessed` proves *a client fetched
  it*, not *a human saw it*; `MailAccessType` `Bind` (explicit open) vs `Sync` (background pull)
  disambiguates.
- **Zscaler ZIA ↔ Falcon sensor join:** `zia.web` rows are pre-enriched with the device's Falcon
  AID (`source.Id`/`client.Id` *is* the sensor `aid`) — an exact join, not a fuzzy hostname
  match. The trap: on a tunnel-client host, endpoint DNS/NetworkConnect telemetry attributes
  egress to the tunnel process (`ZSATunnel.exe`), not the real browser — proxy UA and endpoint
  network layer diverge, and naming the exact originating process definitively needs RTR live
  (`rtr_state: enabled`); everything short of that is strong inference, not proof.
- **Web requests double-log through a decrypting proxy:** a CONNECT to `host:443` with the
  tunnel UA, then the decrypted request with `useragent="Unknown"`. For one row per session,
  filter on the CONNECT leg (e.g. `url=/:443$/`).

## What this skill does not cover

Per-source field semantics (what a given vendor's fields mean) — keep those in your own
data-source notes and let this skill stay about operating the MCP.

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
