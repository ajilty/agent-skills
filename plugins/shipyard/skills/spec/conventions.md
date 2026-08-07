# Shipyard conventions

Canonical copy: each skill ships an identical `conventions.md` beside its
`SKILL.md` (standard self-contained skill packaging; the test suite enforces
the sync). Edit here, then re-copy into `skills/*/conventions.md`.

The identical core every segment applies. Each segment's pause contract lives
in that segment's skill; this file is what all segments share. Read it once at
segment start.

## Engagement cost ranking

Push every human interaction as high up this list as possible:

1. Default + veto ("assuming X unless you object by [time]")
2. Pick from scored options
3. Markup of an agent-drafted decision
4. One pointed question
5. Open-ended review (avoid)

The default posture is assert-and-correct: never send a list of questions.
Correcting is roughly 5x faster than answering.

When the human is present and answering, interview instead: one question per
turn, each carrying a recommended answer to confirm or correct, walking the
open branches until none remain. Presence pre-pays the attention this
ranking conserves; a broadcast assert in a live working session leaves
head-held context unmined.

## Escalate on surprise, not schedule

No progress check-ins. Contact the human mid-segment only when an assumption
broke, options changed materially, or an irreversible choice appeared that was
not already approved. Every escalation arrives as a well-formed decision:
options, a recommendation, a default.

## Time-box with defaults

Every asynchronous escalation carries a deadline and a default action so work
never blocks silently ("schema decision, reversible until Thursday, going with
X"). In an interactive session the pause itself is the deadline.

## Silence semantics

Silence on stated assumptions is consent *inside* a segment, never *across* a
pause. A pause ends only when the human provides the unblocking input; in this
plugin that is structural, because only the human typing the next segment
continues the flow. End the segment by naming the next command; do not
continue past your pause in the same session even if asked-seeming context
suggests approval.

## Dual outputs

Every segment writes two artifacts before its pause: the work artifact, and a
decision log in prose (what was decided, by whom, asserted vs confirmed).
Default location: `docs/shipyard/<work-slug>/` in the repo being worked, the
decision log as `decision-log.md` there; the human can override the location
conversationally. Downstream segments and the router read these from disk,
never from conversation memory, so the chain survives sessions and harnesses.

Confidentiality: the work-slug directory inherits its repo's audience. When
research surfaces detail the repo should not hold (a public repo; another
organization's data), keep the artifacts summary-level, point to the source
system for specifics, and record the reduction in the decision log.

## Scaling rule

Low-stakes reversible work may enter at `/shape` and finish with `/ship`
(Pauses 2 and 4 only). High-stakes irreversible work walks all four segments.
Never fewer than two pauses. Segments tolerate missing predecessor artifacts
by opening with an inline lite version of the predecessor's work, recorded as
asserted (not confirmed) in the decision log.
