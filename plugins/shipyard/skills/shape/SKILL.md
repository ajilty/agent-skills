---
name: shape
description: "Shipyard segment 2: score directions and force the commitment memo"
disable-model-invocation: true
---

# Shape: options and direction

Define where we're going and how we could get there, then force an explicit
human commitment: the returned memo.

The discipline is options-analysis canon: Analysis-of-Alternatives scoring,
Kepner-Tregoe weighted criteria with must/want separation, the decision
brief's BLUF and courses of action, PRINCE2's owned business case, Amazon's
PR/FAQ decision-ready narrative.

Read `conventions.md` beside this skill file first. Input:
`docs/shipyard/<work-slug>/problem.md` and `decision-log.md`,
read from disk. When no confirmed problem statement exists, open with an
inline scope-lite (one paragraph: problem, boundary, key assumptions) and
record it in the decision log as asserted, not confirmed.

## Steps

1. **Define desired state and assess the gap** against the current-state
   baseline.
2. **Generate genuine alternatives**: courses of action, not strawmen. The
   shortlist always includes "do nothing" and "defer" as scored options;
   without them the comparison is not real.
3. **Hold solution altitude.** Build vs buy, approach A vs approach B.
   Schema or vendor-API detail appearing in a draft means the segment is
   specing too early: park that content for `/spec` and return to altitude.
4. **Score options as deltas from the accepted baseline** on cost, risk,
   fit, and effort, crediting controls that already exist: Kepner-Tregoe
   discipline, weighted criteria with must/want separation. Show score
   drivers, not the full matrix.
5. **Draft the decision memo, BLUF**: only decisions that belong to the
   human, each pre-filled with a recommendation, plus one pre-mortem prompt
   ("which option would you be embarrassed to have picked in 12 months?")
   in the PR/FAQ spirit of anticipating concerns before they are raised.
   Close with a copyable block phrased so that the memo pasted back
   verbatim, marked up, is complete and actionable feedback.
6. **Write the dual outputs** to `docs/shipyard/<work-slug>/`:
   - `memo.md`: desired state, gap assessment, scored options with
     recommendation, the copyable memo block.
   - append to `decision-log.md`.
7. **Present the pivot, not the math** ("Option B wins unless data residency
   outweighs cost. Does it?"), then **Pause 2: stop.** The human returns the
   marked-up memo: pick, modify, reject, or defer (about a five-minute
   read). This is the commitment event, the only structurally required human
   decision in the method, and the last cheap exit; ownership of the chosen
   decisions transfers to the human here, PRINCE2's owned business case.
   End by naming the next command: `/spec`.

Completion criterion: `memo.md` exists on disk with "do nothing" and
"defer" among the scored options and a copyable memo block, the pivot
message is delivered, and the segment has stopped at Pause 2 naming `/spec`.
