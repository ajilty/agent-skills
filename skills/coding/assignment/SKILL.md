---
name: assignment
description: Use when the user hands over described work to be run end-to-end as a project assignment; triggers include "run this as an assignment", "full project assignment", "run this through orchestrate", or a request for a decision-ready briefing that ends in a copyable decisions memo.
---

# Assignment

Run one described goal from ambiguity to shipped, decision-gated work. Five
phases, in order; the briefing gates the build. Each phase applies a named
skill when it is available in this session; when one is absent, apply the
one-line essence given for it instead. Never stop or fail because a named
skill is absent.

1. **Grill** — resolve ambiguity before any execution. Skills:
   `grill-with-docs` when the repo keeps CONTEXT.md or ADRs, else `grill-me`.
   Essence: interview the user one question at a time with options and a
   recommendation, exploring the codebase instead of asking where it can
   answer, until the goal is a confirmed acceptance criterion.
2. **Investigate and plan (no build yet)** — skills: `research`, then `plan`.
   If `/orchestrate` is installed, feed the confirmed goal to it and run its
   research and planning lanes, holding build lanes until phase 3's memo
   returns. Essence: read-only findings with confirmed-versus-inferred
   labeling, then a spec with acceptance oracles and operator decisions
   listed, both as durable files.
3. **Brief the operator (the go/no-go gate)** — skill: `brief`. Essence: an
   interactive artifact briefing (current state, desired state, gaps, options
   scored against the accepted baseline, plan, FAQ) closing with a copyable
   memo of only the decisions that are the user's to make. Present it and
   stop: nothing is built before the memo returns, and its decisions bind the
   build.
4. **Build and verify** — skills: `build`, then `verify` (via orchestrate's
   build and verifier lanes when it is running the goal). Essence: single
   writer executes the memo-bound plan with the commit as the artifact; a
   fresh-context agent that did not build it adversarially verifies against
   the goal.
5. **Close out** — skill: `brief` (close-out mode). Essence: update the same
   briefing artifact with what shipped versus the plan, deviations and why,
   and any new decisions in the same memo form.
