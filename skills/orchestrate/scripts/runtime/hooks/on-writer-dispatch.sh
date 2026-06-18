#!/usr/bin/env bash
# SubagentStart (writer only): write-ahead 'dispatched' + lease BEFORE the
# Implementer runs. This is the ONE ledger write that must be deterministic:
# research consensus says must-happen/failure-intolerable actions belong in a
# hook, not loop discipline — and a just-dispatched writer leaves no dirty
# worktree yet, so the reground backstop can't see it until it writes. Everything
# else (returned/verdict, read-only dispatches) stays in-loop, low-cost to miss.
set -euo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
case "$persona" in implementer|actuator) ;; *) exit 0 ;; esac   # writers only
ts="$(date -u +%FT%TZ)"; t="${TICKET:?}"; d="${DISPATCH_ID:-$RANDOM}"
if [ "$persona" = implementer ]; then
  b="${ASSIGNED_BRANCH:-}"
  bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"dispatched\",\"persona\":\"implementer\",\"branch\":\"$b\",\"dispatch_id\":\"$d\"}"
  lease=".agents/runs/orchestrate/tickets/$t/lease"; mkdir -p "$(dirname "$lease")"
  printf '{"dispatch_id":"%s","session":"%s","pid":%s,"ts":"%s"}\n' "$d" "${SESSION_ID:-?}" "$$" "$ts" > "$lease"
else
  # Pre-apply consequence gate, ledger half (SKILL §6b): if a prod-level target
  # lacks an operator ack, leave NO trace — do not journal `dispatched` or take a
  # lease (a false trace would poison the next reground into a HALT). The HARD
  # block on the Actuator's commands is gate-prod-apply.sh wired at PreToolUse,
  # because SubagentStart is non-blocking on shell harnesses.
  for key in ${PROD_TARGETS:-}; do
    if [ ! -f ".agents/runs/orchestrate/tickets/$t/ack-$(bash "$RT/ledger.sh" lease-key "$key")" ]; then
      bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"gate-blocked\",\"persona\":\"actuator\",\"key\":\"$key\"}"
      echo '{"decision":"deny","reason":"pre-apply consequence gate: prod target requires operator ack"}'
      exit 1
    fi
  done
  bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"dispatched\",\"persona\":\"actuator\",\"dispatch_id\":\"$d\"}"
  # Acquire a lease per declared target. A failed acquire (exit 4 = held by
  # another lane) must NOT be silently swallowed: journal it and deny the
  # dispatch, so the Actuator never proceeds against a target it does not hold
  # (this protects the one guaranteed layer in ADR-0002 — serialization).
  conflict=0
  for key in ${TARGETS:-}; do
    if ! bash "$RT/ledger.sh" lease-acquire "$t" "$key"; then
      bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"lease-conflict\",\"persona\":\"actuator\",\"key\":\"$key\"}"
      conflict=1
    fi
  done
  if [ "$conflict" = 1 ]; then
    echo '{"decision":"deny","reason":"mutation target lease held by another lane"}'
    exit 1
  fi
fi
