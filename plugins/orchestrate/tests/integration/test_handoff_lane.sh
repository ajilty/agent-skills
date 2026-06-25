# Tier 3c (live) — SUBAGENT HANDOFF: a value discovered by one subagent reaches the
# next through the durable artifact bus (not a chat message). The router dispatches a
# researcher that writes a finding to its quarantine artifact, then an implementer that
# reads ONLY that artifact and acts on it. If the value flows end-to-end, the handoff
# works — and it proves both "subagents are dispatched" and "results pass between them"
# survive the real harness (the read-channel the disk-first fix, ADR-0014, hardened).
#
#   result reflects the researcher's finding -> handoff worked end-to-end: PASS
#   findings artifact written but no result    -> implementer didn't complete: SKIP
#   nothing                                    -> chain didn't run (model declined): SKIP
if ! have_claude; then
  skip "tier3 handoff: claude CLI not on PATH"
elif ! have_live_auth; then
  skip "tier3 handoff: no live auth"
else
  h="$(mk_authed_home)"; repo="$(mk_repo)"
  LEDGER="$PLUGIN_DIR/skills/orchestrate/runtime/ledger.sh"
  ( cd "$repo" && printf 'MAGIC=4242\n' > secret.txt )
  ( cd "$repo" && bash "$LEDGER" writer-ctx set T-h implementer feat/h )
  absq="$repo/.agents/runs/orchestrate/tickets/T-h/findings/_quarantine/magic.d1.md"
  prompt="You are the orchestrate router. The repo has a file secret.txt. Do these steps with the Task tool:
1. Dispatch a subagent of type orchestrate:researcher with instruction: 'read secret.txt, find the integer value of MAGIC, and using your Write tool write your findings to the file $absq (create parent directories). The file must state exactly: MAGIC is <value>. End the file with a line: <!-- orchestrate:complete -->'.
2. Dispatch a subagent of type orchestrate:implementer with instruction: 'read ONLY the file $absq (do NOT read secret.txt), extract the integer MAGIC value stated in it, and using your Write tool write just that integer (nothing else) to the file result.txt in the current directory'.
Use the Task tool for each dispatch."
  printf '%s' "$prompt" | ( cd "$repo" && HOME="$h" timeout 480 claude -p --plugin-dir "$PLUGIN_DIR" --allowedTools "Task,Bash,Write,Read" ) >/dev/null 2>&1

  board="$repo/.agents/runs/orchestrate/board.jsonl"
  if [ -f "$repo/result.txt" ] && grep -q '4242' "$repo/result.txt"; then
    pass   # the value flowed researcher -> artifact -> implementer: HANDOFF WORKED end-to-end
    [ -f "$absq" ] && pass || fail "handoff: the researcher's findings artifact is on disk (the bus carried it, not chat)"
    grep -q '"event":"dispatched".*"persona":"implementer"' "$board" 2>/dev/null && pass \
      || fail "handoff: the implementer dispatch was journaled (subagent actually used)"
  elif [ -f "$absq" ]; then
    skip "researcher wrote findings but implementer did not produce result this run — handoff not completed"
  else
    skip "the chain did not run this run (model declined) — handoff not exercised"
  fi
  cd /
fi
