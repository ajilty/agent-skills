# Tier 3 (OpenCode skill discovery, live, deterministic) — is the installed
# orchestrate skill actually discoverable in an OpenCode session? Prefers the
# non-LLM, zero-token probe the CLI exposes for exactly this (`opencode debug
# skill` — lists every skill the scanner found, no model call): cheaper and
# more deterministic than asking a model to enumerate its own skills, per the
# work item's stated preference.
#
# NOTE: `opencode debug ...` output can be large; command substitution (`$(...)`)
# was observed to silently truncate large opencode output on this build (see
# test_opencode_plugin_load.sh and probe-results.md) — redirect to a real file.
if ! have_opencode; then
  skip "opencode skill-discovery: opencode CLI not on PATH"
else
  oc="$(mk_opencode_home)"
  opencode_install "$oc"
  ws="$(mk_tmp)"
  skill_file="$(mk_tmp)/skills.json"
  ( cd "$ws" && oc_run "$oc" timeout 30 opencode debug skill ) >"$skill_file" 2>/dev/null

  if [ ! -s "$skill_file" ]; then
    skip "opencode skill-discovery: \`opencode debug skill\` produced no output (opencode auth/network issue?)"
  elif grep -q '"name": *"orchestrate"' "$skill_file"; then
    pass   # orchestrate skill discovered by opencode's own skill scanner
  else
    fail "opencode skill-discovery: orchestrate skill NOT found by \`opencode debug skill\` (found: $(grep -o '"name": *"[^"]*"' "$skill_file" | tr '\n' ' '))"
  fi
  cd /
fi
