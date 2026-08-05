---
name: assignment
description: Use when the user hands over described work to be run end-to-end as a project assignment; triggers include "run this as an assignment", "full project assignment", "run this through orchestrate", or a request for a decision-ready briefing that ends in a copyable decisions memo.
---

# Assignment

Run one described goal from ambiguity to shipped, decision-gated work. Five
phases, in order; the briefing gates the build. Phases 1 and 2 name optional
richer skills: invoke one when it is available in this session, otherwise use
the inline fallback. Never stop or fail because a named skill is absent.

## 1. Grill before working

Resolve ambiguity before any execution.

- Richer skills, if available: `grill-with-docs` when the repo keeps CONTEXT.md
  or ADRs (it updates them as decisions land), else `grill-me`.
- Inline fallback: interview the user about the goal, one question at a time,
  walking each branch of the decision tree; every question carries options and a
  recommendation. Explore the codebase instead of asking whenever the repo can
  answer. Stop when you can state the goal as an acceptance criterion the user
  has confirmed.

## 2. Investigate and plan (no build yet)

- Richer skill, if available: feed the confirmed goal to `/orchestrate` and run
  its research and planning lanes; hold build lanes until phase 3's memo
  returns.
- Inline fallback: read-only research subagents, then a written spec/plan the
  user can inspect.

## 3. Brief the operator (the go/no-go gate)

The deliverable is an interactive artifact briefing written for a
context-switching, decisive senior IT engineering manager, not a peer
implementer: outcomes first, jargon translated, depth available behind the
summary. If no artifact surface exists in the session, deliver the same briefing
as one self-contained HTML or markdown file. Its parts, in order:

1. Current state
2. Desired state
3. Gaps
4. Options scored against the accepted baseline: risk and effort as deltas from
   the status quo, crediting controls that already exist
5. Implementation plan
6. FAQ anticipating the manager's likely concerns
7. Closing: a copyable memo containing only the decisions that are the user's to
   make, each with options and a recommendation, phrased so the memo pasted back
   verbatim is complete, actionable feedback

Present the briefing and stop. The returned memo is the go/no-go: nothing is
built before it comes back, and its decisions bind the build.

## 4. Build and verify

Apply the memo's decisions to the plan, then build: single writer, then an
independent verification pass by a fresh-context agent that did not build it
(orchestrate's build and verifier lanes, when available, are exactly this).

## 5. Close out

Update the briefing artifact with a short delta report: what shipped versus the
plan, deviations and why, and any new decisions that surfaced (same copyable
memo form). No unrequested detail dumps; depth stays available on request.
