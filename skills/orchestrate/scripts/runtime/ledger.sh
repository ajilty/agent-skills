#!/usr/bin/env bash
# ledger.sh — harness-agnostic board ledger (the router's durable control state).
# The orchestrator IS the driver: it appends events as it dispatches, and reads
# them back on resume. No deps beyond coreutils/awk/git.
#
#   ledger.sh append '<json-object>'   # one event line (write-ahead before dispatch)
#   ledger.sh retries <ticket>         # COUNT of REJECTED verdicts for a ticket (no-loop budget, derived)
#   ledger.sh reground                 # reconstruct open lanes; reconcile vs git worktrees (ground truth)
#                                       # exit 0 = clean/empty, exit 3 = ambiguous writer -> HALT
set -euo pipefail
ROOT=".agents/runs/orchestrate"; LEDGER="$ROOT/board.jsonl"
val() { sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" <<< "$1"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  append)
    mkdir -p "$ROOT"; printf '%s\n' "$*" >> "$LEDGER" ;;

  retries)   # derived, never held: compaction can't corrupt a disk count
    t="${1:?ticket}"; [ -f "$LEDGER" ] || { echo 0; exit 0; }
    grep -c "\"ticket\":\"$t\".*\"verdict\":\"REJECTED\"" "$LEDGER" || true ;;

  reground)
    declare -A laststate
    if [ -f "$LEDGER" ]; then
      while IFS= read -r line; do
        t="$(val "$line" ticket)"; [ -z "$t" ] && continue
        ev="$(val "$line" event)"; [ -n "$ev" ] && laststate["$t"]="$ev|$(val "$line" persona)|$(val "$line" branch)"
      done < "$LEDGER"
    fi
    ambiguous=0; printed=0
    # (a) ledger-derived open lanes
    for t in "${!laststate[@]}"; do
      IFS='|' read -r ev persona branch <<< "${laststate[$t]}"
      [ "$ev" = dispatched ] || continue
      printed=1
      if [ "$persona" = implementer ]; then
        if git rev-parse --verify "$branch" >/dev/null 2>&1; then
          echo "OPEN WRITER   ticket=$t branch=$branch -> reconcile worktree before re-dispatch"; ambiguous=1
        else
          echo "OPEN WRITER   ticket=$t branch=$branch MISSING -> re-dispatch candidate"
        fi
      else
        echo "OPEN READONLY ticket=$t persona=$persona -> re-dispatch if $ROOT/tickets/$t artifact absent"
      fi
    done
    # (b) disk ground truth: any worktree on a worktree-agent-* branch with
    #     uncommitted work, even if no ledger event exists (missed append / crash).
    if git rev-parse --git-dir >/dev/null 2>&1; then
      while IFS=$'\t' read -r wt br; do
        case "$br" in *worktree-agent-*)
          if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
            echo "DIRTY WORKTREE $wt ($br) -> uncommitted writer work; reconcile before re-dispatch"; ambiguous=1; printed=1
          fi ;;
        esac
      done < <(git worktree list --porcelain 2>/dev/null | awk '
        /^worktree /{p=$2} /^branch /{b=$2; sub("refs/heads/","",b); print p"\t"b}')
    fi
    [ "$printed" = 0 ] && echo "board: no open lanes"
    [ "$ambiguous" = 1 ] && { echo "REGROUND: ambiguous writer lane(s) -> HALT for human re-attach"; exit 3; }
    echo "REGROUND: clean" ;;

  *) echo "usage: ledger.sh {append '<json>'|retries <ticket>|reground}" >&2; exit 64 ;;
esac
