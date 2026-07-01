RT="$HERE/../skills/orchestrate/runtime"
command -v git >/dev/null 2>&1 || { echo "(skip test_worktree: git absent)"; return 0 2>/dev/null || true; }

# Mirror the field topology that broke: a stale default branch (origin/HEAD -> master)
# plus a canonical CURRENT branch (blank-slate) that is ahead with files master lacks.
# The bug was: worktrees cut from origin/HEAD (stale master) instead of the current branch.
tmp="$(mktemp -d)"
git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/work" 2>/dev/null
( cd "$tmp/work" && git config user.email t@t && git config user.name t \
    && git checkout -q -b master && echo base > base.txt && git add base.txt && git commit -q -m c1 && git push -q -u origin master \
    && git checkout -q -b blank-slate && echo canonical > NEWFILE.txt && git add NEWFILE.txt && git commit -q -m c2 && git push -q -u origin blank-slate )
cd "$tmp/work"
git remote set-head origin master >/dev/null 2>&1   # the stale-orphan trap: origin/HEAD -> master
git checkout -q blank-slate                          # the operator is ON the canonical branch

# THE REGRESSION: create WITHOUT an explicit base must resolve to the CURRENT branch
# (blank-slate), NOT origin/HEAD/master. Proven by a file that exists only on blank-slate.
wt="$(bash "$RT/worktree.sh" create T1 implementer 2>/dev/null)"
assert_eq "$wt" ".agents/worktrees/T1-implementer" "create prints the deterministic path"
test -f "$wt/NEWFILE.txt" && pass || fail "worktree cut from CURRENT branch (blank-slate), NOT stale origin/HEAD/master"
test -f "$wt/base.txt"    && pass || fail "worktree has the base content"
assert_eq "$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)" "worktree-agent-T1-implementer" "worktree on the worktree-agent-* branch (§9b)"
# create realigns origin/HEAD -> the base, so the harness isolation:worktree also benefits
assert_eq "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" "origin/blank-slate" "create aligns origin/HEAD -> current base (defends harness path)"
bash "$RT/worktree.sh" staleness T1 implementer >/dev/null 2>&1
assert_eq "$?" "0" "fresh worktree is current vs origin/blank-slate"

# advance origin/blank-slate -> BEHIND
( cd "$tmp/work" && echo v2 >> NEWFILE.txt && git add NEWFILE.txt && git commit -q -m c3 && git push -q origin blank-slate )
bash "$RT/worktree.sh" staleness T1 implementer >/dev/null 2>&1
assert_eq "$?" "3" "staleness detects BEHIND after origin advances (exit 3)"
# safe-recreate (no work in worktree) -> current
bash "$RT/worktree.sh" create T1 implementer >/dev/null 2>&1
bash "$RT/worktree.sh" staleness T1 implementer >/dev/null 2>&1
assert_eq "$?" "0" "safe-recreate brings a stale CLEAN worktree current"

# a worktree that HOLDS WORK is never destroyed by a stale-recreate
wt2="$(bash "$RT/worktree.sh" path T2 implementer)"
bash "$RT/worktree.sh" create T2 implementer >/dev/null 2>&1
echo wip > "$wt2/work.txt"
( cd "$tmp/work" && echo v3 >> NEWFILE.txt && git add NEWFILE.txt && git commit -q -m c4 && git push -q origin blank-slate )
bash "$RT/worktree.sh" create T2 implementer >/dev/null 2>&1
assert_eq "$?" "3" "create HALTs (exit 3) on a stale worktree holding work — no data loss"
test -f "$wt2/work.txt" && pass || fail "uncommitted work preserved (not destroyed by recreate)"

# missing worktree -> staleness exit 4
bash "$RT/worktree.sh" staleness T9 implementer >/dev/null 2>&1
assert_eq "$?" "4" "staleness on a non-existent worktree -> exit 4 (missing)"

# --- ADR-0019: `committed` proves the work IS the commit (clean tree + commit ahead) ---
# fresh worktree, nothing committed yet -> exit 5 (nothing ahead of base)
bash "$RT/worktree.sh" create T3 implementer >/dev/null 2>&1
wt3="$(bash "$RT/worktree.sh" path T3 implementer)"
bash "$RT/worktree.sh" committed T3 implementer >/dev/null 2>&1
assert_eq "$?" "5" "committed: clean worktree, no commit ahead -> nothing committed (exit 5)"
# commit the work -> exit 0 (committed & clean)
( cd "$wt3" && echo feat > feat.txt && git add feat.txt && git commit -q -m "T3 work" )
bash "$RT/worktree.sh" committed T3 implementer >/dev/null 2>&1
assert_eq "$?" "0" "committed: committed & clean worktree -> exit 0"
# leave an uncommitted change -> exit 2 (the 'validated the tree, not the commit' defect)
echo wip >> "$wt3/feat.txt"
bash "$RT/worktree.sh" committed T3 implementer >/dev/null 2>&1
assert_eq "$?" "2" "committed: uncommitted changes -> exit 2 (commit is not the artifact)"
# missing worktree -> exit 4
bash "$RT/worktree.sh" committed T9 implementer >/dev/null 2>&1
assert_eq "$?" "4" "committed: no worktree -> exit 4"

cd /; rm -rf "$tmp"
