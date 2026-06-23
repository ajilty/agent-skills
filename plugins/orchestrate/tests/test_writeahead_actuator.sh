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

# --- CC PreToolUse-on-dispatch path (ADR-0011): SubagentStart doesn't fire under CC, so
#     the write-ahead runs as PreToolUse on the Agent/Task tool. Persona arrives as
#     tool_input.subagent_type (namespaced); branch/ticket/prod-targets come from the
#     on-disk active-writer record (no TARGETS/ASSIGNED_BRANCH env). Needs jq.
if command -v jq >/dev/null 2>&1; then
  d2="$(mktemp_repo)"; cd "$d2"
  # implementer dispatch: ticket+branch from the record; dispatched + lease written
  bash "$RT/ledger.sh" writer-ctx set T9 implementer feat/x
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":"orchestrate:implementer"}}' | bash "$RT/hooks/on-writer-dispatch.sh"
  grep -q '"event":"dispatched".*"persona":"implementer".*"branch":"feat/x"' .agents/runs/orchestrate/board.jsonl && pass || fail "CC dispatch: implementer write-ahead from subagent_type + disk branch"
  assert_file ".agents/runs/orchestrate/tickets/T9/lease"
  # actuator dispatch: acked prod target -> dispatched + lease the prod target (from record)
  bash "$RT/ledger.sh" writer-ctx set T10 actuator feat/y "tfstate:prod/db"
  bash "$RT/ledger.sh" ack T10 "tfstate:prod/db"
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":"orchestrate:actuator"}}' | bash "$RT/hooks/on-writer-dispatch.sh"
  grep -q '"event":"dispatched".*"persona":"actuator"' .agents/runs/orchestrate/board.jsonl && pass || fail "CC dispatch: actuator write-ahead from subagent_type (acked prod target)"
  assert_file ".agents/runs/orchestrate/leases/tfstate:prod%2Fdb"
  # actuator dispatch with UNACKED prod target -> gate hygiene: NO dispatched/lease trace
  d3="$(mktemp_repo)"; cd "$d3"
  bash "$RT/ledger.sh" writer-ctx set T11 actuator feat/z "tfstate:prod/db"
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":"orchestrate:actuator"}}' | bash "$RT/hooks/on-writer-dispatch.sh"
  grep -q '"event":"dispatched"' .agents/runs/orchestrate/board.jsonl && fail "CC dispatch: unacked actuator must leave NO dispatched trace" || pass
  cd /; rm -rf "$d2" "$d3"
fi
