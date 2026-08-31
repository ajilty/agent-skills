---
name: working-with-splunk-mcp
description: "Splunk MCP gotchas: `Request failed: Session is not logged in.` is session expiry not a bad query (known splunklib bug), only one splunk_run_query lands per re-prime so never batch them, splunk_get_indexes size/count fields are stubbed placeholders, numbers come back as strings. Use when a splunk_run_query fails mid-session, when picking an index to search, or before firing multiple searches at once."
---

# Working with the Splunk MCP — sharp edges

Operating mechanics for the Splunk (Cloud) MCP tools (`splunk_run_query`, `splunk_get_*`, the
`saia_*` assistant tools). These are `splunklib` (splunk-sdk-python) behaviors, true of any
Splunk MCP surface, not one server.

## Auth / session

- **`Request failed: Session is not logged in.` is session expiry, not a bad query or a
  permission problem.** The identical query succeeds once the session is live. It is a known
  upstream `splunklib` session-key bug — auto-relogin "succeeds, but there was an auth error on
  the next request" (`splunk-sdk-python` #486), persisting across SDK versions. The real fix is
  server-side (token/JWT auth, or upgrading the connector), so do **not** try to fix it from the
  query side.
- **Re-prime, then send exactly one search.** A `splunk_get_*` metadata call (`splunk_get_info`,
  `splunk_get_user_info`) re-establishes the session. Follow it with the search.
- **Only one `splunk_run_query` reliably lands per re-prime, and it degrades over a long
  session** — later re-primes stop holding.
- **Never batch multiple `splunk_run_query` calls in one message.** They serialize through a
  single session and every call after the first fails with the session error. Issue them one per
  turn.
- On the error, re-run a `get_*` call and resend a single search — don't blind-retry the same
  query as if it were malformed.

## Choosing an index

- **`splunk_get_indexes` size/count fields are stubbed.** It returns `currentDBSizeMB: "1"` and
  `totalEventCount: "0"` for *every* index regardless of real contents, and caps the list
  (`truncated: true`, with the real count in `total_rows`). You cannot use these fields to find
  which index holds data — they are placeholders.
- Pick candidate indexes by name / domain knowledge, then confirm by searching:
  `... | stats count by index`. Empty output means wrong index or wrong window, not "no such
  data."

## Result shapes

- **Numbers come back as strings** (`"count": "28"`). Cast before doing math or comparisons.
- **A raw-event `| table ...` dump overflows the response cap and spills to a
  `tool-results/*.txt` file** — the tool hands you the path, not the rows. Aggregate in-query
  (`stats`/`chart`/`top` on the few fields you need) instead of tabling wide raw events; `grep`
  the spill file when you must parse one.
- **A substring match on a bare token is a false-positive trap.** A search term like `8041`
  matches that string anywhere in an event (an ephemeral port, a byte count), not just the field
  you meant. Anchor to the field (`dest_port=8041`) or a distinctive multi-character IOC, and
  sanity-check the time span before concluding a hit is real.

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
