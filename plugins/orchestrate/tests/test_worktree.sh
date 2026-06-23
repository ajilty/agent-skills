RT="$HERE/../skills/orchestrate/runtime"
command -v git >/dev/null 2>&1 || { echo "(skip test_worktree: git absent)"; return 0 2>/dev/null || true; }

# Bare origin with a 'main' branch + one commit, plus a working clone (real remote so
# fetch/origin/<base> behave as in the field).
tmp="$(mktemp -d)"
git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/work" 2>/dev/null
( cd "$tmp/work" && git config user.email t@t && git config user.name t \
    && git checkout -q -b main && echo v1 > f.txt && git add f.txt && git commit -q -m c1 \
    && git push -q -u origin main )
cd "$tmp/work"

# create: worktree on the §9b branch, cut from origin/main, current
wt="$(bash "$RT/worktree.sh" create T1 implementer main 2>/dev/null)"
assert_eq "$wt" ".agents/worktrees/T1-implementer" "create prints the deterministic path"
test -d "$wt" && pass || fail "worktree dir created"
assert_eq "$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)" "worktree-agent-T1-implementer" "worktree on the worktree-agent-* branch (§9b)"
bash "$RT/worktree.sh" staleness T1 implementer main >/dev/null 2>&1
assert_eq "$?" "0" "fresh worktree is current vs origin/main"

# advance origin/main -> the existing worktree is now BEHIND
( cd "$tmp/work" && echo v2 >> f.txt && git add f.txt && git commit -q -m c2 && git push -q origin main )
bash "$RT/worktree.sh" staleness T1 implementer main >/dev/null 2>&1
assert_eq "$?" "3" "staleness detects BEHIND after origin advances (exit 3)"

# create again with NO work in the worktree -> safe-recreate from fresh base -> current
bash "$RT/worktree.sh" create T1 implementer main >/dev/null 2>&1
bash "$RT/worktree.sh" staleness T1 implementer main >/dev/null 2>&1
assert_eq "$?" "0" "safe-recreate brings a stale CLEAN worktree current"

# worktree that HOLDS WORK must never be destroyed by a stale-recreate
wt2="$(bash "$RT/worktree.sh" path T2 implementer)"
bash "$RT/worktree.sh" create T2 implementer main >/dev/null 2>&1
echo wip > "$wt2/work.txt"     # uncommitted work in the worktree
( cd "$tmp/work" && echo v3 >> f.txt && git add f.txt && git commit -q -m c3 && git push -q origin main )
bash "$RT/worktree.sh" create T2 implementer main >/dev/null 2>&1
assert_eq "$?" "3" "create HALTs (exit 3) on a stale worktree holding work — no data loss"
test -f "$wt2/work.txt" && pass || fail "uncommitted work preserved (not destroyed by recreate)"

# missing worktree -> staleness reports missing (exit 4)
bash "$RT/worktree.sh" staleness T9 implementer main >/dev/null 2>&1
assert_eq "$?" "4" "staleness on a non-existent worktree -> exit 4 (missing)"

cd /; rm -rf "$tmp"
