# test_status_command.sh — the /orchestrate:status command exists and wires the durable
# state sources it renders from (spec docs/specs/2026-07-02-orchestrate-status-command-design.md).
# The render itself is LLM output and is NOT asserted here; this guards presence + wiring.
C="$HERE/../commands/status.md"
assert_file "$C"
grep -q '^description:' "$C"       && pass || fail "status command has a description frontmatter"
grep -q 'reground' "$C"            && pass || fail "status reads ledger reground (open lanes + goal anchor)"
grep -q 'board.jsonl' "$C"         && pass || fail "status reads the board"
grep -qi 'goal' "$C"               && pass || fail "status surfaces the goal anchor (ADR-0020)"
grep -qi 'needs you' "$C"          && pass || fail "status has the conditional needs-you section"
grep -q 'write nothing\|read-only' "$C" && pass || fail "status is a read-only projection (writes nothing)"
grep -q '🌳' "$C"                  && pass || fail "status renders the lane tree (emoji legend present)"
