#!/usr/bin/env bash
# PreToolUse (actuator, Bash): pre-apply consequence gate (SKILL §6b), the hard
# floor. Deny the actuator's commands while any prod-level mutation target
# (PROD_TARGETS — the router includes every prod AND undeclared/unknown target,
# fail-closed) lacks an operator ack, so a consequential apply cannot run.
# SubagentStart is NON-blocking on shell harnesses, so the block must live here at
# tool-use; the dispatch-time ledger hygiene (no false dispatched/lease trace when
# unacked) is in on-writer-dispatch.sh. Non-actuator personas are a no-op.
set -uo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
[ "$persona" = actuator ] || { echo '{"decision":"allow"}'; exit 0; }
t="${TICKET:-}"; ts="$(date -u +%FT%TZ)"
blocked=0
for key in ${PROD_TARGETS:-}; do
  m=".agents/runs/orchestrate/tickets/$t/ack-$(bash "$RT/ledger.sh" lease-key "$key")"
  if [ ! -f "$m" ]; then
    bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"gate-blocked\",\"persona\":\"actuator\",\"key\":\"$key\"}"
    blocked=1
  fi
done
if [ "$blocked" = 1 ]; then
  echo '{"decision":"deny","reason":"pre-apply consequence gate: prod target requires operator ack"}'
  exit 1
fi
echo '{"decision":"allow"}'; exit 0
