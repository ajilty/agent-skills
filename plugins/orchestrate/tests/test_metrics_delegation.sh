# Tier 3c — DELEGATION HEALTH metrics. The infra-log analysis showed verification is
# the least-delegated function (14 verifier dispatches vs ~1500 inline checks) and
# delegation tapers into a self-driving main loop. Today `metrics` reports only a TOTAL
# dispatch count, which hides that. These add the breakdown that turns "subagents feel
# underused" into a number: per-persona dispatch counts + verify_coverage (the fraction
# of shipped lanes that actually got a verifier verdict).
R="$HERE/../skills/orchestrate/runtime/ledger.sh"
d="$(mktemp_repo)"; cd "$d"

# T1: a fully-verified lane (researcher + implementer + verifier + verdict + done)
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"researcher"}'
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"implementer"}'
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"verifier"}'
bash "$R" append '{"ticket":"T1","event":"verdict","verdict":"APPROVED"}'
bash "$R" append '{"ticket":"T1","event":"done"}'
# T2: shipped WITHOUT a verdict — self-verified / unverified (the failure we care about)
bash "$R" append '{"ticket":"T2","event":"dispatched","persona":"implementer"}'
bash "$R" append '{"ticket":"T2","event":"done"}'

m="$(bash "$R" metrics)"
case "$m" in *"disp_researcher=1"*)  pass;; *) fail "metrics breaks out researcher dispatches ($m)";; esac
case "$m" in *"disp_implementer=2"*) pass;; *) fail "metrics breaks out implementer dispatches ($m)";; esac
case "$m" in *"disp_verifier=1"*)    pass;; *) fail "metrics breaks out verifier dispatches ($m)";; esac
# verify_coverage = shipped lanes that got a verdict / shipped lanes = 1/2 here
case "$m" in *"verify_coverage=1/2"*) pass;; *) fail "metrics reports verify_coverage (verified ships / total ships) ($m)";; esac

# a validator dispatch counts toward the verify breakdown (real sessions used bare 'validator')
d2="$(mktemp_repo)"; cd "$d2"
bash "$R" append '{"ticket":"T1","event":"dispatched","persona":"validator"}'
m2="$(bash "$R" metrics)"
case "$m2" in *"disp_verifier=1"*) pass;; *) fail "validator counts as a verifier dispatch ($m2)";; esac

cd /; rm -rf "$d" "$d2"
