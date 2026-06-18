#!/usr/bin/env bash
# PreToolUse (Bash): keep the IMPLEMENTER on its assigned worktree-agent branch.
#
# Input source: parse Claude Code's stdin JSON (tool_input.command, agent_type);
# fall back to env for Codex/OpenCode. Contract: ALLOW = exit 0 no stdout; DENY =
# stderr + exit 2. Self-guards; never errors.
#
# NOTE: the off-branch-commit check needs the per-dispatch ASSIGNED_BRANCH, which
# CC does not pass to subagent hooks via env — until that reads from on-disk ticket
# state (see TODO), only branch create/switch is enforced under CC.
set -uo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
persona="$(J .agent_type)"; [ -n "$persona" ] || persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
[ "$persona" = implementer ] || exit 0
cmd="$(J .tool_input.command)"; [ -n "$cmd" ] || cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
case "$cmd" in
  *"git checkout -b"*|*"git switch -c"*|*"git branch "*)
    echo "orchestrate: branch is router-owned (SKILL §9b)" >&2; exit 2 ;;
esac
if printf '%s' "$cmd" | grep -q 'git commit'; then
  ab="${ASSIGNED_BRANCH:-$(bash "$RT/ledger.sh" writer-ctx get assigned_branch)}"
  if [ -n "$ab" ] && [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)" != "$ab" ]; then
    echo "orchestrate: HEAD off assigned branch ($ab)" >&2; exit 2
  fi
fi
exit 0
