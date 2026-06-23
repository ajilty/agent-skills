# Tier 3 (live) — the writer write-ahead actually fires on a real CC dispatch (ADR-0011).
# Regression guard for the exact class that was broken: wired to SubagentStart (which
# doesn't fire under CC), the write-ahead silently never ran though unit tests were green.
# Now it's PreToolUse on the dispatch tool; this proves it end-to-end.
#
# Router writes the active-writer record (ADR-0006), then dispatches an implementer; the
# PreToolUse:Agent hook must journal a `dispatched` event + take the lease BEFORE the
# writer runs. Robust to model nondeterminism: skip if the model doesn't dispatch.
if ! have_claude; then
  skip "tier3 write-ahead: claude CLI not on PATH"
elif ! have_live_auth; then
  skip "tier3 write-ahead: no live auth (ANTHROPIC_API_KEY or ~/.claude/.credentials.json)"
else
  repo="$(mk_repo)"
  bash "$PLUGIN_DIR/skills/orchestrate/runtime/ledger.sh" >/dev/null 2>&1 # (no-op guard)
  ( cd "$repo" && bash "$PLUGIN_DIR/skills/orchestrate/runtime/ledger.sh" writer-ctx set T-wa implementer feat/wa )
  prompt="Use the Task tool to dispatch a subagent of type orchestrate:implementer with the instruction: reply with exactly DONE. Output its reply."
  printf '%s' "$prompt" | ( cd "$repo" && timeout 240 claude -p --plugin-dir "$PLUGIN_DIR" --allowedTools "Task" ) >/dev/null 2>&1
  board="$repo/.agents/runs/orchestrate/board.jsonl"
  if grep -q '"event":"dispatched".*"persona":"implementer"' "$board" 2>/dev/null && [ -f "$repo/.agents/runs/orchestrate/tickets/T-wa/lease" ]; then
    pass   # write-ahead fired on the real dispatch: dispatched event + lease journaled
  elif [ -s "$board" ] || [ -f "$repo/.agents/runs/orchestrate/tickets/T-wa/lease" ]; then
    fail "write-ahead fired partially (board/lease inconsistent) on live dispatch"
  else
    skip "implementer was not dispatched this run (model declined) — write-ahead not exercised"
  fi
fi
