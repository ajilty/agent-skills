# Tier 3b (OpenCode plugin load, live) — does the orchestrate plugin load at all
# in a real `opencode run`? Two halves:
#   1. STRUCTURAL (free, no model call): `opencode debug config` resolves and
#      lists the loaded plugin file paths — assert orchestrate.ts is in it.
#   2. LIVE (one minimal model call): a trivial `opencode run` completes cleanly
#      (exit 0) with no plugin-load error in the session log. This is the
#      cheapest possible live check — no tool call is needed, since the plugin
#      loads once at session start regardless of what the model does.
# Self-skips without opencode / live auth (SKIP, not FAIL, per the acceptance
# oracle's PATH-stripped contract).
if ! have_opencode; then
  skip "opencode plugin-load: opencode CLI not on PATH"
elif ! have_opencode_auth; then
  skip "opencode plugin-load: no opencode auth (~/.local/share/opencode/auth.json)"
else
  oc="$(mk_opencode_home)"
  opencode_install "$oc"
  ws="$(mk_tmp)"

  # 1. Structural: the resolved config lists our plugin (no model call). NOTE:
  # `opencode debug config` output is LONG (every agent's full prompt is
  # inlined) -- capturing it via `$(...)` command substitution truncates
  # silently on this build (observed: cut off mid-stream every time, no error,
  # no timeout). Redirect to a real file instead, which is complete every time.
  cfg_file="$(mk_tmp)/config.json"
  ( cd "$ws" && oc_run "$oc" timeout 30 opencode debug config ) >"$cfg_file" 2>/dev/null
  if grep -q "plugins/orchestrate.ts" "$cfg_file"; then
    pass   # orchestrate.ts is a registered plugin in resolved config
  else
    fail "opencode plugin-load: orchestrate.ts not present in \`opencode debug config\` plugin list ($(wc -l <"$cfg_file") lines captured)"
  fi

  # 2. Live: a trivial session must not error at plugin load.
  out="$(cd "$ws" && oc_run "$oc" timeout 90 opencode run --model "$OC_MODEL" "Reply with exactly the word: pong" 2>&1)"
  rc=$?
  if [ "$rc" -eq 124 ]; then
    skip "opencode plugin-load: live run timed out (model latency) — structural half already confirmed the plugin is registered"
  elif [ "$rc" -ne 0 ]; then
    fail "opencode plugin-load: \`opencode run\` exited $rc: $(printf '%s' "$out" | tail -5)"
  elif printf '%s' "$out" | grep -qiE 'plugin.*(error|failed|threw)|error.*plugin'; then
    fail "opencode plugin-load: plugin-related error surfaced in run output: $(printf '%s' "$out" | grep -iE 'plugin' | head -3)"
  else
    pass   # session completed with no plugin-load error surfaced
  fi

  # Log-level corroboration: no plugin error lines in the sandboxed log dir.
  logdir="$oc/.local/share/opencode/log"
  errs="$(grep -riE "plugin" "$logdir" 2>/dev/null | grep -iE "error|failed|threw" || true)"
  if [ -n "$errs" ]; then
    fail "opencode plugin-load: plugin error(s) in session log: $(printf '%s' "$errs" | head -3)"
  else
    pass   # no plugin errors logged
  fi
  cd /
fi
