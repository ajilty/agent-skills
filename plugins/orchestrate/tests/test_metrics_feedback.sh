# Tier 3c, Layer 3 — ledger-derived §8 metrics + the durable feedback record
# (deterministic, no live model). Backs the /orchestrate:feedback command.
R="$HERE/../skills/orchestrate/runtime/ledger.sh"
d="$(mktemp_repo)"; cd "$d"

# Plant a board with a representative mix of events.
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"implementer"}'
bash "$R" append '{"ticket":"T1","event":"verdict","verdict":"REJECTED"}'
bash "$R" append '{"ticket":"T1","event":"verdict","verdict":"APPROVED"}'
bash "$R" append '{"ticket":"T1","event":"done"}'
bash "$R" append '{"ticket":"T2","event":"fork","state":"halted","fork_id":"F1"}'
bash "$R" append '{"ticket":"T2","event":"decision","fork_id":"F1","adr":"0099"}'
bash "$R" append '{"ticket":"T2","event":"lease-conflict","persona":"actuator","key":"db"}'

m="$(bash "$R" metrics)"
case "$m" in *"shipped=1"*)   pass;; *) fail "metrics shipped=1 ($m)";; esac
case "$m" in *"rejects=1"*)   pass;; *) fail "metrics rejects=1 ($m)";; esac
case "$m" in *"forks=1"*)     pass;; *) fail "metrics forks=1 ($m)";; esac
case "$m" in *"decisions=1"*) pass;; *) fail "metrics decisions=1 ($m)";; esac
# friction = rejects(1) + oracle_inconsistent(0) + lease_conflicts(1) = 2
case "$m" in *"friction=2"*)  pass;; *) fail "metrics friction=2 ($m)";; esac
# ticket filter narrows the replay
mt="$(bash "$R" metrics T2)"
case "$mt" in *"shipped=0"*"forks=1"*) pass;; *) fail "metrics ticket-filter ($mt)";; esac

# feedback appends a durable record embedding the snapshot + the operator note
bash "$R" feedback "smooth run, one healthy fork" >/dev/null
FB=".agents/runs/orchestrate/eval/feedback.jsonl"
assert_file "$FB"
grep -q '"event":"feedback"' "$FB"        && pass || fail "feedback record written"
grep -q '"shipped":1'        "$FB"        && pass || fail "feedback embeds metrics snapshot"
grep -q 'smooth run, one healthy fork' "$FB" && pass || fail "feedback embeds the operator note"

cd /; rm -rf "$d"
