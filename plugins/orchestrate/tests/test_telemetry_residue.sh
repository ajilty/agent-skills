# 2026-08-05 wave-2 review gaps: (1) hook telemetry appended to a linked worktree's
# COPY of board.jsonl left the tree permanently dirty after merge, and reground then
# HALTed on "ambiguous in-flight writer" for lanes that were done (4 false HALTs).
# Fixes under test: ledger.sh anchors the board at the MAIN checkout root from any
# worktree cwd; reground classifies board.jsonl-only dirt as residue (no HALT) while
# real work still fails closed; worktree.sh inspect is the read-only reconcile window.
R="$HERE/../skills/orchestrate/runtime"
d="$(mktemp -d)"; ( cd "$d" && git init -q && git config user.email t@t && git config user.name t
  mkdir -p .agents/runs/orchestrate && echo '{"event":"goal","note":"g"}' > .agents/runs/orchestrate/board.jsonl
  git add -A && git commit -qm init
  git worktree add -q -b worktree-agent-T1-implementer .agents/worktrees/T1-implementer HEAD )
wt="$d/.agents/worktrees/T1-implementer"

# 1) append from INSIDE the worktree lands in the ROOT board; worktree stays clean
( cd "$wt" && bash "$R/ledger.sh" append '{"event":"denied","hook":"keep-on-branch","note":"t"}' >/dev/null 2>&1 )
grep -q '"event":"denied"' "$d/.agents/runs/orchestrate/board.jsonl" && pass || fail "worktree append lands in root board"
[ -z "$(git -C "$wt" status --porcelain)" ] && pass || fail "worktree stays clean after telemetry append"

# 2) legacy residue (board.jsonl-only dirt in the worktree copy): reground reports, no HALT
echo '{"event":"denied","note":"legacy"}' >> "$wt/.agents/runs/orchestrate/board.jsonl"
out="$(cd "$d" && bash "$R/ledger.sh" reground)"; rc=$?
assert_eq "$rc" 0 "board.jsonl-only dirt does not HALT reground"
case "$out" in *"TELEMETRY RESIDUE"*) pass;; *) fail "reground names the residue ($out)";; esac

# 3) real uncommitted work (even alongside residue) still fails closed
echo x >> "$wt/real-work.txt"
( cd "$d" && bash "$R/ledger.sh" reground >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" 3 "real uncommitted work still HALTs reground"

# 4) inspect: read-only window sees the lane, counts dirt and telemetry separately
out="$(cd "$d" && bash "$R/worktree.sh" inspect)"
case "$out" in *"worktree-agent-T1-implementer"*"dirty=2(telemetry=1)"*) pass;; *) fail "inspect reports dirty/telemetry counts ($out)";; esac
out="$(cd "$d" && bash "$R/worktree.sh" inspect T1)"
case "$out" in *"worktree-agent-T1-implementer"*) pass;; *) fail "inspect filters by ticket ($out)";; esac
out="$(cd "$d" && bash "$R/worktree.sh" inspect OTHER)"
[ -z "$out" ] && pass || fail "inspect ticket filter excludes non-matching lanes ($out)"

rm -rf "$d"
