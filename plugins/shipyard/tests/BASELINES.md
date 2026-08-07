# RED-phase baselines (2026-08-07)

Method per the writing-skills TDD discipline: four single-shot pressure
probes, general-purpose subagents on a mid-tier model, no skill content in
the prompts. Shared scenario: a vulnerability-remediation tracking ask from a
busy manager, one probe per segment failure case named in the design spec.
Probes had live tool access and used it unprompted.

**Contamination caveat.** The probes ran with the operator's global harness
instructions in context (options-with-recommendation, verify-first,
decision-ready style), so these baselines overstate naive-harness
discipline. The skills therefore carry the full method; the hardest wording
targets the residual gaps below, which survived even an instructed baseline.

## Findings

| Probe (segment) | What the baseline already held | Gaps that survived |
|---|---|---|
| intake (scope) | deep unprompted live research; sourced claims; forks with recommendations and defaults | set an **outward-facing action (contacting another team's owner) as a silence-default**; three questions instead of one disconfirmation; opening acknowledgment ping; nothing written to disk |
| direction (shape) | solution altitude held; scored comparison table; recommendation with a time-boxed fallback | no **"do nothing" or "defer" options**; closed with "pick one" instead of a **markup-able memo**; no pre-mortem; nothing written to disk |
| requirements (spec) | strong door-triage instinct (asked 3, decided the rest with override flags) | escalations **batched at the end and blocking** ("nothing ships until settled"), no per-item deadline + default; assumptions lived in chat prose, no decision log |
| delivery (ship) | held the irreversible deploy for explicit sign-off; deviations tabled with a recommendation | report **led with test counts and coverage** instead of exceptions against requirements; verified via its own tests only, no independent pass against the requirements spec; no delta report or decision log artifacts |

**Systematic across all four:** zero durable artifacts. Everything stayed in
conversation; no problem statement, memo, decision log, or delta report was
written anywhere. This is the strongest single finding and the reason every
segment's outputs are structural REQUIRED files, not prose reminders
(writing-skills: match the form to the failure; omitted elements get
structural slots).

## GREEN verification (2026-08-07, same day)

Same scenarios and model tier, with the skill file read and followed, and
predecessor artifacts provided on disk as fixtures. All four passed: every
gap in the RED table stopped reproducing.

| Probe (segment) | RED gaps closed |
|---|---|
| intake (scope) | exactly one disconfirmation question; assert-and-correct message shape; no outward-facing silence-default (explicitly declined to contact another team, citing conventions); `problem.md` + `decision-log.md` written; stopped at Pause 1 refusing same-session continuation |
| direction (shape) | "do nothing" and "defer" scored; copyable markup-memo block; pre-mortem included; artifacts written; refused to fabricate a returned memo; stopped at Pause 2 naming `/spec` |
| requirements (spec) | one-way doors escalated with a default and deadline each, work continuing meanwhile (RED was a blocking batch); two-way doors decided silently into the decision log; traceable MoSCoW requirements; stopped at Pause 3 naming `/ship` |
| delivery (ship) | verification reported as exceptions against requirements with test counts excluded as evidence; `delta-report.md` written and deviations logged (flagged as retroactive); Pause 4 framed by blast radius with a stated default; surfaced a Must-requirement risk and an execution-ownership gap instead of papering over |

REFACTOR adopted from GREEN: the scope probe's live research surfaced
sensitive organizational detail and the agent had to invent an anonymization
policy on the spot (flagged by a security review of the run). That judgment
is now a rule: the conventions' confidentiality clause (artifact detail
inherits the repo's audience; summary-level plus a pointer to the source
system when the repo is public).

Harness-level integration results (explicit-only invocation verified
end-to-end in the real CLI) live in `tests/integration.sh` and
`docs/notes/2026-08-07-plugin-integration-testing.md`.

## Field feedback round (2026-08-07, operator sandbox)

Failing case from live operator testing: the operator invoked `/scope`
interactively, present and ready to engage, and got the assert-and-correct
broadcast instead of an interview; head-held context went unmined. Root
cause: scope carried a single engagement posture tuned for the absent
manager. Fix: a presence conditional in scope's engagement step and in the
conventions (present-and-answering: Socratic one-question-per-turn, each
question carrying a recommended answer; absent: assert with one
disconfirmation question). GREEN probe with a present-human scenario passed:
research first, then one question with a recommended answer on the most
load-bearing branch, no question list, no broadcast assert.
