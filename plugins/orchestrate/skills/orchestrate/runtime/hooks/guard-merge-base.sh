#!/usr/bin/env bash
# PreToolUse (Bash): merges on the SHARED main checkout must land on the journaled
# integration base (ADR-0027). Field failure ×2: a lane merge landed on a bystander
# branch the operator happened to have checked out — the router never asserted HEAD
# before merging. The base is the `goal` event's optional `base` field (journaled at
# intake); when present and HEAD differs on the PRIMARY checkout, the merge is denied.
#
# Fail-open by design when no base is journaled (the floor keys only on explicit
# intent, like gate-prod-apply's ack files) and in linked worktrees (a writer's merge
# inside its own sandbox is keep-on-branch's concern, not this floor's).
#
# Contract (Claude Code): ALLOW = exit 0 no stdout; DENY = stderr + exit 2. stdin
# JSON with env fallback, persona-independent (the offender is the router itself).
set -uo pipefail
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
cmd="$(J .tool_input.command)"; [ -n "$cmd" ] || cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
[ -n "$cmd" ] || exit 0

norm=" ${cmd//[;|&()\`]/ } "
case "$norm" in *" git "*) ;; *) exit 0 ;; esac
case "$norm" in *" merge "*) ;; *) exit 0 ;; esac

# Primary checkout only (git-dir == git-common-dir), same detection as guard-shared-checkout.
gd="$(git rev-parse --git-dir 2>/dev/null || true)"; [ -n "$gd" ] || exit 0
gcd="$(git rev-parse --git-common-dir 2>/dev/null || true)"
[ "$(cd "$gd" 2>/dev/null && pwd -P)" = "$(cd "$gcd" 2>/dev/null && pwd -P)" ] || exit 0

board=".agents/runs/orchestrate/board.jsonl"; [ -f "$board" ] || exit 0
base="$(grep '"event":"goal"' "$board" 2>/dev/null | tail -1 | sed -n 's/.*"base":"\([^"]*\)".*/\1/p')"
[ -n "$base" ] || exit 0

head="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ "$head" != "$base" ]; then
  echo "orchestrate: merge refused — HEAD is '$head' but the journaled integration base is '$base' (goal event). Check out '$base' first; a merge landing on a bystander branch is the measured branch-drift failure (ADR-0027)." >&2
  exit 2
fi
exit 0
