# Decision log: vuln-tracking-d

- 2026-08-07: problem confirmed by the manager (Pause 1 passed). Confirmed.
- 2026-08-07: memo returned picking build-on-ticketing-API with read-only
  constraint (Pause 2 passed). Confirmed.
- 2026-08-07: one-way doors approved: 1:1 data model, read-only auth
  (Pause 3 passed). Confirmed.
- Two-way doors, asserted: retry is exponential backoff, capped; dashboard
  is a minimal built-in view; tags reuse existing ticket labels.
