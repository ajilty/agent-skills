#!/usr/bin/env bash
# PreToolUse (Bash): UNIVERSAL git-safety floor (ADR-0013, SKILL §9a). No agent — the
# router OR any persona — may run a working-tree/history-DISCARDING git op against the
# PRIMARY (shared "main") worktree. This is the hard stop for the data-loss class that
# bit a real run: a stray `git reset --hard origin/<base>` (e.g. a §9a base-correction)
# eating an unpushed commit when an agent lands on the main checkout — the known
# isolation-lands-on-main harness trap.
#
# This hook is PERSONA-INDEPENDENT (unlike the other persona-guarded hooks) because the
# offender is often the router itself (no agent_type). Scope is the PRIMARY worktree
# ONLY — detected by git-dir == git-common-dir; a writer's linked worktree is its own
# throwaway sandbox and is left alone. The legitimate §9a base-correction (git fetch +
# git worktree add/recreate) is NOT destructive-to-main and stays allowed.
#
# Contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on stderr +
# exit 2. Pure command+cwd logic — needs no orchestrate env; never errors.
set -uo pipefail
# ADR-0032: a denial is FEEDBACK — journal it to the board (event "denied") so
# metrics/status/harvest see the friction without operator relay. Fires on ANY
# exit-2 path via the EXIT trap; never blocks, never alters the deny (explicit
# exit codes survive the trap), never touches stdout.
_journal_denial(){ rc=$?; [ "$rc" = 2 ] || return 0
  [ -f ".agents/runs/orchestrate/board.jsonl" ] || return 0   # wrong cwd -> skip
  rt="$(cd "$(dirname "$0")/.." && pwd)" || return 0
  n="$(printf '%.80s' "${cmd:-${p:-}}" | tr '\n' ' ' | tr '"\\' "'/")"
  bash "$rt/ledger.sh" append "{\"event\":\"denied\",\"hook\":\"guard-shared-checkout\",\"persona\":\"${persona:--}\",\"note\":\"$n\"}" >/dev/null 2>&1 || true
  return 0; }
trap _journal_denial EXIT
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
cmd="$(J .tool_input.command)"; [ -n "$cmd" ] || cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
[ -n "$cmd" ] || exit 0

# Word-bounded normalization (same approach as run-scope.sh): collapse shell separators
# to spaces and wrap, so verb checks can't match substrings and inter-token options
# (git -C <dir> reset, git -c k=v checkout) can't slip past.
norm=" ${cmd//[;|&()\`]/ } "
case "$norm" in *" git "*) ;; *) exit 0 ;; esac   # not a git command -> not our concern

# Working-tree / committed-history DISCARDING ops (the "eats local work" set). Check each
# STATEMENT's OWN args, not the whole compound line: a token in one statement (an unrelated
# path, or a commit-message heredoc) must not trip a verb in another. Live 2026-07-06:
# `git checkout -b X && git commit …` was false-denied because a `.`/`--` elsewhere in the
# line matched the checkout case. Split on shell separators, then run the per-verb checks
# per segment (the same token logic, just scoped).
destructive=0
while IFS= read -r seg; do
  n=" $seg "
  case "$n" in *" git "*) ;; *) continue ;; esac
  case "$n" in *" reset "*)    case "$n" in *" --hard "*) destructive=1 ;; esac ;; esac
  case "$n" in *" clean "*)    case "$n" in *" -f"*)     destructive=1 ;; esac ;; esac   # -f / -fd / -ffdx
  case "$n" in *" checkout "*) case "$n" in *" -f "*|*" --force "*|*" . "*|*" -- "*) destructive=1 ;; esac ;; esac
  case "$n" in *" switch "*)   case "$n" in *" --discard-changes "*|*" -f "*) destructive=1 ;; esac ;; esac
done <<< "$(printf '%s' "$cmd" | tr ';|&()`' '\n')"
[ "$destructive" = 1 ] || exit 0

# Only block on the PRIMARY (shared main) worktree. In a linked worktree, git-dir is
# .git/worktrees/<name> while git-common-dir is .git -> they differ -> allow.
gd="$(git rev-parse --git-dir 2>/dev/null || true)"; [ -n "$gd" ] || exit 0
gcd="$(git rev-parse --git-common-dir 2>/dev/null || true)"
if [ "$(cd "$gd" 2>/dev/null && pwd -P)" = "$(cd "$gcd" 2>/dev/null && pwd -P)" ]; then
  echo "orchestrate: refusing a destructive git op on the SHARED main checkout (§9a) — operate in a worktree; recreate, don't reset" >&2
  exit 2
fi
exit 0
