#!/usr/bin/env bash
# PreToolUse (implementer): deny reads under $HELDOUT_ROOT. Fail closed.
set -euo pipefail
p="${RESOLVED_PATH:-${CODEX_TOOL_PATH:-}}"
case "$p" in
  "${HELDOUT_ROOT:?}"/*) echo '{"decision":"deny","reason":"held-out test path"}'; exit 0 ;;
  "")                    echo '{"decision":"deny","reason":"unresolvable path"}'; exit 0 ;;
esac
echo '{"decision":"allow"}'
