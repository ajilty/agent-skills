#!/usr/bin/env bash
# PreToolUse (Write|Edit): confine the PLANNER to writing only the spec/ADR
# artifact paths (agents.yaml `write_scope`, SKILL §5; fail_closed). The planner's
# only write target is the committed spec + ADR plus the per-ticket artifact dir;
# a write anywhere else (source tree, configs) is refused. Other personas are
# unaffected — capability subtraction already governs them.
#
# Input source: Claude Code delivers tool_input + agent_type on STDIN as JSON; we
# parse stdin (jq) and fall back to env for Codex/OpenCode (RESOLVED_PATH/PERSONA).
# Without jq under CC it degrades to allow (safe, not enforcing) — same posture as
# the sibling hooks.
#
# Contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on stderr +
# exit 2. Self-guards on persona; never errors. Fail-closed: a planner write whose
# path can't be resolved falls through to deny, and any `..` is rejected (no
# climbing out of an allowed prefix). Accepted residual: the prefix is matched
# textually, so a path that merely *contains* an allowed segment (e.g.
# foo/docs/specs/x.md) is allowed — benign (still a docs-shaped target, not source)
# and the planner is a trusted internal persona; the load-bearing denial is the
# source tree (src/, configs), which has no such segment.
set -uo pipefail
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
persona="$(J .agent_type)"; [ -n "$persona" ] || persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
[ "$persona" = planner ] || exit 0
p="$(J .tool_input.file_path)"; [ -n "$p" ] || p="$(J .tool_input.path)"
[ -n "$p" ] || p="${RESOLVED_PATH:-${CODEX_TOOL_PATH:-}}"
# Reject `..` traversal first: a textual prefix match can't be trusted once a path
# can climb out of it (docs/specs/../../src/x). A spec/ADR write never needs `..`.
case "$p" in
  ..|../*|*/..|*/../*) echo "orchestrate: planner write path must not contain '..' (refused: $p)" >&2; exit 2 ;;
esac
case "$p" in
  docs/specs/*|*/docs/specs/*|docs/adr/*|*/docs/adr/*|.agents/runs/orchestrate/tickets/*|*/.agents/runs/orchestrate/tickets/*) exit 0 ;;
esac
echo "orchestrate: planner writes are confined to the spec/ADR artifact — docs/specs/, docs/adr/, or the per-ticket dir (refused: ${p:-<unresolved>})" >&2
exit 2
