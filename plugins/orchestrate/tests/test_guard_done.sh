# Tier 3c — the done-gate ENFORCEMENT hook (un-bypassable). The validation re-probe
# proved the autonomous router raw-appends `done` (bypassing the `ledger.sh done`
# helper, so the verify gate never fired). guard-done.sh funnels every done-write
# through the gated helper by DENYING a direct event:"done" append; the helper is then
# the only door, and it enforces verify-before-done.
GD="$HERE/../skills/orchestrate/runtime/hooks/guard-done.sh"
chk(){ TOOL_INPUT="$1" bash "$GD" </dev/null >/dev/null 2>&1; assert_eq "$?" "$2" "${3:-}"; }

# raw appends of a done event -> DENIED (forced through the gated helper)
chk 'bash ledger.sh append '"'"'{"ticket":"T1","event":"done"}'"'"'' 2 "raw ledger.sh append of done -> denied"
chk 'echo '"'"'{"event":"done","ticket":"T1"}'"'"' >> .agents/runs/orchestrate/board.jsonl' 2 "echo >> board with done -> denied"
chk 'printf "%s" '"'"'{"event": "done"}'"'"' >> board.jsonl' 2 "spaced event:\"done\" -> denied"

# the GATED helper path itself is allowed (it carries no literal event-json)
chk 'bash skills/orchestrate/runtime/ledger.sh done T1' 0 "ledger.sh done <ticket> -> allowed (the gated path)"
# other ledger writes are unaffected
chk 'bash ledger.sh append '"'"'{"ticket":"T1","event":"dispatched","persona":"verifier"}'"'"'' 0 "appending a non-done event -> allowed"
chk 'bash ledger.sh clarify grill-with-docs' 0 "other ledger subcommands -> allowed"
# unrelated command -> allowed
chk 'git status' 0 "unrelated command -> allowed"
