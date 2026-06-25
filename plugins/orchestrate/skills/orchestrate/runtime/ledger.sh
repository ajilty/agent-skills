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

  metrics)   # §8 metrics, derived by replaying the ledger (no separate sink). Optional
             # ticket filter. Emits key=val pairs; splits healthy escalations (forks/
             # decisions) from friction (rejects + oracle-inconsistencies + lease-conflicts).
    t="${1:-}"
    src(){ [ -f "$LEDGER" ] || return 0; if [ -n "$t" ]; then grep "\"ticket\":\"$t\"" "$LEDGER"; else cat "$LEDGER"; fi; }
    c(){ src | grep -c "$1" 2>/dev/null || true; }
    sh=$(c '"event":"done"'); di=$(c '"event":"dispatched"'); fk=$(c '"event":"fork"')
    de=$(c '"event":"decision"'); rj=$(c '"verdict":"REJECTED"'); oi=$(c '"verdict":"INCONSISTENT_ORACLE"')
    lc=$(c '"event":"lease-conflict"'); fr=$(( rj + oi + lc ))
    # delegation health (the infra-log finding: verification is the least-delegated function).
    dr=$(c '"event":"dispatched".*"persona":"researcher"'); dp=$(c '"event":"dispatched".*"persona":"planner"')
    dimp=$(c '"event":"dispatched".*"persona":"implementer"'); da=$(c '"event":"dispatched".*"persona":"actuator"')
    dv=$(src | grep -cE '"event":"dispatched".*"persona":"(verifier|validator)"' 2>/dev/null || true)
    # verify_coverage: of shipped (done) lanes, how many actually got a verifier verdict?
    verified=0; total=0
    while IFS= read -r tk; do [ -n "$tk" ] || continue; total=$((total+1))
      src | grep -q "\"ticket\":\"$tk\".*\"event\":\"verdict\"" && verified=$((verified+1))
    done < <(src | grep '"event":"done"' | sed -n 's/.*"ticket":"\([^"]*\)".*/\1/p' | sort -u)
    printf 'shipped=%s dispatches=%s forks=%s decisions=%s rejects=%s oracle_inconsistent=%s lease_conflicts=%s friction=%s disp_researcher=%s disp_planner=%s disp_implementer=%s disp_verifier=%s disp_actuator=%s verify_coverage=%s/%s\n' \
      "$sh" "$di" "$fk" "$de" "$rj" "$oi" "$lc" "$fr" "$dr" "$dp" "$dimp" "$dv" "$da" "$verified" "$total" ;;

  feedback)  # Tier 3c, Layer 3: append a durable operator-feedback record (a ledger
             # metrics snapshot + a free-text rating) to the eval log, and echo it. This
             # is the live, observational complement to the headless A/B (tests/eval).
    note="${*:-}"; ed="$ROOT/eval"; mkdir -p "$ed"
    m="$(bash "$0" metrics)"
    json=""; for kv in $m; do json="$json,\"${kv%%=*}\":${kv#*=}"; done
    nl="${note//\\/\\\\}"; nl="${nl//\"/\\\"}"
    printf '{"ts":"%s","event":"feedback","note":"%s"%s}\n' "$(date -u +%FT%TZ)" "$nl" "$json" >> "$ed/feedback.jsonl"
    printf 'feedback recorded -> %s\n%s\nnote: %s\n' "$ed/feedback.jsonl" "$m" "${note:-<none>}" ;;

  conformance)  # Tier 3c trace conformance: assert the ledger contains the expected
                # choreography as an ORDERED SUBSEQUENCE. Each arg is event[:detail],
                # e.g. dispatched:implementer, returned:researcher, verdict, verdict:APPROVED.
                # Catches orchestrate silently SKIPPING a step (e.g. the verifier never
                # ran -> no verdict). exit 0 = chain ran as designed; exit 1 = first unmet
                # step named; exit 64 = no specs.
    [ $# -gt 0 ] || { echo "usage: ledger.sh conformance <event[:detail]>..." >&2; exit 64; }
    specs=("$@"); n=$#; i=0
    if [ -f "$LEDGER" ]; then
      while IFS= read -r line; do
        [ "$i" -lt "$n" ] || break
        spec="${specs[$i]}"; kind="${spec%%:*}"; detail=""
        case "$spec" in *:*) detail="${spec#*:}";; esac
        case "$line" in *"\"event\":\"$kind\""*) ;; *) continue;; esac
        if [ -n "$detail" ]; then case "$line" in *"\"$detail\""*) ;; *) continue;; esac; fi
        i=$((i+1))
      done < "$LEDGER"
    fi
    [ "$i" -ge "$n" ] && exit 0
    echo "conformance: chain broke at step $((i+1))/$n — missing (or out of order): ${specs[$i]}" >&2
    exit 1 ;;

  reground)
    declare -A laststate
    if [ -f "$LEDGER" ]; then
      while IFS= read -r line; do
        t="$(val "$line" ticket)"; [ -z "$t" ] && continue
        ev="$(val "$line" event)"; [ -n "$ev" ] && laststate["$t"]="$ev|$(val "$line" persona)|$(val "$line" branch)|$(val "$line" slug)"
      done < "$LEDGER"
    fi
    ambiguous=0; printed=0
    # (a) ledger-derived open lanes
    for t in "${!laststate[@]}"; do
      IFS='|' read -r ev persona branch slug <<< "${laststate[$t]}"
      [ "$ev" = dispatched ] || continue
      printed=1
      if [ "$persona" = implementer ]; then
        if git rev-parse --verify "$branch" >/dev/null 2>&1; then
          echo "OPEN WRITER   ticket=$t branch=$branch -> reconcile worktree before re-dispatch"; ambiguous=1
        else
          echo "OPEN WRITER   ticket=$t branch=$branch MISSING -> re-dispatch candidate"
        fi
      else
        # READ-ONLY lane (ADR-0014): the result is now a durable file, so the
        # re-dispatch decision keys on its PRESENCE, not a guess. A read-only
        # re-dispatch is idempotent (no writer lease) -> never an ambiguous HALT.
        art="$ROOT/tickets/$t/findings/$slug.md"
        if [ -n "$slug" ] && [ -f "$art" ]; then
          echo "READONLY DONE  ticket=$t slug=$slug -> result on disk: $art"
        else
          echo "OPEN READONLY  ticket=$t persona=$persona slug=${slug:-?} -> re-dispatch (no result on disk${slug:+: $art})"
        fi
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
    # (d) dangling active-writer record (ADR-0006): a writer that did not cleanly
    #     close (router crashed between writer-ctx set and clear). A stale record
    #     can let a later dispatch read an already-acked context and bypass the
    #     pre-apply gate, so treat it as an ambiguous in-flight writer and HALT for
    #     reconcile (the operator/router clears it via `writer-ctx clear`). We do
    #     NOT auto-clear: at compaction the record may belong to a live writer.
    if [ -f "$ROOT/active-writer.json" ]; then
      awt="$(sed -n 's/^ticket=//p' "$ROOT/active-writer.json")"
      awp="$(sed -n 's/^persona=//p' "$ROOT/active-writer.json")"
      echo "OPEN WRITER   active-writer ticket=$awt persona=$awp -> reconcile (ledger.sh writer-ctx clear) before re-dispatch"
      ambiguous=1; printed=1
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

  clarify)    # journal the router's intake-clarification decision (§2b/ADR-0004): which
              # clarification skill was selected (first-present-wins), so the choreography
              # is a checkable trace instead of invisible router-context behavior.
    sk="${1:?skill}"; tk="${2:-intake}"; mkdir -p "$ROOT"
    printf '{"ts":"%s","ticket":"%s","event":"clarify","skill":"%s"}\n' "$(date -u +%FT%TZ)" "$tk" "$sk" >> "$LEDGER" ;;

  done)       # close a lane FAIL-CLOSED on unverified ships: a verifying tier (T1/T2)
              # may not be marked done without a verdict for that ticket. T0 (one
              # Implementer vs the oracle — the oracle IS the check) is exempt; unknown
              # tier requires a verdict (fail-closed). The ENFORCEMENT half of
              # "verification is not optional" — the router under-delegates verification,
              # so the gate makes a ship without a Verifier impossible, not just discouraged.
    tk="${1:?ticket}"; mkdir -p "$ROOT"; tier=""; hv=0
    if [ -f "$LEDGER" ]; then
      tier="$(grep "\"ticket\":\"$tk\".*\"event\":\"intake\"" "$LEDGER" 2>/dev/null | sed -n 's/.*"tier":"\([^"]*\)".*/\1/p' | tail -1 || true)"
      grep -q "\"ticket\":\"$tk\".*\"event\":\"verdict\"" "$LEDGER" 2>/dev/null && hv=1 || true
    fi
    case "$tier" in
      T0*|t0*) ;;   # T0 baseline lane: the acceptance oracle is the check, no Verifier
      *) if [ "$hv" != 1 ]; then
           echo "orchestrate: refusing 'done' for $tk — no Verifier verdict on the board (tier=${tier:-unknown}). A T1/T2 lane must pass a Verifier first: dispatch the verifier, record its verdict, then mark done. (T0 baseline lanes are exempt — set tier=T0 at intake.)" >&2
           exit 3
         fi ;;
    esac
    printf '{"ts":"%s","ticket":"%s","event":"done"}\n' "$(date -u +%FT%TZ)" "$tk" >> "$LEDGER" ;;

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

  *) echo "usage: ledger.sh {append '<json>'|retries <ticket>|reground|metrics [ticket]|feedback <note>|conformance <event[:detail]>...|clarify <skill> [ticket]|done <ticket>|lease-{key,acquire,release,check}|ack|decision <ticket> <fork_id> [adr]|writer-ctx set|get|clear}" >&2; exit 64 ;;
esac
