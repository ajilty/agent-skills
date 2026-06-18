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
LEASES="$ROOT/leases"
enc(){ printf '%s' "$1" | sed 's#/#%2F#g'; }   # only '/' needs encoding on Linux
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
    # (c) target leases: reconcile — release a done ticket's lease (so it can't
    #     block a later ticket on the same target); HALT on a lease whose ticket
    #     never reached 'done' (crashed/in-flight), fail-closed.
    if [ -d "$LEASES" ]; then
      for f in "$LEASES"/*; do
        [ -e "$f" ] || continue
        lt="$(val "$(cat "$f")" ticket)"; lk="$(val "$(cat "$f")" key)"
        done_evt=0
        if [ -f "$LEDGER" ]; then grep -q "\"ticket\":\"$lt\".*\"event\":\"done\"" "$LEDGER" && done_evt=1; fi
        [ "$done_evt" = 1 ] && { rm -f "$f"; continue; }   # reconcile: release the done ticket's lease
        echo "OPEN LEASE $lk ticket=$lt -> release or reconcile before re-dispatch"; ambiguous=1; printed=1
      done
    fi
    [ "$printed" = 0 ] && echo "board: no open lanes"
    [ "$ambiguous" = 1 ] && { echo "REGROUND: ambiguous writer lane(s) -> HALT for human re-attach"; exit 3; }
    echo "REGROUND: clean" ;;

  lease-key) printf '%s\n' "$(enc "${1:?key}")" ;;

  lease-acquire)   # exit 0 if free or self-owned, 4 if held by another ticket
    tk="${1:?ticket}"; key="${2:?key}"; f="$LEASES/$(enc "$key")"
    mkdir -p "$LEASES"
    if [ -f "$f" ]; then
      owner="$(val "$(cat "$f")" ticket)"
      [ "$owner" = "$tk" ] && exit 0 || exit 4
    fi
    printf '{"key":"%s","ticket":"%s","ts":"%s"}\n' "$key" "$tk" "$(date -u +%FT%TZ)" > "$f" ;;

  lease-release) key="${1:?key}"; rm -f "$LEASES/$(enc "$key")" ;;

  lease-check)   key="${1:?key}"; [ -f "$LEASES/$(enc "$key")" ] && exit 4 || exit 0 ;;

  ack)   # operator confirms a prod-level mutation target for a ticket (pre-apply gate, SKILL §6b)
    tk="${1:?ticket}"; key="${2:?key}"; m="$ROOT/tickets/$tk/ack-$(enc "$key")"
    mkdir -p "$(dirname "$m")"; : > "$m" ;;

  decision)   # record a resolved DECISION_FORK to the board (judgment-memory capture, SKILL §11)
    tk="${1:?ticket}"; fid="${2:?fork_id}"; adr="${3:-}"; mkdir -p "$ROOT"
    printf '{"ts":"%s","ticket":"%s","event":"decision","fork_id":"%s","adr":"%s"}\n' "$(date -u +%FT%TZ)" "$tk" "$fid" "$adr" >> "$LEDGER" ;;

  writer-ctx)  # per-dispatch enforcement context (ADR-0006): the router writes this
               # BEFORE dispatching a writer; the hooks read it (CC passes no router
               # env to subagent hooks). Line format -> no jq needed. Single active
               # writer (single-writer rail), cleared on lane close.
    sub="${1:-}"; shift || true; f="$ROOT/active-writer.json"
    case "$sub" in
      set)   # set <ticket> <persona> <assigned_branch> [prod_target...]
        wt="${1:?ticket}"; wp="${2:?persona}"; wb="${3:-}"; pt="${*:4}"; mkdir -p "$ROOT"
        printf 'ticket=%s\npersona=%s\nassigned_branch=%s\nprod_targets=%s\nts=%s\n' \
          "$wt" "$wp" "$wb" "$pt" "$(date -u +%FT%TZ)" > "$f" ;;
      get)   k="${1:?key}"; [ -f "$f" ] || exit 0; sed -n "s/^$k=//p" "$f" ;;
      clear) rm -f "$f" ;;
      *) echo "usage: ledger.sh writer-ctx set <ticket> <persona> <branch> [prod...] | get <key> | clear" >&2; exit 64 ;;
    esac ;;

  *) echo "usage: ledger.sh {append '<json>'|retries <ticket>|reground|lease-{key,acquire,release,check}|ack|decision <ticket> <fork_id> [adr]|writer-ctx set|get|clear}" >&2; exit 64 ;;
esac
