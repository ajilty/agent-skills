# Research Brief: Where to set the clarification-firing threshold in the orchestrate router

Status: **RESOLVED + implemented.** Decision: calibrated **O6** — a front-door clarify-gate
(before the first dispatch) keyed on "can a Planner name an acceptance oracle as-stated?",
erring toward asking, with a headless HALT-open fallback and a 2-round non-convergence cap.
O7 (defer to superpowers) was disqualified: brainstorming's HARD-GATE fires on every goal and
stalls headless. A live probe confirmed the prior post-Planner trigger let a fuzzy goal reach
an Implementer with zero `clarify` (silent-rework); a second probe against the edited SKILL.md
confirmed the gate now clarifies-and-HALTs instead. Implemented in SKILL.md §2b + loop step 2,
guarded by `tests/test_build.sh` (binding) and `tests/integration/test_clarify_gate_lane.sh`
(judgment). The brief below is the original analysis, kept for the reasoning trail.

Separates **confirmed** facts (read from code/skill bodies or observed in live runs) from
**inferred** judgment.

## 0. Design north star (the founding constraint — read this first)

**The real aim is the operator's productivity, efficiency, and ease.** That is the objective
function every option is judged against. "Wrapper, not framework" (below) is the *means* to that
end — a deliberately tiny surface the operator never has to babysit or remember to drive — not an
end in itself. Autonomy, too, is a means: it serves ease only up to the point where *too much*
autonomy produces a wrong deliverable the operator must then review and reject (which is toil).
So the threshold question reduces to one thing: **set clarification to minimise the operator's
total effort** — interruptions avoided, rework avoided, babysitting eliminated — not to maximise
autonomy or architectural purity for their own sake. When two options tie on toil, prefer the one
that is easier for the operator (less to manage, less to remember).

orchestrate's original design inspiration, verbatim:

> A deliberately tiny layer that makes a superpowers-equipped agent behave like a standing
> operator loop: you keep feeding it goals of any altitude, it routes them, it gates the
> dangerous ones, and it recovers its place after a crash or compaction — without you ever
> reminding it to.
>
> It is a **wrapper, not a framework**. It adds only the two things superpowers doesn't: a
> **front door** and **durable resume**. Everything else (build pipeline, fresh-subagent
> review, worktrees, finishing) is superpowers; recall is episodic-memory.

This is the lens every option below must be judged through. The implication for *this*
question is sharp and uncomfortable:

- Clarification is a superpowers capability (`brainstorming`, `grill-me`, `grill-with-docs`).
- A wrapper should **route to** that capability, not **reimplement** the decision of when it
  fires.
- Therefore any option where orchestrate grows its **own** bespoke "when to clarify" logic
  (a custom fuzziness detector, a narrow trigger that differs from superpowers' own bar) is a
  drift toward *framework*, and carries the burden of proof: it must justify why the wrapper
  needs to override superpowers' native judgment instead of deferring to it.

The narrow §2b trigger described in §2 is exactly such an override. The central research
question is whether that override earns its keep, or whether the wrapper-pure move is to let
superpowers' own clarification bar decide.

## 1. System context (what a cold reader needs)

**orchestrate** is a harness-neutral plugin. A **router** (the main agent loop running the
`orchestrate` SKILL.md) takes a goal and decomposes it into role-typed subagent dispatches:
`researcher`, `planner`, `implementer`, `verifier`, `actuator`. Single-writer leases, a durable
append-only ledger (`board.jsonl`), and fail-closed hooks enforce safety and verification (no
correctness-sensitive ticket reaches `done` without a verifier verdict).

**Division of labour for disciplines (confirmed by reading the persona bodies):**

| Discipline | Where it lives | Why |
|---|---|---|
| systematic-debugging, writing-plans, verification-before-completion | **Embodied in persona bodies** | Subagents must not depend on external skills; superpowers' `using-superpowers` has a `<SUBAGENT-STOP>` telling dispatched subagents to skip skill-discovery. |
| **Clarification** (brainstorming, grill-me, grill-with-docs) | **Router context only** | A persona cannot do it: subagents do not talk to the user and do not own the goal. |

Clarification is the single discipline that cannot be delegated to a persona, which is why its
firing policy is the live design question — and why §0 bites hardest here.

## 2. The clarification mechanism today (§2b) — confirmed facts

- **Trigger:** clarification fires **only when the planner cannot sign off** (an irreducible
  `#UNKNOWN` blocks the spec). "A clear goal of any altitude proceeds without pausing."
- **Selection:** first-present-wins over `grill-with-docs → grill-me → brainstorming → inline`.
  **Exactly one** fires (a selection, never a chain).
- **Interactivity gate:** the formal skills are interactive; in a **non-interactive (headless)
  session** §2b "falls through to inline Q&A," journaled as `inline`.
- **Journaling:** `ledger.sh clarify <skill>` writes a canonical `clarify` event (board is
  machine-read by reground / metrics / conformance).
- **Trust:** clarification returns pass the §4a quarantine gate (operator answers `TRUSTED`;
  externally surfaced material is `#EXTERNAL(untrusted)`, admissible only as `#ASSUMPTION`).
- **An irreducible operator-only call is NOT clarification** — it surfaces as a `DECISION_FORK`
  (§3b).
- **CORRECTION (was a false claim):** the `clarification_skills` binding is **present** at
  `agents.yaml:180`, nested under `conventions:` (`[grill-with-docs, grill-me, brainstorming,
  inline]`), matching the §2b prose default. An earlier top-level `yq` query missed it (wrong
  path). No defect. The only real follow-up: nothing compiles this router-prose config per
  harness, so add a `test_build.sh` assertion that it stays present and order-matched so it can't
  silently rot.

## 3. The contention (stated precisely)

| | superpowers `brainstorming` bar | orchestrate §2b bar |
|---|---|---|
| Rule | "You MUST use this **before any creative work**." | Clarify **only when a planner is blocked** by an irreducible `#UNKNOWN`. |
| Posture | Proactive, broad | Reactive, narrow |
| Premise | The cheapest defect is the one never built. | Autonomy *is* the product; pausing on every fuzzy goal defeats it. |
| Guards against | Building the wrong thing confidently | Death by interruption / low autonomy |
| §0 alignment | Native superpowers judgment (wrapper-pure) | Wrapper overriding superpowers (framework-ish) |

**Empirical observation (confirmed):** in a real multi-ticket infrastructure session the router
barely used grill-me. Investigation showed this was **behaviour-as-designed**: goals were
concrete enough that no `#UNKNOWN` blocked planner sign-off, and genuinely ambiguous points
(host-affinity, test-placement) were resolved with inline `AskUserQuestion` forks, which §2b
counts as a **valid inline clarification**. The operator's surprise is a **threshold-expectation
mismatch**, not a bug.

**Calibration evidence (confirmed):** two live headless runs on a *fully-specified* goal
(`parse_duration` spec handed over) both correctly **skipped clarification** and ran the full
chain (planner → implementer → verifier), producing correct code that passed a hidden oracle.
Confirms the narrow bar is right on clear goals; says nothing about fuzzy goals.

**The decision:** where to set the firing threshold and how to detect the firing condition,
trading autonomy against wrong-thing-built risk, **without drifting from wrapper to framework**.

## 4. Constraints and forces (the real environment)

| Force | Implication |
|---|---|
| **Wrapper, not framework** (§0, binding) | Prefer deferring to superpowers' native clarification judgment over reimplementing it. New orchestrate-side decision logic must justify itself. |
| **Autonomy is a core value** (binding) | Broadening must not make the router pause on every goal. |
| **Simplicity bias** (binding) | No knobs/schemas/"someday" flexibility speculatively. The LLM is parser AND generator of these artifacts. |
| **Portability** | Policy must compile across harnesses (Claude Code / Codex / opencode). |
| **Headless testability** | Interactive skills can't run under `claude -p`; only the `clarify`-before-build judgment is headlessly assertable. "Which formal skill fired" is interactive-only. |
| **Operator expects clarification skills installed and valuable** (stated) | A policy that almost never fires them under-delivers against expectation. |
| **Interruption tolerance** (inferred) | Operator iterates continuously and pressure-tests, so an up-front gate may be welcomed rather than resented. Validate. |

## 5. Option space

| # | Option | Mechanism | §0 alignment | Autonomy | Wrong-thing risk | Headless-testable | Complexity |
|---|---|---|---|---|---|---|---|
| **O1** | Status quo (narrow) + binding fix | Fire only on planner-blocking `#UNKNOWN` | Override (framework-ish) | Highest | Highest | Yes | Lowest |
| **O2** | Broaden to fuzzy/greenfield | Fire up-front on open design space; concrete goals proceed | Mixed | Medium | Low | Partly | Medium |
| **O3** | Per-invocation override | Narrow default + operator forces/suppresses per call | Neutral | Operator-chosen | Operator-controlled | Yes | Low-Med |
| **O4** | Sharpen detection, keep bar | Keep narrow philosophy, fire it more reliably/earlier | Override | High | Medium | Yes | Medium |
| **O5** | Tie to intake tier | T0 skip, T1 narrow, T2/greenfield broad | Mixed | Medium | Low | Yes | Low (reuses tiers) |
| **O6** | Self-check then escalate | Cheap internal "enough to plan?" gate, escalate on ambiguity | Override (bespoke detector) | Med-High | Low | Yes | Medium |
| **O7** | **Front door defers to superpowers** | The front door invokes `brainstorming` for any non-trivial goal; superpowers' own bar decides; orchestrate keeps only routing + resume | **Purest wrapper** | Set by superpowers | Low | Partly | Low (deletes bespoke logic) |

### Pros / cons

**O1 — Status quo + binding fix.** Pros: zero behavioural risk; full autonomy; trivial; binding
fix closes the confirmed gap. Cons: ignores operator expectation; formal skills stay rare;
confidently-wrong build on a fuzzy goal still possible; §0-wise it is a wrapper overriding
superpowers with a *narrower* bar than superpowers ships.

**O2 — Broaden to fuzzy/greenfield.** Pros: catches wrong-thing-built early; uses the valued
skills where they pay off; closest to operator expectation. Cons: hinges on a reliable fuzziness
detector (§6) — and building that detector inside orchestrate is the framework drift §0 warns
against; modest extra interruption; risk of firing on inherently-open goals.

**O3 — Per-invocation override.** Pros: defers philosophy to point of use; respects
"posture decisions are the operator's"; cheap; §0-neutral. Cons: adds a control surface; useless
in autonomous/cron runs with no human to set the flag; punts the default rather than answering it.

**O4 — Sharpen detection, keep bar.** Pros: keeps autonomy; fixes the real complaint if the true
problem is "should have fired and didn't"; no new interruption on clear goals. Cons: doesn't
deliver a *broader* bar if that's what's wanted; "better #UNKNOWN surfacing" is hard to specify;
still an override of superpowers' bar.

**O5 — Tie to intake tier.** Pros: reuses existing, journaled machinery; principled inspectable
mapping; testable per tier. Cons: couples risk-tier and clarification-eagerness, which may not
correlate; a high-tier goal can still be perfectly clear.

**O6 — Self-check then escalate.** Pros: a calibrated O2 — broad in spirit, false fires
suppressed by the gate; mirrors how a careful human decides "do I know enough to start?";
testable. Cons: the self-check is itself a bespoke judgment (framework drift); more router prompt
complexity.

**O7 — Front door defers to superpowers.** Pros: the purest expression of §0 — orchestrate stops
deciding when to clarify and lets brainstorming's native "before any creative work" bar run;
*deletes* bespoke §2b trigger logic (simplicity win); automatically matches operator expectation
because it just uses the skills. Cons: gives up fine control over autonomy (brainstorming may
fire more than the autonomy value likes); brainstorming is interactive, so headless runs still
need a defined fallback; needs the "ignore the skill's built-in next-step handoff, return to the
loop" discipline (already in §2b) to remain a wrapper and not get hijacked by the sub-skill's
flow.

## 6. Cross-cutting sub-questions the research must resolve

1. **Does the wrapper need its own fuzziness detector at all (§0)?** If O7 is viable, several
   options collapse. Is there any case where superpowers' brainstorming bar is *wrong* for an
   operator-loop context, justifying an orchestrate-side override?
2. **Fuzziness detection (crux of O2/O5/O6, only if §6.1 says yes).** What cheap, portable signal
   separates "concrete goal of any altitude" from "open design space"? Candidates: absence of a
   spec/acceptance criteria; design verbs (design/build/improve/rethink) vs change verbs
   (fix/add/rename); abstractness; whether a planner can name a testable oracle. Which is reliable?
3. **Clarify vs DECISION_FORK boundary (§3b).** Where is the line between "resolvable by
   interview" and "irreducible operator call"? A broader trigger pushes more cases to this edge.
4. **Headless / autonomous behaviour.** When ambiguous *and* non-interactive (cron, CI, `-p`),
   should the router (a) HALT and stay open, (b) make a documented `#ASSUMPTION` and proceed, or
   (c) proceed silently? Affects unattended use; current "fall through to inline" means no human
   answers in a truly headless run.
5. **Non-convergence guard.** A broad bar on an inherently open goal risks an endless
   clarification loop. What bounds it?
6. **Episodic-memory interaction.** §0 says "recall is episodic-memory." Should prior
   clarifications on similar goals be recalled to *suppress* re-clarifying the same ambiguity?

## 7. Evaluation / success criteria

- **Fixture (headless-testable layer):** goal-only autonomy fixture asserts the policy via board
  conformance + on-disk artifact corroboration + hidden oracle: *clear goal → no `clarify`, full
  chain*; *fuzzy goal → `clarify` before any `implementer` dispatch*. ("Which formal skill" is
  interactive-only, out of scope for CI.)
- **Metric (the objective from §0):** minimise **total operator toil**. Decompose it as
  `interruption cost` (a false-clarify on a clear goal = pure friction) + `rework cost` (a
  missed-clarify = a wrong deliverable the operator must review and reject) + `babysitting cost`
  (the operator having to drive or remind the loop). The threshold is set where the marginal
  interruption avoided equals the marginal rework it would have prevented. Ease is the tiebreaker:
  fewer moving parts the operator must manage wins.
- **Trust model (validated):** never assert on the board alone; corroborate each claimed dispatch
  with the scoped on-disk artifact the persona leaves (ADR-0014) — `ledger.sh append` writes the
  router's JSON verbatim, so the board is a self-report.

## 8. Working recommendation (for the research agent to challenge, not accept)

Two candidates, and §0 pulls hard toward the first:

- **§0-pure: O7** — front door defers to superpowers' brainstorming bar; delete the bespoke
  narrow trigger; keep only routing + durable resume + the "ignore sub-skill handoff, return to
  loop" discipline and a defined headless fallback (journaled `#ASSUMPTION`, never silent guess).
  Simplest, most aligned, auto-satisfies operator expectation. Risk: less autonomy control.
- **Calibrated O6+O5** — broaden in spirit but gate firing on a cheap self-check informed by
  intake tier. More autonomy control, but it grows orchestrate-side judgment machinery, which is
  the framework drift §0 warns against.

The research pass should resolve **§6.1 first** (does the wrapper need its own detector at all),
because a "no" collapses the option space toward O7 and most of the rest becomes moot.
