R="$HERE/../skills/orchestrate/runtime/ledger.sh"
d="$(mktemp_repo)"; cd "$d"
# a lease whose ticket never reached 'done' -> reground HALTs (exit 3) and names it
bash "$R" lease-acquire T9 'db:orders-primary'
out="$(bash "$R" reground 2>&1)"; code=$?
assert_eq "$code" "3" "open lease -> HALT"
case "$out" in *"OPEN LEASE db:orders-primary"*) pass;; *) fail "reground names the open lease";; esac
# once the ticket is done, the lease is no longer open
bash "$R" append '{"ticket":"T9","event":"done"}'
out="$(bash "$R" reground 2>&1)"; code=$?
assert_eq "$code" "0" "done ticket -> lease not open"
assert_no_file ".agents/runs/orchestrate/leases/db:orders-primary"   # reground RELEASED the done ticket's lease
cd /; rm -rf "$d"
