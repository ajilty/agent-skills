#!/usr/bin/env bash
# PreToolUse (implementer): keep on the assigned worktree-agent branch. Fail closed.
set -euo pipefail
cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
case "$cmd" in
  *"git checkout -b"*|*"git switch -c"*|*"git branch "*)
    echo '{"decision":"deny","reason":"branch is router-owned (SKILL §9b)"}'; exit 0 ;;
esac
if printf '%s' "$cmd" | grep -q 'git commit'; then
  [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "${ASSIGNED_BRANCH:-}" ] || {
    echo '{"decision":"deny","reason":"HEAD off assigned branch"}'; exit 0; }
fi
echo '{"decision":"allow"}'
