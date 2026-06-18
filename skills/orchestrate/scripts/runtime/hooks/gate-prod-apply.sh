#!/usr/bin/env bash
# SubagentStart (actuator): pre-apply consequence gate (SKILL §8). Deny the
# dispatch if any prod-level mutation target lacks an operator ack. Fail-closed:
# the router populates PROD_TARGETS with every prod AND undeclared/unknown target,
# so an unacked consequential apply cannot proceed. Wire this BEFORE the
# write-ahead hook so a denied dispatch never journals a `dispatched` or takes a
# lease. Non-actuator personas are a no-op.
set -euo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
[ "$persona" = actuator ] || exit 0
t="${TICKET:?}"; ts="$(date -u +%FT%TZ)"
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
exit 0
