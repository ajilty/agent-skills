#!/usr/bin/env bash
# PreToolUse (actuator, Bash): pre-apply consequence gate (SKILL §6b), the hard
# floor — deny the actuator's commands while any prod-level mutation target lacks
# an operator ack.
#
# Input source: persona from Claude Code's stdin JSON (agent_type), env fallback.
# Contract: ALLOW = exit 0 no stdout; DENY = journal gate-blocked + stderr + exit 2.
#
# NOTE: PROD_TARGETS/TICKET are per-dispatch context. CC does not pass router-set
# env to subagent hooks, so under CC these come up empty and the gate cannot yet
# enforce — it must read them from on-disk ticket state keyed by agent_id (TODO,
# part 2). Persona detection is correct now; the disk lookup makes it enforce.
set -uo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
persona="$(J .agent_type)"; [ -n "$persona" ] || persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
persona="${persona##*:}"   # strip plugin namespace: CC sends agent_type as <plugin>:<persona> (e.g. orchestrate:actuator)
[ "$persona" = actuator ] || exit 0
# per-dispatch context: env (Codex/OpenCode) first, else the on-disk active-writer
# record the router wrote at dispatch (ADR-0006 — CC passes no router env to hooks).
t="${TICKET:-$(bash "$RT/ledger.sh" writer-ctx get ticket)}"; ts="$(date -u +%FT%TZ)"
pts="${PROD_TARGETS:-$(bash "$RT/ledger.sh" writer-ctx get prod_targets)}"
blocked=0; bkey=""
for key in $pts; do
  m=".agents/runs/orchestrate/tickets/$t/ack-$(bash "$RT/ledger.sh" lease-key "$key")"
  if [ ! -f "$m" ]; then
    bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"gate-blocked\",\"persona\":\"actuator\",\"key\":\"$key\"}"
    blocked=1; bkey="$key"
  fi
done
[ "$blocked" = 1 ] && { echo "orchestrate: pre-apply gate — prod target requires operator ack ($bkey)" >&2; exit 2; }
exit 0
