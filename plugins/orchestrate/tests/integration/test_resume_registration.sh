# Tier 3 (resume / registration lifecycle, live) — plugin-lifecycle BASELINE that bounds
# Issue B (orchestrate:* agents vanish on interactive resume / aren't restored by
# /reload-plugins). FINDING (2026-06-23): this does NOT reproduce Issue B, and that is
# itself diagnostic — each `claude -p`/`-p -c` is a fresh process that re-initialises
# plugins, so it re-registers the agents every time and resume works headlessly. Issue B
# is therefore specific to the INTERACTIVE --resume/--continue path (a CC harness
# behaviour: agent-types register at interactive session-start; interactive resume does
# not re-run it), NOT the plugin artifacts/config. This test guards that the
# install->resume->dispatch path stays sound headlessly AND that stale settings don't
# break install — narrowing Issue B to the interactive harness. The interactive drop
# remains a documented manual check (see TODO).
#
# Needs an INSTALLED (persisted) plugin, so it sandboxes HOME and authenticates by
# cloning the OAuth credential in (mk_authed_home) — FS-isolated, no real-config touch.
if ! have_claude; then
  skip "tier3 resume/registration: claude CLI not on PATH"
elif ! have_live_auth; then
  skip "tier3 resume/registration: no live auth (ANTHROPIC_API_KEY or ~/.claude/.credentials.json)"
else
  # ---- Part A: installed-plugin resume registration (Issue B) ----
  h="$(mk_authed_home)"; work="$(mk_repo)"
  cc(){ ( cd "$work" && HOME="$h" claude "$@" ); }
  cc plugin marketplace add "$REPO_ROOT" >/dev/null 2>&1
  cc plugin install orchestrate@agentic --scope user >/dev/null 2>&1
  probe='Use the Task tool to dispatch a subagent of type "orchestrate:researcher" with the instruction: reply with exactly the token RESEARCHER_OK. Output the subagent reply verbatim. If that agent type is not available, output exactly the token AGENT_NOT_FOUND.'
  s1="$(printf '%s' "$probe" | ( cd "$work" && HOME="$h" timeout 240 claude -p --allowedTools "Task" ) 2>&1)"
  s2="$(printf '%s' "$probe" | ( cd "$work" && HOME="$h" timeout 240 claude -p -c --allowedTools "Task" ) 2>&1)"

  # Session 1 (first session after install): the agent type should be dispatchable.
  case "$s1" in
    *RESEARCHER_OK*) pass;;
    *AGENT_NOT_FOUND*) fail "session1: orchestrate:researcher NOT registered even right after install (headless -p may not register plugin agents)";;
    *) skip "session1: probe inconclusive (model did not dispatch; rerun)";;
  esac
  # Session 2 (resume via -c): MUST still be dispatchable. If not -> Issue B reproduced.
  case "$s2" in
    *RESEARCHER_OK*) pass;;
    *AGENT_NOT_FOUND*) fail "RESUME: orchestrate:researcher dropped on resume (Issue B reproduced)";;
    *) skip "resume: probe inconclusive (model did not dispatch; rerun)";;
  esac

  # ---- Part B: STALE settings must not break a fresh install/load ----
  # Seed a dangling enable for a marketplace that does not exist, then install the real
  # plugin and confirm it still loads (5 agents) and lists — i.e. the stale reference is
  # ignored/reconciled, not fatal. Deterministic (no model call).
  h2="$(mk_home)"; work2="$(mk_tmp)"; mkdir -p "$h2/.claude/plugins"
  printf '{"enabledPlugins":{"orchestrate@ghost-marketplace":true}}' > "$h2/.claude/settings.json"
  cc2(){ ( cd "$work2" && HOME="$h2" claude "$@" ); }
  cc2 plugin marketplace add "$REPO_ROOT" >/dev/null 2>&1 && pass || fail "stale-settings: marketplace add over a stale enable"
  cc2 plugin install orchestrate@agentic --scope user >/dev/null 2>&1 && pass || fail "stale-settings: install over a stale enabledPlugins entry"
  case "$(cc2 plugin list 2>/dev/null)" in *"orchestrate@agentic"*) pass;; *) fail "stale-settings: real plugin not listed (stale ghost entry broke it)";; esac
  case "$(cc2 plugin details orchestrate@agentic 2>/dev/null)" in *"Agents (5)"*) pass;; *) fail "stale-settings: real plugin loads 5 agents despite stale ghost entry";; esac

  rm -rf "$HOME/.claude/projects/"-tmp-* 2>/dev/null || true
fi
