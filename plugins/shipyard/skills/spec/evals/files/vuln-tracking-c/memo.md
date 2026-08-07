# Decision memo: direction (vuln-tracking-c) [RETURNED]

Desired state: a single tracked view; one owner per finding; pre-breach
alerts.

Gap: no shared tracking layer; ownership unassigned for a subset of assets.

Options, scored as deltas from the accepted baseline (drivers shown):

1. Do nothing: keeps the 10 hrs/week chase and late breach discovery; risk
   grows with the backlog.
2. Defer one quarter: same as (1) plus queue growth; frees this quarter.
3. Buy a vulnerability-management platform: strongest ceiling; new spend,
   procurement, migration.
4. Build a lightweight tracking service on the existing ticketing API: fits
   the scope exactly; cheapest; ceiling limited to tracking/reporting.
   RECOMMENDED.

Pre-mortem: the embarrassed-in-12-months pick is (3) if spend outpaces use,
or (1) if a breach lands late.

--- MEMO (returned by the manager, 2026-08-07) ---

- [x] Option 4: build on the ticketing API. PICKED as-is.
- Constraint added: v1 uses read-only API access; write-back is a later
  decision.
- [ ] Option 3 rejected: no new platform spend this year.
