#!/usr/bin/env bash
# PreToolUse(Bash): funnel EVERY `done` event through the gated `ledger.sh done`
# helper. The router's measured habit is to raw-append a done event (`ledger.sh append`
# / `echo >> board.jsonl`), which bypasses the fail-closed verify gate — so a T1/T2 lane
# can ship without a Verifier verdict. This hook DENIES any Bash that writes an
# event:"done" directly; the only admitted path is `ledger.sh done <ticket>`, which
# enforces the gate. That makes "ship unverified" impossible, not merely discouraged —
# the enforcement half that prose (and a bypassable helper) could not deliver.
#
# Persona-independent (the offender is the router itself, which carries no agent_type),
# same posture as guard-shared-checkout.sh. Best-effort string match (a determined
# obfuscation is out of scope, as with the other guard hooks).
#
# Contract (Claude Code): ALLOW = exit 0, no stdout; DENY = reason on stderr + exit 2.
# Input on STDIN as JSON (tool_input.command); env fallback for Codex/OpenCode. Without
# jq under CC it degrades to allow (same posture as the sibling hooks).
set -uo pipefail
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
cmd="$(J .tool_input.command)"; [ -n "$cmd" ] || cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
[ -n "$cmd" ] || exit 0
# A direct write of a done event into the board. The gated `ledger.sh done <ticket>`
# command carries no literal event-json, so it is unaffected — only raw appends match.
case "$cmd" in
  *'"event":"done"'*|*"'event':'done'"*|*'"event": "done"'*)
    echo "orchestrate: do not write a 'done' event directly — close the lane with 'ledger.sh done <ticket>'. It is fail-closed: a T1/T2 lane with no Verifier verdict on the board is refused (verification is not optional; T0 baseline lanes are exempt)." >&2
    exit 2 ;;
esac
exit 0
