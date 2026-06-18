RT="$HERE/../skills/orchestrate/runtime"
GATE="$RT/hooks/gate-prod-apply.sh"
KOB="$RT/hooks/keep-on-branch.sh"
d="$(mktemp_repo)"; cd "$d"

# --- ledger writer-ctx set/get/clear roundtrip (ADR-0006 on-disk bridge) ---
bash "$RT/ledger.sh" writer-ctx set T7 actuator "" 'tfstate:prod/db k8s:stg/app'
assert_eq "$(bash "$RT/ledger.sh" writer-ctx get ticket)" "T7" "writer-ctx get ticket"
assert_eq "$(bash "$RT/ledger.sh" writer-ctx get persona)" "actuator" "writer-ctx get persona"
assert_eq "$(bash "$RT/ledger.sh" writer-ctx get prod_targets)" "tfstate:prod/db k8s:stg/app" "writer-ctx get prod_targets"
bash "$RT/ledger.sh" writer-ctx clear
assert_no_file ".agents/runs/orchestrate/active-writer.json"

# --- gate ENFORCES from the record with NO per-dispatch env (the CC scenario) ---
bash "$RT/ledger.sh" writer-ctx set T7 actuator "" 'tfstate:prod/db'
PERSONA=actuator bash "$GATE" >/dev/null 2>&1; rc=$?   # no TICKET/PROD_TARGETS env -> reads record
assert_eq "$rc" "2" "gate denies from active-writer record (unacked prod target, no env)"
grep -q '"event":"gate-blocked".*"key":"tfstate:prod/db"' .agents/runs/orchestrate/board.jsonl && pass || fail "gate-blocked journaled via record path"
bash "$RT/ledger.sh" ack T7 'tfstate:prod/db'
PERSONA=actuator bash "$GATE" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "gate allows from record after operator ack"
bash "$RT/ledger.sh" writer-ctx clear
PERSONA=actuator bash "$GATE" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "gate allows after lane close (writer-ctx cleared)"

# --- branch-guard reads assigned_branch from the record (no env) ---
bash "$RT/ledger.sh" writer-ctx set T8 implementer worktree-agent-T8-impl
PERSONA=implementer TOOL_INPUT='git commit -m x' bash "$KOB" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "keep-on-branch denies off-assigned-branch commit from record"

# --- writer-ctx set OVERWRITES the prior record (the per-dispatch refresh) ---
bash "$RT/ledger.sh" writer-ctx set TA actuator "" 'a:1'
bash "$RT/ledger.sh" writer-ctx set TB implementer br 'b:2'
assert_eq "$(bash "$RT/ledger.sh" writer-ctx get ticket)" "TB" "writer-ctx set overwrites prior record (ticket)"
assert_eq "$(bash "$RT/ledger.sh" writer-ctx get prod_targets)" "b:2" "writer-ctx set overwrites prior record (targets)"
bash "$RT/ledger.sh" writer-ctx clear

# --- reground HALTs on a dangling active-writer record (stale after crash) ---
bash "$RT/ledger.sh" writer-ctx set TZ actuator "" 'tfstate:prod/x'
out="$(bash "$RT/ledger.sh" reground 2>&1)"; code=$?
assert_eq "$code" "3" "dangling active-writer -> reground HALT (exit 3)"
case "$out" in *"active-writer ticket=TZ"*) pass;; *) fail "reground names the dangling active-writer (got: $out)";; esac
bash "$RT/ledger.sh" writer-ctx clear
out="$(bash "$RT/ledger.sh" reground 2>&1)"; code=$?
assert_eq "$code" "0" "after writer-ctx clear -> reground clean (exit 0)"
# an empty/malformed active-writer.json still HALTs (set -e safe; existence drives it)
: > .agents/runs/orchestrate/active-writer.json
out="$(bash "$RT/ledger.sh" reground 2>&1)"; code=$?
assert_eq "$code" "3" "empty active-writer.json still HALTs (set -e safe)"
rm -f .agents/runs/orchestrate/active-writer.json
cd /; rm -rf "$d"
