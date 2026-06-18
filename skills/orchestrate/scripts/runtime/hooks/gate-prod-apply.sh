#!/usr/bin/env bash
# PreToolUse (actuator, Bash): pre-apply consequence gate (SKILL §6b), the hard
# floor — deny the actuator's commands while any prod-level mutation target
# (PROD_TARGETS; the router includes every prod AND undeclared/unknown target,
# fail-closed) lacks an operator ack.
#
# Hook contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = journal
# gate-blocked + reason on stderr + exit 2 (decision JSON fails CC hook-output
# validation; exit 2 is the real "block", exit 1 would let the tool proceed).
# Non-actuator personas are a no-op. Never errors.
set -uo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
[ "$persona" = actuator ] || exit 0
t="${TICKET:-}"; ts="$(date -u +%FT%TZ)"
blocked=0; bkey=""
for key in ${PROD_TARGETS:-}; do
  m=".agents/runs/orchestrate/tickets/$t/ack-$(bash "$RT/ledger.sh" lease-key "$key")"
  if [ ! -f "$m" ]; then
    bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"gate-blocked\",\"persona\":\"actuator\",\"key\":\"$key\"}"
    blocked=1; bkey="$key"
  fi
done
[ "$blocked" = 1 ] && { echo "orchestrate: pre-apply gate — prod target requires operator ack ($bkey)" >&2; exit 2; }
exit 0
