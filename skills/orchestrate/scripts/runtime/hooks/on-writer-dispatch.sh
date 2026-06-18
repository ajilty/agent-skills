#!/usr/bin/env bash
# SubagentStart (writers): write-ahead 'dispatched' + lease BEFORE the writer runs,
# so a just-dispatched writer that left no dirty worktree is still visible to
# reground. SubagentStart is NON-blocking and its stdout is not a decision, so this
# does ledger side-effects only and ALWAYS exits 0 — never decision JSON, never aborts.
#
# Input source: persona from Claude Code's stdin JSON (agent_type), env fallback.
# NOTE: TICKET/TARGETS/PROD_TARGETS are per-dispatch context not passed to CC
# subagent hooks via env (TODO part 2: read from on-disk ticket state by agent_id).
set -uo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
persona="$(J .agent_type)"; [ -n "$persona" ] || persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
case "$persona" in implementer|actuator) ;; *) exit 0 ;; esac
ts="$(date -u +%FT%TZ)"; t="${TICKET:-$(bash "$RT/ledger.sh" writer-ctx get ticket)}"; d="${DISPATCH_ID:-$RANDOM}"
[ -n "$t" ] || exit 0    # no ticket context -> nothing to write-ahead

if [ "$persona" = implementer ]; then
  b="${ASSIGNED_BRANCH:-}"
  bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"dispatched\",\"persona\":\"implementer\",\"branch\":\"$b\",\"dispatch_id\":\"$d\"}"
  lease=".agents/runs/orchestrate/tickets/$t/lease"; mkdir -p "$(dirname "$lease")"
  printf '{"dispatch_id":"%s","session":"%s","pid":%s,"ts":"%s"}\n' "$d" "${SESSION_ID:-?}" "$$" "$ts" > "$lease"
  exit 0
fi

# actuator: ledger hygiene for the pre-apply gate — if a prod-level target lacks an
# operator ack, leave NO trace (no dispatched/lease) so reground isn't poisoned.
pts="${PROD_TARGETS:-$(bash "$RT/ledger.sh" writer-ctx get prod_targets)}"
for key in $pts; do
  [ -f ".agents/runs/orchestrate/tickets/$t/ack-$(bash "$RT/ledger.sh" lease-key "$key")" ] || {
    bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"gate-blocked\",\"persona\":\"actuator\",\"key\":\"$key\"}"
    exit 0
  }
done
bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"dispatched\",\"persona\":\"actuator\",\"dispatch_id\":\"$d\"}"
for key in ${TARGETS:-}; do
  bash "$RT/ledger.sh" lease-acquire "$t" "$key" || \
    bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"lease-conflict\",\"persona\":\"actuator\",\"key\":\"$key\"}"
done
exit 0
