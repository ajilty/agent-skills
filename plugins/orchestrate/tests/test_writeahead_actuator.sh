RT="$HERE/../skills/orchestrate/runtime"
d="$(mktemp_repo)"; cd "$d"
PERSONA=actuator TICKET=T3 TARGETS='k8s:clusterB/app db:orders' DISPATCH_ID=d1 \
  bash "$RT/hooks/on-writer-dispatch.sh"
# a dispatched event for the actuator is journaled
grep -q '"event":"dispatched".*"persona":"actuator"' .agents/runs/orchestrate/board.jsonl && pass || fail "actuator dispatch journaled"
# both targets are leased to T3
assert_file ".agents/runs/orchestrate/leases/k8s:clusterB%2Fapp"
assert_file ".agents/runs/orchestrate/leases/db:orders"
# a non-writer persona is a no-op
PERSONA=researcher TICKET=T4 bash "$RT/hooks/on-writer-dispatch.sh"
grep -q '"ticket":"T4"' .agents/runs/orchestrate/board.jsonl && fail "researcher must be no-op" || pass
# a target held by a DIFFERENT ticket -> hook JOURNALS lease-conflict and exits 0
# (SubagentStart is non-blocking; serialization is the router's pre-dispatch check).
bash "$RT/ledger.sh" lease-acquire TOTHER 'tfstate:prod/db'
PERSONA=actuator TICKET=T5 TARGETS='tfstate:prod/db' DISPATCH_ID=d5 \
  bash "$RT/hooks/on-writer-dispatch.sh" >/dev/null 2>&1
rc=$?
assert_eq "$rc" "0" "actuator write-ahead exits 0 even on lease conflict (non-blocking)"
grep -q '"event":"lease-conflict".*"key":"tfstate:prod/db"' .agents/runs/orchestrate/board.jsonl && pass || fail "lease-conflict journaled"
cd /; rm -rf "$d"
