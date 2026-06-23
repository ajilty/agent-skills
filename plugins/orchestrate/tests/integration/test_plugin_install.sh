# Tier 2 — plugin-install smoke against the REAL `claude` CLI. No API key needed:
# validate/marketplace/install/details make no model calls. Filesystem-isolated at
# the HOME level (not via CLAUDE_CONFIG_DIR): every `claude` runs with HOME and cwd
# pointed at throwaway dirs, so user config, the project-scope `.claude/`, and the
# plugin cache all land in the sandbox — nothing touches the repo or real ~/.claude.
# Proves Claude Code actually ingests the packaged plugin (the gap the zero-dep suite
# can't reach — it only checks the artifacts structurally).
if ! have_claude; then
  skip "tier2 plugin-install: claude CLI not on PATH"
else
  h="$(mk_home)"; work="$(mk_tmp)"
  cc(){ ( cd "$work" && HOME="$h" claude "$@" ); }   # FS-isolated claude invocation

  # 1) Manifests validate via the official validator.
  cc plugin validate "$PLUGIN_DIR" >/dev/null 2>&1 && pass || fail "plugin.json validates (claude plugin validate)"
  cc plugin validate "$REPO_ROOT"  >/dev/null 2>&1 && pass || fail "marketplace.json validates (claude plugin validate)"

  # 2) Add the local marketplace and install the plugin.
  cc plugin marketplace add "$REPO_ROOT" >/dev/null 2>&1 && pass || fail "marketplace add (local path)"
  cc plugin install orchestrate@ajilty-agent-skills >/dev/null 2>&1 && pass || fail "plugin install"

  # 3) Component inventory from the installed plugin (the harness actually parsed it).
  det="$(cc plugin details orchestrate 2>/dev/null)"
  case "$det" in *"Agents (5)"*) pass;; *) fail "details reports 5 agents";; esac
  for a in researcher planner implementer verifier actuator; do
    case "$det" in *"$a"*) pass;; *) fail "details lists agent: $a";; esac
  done
  case "$det" in *"start"*) pass;; *) fail "details lists the start command/skill (/orchestrate:start)";; esac
  case "$det" in *"Hooks (3)"*) pass;; *) fail "details reports 3 registered hook events";; esac

  # 4) Isolation self-check: nothing leaked into the repo or the real ~/.claude.
  if grep -rqs ajilty-agent-skills "$REPO_ROOT/.claude" 2>/dev/null; then
    fail "leaked marketplace/plugin into the repo's .claude/ (project-scope leak)"
  else pass; fi
  if grep -rqs ajilty-agent-skills "$HOME/.claude/plugins/known_marketplaces.json" 2>/dev/null; then
    fail "leaked marketplace into the real ~/.claude (HOME sandbox failed)"
  else pass; fi
fi
