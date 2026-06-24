#!/usr/bin/env bash
# Tier 3c, Layer 2 — live effectiveness A/B runner. For each fixture, runs two arms on
# the SAME seed state, K times, and prints a scorecard. The held-out pass rate is the
# signal (visible can be green on a broken result — that is the fixture's whole point).
#
#   bash tests/eval/run.sh [K] [fixture-name]      # default K=1, discount-coupling
#
# Arms:
#   naive       — one `claude -p` session, full edit tools, NO orchestrate.
#   orchestrate — a SINGLE-PASS driving of the real personas (implementer -> verifier
#                 handed the held-out oracle via $HELDOUT_ROOT -> fix-once on REJECT).
#                 This is NOT the full standing router loop (no ledger/leases/worktrees);
#                 it isolates the load-bearing structural feature the A/B is about — a
#                 fresh-context verifier running a held-out check the implementer never
#                 saw — so any delta is attributable to that, honestly labeled.
#
# Reporting only: a quality delta NEVER hard-fails CI (the safety fixtures are the
# gate). FS-isolated (HOME+cwd) like the rest of the live tier; self-skips without
# claude/auth/python3.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"            # tests/eval
INT_HERE="$HERE/../integration"; export INT_HERE
. "$INT_HERE/lib.sh"                              # mk_tmp/mk_authed_home/have_* + PLUGIN_DIR + EXIT-trap isolation
K="${1:-1}"; FXNAME="${2:-discount-coupling}"
FX="$HERE/fixtures/$FXNAME"; ORACLE="$FX/heldout/test_oracle.py"; SCORE="$HERE/score.sh"

have_claude     || { echo "(skip eval: claude not on PATH)"; exit 0; }
have_live_auth  || { echo "(skip eval: no live auth)"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "(skip eval: python3 absent)"; exit 0; }
[ -d "$FX" ] || { echo "no such fixture: $FXNAME" >&2; exit 2; }

h="$(mk_authed_home)"
seed_repo(){ local d; d="$(mk_tmp)/repo"; mkdir -p "$d"; cp "$FX/seed/"*.py "$d/"; printf '%s\n' "$d"; }

run_naive(){ local repo="$1"
  printf '%s\n\nWork in the current directory; edit files with your tools. Ensure test_cart.py passes when done.' "$(cat "$FX/goal.md")" \
    | ( cd "$repo" && HOME="$h" timeout 300 claude -p --allowedTools "Read,Grep,Glob,Edit,Write,Bash" ) >/dev/null 2>&1 || true
}

run_orchestrate(){ local repo="$1"
  local hr; hr="$(mk_tmp)/heldout"; mkdir -p "$hr"; cp "$ORACLE" "$hr/test_oracle.py"
  local goal; goal="$(cat "$FX/goal.md")"
  local prompt="You are the orchestrate router driving one goal to completion. Goal:
$goal

Work in the current directory. Do exactly this, using the Task tool for each dispatch:
1. Dispatch a subagent of type orchestrate:implementer to make the change (Bash/Write/Edit allowed).
2. Dispatch a subagent of type orchestrate:verifier. Instruct it to run exactly this from the repo root: python3 \$HELDOUT_ROOT/test_oracle.py .  — treat a NONZERO exit as REJECTED and report which assertion failed.
3. If the verifier REJECTED, dispatch orchestrate:implementer ONE more time to fix the specific breakage it reported, then stop. If APPROVED, stop."
  printf '%s' "$prompt" | ( cd "$repo" && HOME="$h" HELDOUT_ROOT="$hr" timeout 600 claude -p --plugin-dir "$PLUGIN_DIR" --allowedTools "Task,Read,Grep,Glob,Edit,Write,Bash" ) >/dev/null 2>&1 || true
}

declare -A HV=( [naive]=0 [orchestrate]=0 ) VV=( [naive]=0 [orchestrate]=0 )
for arm in naive orchestrate; do
  for k in $(seq 1 "$K"); do
    repo="$(seed_repo)"
    "run_$arm" "$repo"
    eval "$(bash "$SCORE" "$repo" "$ORACLE")"
    VV[$arm]=$(( ${VV[$arm]} + visible )); HV[$arm]=$(( ${HV[$arm]} + heldout ))
    echo "  $arm run $k/$K: visible=$visible heldout=$heldout"
  done
done

echo
echo "=== Tier 3c effectiveness scorecard ($FXNAME, K=$K) ==="
printf '%-12s %-14s %-14s\n' arm visible_pass heldout_pass
for arm in naive orchestrate; do printf '%-12s %-14s %-14s\n' "$arm" "${VV[$arm]}/$K" "${HV[$arm]}/$K"; done
echo
echo "held-out pass is the real signal (visible can be green on a broken result)."
echo "reporting only — a quality delta never hard-fails CI; the safety fixtures are the gate."
