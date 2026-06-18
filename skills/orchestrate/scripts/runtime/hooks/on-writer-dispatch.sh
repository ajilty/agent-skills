#!/usr/bin/env bash
# SubagentStart (writers): write-ahead 'dispatched' + lease BEFORE the writer runs,
# so a just-dispatched writer that left no dirty worktree is still visible to
# reground. SubagentStart is NON-blocking and its output is not a decision, so this
# does ledger side-effects only and ALWAYS exits 0 — it never emits decision JSON
# and never :? aborts. The hard enforcement lives in the PreToolUse hooks.
set -uo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
case "$persona" in implementer|actuator) ;; *) exit 0 ;; esac   # writers only
ts="$(date -u +%FT%TZ)"; t="${TICKET:-}"; d="${DISPATCH_ID:-$RANDOM}"
[ -n "$t" ] || exit 0    # no ticket context -> nothing to write-ahead

if [ "$persona" = implementer ]; then
  b="${ASSIGNED_BRANCH:-}"
  bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"dispatched\",\"persona\":\"implementer\",\"branch\":\"$b\",\"dispatch_id\":\"$d\"}"
  lease=".agents/runs/orchestrate/tickets/$t/lease"; mkdir -p "$(dirname "$lease")"
  printf '{"dispatch_id":"%s","session":"%s","pid":%s,"ts":"%s"}\n' "$d" "${SESSION_ID:-?}" "$$" "$ts" > "$lease"
  exit 0
fi

# actuator: ledger hygiene for the pre-apply gate — if a prod-level target lacks an
# operator ack, leave NO trace (no dispatched/lease) so reground isn't poisoned;
# the actual block is gate-prod-apply.sh at PreToolUse.
for key in ${PROD_TARGETS:-}; do
  [ -f ".agents/runs/orchestrate/tickets/$t/ack-$(bash "$RT/ledger.sh" lease-key "$key")" ] || {
    bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"gate-blocked\",\"persona\":\"actuator\",\"key\":\"$key\"}"
    exit 0
  }
done
bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"dispatched\",\"persona\":\"actuator\",\"dispatch_id\":\"$d\"}"
# Acquire a lease per declared target; a failed acquire (held by another lane) is
# journaled (observability) — serialization is enforced by the router's pre-dispatch
# lease-check, not by this non-blocking hook.
for key in ${TARGETS:-}; do
  bash "$RT/ledger.sh" lease-acquire "$t" "$key" || \
    bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"lease-conflict\",\"persona\":\"actuator\",\"key\":\"$key\"}"
done
exit 0
