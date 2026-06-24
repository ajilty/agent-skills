---
description: Record a one-line effectiveness rating + a ledger-derived metrics snapshot for the current run (Tier 3c feedback loop).
---
Capture operator feedback on the current orchestrate run and append a durable record
to the eval log — the live, observational complement to the headless A/B eval.

From the repo root (where `.agents/runs/orchestrate/board.jsonl` lives), run:

`bash ${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/runtime/ledger.sh feedback "$ARGUMENTS"`

Then read back the printed snapshot and give the operator a two-line read of how the
run went, per SKILL §8: **shipped** changes, and **healthy** escalations
(forks/decisions — the tool correctly surfacing hard calls) versus **friction**
(rejects, oracle-inconsistencies, lease-conflicts — the number to drive down). The
record is appended to `.agents/runs/orchestrate/eval/feedback.jsonl` for trend
tracking; the free-text note is whatever the operator passed as arguments.
