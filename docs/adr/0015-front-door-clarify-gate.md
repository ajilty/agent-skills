# Clarification is a front-door gate keyed on a nameable oracle, not a post-Planner fallback

§2b previously fired clarification **only when a Planner could not sign off** — an
irreducible `#UNKNOWN` blocked the spec. That bar is too late. A live probe made the
failure concrete: handed the deliberately fuzzy goal "add rate limiting to api.py" (limit,
scope, backend, response code, window all unstated), the router ran
`intake → researcher → planner → implementer` and **built a deliverable with zero `clarify`
event**. The premium-tier Planner did not bounce; it invented a plausible spec and signed
off, and the loop implemented it. On a real goal the operator would get back a rate limiter
of the wrong design and have to review and reject it. That review-and-reject is the costliest
form of operator toil, and the late trigger is what permits it.

The inverse failure bounds the fix. Deferring "when to clarify" to superpowers' own
`brainstorming` skill (the "wrapper, not framework" temptation) is **not** viable:
brainstorming carries a HARD-GATE that fires "before any creative work… regardless of
perceived simplicity" and blocks on human approval. It would interrupt every clear goal
(the parse_duration calibration, which correctly runs autonomously, would stall) and would
hard-stall every headless run, while also seizing control flow toward its own
`writing-plans` pipeline — the opposite of a tiny operator loop you never babysit.

So neither native bar is right: brainstorming fires too eagerly, the old §2b fires too late.
The objective is not autonomy or architectural purity for their own sake; it is the
operator's productivity and ease, i.e. **minimum total toil** = interruption (a false
clarify on a clear goal) + rework (a missed clarify ships the wrong thing) + babysitting.
The threshold sits where the marginal interruption avoided equals the marginal rework it
prevents, and the operator chose to **err toward asking** when genuinely ambiguous, because
a wrong deliverable costs more than an occasional question.

**Decision.** Clarification becomes a **front-door gate**: it runs once, after intake and
**before the first dispatch**. The gate asks one question of the goal as-stated — *can a
Planner name a real acceptance oracle for this without inventing requirements?* — consulting
`docs/adr/INDEX.md` first, so an `active` decision that already resolves the ambiguity counts
as the answer. If yes, the goal is clear at any altitude and proceeds with no clarification.
If no, the goal has open design space and the gate fires one bound `clarification_skills`
mechanism (first-present-wins) **before any persona is dispatched**, so a Planner never
invents-and-signs-off. The fire-condition is pinned to the Planner's existing oracle
obligation rather than a new router-side fuzziness classifier — the router stays dumb; the
signal already exists.

The detection signal is "oracle nameable as-stated," not the design-verb-vs-change-verb
heuristic. The heuristic fails on cases like "add rate limiting" ("add" is a change verb but
the goal is wide open); "oracle nameable" holds across the tested examples and reuses
machinery the Planner persona already embodies.

**Headless fallback.** When the gate fires in a non-interactive session there is no operator
to interview: the router journals `clarify` with `skill=inline` and **HALTs the lane open**
for the next resume. It does **not** silent-build a dispatch against an unresolved goal.
Proceed-on-`#ASSUMPTION` (a documented default with a verify-at-impl check) is a per-run
opt-in only; the Verifier's open-tag rule then forces it back to a human before `done`.

**Non-convergence.** The interview is bounded: after 2 `clarify` rounds on one ticket
(counted from the ledger, the `retries` pattern), the router stops asking and surfaces the
residual as a `DECISION_FORK` — converting "going in circles" into one operator call.

## Considered options
- **O7 — defer entirely to superpowers' brainstorming bar** (purest wrapper) — rejected.
  brainstorming's HARD-GATE fires on every goal and blocks on approval, deleting autonomy and
  hard-stalling headless runs; it also fights the router for control flow. Ranks worst on
  total toil, not best, once per-goal interruption and headless stalls are counted as toil.
- **O1 — keep the narrow post-Planner trigger** — rejected. The live probe showed it permits
  silent-rework (Planner invents a spec for a fuzzy goal and the loop builds it). Its one
  affirmative deliverable, a "binding fix," was a non-issue: `clarification_skills` was
  already present in `agents.yaml` (under `conventions:`); an earlier top-level query misread
  it as absent.
- **O2 / O4 / O6 with a bespoke router-side fuzziness detector** — the detector is the real
  framework drift. Avoided by keying the gate on the Planner's *existing* oracle obligation
  instead of a new classifier.
- **Err toward proceeding (clarify only on a hard fork)** — rejected by the operator: a wrong
  deliverable is more expensive than an occasional question; the gate errs toward asking.

## Consequences
- The trigger moves from post-Planner to pre-dispatch in `SKILL.md` §2b and loop step 2. A
  fuzzy goal now clarifies-and-HALTs instead of building; a clear goal still proceeds. Both
  verified live before and after the change.
- The gap that let this through was a **missing judgment test**: every clarify test either
  hard-coded the journaling (testing plumbing) or asserted a no-op. A live judgment fixture
  (`test_clarify_gate_lane.sh`) is added: it gives a bare fuzzy goal with no hint to clarify
  and asserts a `clarify` appears before any implementer dispatch, plus a clear-goal
  over-fire guard. A deterministic `test_build.sh` assertion pins `clarification_skills`
  present and order-matched so the router-prose binding can't silently rot.
- `clarification_skills` is router-prose config, compiled by no harness generator; the build
  assertion is its only guard.
- Supersedes the "fires only when the Planner cannot sign off" clause of §2b. ADR-0009
  (clarification returns pass the quarantine gate) and ADR-0004 (router owns sequencing,
  ignore the sub-skill handoff) are unchanged and still load-bearing.

## Status

active
