# Tier 3c (live) — runtime proof that the compiled model tiers are HONORED (and
# differentiated). test_build asserts the compiled frontmatter (verifier->opus,
# researcher->haiku); this proves CC actually runs each persona on that model: dispatch
# a real verifier and a real researcher, have each self-report its model family, and
# assert they differ as compiled. Runs with CLAUDE_CODE_SUBAGENT_MODEL neutralized (its
# rank-1 override would otherwise force every subagent to inherit — the operator gotcha).
# Model is self-reportable; effort is not, so effort stays a compile-time check.
if ! have_claude; then
  skip "tier3 model-tier: claude CLI not on PATH"
elif ! have_live_auth; then
  skip "tier3 model-tier: no live auth"
else
  h="$(mk_authed_home)"; repo="$(mk_repo)"
  report(){ # <persona> -> echoes the subagent's one-word model reply
    local persona="$1"
    local p="Use the Task tool to dispatch a subagent of type orchestrate:$persona with this exact instruction: 'Reply with ONLY the model family you are running on as one lowercase word: opus, sonnet, or haiku. Output just that one word, nothing else.' Then output the subagent's reply verbatim."
    printf '%s' "$p" | ( cd "$repo" && HOME="$h" env -u CLAUDE_CODE_SUBAGENT_MODEL timeout 240 claude -p --plugin-dir "$PLUGIN_DIR" --allowedTools "Task" ) 2>&1
  }

  ov="$(report verifier)"
  case "$ov" in
    *opus*)          pass ;;                                   # premium tier honored at runtime
    *haiku*|*sonnet*) fail "verifier ran on the wrong model (want opus): $(printf '%s' "$ov" | tail -c 120)" ;;
    *)               skip "verifier model self-report inconclusive this run" ;;
  esac

  orr="$(report researcher)"
  case "$orr" in
    *haiku*)         pass ;;                                   # economy tier honored -> DIFFERENTIATED from the verifier
    *opus*|*sonnet*) fail "researcher ran on the wrong model (want haiku): $(printf '%s' "$orr" | tail -c 120)" ;;
    *)               skip "researcher model self-report inconclusive this run" ;;
  esac
  cd /
fi
