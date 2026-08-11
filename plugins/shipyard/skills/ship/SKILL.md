---
name: ship
description: "Shipyard segment 4: build to spec, verify independently, deliver on explicit acceptance"
disable-model-invocation: true
---

# Ship: build, verify, deliver

Build against the spec, verify independently of the build, deliver on
explicit acceptance.

The discipline is delivery canon: ISO/IEC/IEEE 29119 test reporting, ITIL 4
service validation and change enablement, the SRE launch and
operational-readiness review, PMBOK Validate Scope, DORA-style progressive
delivery.

Read `references/conventions.md` in this skill's directory first. Inputs
from
`docs/shipyard/<work-slug>/`: `requirements.md`,
`build-spec.md`, `decision-log.md`. Verify against whatever spec exists; a
thinner baseline is itself recorded in the delta report.

## Steps

1. **Settle the engine at entry.** Default is building in a single loop
   here. The human may instead hand `build-spec.md` to an installed
   orchestration system; take the choice from the memo, the decision log,
   or the human at invocation. Never stop or fail because a named
   capability is absent.
2. **Build against the spec**, progressive-delivery style where the work
   allows (small batches, a pilot slice first), recording as-built
   deviations in the decision log as they occur, not reconstructed at the
   end.
3. **Escalate material issues mid-build as well-formed decisions**: options,
   a recommendation, a default with a deadline. Never as bare problems.
4. **Verify against `requirements.md`, independently of the build path**:
   fresh context, ideally a verifier that did not build it. The verification
   report is 29119 discipline: exceptions against requirements ("REQ-3
   unmet because X"), never activity. Test counts and coverage percentages
   are not verification results and do not appear in it.
5. **Write the delta report** (`delta-report.md`): everything that differs
   from what was approved at Pauses 2 and 3. Zero deltas is one line.
6. **Pause 4: acceptance, framed by blast radius**, the launch-review
   posture. Low and reversible: state a default with a deadline ("shipping
   at 2pm unless stopped"). High or irreversible: an explicit yes is
   required; nothing outward-facing or irreversible moves on silence or
   inferred approval. Acceptance is PMBOK Validate Scope: it transfers
   ownership and knowingly accepts residual defects; it does not assert
   there are none (about a one-minute read when upstream segments held).
7. **Close the loop.** Append a brief post-ship note to the delta report:
   what was learned, what to change upstream. Amend or supersede any
   graduated decision record (see conventions: decision graduation) that an
   as-built deviation contradicts, so records track reality.

Completion criterion: verification ran against `requirements.md` from a
context independent of the builder, `delta-report.md` exists on disk, and
the shipped thing moved only on explicit acceptance or an expired stated
default within its blast radius.
