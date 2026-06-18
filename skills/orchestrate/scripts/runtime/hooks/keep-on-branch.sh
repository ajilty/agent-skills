#!/usr/bin/env bash
# PreToolUse (Bash): keep the IMPLEMENTER on its assigned worktree-agent branch.
#
# Hook contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on
# stderr + exit 2 (decision JSON fails CC hook-output validation). Never errors:
#  - self-guard on persona (only the implementer is constrained),
#  - off-branch commit check only when ASSIGNED_BRANCH is set (else allow).
set -uo pipefail
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
[ "$persona" = implementer ] || exit 0
cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
case "$cmd" in
  *"git checkout -b"*|*"git switch -c"*|*"git branch "*)
    echo "orchestrate: branch is router-owned (SKILL §9b)" >&2; exit 2 ;;
esac
if printf '%s' "$cmd" | grep -q 'git commit'; then
  ab="${ASSIGNED_BRANCH:-}"
  if [ -n "$ab" ] && [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)" != "$ab" ]; then
    echo "orchestrate: HEAD off assigned branch ($ab)" >&2; exit 2
  fi
fi
exit 0
