# Tier 3c (reframed, the operator's call) — TRACE CONFORMANCE. Instead of grading
# output quality (the expensive A/B), assert the machinery actually executed the
# expected choreography: the right personas dispatched and the verifier ran, in order.
# This catches the failure class we keep hitting — orchestrate silently degrading into
# one agent that SKIPS its own discipline (the namespaced-persona + dead-SubagentStart
# bugs were exactly this: green in unit tests, steps not firing on the real harness).
#
# `ledger.sh conformance <event[:detail]>...` asserts those specs appear as an ordered
# subsequence of board.jsonl. exit 0 = the chain ran as designed; exit 1 = a step is
# missing/out-of-order (names the broken step).
R="$HERE/../skills/orchestrate/runtime/ledger.sh"

# 1) CONFORMANT: implementer dispatched, then a verdict recorded -> chain ran as designed
d="$(mktemp_repo)"; cd "$d"
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"implementer","branch":"worktree-agent-T1-implementer"}'
bash "$R" append '{"ticket":"T1","event":"verdict","verdict":"APPROVED"}'
bash "$R" conformance dispatched:implementer verdict >/dev/null 2>&1
assert_eq "$?" "0" "conformant: implementer dispatched -> verdict, present and in order"
cd /; rm -rf "$d"

# 2) DEGRADED (load-bearing): implementer ran but the verifier was SKIPPED -> no verdict.
#    This is orchestrate quietly degrading to no-verification. Conformance MUST catch it.
d="$(mktemp_repo)"; cd "$d"
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"implementer"}'
out="$(bash "$R" conformance dispatched:implementer verdict 2>&1)"; code=$?
assert_eq "$code" "1" "degraded: missing verdict (verifier skipped) -> conformance FAILS"
case "$out" in *verdict*) pass;; *) fail "names the missing step (verdict): $out";; esac
cd /; rm -rf "$d"

# 3) DETAIL must match: a researcher dispatch does NOT satisfy dispatched:implementer
d="$(mktemp_repo)"; cd "$d"
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"researcher","slug":"x"}'
bash "$R" append '{"ticket":"T1","event":"verdict","verdict":"APPROVED"}'
bash "$R" conformance dispatched:implementer verdict >/dev/null 2>&1
assert_eq "$?" "1" "wrong persona: researcher dispatch does not satisfy dispatched:implementer"
cd /; rm -rf "$d"

# 4) ORDER matters: a verdict BEFORE the dispatch is not a valid chain
d="$(mktemp_repo)"; cd "$d"
bash "$R" append '{"ticket":"T1","event":"verdict","verdict":"APPROVED"}'
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"implementer"}'
bash "$R" conformance dispatched:implementer verdict >/dev/null 2>&1
assert_eq "$?" "1" "order: verdict before dispatch is not a valid subsequence"
cd /; rm -rf "$d"

# 5) no specs -> usage error (guard)
bash "$R" conformance >/dev/null 2>&1
assert_eq "$?" "64" "no specs -> usage exit 64"
