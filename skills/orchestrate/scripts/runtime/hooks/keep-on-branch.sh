#!/usr/bin/env bash
# PreToolUse (Bash): keep the IMPLEMENTER on its assigned worktree-agent branch.
#
# Robustness contract (runs on every Bash call, in the router and every subagent):
# never error — always emit valid JSON and exit 0.
#  - self-guard on persona: only the implementer is constrained; the router and
#    other personas branch/commit freely.
#  - the off-branch commit check only applies when ASSIGNED_BRANCH is set (else we
#    can't enforce it — degrade to allow rather than block a legitimate commit).
set -uo pipefail
persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
[ "$persona" = implementer ] || { echo '{"decision":"allow"}'; exit 0; }
cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
case "$cmd" in
  *"git checkout -b"*|*"git switch -c"*|*"git branch "*)
    echo '{"decision":"deny","reason":"branch is router-owned (SKILL §9b)"}'; exit 0 ;;
esac
if printf '%s' "$cmd" | grep -q 'git commit'; then
  ab="${ASSIGNED_BRANCH:-}"
  if [ -n "$ab" ] && [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)" != "$ab" ]; then
    echo '{"decision":"deny","reason":"HEAD off assigned branch"}'; exit 0
  fi
fi
echo '{"decision":"allow"}'
