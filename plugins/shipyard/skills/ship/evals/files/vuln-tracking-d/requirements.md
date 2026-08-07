# Requirements (vuln-tracking-d)

Traceability root: returned memo (build on ticketing API, read-only v1).

- REQ-1 (Must): every scanner finding matching the remediation filter
  appears as a tracked item within one sync cycle. [trace: memo pick]
- REQ-2 (Must): each open item shows owning team, age, and SLA state;
  thresholds configurable. [trace: memo pick]
- REQ-3 (Must): a pre-breach alert fires exactly once per item at 80% of
  the SLA window. [trace: memo pick]
- REQ-4 (Should): sync is webhook-driven for near-real-time updates.
  [trace: build spec]
- REQ-5 (Should): each team receives a per-team Slack digest of open and
  overdue items. [trace: memo pick]
- REQ-6 (Must): the service holds read-only credentials to the ticketing
  API. [trace: memo constraint]
