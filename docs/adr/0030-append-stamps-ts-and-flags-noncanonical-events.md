# `ledger.sh append` stamps ts and flags non-canonical events; helpers must out-earn raw echo

Harvest round 3 (2026-07-17, infrastructure board): 311 of 503 board lines carried no
`ts` field, and every recent event except `done` was timestamp-less. Root cause was not
router forgetfulness in general — it was economics. The old `append` was a zero-value
passthrough (`printf '%s\n' "$*" >> "$LEDGER"`), so routers rationally hand-echoed raw
JSON with whatever fields they remembered. `done` alone hit 100% ts compliance, because
that helper does real work (the fail-closed verdict check) and so is always used. Missing
`ts` degrades status pace, lease-staleness reasoning, feedback timestamps, and any
time-bucketed cross-run analysis. The same board's historical event-name zoo (`dispatch`,
`fix`, `apply`, ~40 names) shows the sibling failure the same door admits.

**Decision.** A ledger helper must earn its keep, or the prose telling routers to use it
will lose to `echo >>`. `append` now (a) stamps `ts` (UTC) when the JSON lacks it,
(b) warns on stderr when `event` is outside the canonical vocabulary, and (c) **never
drops the line** — on an append-only journal a mis-named event beats a lost one, so
validation informs, it does not reject. SKILL.md and resume.md say: journal via
`ledger.sh append`, never a raw echo to the board.

## Considered options
- **Prose-only ("always include ts")** — rejected: the vocabulary prose already existed
  and lost; write-time mechanics beat contract prose (same lesson as ADR-0019's
  commit-proof and the fail-closed `done`).
- **Fail-closed on a non-canonical event** — rejected: a router mid-run with a newer
  SKILL than its installed runtime would lose events; losing journal lines is strictly
  worse than a wrong name that a warning surfaces.
- **Read-side tolerance (make consumers cope with missing ts)** — rejected: every
  consumer would need the workaround forever; one write-side stamp fixes all of them.

## Consequences
- Test fixtures that plant boards via `append` now produce ts-stamped lines for free,
  and the suite asserts the every-line-has-ts invariant (`test_append_contract.sh`) —
  the invariant the old suite never encoded, which is why deterministic tests missed it.
- Boards written by older runtimes keep their ts-less history; consumers already treat
  ts as optional-on-read.

## Status

active
