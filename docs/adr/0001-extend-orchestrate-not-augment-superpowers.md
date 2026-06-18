# Extend orchestrate rather than augment superpowers

We need a standing operator loop that delivers strong assurances — fail-closed
enforcement, single-writer, trust quarantine, durable resume — *and* lightweight
"throw it a goal" ergonomics. The assurances are almost entirely orchestrate's
mechanism; superpowers provides them only by convention (prompt-asserted, no
capability sandbox, markdown ledger). So we make orchestrate the single loop and
borrow superpowers / mattpocock grilling skills for the interactive front-end by
reference, rather than augmenting the superpowers spine.

## Considered options

- **Augment superpowers** — add skills to its spine. Lightest, but forfeits the
  hard assurances (capability enforcement, target leasing, quarantine, durable
  board) that are the entire point.
- **Thin layer over both** — a controller delegating to superpowers (front-end)
  and orchestrate (execution). Best-of-both on paper, but runs two live state
  machines (`board.jsonl` + `.git/sdd`) and carries the most integration debt.

## Consequences

orchestrate keeps its weight (`yq`, worktrees, per-harness compile step).
superpowers and grilling skills are used **by reference for their work**, never
as executors (see [ADR-0004](0004-router-owns-sequencing.md)).
