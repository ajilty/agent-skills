---
name: spec
description: "Shipyard segment 3: turn the committed direction into testable requirements and a build spec"
disable-model-invocation: true
---

# Spec: requirements and design

Convert the committed direction into something build-ready and testable.

The discipline is requirements-engineering canon: ISO/IEC/IEEE 29148
verifiability, BABOK traceability with MoSCoW prioritization, ISO/IEC/IEEE
42010 architecture description, Nygard decision records, Amazon's one-way
and two-way doors.

Read `references/conventions.md` in this skill's directory first. Input:
the returned
memo at `docs/shipyard/<work-slug>/memo.md` and
the decision log, read from disk. Memo decisions are settled; this segment
never re-opens them. A commitment stated directly by the human at invocation
substitutes for a returned memo (record it in the decision log as
human-confirmed); no commitment at all means stop and name `/shape`: a
commitment is never inferred.

## Steps

1. **Derive requirements from the memo decisions**: functional and
   non-functional, every one testable to the 29148 bar (verifiable,
   unambiguous), prioritized (MoSCoW), and traceable to the decision it
   serves.
2. **Produce the build spec**: architecture and design decisions with
   rationale (a 42010-style architecture description in miniature), plus
   the implementation plan.
3. **Triage every design decision with the Amazon door test.**
   Two-way doors: decide, record in the decision log, move on; the human
   never sees these unless something breaks. One-way doors: escalate each
   as it is hit, not batched at the end, each with a default and a deadline
   ("schema decision, reversible until Thursday, going with X"). Work
   continues on the default; it never blocks waiting for the answer.
4. **Only two escalation triggers exist**: a material gap discovered in
   scope/shape output, and a one-way door the memo does not already cover.
   Nothing else escalates. The human sees two to four decisions out of
   dozens; suppressing the rest is this segment's job.
5. **Write the dual outputs** to `docs/shipyard/<work-slug>/`:
   - `requirements.md` and `build-spec.md`.
   - append every triaged decision to `decision-log.md`, two-way doors
     included, marked asserted vs confirmed: Nygard's record spirit
     (decision, context, consequences) in prose.
6. **Pause 3: stop.** The human approves the one-way doors (about a
   two-minute read): the last point where changing course costs an edit
   instead of a rebuild. End by naming the next command: `/ship`.

Completion criterion: `requirements.md` (testable, prioritized, traceable)
and `build-spec.md` exist on disk, every design decision appears in the
decision log, open one-way doors carry a default and a deadline, and the
segment has stopped at Pause 3 naming `/ship`.
