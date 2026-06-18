# Judgment memory is in-repo and tracked, never harness memory

Decisions made across goals must travel with the repo to any user, clone, or
harness. We persist them as **tracked `docs/adr/` records** (plus an `INDEX.md`),
recorded from the existing `DECISION_FORK` / `#DECISION` flow — not in
harness/conversation memory (e.g. Claude Code memory), which the next user of the
repo would not have, and which would break orchestrate's harness-neutral,
no-lock-in invariant.

## Consequences

A small write step in the loop persists an ADR at fork-resolution (operator-gated
promotion; all resolutions are recorded to `board.jsonl` regardless). Recall is
the Planner reading `docs/adr/INDEX.md` at intake; a goal that contradicts an
active ADR raises a `DECISION_FORK` citing it (supersede flow). An ADR whose
justification traces to `UNTRUSTED` provenance is invalid, exactly like a
`#DECISION`.
