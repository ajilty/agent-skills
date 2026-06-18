R="$HERE/../scripts/runtime/ledger.sh"
d="$(mktemp_repo)"; cd "$d"
# encoding: only '/' is encoded
assert_eq "$(bash "$R" lease-key 'k8s:clusterB/app')" 'k8s:clusterB%2Fapp' "lease-key encodes slash"
# free target acquires
assert_exit 0 bash "$R" lease-acquire T1 'tfstate:prod/net'
assert_file ".agents/runs/orchestrate/leases/tfstate:prod%2Fnet"
# same ticket re-acquire is idempotent (0); other ticket denied (4)
assert_exit 0 bash "$R" lease-acquire T1 'tfstate:prod/net'
assert_exit 4 bash "$R" lease-acquire T2 'tfstate:prod/net'
# check reflects held; release frees it
assert_exit 4 bash "$R" lease-check 'tfstate:prod/net'
bash "$R" lease-release 'tfstate:prod/net'
assert_exit 0 bash "$R" lease-check 'tfstate:prod/net'
cd /; rm -rf "$d"
