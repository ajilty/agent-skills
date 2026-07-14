# Researcher is two jobs; a T1 spec gap is not bought back by implementer model tier

Field calibration (live sessions, 2026-07-14), building on ADR-0024's dispatch-time
horsepower binding. Three findings from real dispatches:

- **Both researchers earned their keep on judgment, not reduction.** One caught that a
  planned deliverable was already live (killing it) and that a LAN requirement was a
  plan-time provider handshake, not a resource need — the distinction a DECISION_FORK
  hinged on. The other's value was elimination logic (a 2.2 GiB image vs a 2 GiB release
  cap; a presigned-URL-replans-forever interaction). This is exactly the class of
  non-obvious interaction a small model misses **silently**, and a silently wrong research
  fact poisons the Planner downstream, where rework is expensive. haiku/medium fits only
  the *inventory* half of the role.
- **A flagship T1 implementer still produced design drift.** A T1 lane has no Planner; the
  implementer designed from a thin work-item and produced bespoke-script drift the operator
  caught — at flagship tier. The missing reuse criterion caused it; model tier could not
  buy it back.
- **The troubleshooter had no tier row** despite being the most-used off-table dispatch
  (the ADR-0021 tripwire fires constantly), and as "Researcher in diagnostic mode" it
  inherited the economy tier — wrong for causal-chain diagnosis.

**Decision.** Calibrate the §2a′ dispatch table; personas and the compiled contract are
unchanged (ADR-0024 made flavors free at dispatch):

1. **Researcher splits into two dispatch flavors, selected by what consumes the output:**
   sweep/inventory (haiku/medium — mechanical extraction) vs judgment (sonnet/high — the
   findings feed an ADR/spec or eliminate design options).
2. **Troubleshooter gets its own row:** sonnet/high default; escalate to opus for
   livelock/corruption-class incidents where the causal chain is long.
3. **Refactor-shaped T1 rule (structural, §2a):** behavior-preservation/reuse work in a
   T1 lane gets a planner-grade work-item (explicit criteria, named invariants) or a cheap
   Planner pass — never an implementer model escalation, which is the wrong lever for
   design drift.
4. **Unchanged:** planner opus/high and verifier opus/max (both earned their tiers —
   collision-avoidance and fork-framing were load-bearing; verifiers caught real defects).
   Mechanical-verification waste is handled by the ADR-0024 batch-by-tier rule, not a
   verifier tier cut.

## Considered options
- **A new "judgment-researcher" or "debugger" persona** — rejected: ADR-0024 binds
  horsepower at dispatch, so flavors are a table row, not a new agent; five personas stay
  the contract (simplicity, installer stability).
- **Raise the researcher's compiled default to sonnet** — rejected: sweeps are the volume
  case and would silently pay the higher tier; the economy floor stays, judgment is the
  named exception the router selects deliberately (and model_mix audits).
- **Escalate implementer model for refactor-shaped T1** — rejected by direct evidence: the
  failure reproduced at flagship tier. The gap is spec-shaped.

## Consequences
- SKILL §2a′ table gains the flavor rows + selection column; §2a gains the refactor-shaped
  T1 rule. Codex note: its per-persona `.toml` carries one static tier per persona, so
  flavor selection there awaits a per-dispatch override in `dispatch-persona.sh` (small
  follow-up; CC is the primary field harness today).
- `model_mix` (0.8.9) now shows researcher dispatches at two tiers by design; a run that is
  all-sonnet researchers with no judgment-shaped output is the new drift signal.

## Status

active
