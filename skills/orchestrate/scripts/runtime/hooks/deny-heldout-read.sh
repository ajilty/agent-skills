#!/usr/bin/env bash
# PreToolUse: bar the WRITERS (implementer/actuator) from reading the held-out
# oracle under $HELDOUT_ROOT — defense-in-depth behind the filesystem isolation.
#
# Robustness contract (a hook runs on EVERY matched tool call, in the router and
# every subagent): it must NEVER error — always emit valid JSON and exit 0.
#  - self-guard on persona: only the writers are checked; the Verifier and router
#    MUST be able to read the oracle, so they always pass.
#  - no HELDOUT_ROOT configured => no boundary => allow (do not :? abort).
#  - empty/unresolvable path (e.g. a Bash call) => allow; the real boundary is the
#    filesystem isolation ($HELDOUT_ROOT outside the writer's tree), not this hook.
set -uo pipefail
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
case "$persona" in implementer|actuator) ;; *) echo '{"decision":"allow"}'; exit 0 ;; esac
[ -n "${HELDOUT_ROOT:-}" ] || { echo '{"decision":"allow"}'; exit 0; }
p="${RESOLVED_PATH:-${CODEX_TOOL_PATH:-}}"
case "$p" in
  "$HELDOUT_ROOT"/*) echo '{"decision":"deny","reason":"held-out oracle is off-limits to the writer"}'; exit 0 ;;
esac
echo '{"decision":"allow"}'
