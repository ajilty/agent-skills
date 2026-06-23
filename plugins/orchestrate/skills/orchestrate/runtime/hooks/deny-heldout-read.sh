#!/usr/bin/env bash
# PreToolUse: bar the WRITERS (implementer/actuator) from reading the held-out
# oracle under $HELDOUT_ROOT — defense-in-depth behind the filesystem isolation.
#
# Input source: Claude Code delivers the payload on STDIN as JSON (tool_input,
# agent_type); there is no agent env var. We parse stdin (jq) and fall back to env
# for Codex/OpenCode (which set RESOLVED_PATH/PERSONA-style vars). Needs jq to
# enforce under CC; without jq it degrades to allow (safe, not enforcing).
#
# Contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on stderr +
# exit 2. Self-guards on persona; never errors.
set -uo pipefail
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
persona="$(J .agent_type)"; [ -n "$persona" ] || persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
persona="${persona##*:}"   # strip plugin namespace: CC sends agent_type as <plugin>:<persona> (e.g. orchestrate:actuator)
case "$persona" in implementer|actuator) ;; *) exit 0 ;; esac
[ -n "${HELDOUT_ROOT:-}" ] || exit 0
p="$(J .tool_input.file_path)"; [ -n "$p" ] || p="$(J .tool_input.path)"
[ -n "$p" ] || p="${RESOLVED_PATH:-${CODEX_TOOL_PATH:-}}"
case "$p" in
  "$HELDOUT_ROOT"/*) echo "orchestrate: held-out oracle is off-limits to the writer ($p)" >&2; exit 2 ;;
esac
exit 0
