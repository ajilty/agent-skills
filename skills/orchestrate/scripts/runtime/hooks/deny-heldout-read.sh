#!/usr/bin/env bash
# PreToolUse: bar the WRITERS (implementer/actuator) from reading the held-out
# oracle under $HELDOUT_ROOT — defense-in-depth behind the filesystem isolation.
#
# Hook contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on
# stderr + exit 2. Emitting decision JSON on stdout fails CC's hook-output
# validation ("Invalid input"), so we use the stdout-free exit-code contract,
# which is also the most portable across harnesses. A hook runs on EVERY matched
# tool call in the router and every subagent, so it must NEVER error:
#  - self-guard on persona (only writers checked; Verifier/router read freely),
#  - no HELDOUT_ROOT configured => nothing to enforce => allow,
#  - empty/unresolvable path (e.g. a Bash call) => allow; the real boundary is the
#    filesystem isolation ($HELDOUT_ROOT outside the writer's tree).
set -uo pipefail
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
case "$persona" in implementer|actuator) ;; *) exit 0 ;; esac
[ -n "${HELDOUT_ROOT:-}" ] || exit 0
p="${RESOLVED_PATH:-${CODEX_TOOL_PATH:-}}"
case "$p" in
  "$HELDOUT_ROOT"/*) echo "orchestrate: held-out oracle is off-limits to the writer ($p)" >&2; exit 2 ;;
esac
exit 0
