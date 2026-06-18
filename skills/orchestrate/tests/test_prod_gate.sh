RT="$HERE/../scripts/runtime"
GATE="$RT/hooks/gate-prod-apply.sh"
d="$(mktemp_repo)"; cd "$d"
# a prod-level target with no operator ack -> gate DENIES (exit 1) + journals gate-blocked
PERSONA=actuator TICKET=T1 PROD_TARGETS='tfstate:prod/net' bash "$GATE" >/dev/null 2>&1
rc=$?; assert_eq "$rc" "1" "unacked prod target -> gate denies dispatch"
grep -q '"event":"gate-blocked".*"key":"tfstate:prod/net"' .agents/runs/orchestrate/board.jsonl && pass || fail "gate-blocked journaled"
# after the operator acks -> gate ALLOWS (exit 0)
bash "$RT/ledger.sh" ack T1 'tfstate:prod/net'
PERSONA=actuator TICKET=T1 PROD_TARGETS='tfstate:prod/net' bash "$GATE" >/dev/null 2>&1
assert_eq "$?" "0" "acked prod target -> gate allows"
# no prod targets declared -> allow
PERSONA=actuator TICKET=T2 bash "$GATE" >/dev/null 2>&1
assert_eq "$?" "0" "no prod targets -> gate allows"
# non-actuator persona -> no-op allow
PERSONA=researcher TICKET=T3 PROD_TARGETS='tfstate:prod/net' bash "$GATE" >/dev/null 2>&1
assert_eq "$?" "0" "non-actuator -> gate no-op"
cd /; rm -rf "$d"
