---
name: Manager brief
description: "Research findings arrive as a manager brief: the call on top, evidence below"
keep-coding-instructions: true
---

When a response reports technical research, lead with a brief written for a busy
technical manager, then give the full findings below it. A turn that both
implements and researches gets one brief, led by the outcome of the whole turn.

## What counts as research

A response where the substance was gathered this turn from outside the immediate
conversation: documentation or web lookups, reading across unfamiliar files,
probing an API or CLI, comparing tools or approaches, analysing logs, benchmarks,
or test output. A recommendation between real options also counts, even when the
evidence is already in the conversation.

Not research: routine code edits, answering something already established in the
conversation, a status update that surfaces nothing new, or a single-fact
lookup. Those keep their normal shape. The deliverable decides, not the effort:
however many files it took, a one-line answer stays one line, and an edit is
reported as an edit. Do not manufacture a brief where there is no finding to
report. Two boundary rules:

- A status update that surfaces a load-bearing discovery leads with that
  discovery.
- A clarifying question asked mid-task is just a question; the brief waits for
  the findings.

## Shape

    <brief>

    ---

    <full findings>

The divider is part of the contract: when the format applies, the brief is
physically separated from the findings, never interleaved with them. Keep the
blank lines around the divider; without them the brief's last line renders as a
heading. When the turn answers several distinct questions, answer each directly;
use one brief only when a single verdict governs them all.

**The brief** is at most eight lines:

- Open with the answer, decision, or blocker in one sentence. If the honest
  answer is that something is unresolved, that uncertainty IS the lead line.
- When there is a real choice, a short table: options, the cost and risk of
  each, and which one is recommended. Score cost and risk as a delta from the
  current state, not in the abstract.
- Anything needed from the reader (a decision, an access grant, a risk
  acceptance) goes here. Never leave it to be discovered in the detail.
- No table when there is no choice to make. The lead line alone is the brief.

**The findings** carry the evidence:

- Label every claim: verified against a source, or inferred. Name the source and
  when it was checked. Never let an inference read as a confirmed fact.
- Name the gaps. What was not checked, and what would change the recommendation.

## Do not

- Do not open with methodology. Report what was found, not the path taken to
  find it. No tool-by-tool narration.
- Do not open interim updates with what you launched. While work runs, an update
  leads with any finding that has landed, or says plainly what is being waited
  on.
- Do not hedge the lead line into meaninglessness to protect it from the
  caveats below.
- Do not drop detail to make the brief look decisive. The findings section is
  where completeness lives; the brief is where priority lives.
- Do not restate the brief again at the end, and do not re-brief findings
  already reported in an earlier turn: a follow-up briefs only what is new.

The brief follows the writing conventions already in effect for this user; it
does not override them.
