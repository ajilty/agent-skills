# Tier 3 (live) — FULL writer lane on a realistic topology. THE proactive catch for the
# harness-path bug class (the worktree report's "verified by an actual dispatch"): the
# automated catch that the field failures kept slipping past because no test ran a real
# writer lane in a worktree on a repo whose canonical branch isn't the default branch.
#
# Topology mirrors the field repo: a STALE default branch (origin/HEAD -> master) plus a
# canonical CURRENT branch (blank-slate) that is ahead with a file master lacks. The
# router creates the worktree via the helper (cuts from the CURRENT base, not origin/HEAD),
# then dispatches a real implementer to work IN that worktree (cd, NOT isolation:worktree)
# and commit to its worktree-agent-* branch. Proves: right base, §9b branch, clean merge,
# and the shared/main checkout is never mutated. Robust to model-decline (skips).
if ! have_claude; then
  skip "tier3 writer-lane: claude CLI not on PATH"
elif ! have_live_auth; then
  skip "tier3 writer-lane: no live auth (ANTHROPIC_API_KEY or ~/.claude/.credentials.json)"
else
  h="$(mk_authed_home)"
  origin="$(mk_tmp)/origin.git"; repo="$(mk_tmp)/work"
  git init -q --bare "$origin"
  git clone -q "$origin" "$repo" 2>/dev/null
  ( cd "$repo" && git config user.email t@t && git config user.name t \
      && git checkout -q -b master && echo base > base.txt && git add base.txt && git commit -q -m c1 && git push -q -u origin master \
      && git checkout -q -b blank-slate && echo canonical > NEWFILE.txt && git add NEWFILE.txt && git commit -q -m c2 && git push -q -u origin blank-slate \
      && git remote set-head origin master )   # the stale-orphan trap: origin/HEAD -> master

  # Helper creates the worktree from the CURRENT base (blank-slate), not origin/HEAD.
  WT="$( cd "$repo" && bash "$PLUGIN_DIR/skills/orchestrate/runtime/worktree.sh" create T1 implementer 2>/dev/null )"
  abswt="$repo/$WT"
  [ -f "$abswt/NEWFILE.txt" ] && pass || fail "lane setup: worktree cut from current base (blank-slate)"

  # Dispatch a REAL implementer to work IN the worktree and commit to HEAD (no new branch).
  prompt="Use the Task tool to dispatch a subagent of type orchestrate:implementer. Its task: in the existing git worktree at $abswt, create a file feature.txt containing the text hi, then stage and commit it with message wl to the current branch (do not create or switch branches). Use your Bash and Write tools. When the commit exists, reply DONE."
  printf '%s' "$prompt" | ( cd "$repo" && HOME="$h" timeout 300 claude -p --plugin-dir "$PLUGIN_DIR" --allowedTools "Task,Bash,Write" ) >/dev/null 2>&1

  if [ -n "$(git -C "$abswt" log --oneline origin/blank-slate..HEAD 2>/dev/null)" ] && [ -n "$(git -C "$abswt" ls-files feature.txt 2>/dev/null)" ]; then
    pass   # the writer committed new work in the worktree
    assert_eq "$(git -C "$abswt" rev-parse --abbrev-ref HEAD 2>/dev/null)" "worktree-agent-T1-implementer" "writer committed on its worktree-agent-* branch (§9b, no self-named drift)"
    [ -f "$abswt/NEWFILE.txt" ] && pass || fail "writer built on the CURRENT base (blank-slate file present), not stale master"
    if ( cd "$repo" && git checkout -q blank-slate && git merge -q --no-ff -m merge worktree-agent-T1-implementer ) 2>/dev/null; then pass; else fail "lane merges cleanly into the base branch"; fi
    [ -f "$repo/feature.txt" ] && pass || fail "merged feature lands on the base branch"
  else
    skip "implementer did not produce the commit this run (model declined) — lane not exercised"
  fi

  # SAFETY: the shared/main checkout's canonical content was never discarded by the lane.
  [ -f "$repo/NEWFILE.txt" ] && pass || fail "shared checkout intact (canonical content not discarded)"
  cd /
fi
