---
name: scope
description: "Shipyard segment 1: turn a raw ask into a confirmed problem statement"
disable-model-invocation: true
---

# Scope: intake and discovery

Turn a raw ask into a confirmed problem. No solution talk: options, tools,
and approaches belong to `/shape`; if they appear in a draft here, move them
out and return to the problem.

Read `../../references/conventions.md` (relative to this skill's directory)
first: it defines the engagement ranking, escalation rules, silence
semantics, dual outputs, and scaling rule this segment applies.

## Steps

1. **Research before asking.** Establish from systems, docs, and data, not
   only from the human: who has the problem, what is true today, what
   success looks like. Label every claim sourced or inferred.
2. **Draw the boundary.** Explicitly in and explicitly out. An adjacent
   problem discovered during research goes into the write-up as
   out-of-scope, never silently into scope.
3. **Register assumptions inline as they form**, each with a stated default.
   A default must be reversible and inward-facing: contacting people,
   spending money, or anything that leaves the sandbox never rides on
   silence; those become escalations with an explicit ask.
4. **Write the dual outputs** to `docs/shipyard/<work-slug>/`:
   - `problem.md`: problem statement, current-state summary with sources,
     scope boundary (in/out), assumption register with defaults.
   - `decision-log.md`: prose log of what was asserted vs confirmed, by whom.
5. **Present for confirmation, assert-don't-ask.** The message is: "I'm
   treating this as X affecting Y, scoped to Z, assuming A and B. Wrong
   anywhere?", plus at most one disconfirmation question: the single fact
   that would most change the framing. Correcting is roughly 5x faster than
   answering; a list of questions is this segment's failure mode.
6. **Pause 1: stop.** The human confirms "this is the right problem" (about
   a two-minute read); this is the cheapest kill point in the flow. End by
   naming the next command: `/shape`. Do not begin direction work in this
   session, even if the confirmation arrives immediately.

Completion criterion: `problem.md` and `decision-log.md` exist on disk, the
assert-style confirmation message is delivered, and the segment has stopped
at Pause 1 naming `/shape`.
