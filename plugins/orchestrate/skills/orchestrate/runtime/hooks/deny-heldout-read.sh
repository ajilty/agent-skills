#!/usr/bin/env bash
# PreToolUse: bar the WRITERS (implementer/actuator) from reading the held-out
# oracle under $HELDOUT_ROOT — defense-in-depth behind the filesystem isolation.
#
# Input source: Claude Code delivers the payload on STDIN as JSON (tool_input,
# agent_type); there is no agent env var. We parse stdin (jq) and fall back to env
# for Codex/OpenCode (which set RESOLVED_PATH/PERSONA-style vars). Needs jq to
# enforce under CC; without jq it degrades to allow (safe, not enforcing).
#
# We inspect BOTH a structured path (Read/Edit tool_input.file_path) AND the shell
# command (Bash tool_input.command): a writer can otherwise read the oracle via
# `cat $HELDOUT_ROOT/x`, which carries no file_path, and the denial fails open on
# every Bash-capable writer (CC and Codex alike).
#
# Contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on stderr +
# exit 2. Self-guards on persona; never errors.
set -uo pipefail
# ADR-0032: a denial is FEEDBACK — journal it to the board (event "denied") so
# metrics/status/harvest see the friction without operator relay. Fires on ANY
# exit-2 path via the EXIT trap; never blocks, never alters the deny (explicit
# exit codes survive the trap), never touches stdout.
_journal_denial(){ rc=$?; [ "$rc" = 2 ] || return 0
  [ -f ".agents/runs/orchestrate/board.jsonl" ] || return 0   # wrong cwd -> skip
  rt="$(cd "$(dirname "$0")/.." && pwd)" || return 0
  n="$(printf '%.80s' "${cmd:-${p:-}}" | tr '\n' ' ' | tr '"\\' "'/")"
  bash "$rt/ledger.sh" append "{\"event\":\"denied\",\"hook\":\"deny-heldout-read\",\"persona\":\"${persona:--}\",\"note\":\"$n\"}" >/dev/null 2>&1 || true
  return 0; }
trap _journal_denial EXIT
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
# Shell-command path: deny any Bash that references a path UNDER the held-out root
# (same under-root precision as the file_path check — '$HELDOUT_ROOT/' boundary, so
# /tmp/ho/x denies but /tmp/hotel does not).
cmd="$(J .tool_input.command)"
case "$cmd" in
  *"$HELDOUT_ROOT"/*) echo "orchestrate: held-out oracle is off-limits to the writer (command references $HELDOUT_ROOT)" >&2; exit 2 ;;
esac
exit 0
