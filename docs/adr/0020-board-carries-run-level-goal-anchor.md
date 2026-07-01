# The board carries a run-level goal anchor, so a clean board is still resumable

Field report (ADR-0019 sibling): a run's board had no open lanes ("clean"), so all
resumability lived in a densely-written external `STATUS.md` — the orchestration
lane-state carried zero redundancy across compaction. `board.jsonl` records per-ticket
lane events (what happened), not the run's goal or a pointer to the plan, so `reground`
on a clean board reported "no open lanes" and a resumed agent had no durable north star
or next-step location. `STATUS.md` is **not** an orchestrate artifact (it is an
operator/handoff doc), so orchestrate's own durable state did not carry the goal at all.

**Decision.** Add one run-level board event, `goal`, journaled at intake (the spec path
filled in once the Planner signs it): `{"event":"goal","note","spec"}` with **no ticket
field** (reground's lane loop skips no-ticket lines, so it is never mistaken for a lane).
`reground` surfaces the latest `goal` even when no lanes are open
(`GOAL: <note> -> resume from plan: <spec>`) and annotates "no open lanes" with a reminder
that the goal stays open until the plan is complete. The plan itself is **not** duplicated
onto the board — it lives durably in the signed spec/ADR (ordered tasks); the `goal` event
only anchors the board to the north star and points at where the plan lives.

## Considered options
- **Duplicate structured plan / phase / next-action state into `board.jsonl`** — rejected:
  the plan is an artifact an LLM both authors and consumes (the spec/ADR); copying it into
  the board duplicates state and invites drift. Reserve board structure for what the
  deterministic consumers (reground / metrics / conformance) need — a *pointer*, not the
  plan. (This is the house rule against schematizing LLM-produced-and-consumed artifacts.)
- **Make `reground` parse the spec to count specced-but-undone tasks** — rejected: couples
  reground to spec format; the `goal` event's `spec` pointer lets a human or agent open the
  plan directly, no parser required.
- **Keep relying on `STATUS.md` / an external handoff doc** — rejected: that *is* the single
  point of failure the field report named; orchestrate's durable state must carry its own
  north star.

## Consequences
- New `ledger.sh goal <note> [spec]` event + `reground` surfacing; `resume.md` vocabulary
  and the SKILL intake step updated; covered by `tests/test_goal_anchor.sh`. No persona body
  changed, so `agents/` is unaffected.
- A clean board no longer reads as "finished": `reground` shows the goal + plan pointer and
  flags that completion must be verified against the plan.
- Deliberately adds no phase/next-action structure. If a run needs finer resume state, the
  spec/ADR is the place for it, not the board.

## Status

active
