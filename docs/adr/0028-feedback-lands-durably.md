# Run feedback lands durably: review sidecar, version stamp, dev-side harvest

The plugin's improvement loop ran on the operator hand-copying session feedback into the
dev session — lossy and painful (operator, 2026-07-14: "a pain for me to keep copying it
to you"). The durable channel existed (`ledger.sh feedback` → per-repo
`eval/feedback.jsonl`) but broke at both ends: the two richest reviews never landed
(routers reported they could not run shell at feedback time, and the note field is
one-liner-shaped, so qualitative content had nowhere to go), and nothing on the dev side
ever read the files — the operator was the transport.

**Decision.** Fix both ends; add no new storage:
- **Source (target repos):** the full qualitative review is written to
  `eval/reviews/<UTC-ts>.md` (each point tied to a specific dispatch with evidence — the
  shape field reviews organically converged on), with the `feedback` row's note pointing
  at it. Rows are stamped with `plugin_version` (read from the plugin manifest by
  `ledger.sh`), so trends attribute to releases instead of operator memory. Feedback
  journaling is a SKILL wrap-up loop step (step 6), not only an operator invocation; when
  shell is unavailable, the command prints the exact `ledger.sh feedback` line for the
  operator (bare name resolves via the ADR-0018 shims).
- **Dev side (this repo):** a `/harvest-feedback` project command reads the local live
  repos' `feedback.jsonl` + review sidecars read-only, correlates each improvement item
  against ADRs/TODO (fixed / ticketed / NEW / recurrence — recurrence promotes to fix,
  per the ADR-0026 precedent), and proposes ranked changes.

## Considered options
- **Central spool (`~/.local/share/orchestrate/feedback.jsonl`)** — deferred, not
  rejected: it earns its keep only when live repos leave this machine, and it composes
  with this design later (harvest reads one more path). Avoids out-of-repo state today.
- **Tracked-axis feedback (commit reviews to the target repo's `docs/`)** — rejected:
  publishes run reviews into the live repo's history, a posture call the plugin should
  not presume (ADR-0005 keeps run state on the gitignored axis).
- **Status quo (operator pastes)** — rejected: the measured pain, plus unversioned and
  lossy.

## Consequences
- `ledger.sh feedback` stamps `plugin_version`; `commands/feedback.md` carries the review
  shape + sidecar + no-shell fallback; SKILL gains wrap-up step 6; the dev repo commits
  `.claude/commands/harvest-feedback.md`. Covered in `test_metrics_feedback.sh`.
- Harvest is machine-local by design (both repos live on one machine today); the central
  spool is the named follow-up if that changes.

## Status

active
