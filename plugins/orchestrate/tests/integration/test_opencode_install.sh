# Tier 3 (OpenCode install, static — no auth needed) — the compiled orchestrate.ts
# must actually PARSE under OpenCode's TS-stripping runtime, wire the confirmed
# load-bearing hook with the correct callback signature, and land every generated
# surface (agents/, commands/, plugins/, skill) exactly where a live `opencode`
# reads from. Guards on have_opencode (not have_opencode_auth) — this probe needs
# the CLI's bundled `node`/parsing behavior but no live model call, matching the
# work item's "static, no auth needed" framing; still self-skips per the
# acceptance oracle's "PATH stripped of opencode -> SKIP, not FAIL" contract.
if ! have_opencode; then
  skip "opencode install: opencode CLI not on PATH"
else
  oc="$(mk_opencode_home)"
  opencode_install "$oc"
  cfg="$oc/.config/opencode"
  plug="$cfg/plugins/orchestrate.ts"

  if [ ! -f "$plug" ]; then
    fail "opencode install: no orchestrate.ts emitted at $plug"
  else
    pass
    # Syntax validity: OpenCode's bundled node must be able to strip+parse this
    # TS file. `node --check` alone chokes on TS syntax (types, `as`, etc.), so
    # prefer --experimental-strip-types when the host node supports it; fall back
    # to a plain syntax skip (not a fail) rather than asserting on an unsupported
    # host node.
    if command -v node >/dev/null 2>&1; then
      if node --experimental-strip-types --check "$plug" >/tmp/oc_install_check.$$ 2>&1; then
        pass   # orchestrate.ts parses under strip-types
      else
        if grep -qi "unknown or unexpected option" /tmp/oc_install_check.$$ 2>/dev/null; then
          skip "opencode install: host node lacks --experimental-strip-types — cannot syntax-check TS directly"
        else
          fail "opencode install: orchestrate.ts failed to parse: $(head -3 /tmp/oc_install_check.$$)"
        fi
      fi
      rm -f /tmp/oc_install_check.$$
    else
      skip "opencode install: no node on PATH to syntax-check the emitted TS"
    fi

    # The confirmed, load-bearing hook (live-probed against 1.18.4): must be
    # wired with the (input, output) signature — args live on the SECOND
    # parameter (Hooks["tool.execute.before"] output.args), and a single-arg
    # callback silently reads undefined forever (the exact bug this tier found
    # and fixed; see probe-results.md). This assertion locks that fix in place.
    if grep -q '"tool.execute.before": *async (input: any, output: any)' "$plug"; then
      pass   # tool.execute.before wired with the 2-arg signature the live args live on
    else
      fail "opencode install: tool.execute.before is not wired with a 2-arg (input, output) callback — args live on output.args live (probe-results.md); a 1-arg callback silently no-ops every path/command check"
    fi
    # Hook env must be passed EXPLICITLY per call — implicit process.env inheritance
    # silently failed open on this Bun build (probe-results.md). The reconciled
    # installer uses Bun \$'s per-call .env({ ...process.env, ...env }).
    grep -q '\.env({ \.\.\.process\.env' "$plug" && pass || fail "opencode install: sh() does not pass an explicit per-call env ( .env({ ...process.env, ...env }) ) — hook subprocesses silently lose RESOLVED_PATH/TOOL_INPUT/PATH on this Bun build (probe-results.md)"

    # Documented hooks only (ADR-0034 resolution 2026-07-21): shell.env +
    # session.compacted wired, and NO subagent.start (not a documented event —
    # writer write-ahead is in-loop). test_opencode_compaction_event.sh remains
    # the live arbiter of whether session.compacted actually fires.
    if grep -q '"shell.env"' "$plug" && grep -q '"session.compacted"' "$plug" && ! grep -q '"subagent.start"' "$plug"; then
      pass   # documented hook set exactly (compaction firing bounded live by test_opencode_compaction_event.sh)
    else
      fail "opencode install: expected shell.env + session.compacted and NO subagent.start — installer output changed shape"
    fi
  fi

  # File placement: agents/ (5 personas), commands/ (3), skill dir (SKILL.md +
  # runtime/ + references/) exactly where a live opencode with this HOME/XDG set
  # would read them from (same vars oc_run uses — no separate path arithmetic).
  n_agents="$(find "$cfg/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq "${n_agents:-0}" 5 "opencode install: 5 persona agent files"
  n_cmds="$(find "$cfg/commands" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq "${n_cmds:-0}" 3 "opencode install: 3 command files"
  [ -f "$oc/.agents/skills/orchestrate/SKILL.md" ] && pass || fail "opencode install: skill did not land at HOME/.agents/skills/orchestrate/SKILL.md"
  [ -x "$oc/.agents/skills/orchestrate/runtime/hooks/deny-heldout-read.sh" ] && pass || fail "opencode install: deny-heldout-read.sh not installed executable in the skill's runtime"
  cd /
fi
