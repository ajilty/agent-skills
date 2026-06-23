# write-scope.sh for the READ lane (ADR-0014, disk-first read lane). The hook
# already confines the planner to spec/ADR; this extends the SAME mechanism (keyed
# on agent_type/PERSONA, no active-writer record) to the two read-only personas that
# now own a path-scoped `results-only` Write:
#   researcher -> ONLY tickets/*/findings/_quarantine/*   (RAW; router gates+promotes)
#   verifier   -> ONLY tickets/*/verdicts/*
# The load-bearing denials hold: source tree, prod, AND the *trusted* findings path
# (writing it directly would bypass the §4 quarantine gate) and the other lane.
WS="$HERE/../skills/orchestrate/runtime/hooks/write-scope.sh"
# chk <persona> <path> <want_exit>   (drive purely by env; stdin closed so the
# jq/stdin path degrades to the env fallback — same as a real CC call without jq).
chk(){ PERSONA="$1" RESOLVED_PATH="$2" bash "$WS" </dev/null >/dev/null 2>&1; assert_eq "$?" "$3" "$1 write '$2'"; }

Q=".agents/runs/orchestrate/tickets/T1/findings/_quarantine"
F=".agents/runs/orchestrate/tickets/T1/findings"
V=".agents/runs/orchestrate/tickets/T1/verdicts"

# --- researcher: results-only -> quarantine subdir ONLY ----------------------
chk researcher "$Q/topic.d17a.md"     0   # its own raw result lane: ALLOW
chk researcher "/tmp/x/$Q/topic.d1.md" 0  # absolute path under a sandbox cwd: ALLOW
chk researcher "$F/topic.md"          2   # the TRUSTED (promoted) path: DENY (would bypass §4 gate)
chk researcher "$V/db.md"             2   # the verifier's lane: DENY
chk researcher "src/app.py"           2   # source tree: DENY
chk researcher "../../etc/passwd"     2   # traversal: DENY
chk researcher ""                     2   # unresolved path: DENY (fail-closed)

# --- verifier: results-only -> verdicts subdir ONLY --------------------------
chk verifier "$V/db-orders.d44.md"    0   # its own verdict lane: ALLOW
chk verifier "$Q/topic.md"            2   # the researcher's lane: DENY
chk verifier "src/app.py"             2   # source tree: DENY

# --- planner: unchanged regression ------------------------------------------
chk planner "docs/specs/x.md"         0
chk planner "docs/adr/0001-x.md"      0
chk planner "src/app.py"              2

# --- write-restricted-by-other-means personas: write-scope is a NO-OP --------
# implementer/actuator writes are governed by branch_guard / capability subtraction,
# not write-scope; the hook must not interfere (exit 0 = allow-through).
chk implementer "src/app.py"          0
chk actuator    "src/app.py"          0
