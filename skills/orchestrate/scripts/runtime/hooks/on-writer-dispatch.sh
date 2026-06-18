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
[ "$persona" = implementer ] || exit 0          # writer only; no-op for others
ts="$(date -u +%FT%TZ)"; t="${TICKET:?}"; b="${ASSIGNED_BRANCH:-}"; d="${DISPATCH_ID:-$RANDOM}"
bash "$RT/ledger.sh" append "{\"ts\":\"$ts\",\"ticket\":\"$t\",\"event\":\"dispatched\",\"persona\":\"implementer\",\"branch\":\"$b\",\"dispatch_id\":\"$d\"}"
lease=".agents/runs/orchestrate/tickets/$t/lease"; mkdir -p "$(dirname "$lease")"
printf '{"dispatch_id":"%s","session":"%s","pid":%s,"ts":"%s"}\n' "$d" "${SESSION_ID:-?}" "$$" "$ts" > "$lease"
