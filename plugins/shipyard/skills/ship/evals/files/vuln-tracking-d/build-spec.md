# Build spec (vuln-tracking-d)

Architecture: sync worker (webhook consumer) -> small store -> SLA engine ->
alerter (Slack) + read-only dashboard.

One-way doors approved at Pause 3: data model is a 1:1 projection of
tickets; read-only auth (via memo constraint).

Two-way doors decided in the decision log: retry/backoff shape, dashboard
framework, tag reuse.

Plan: sync -> SLA engine -> alerts -> dashboard; verify against
requirements.md; delta report at the end.
