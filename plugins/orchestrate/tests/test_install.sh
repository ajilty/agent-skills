SK="$HERE/.."   # plugins/orchestrate
have_yq4 || { echo "(skip test_install: $YQ4_SKIP)"; return 0 2>/dev/null || true; }
d="$(mktemp_repo)"; cd "$d"
# codex: emits ALL five personas, honors --dir (no AGENTS.orchestrate.md anywhere — the
# brain is now a NATIVE skill under .agents/skills, ADR-0034), ships runtime inside it
o="${TMPDIR:-/tmp}/p4cx.$$"; rm -rf "$o"; bash "$SK/scripts/install-codex.sh" --scope project --dir "$o" >/dev/null 2>&1
SKD="$o/.agents/skills/orchestrate"
for p in researcher planner implementer verifier actuator; do assert_file "$o/agents/$p.toml"; done
assert_no_file "AGENTS.orchestrate.md"
assert_no_file "$o/AGENTS.orchestrate.md"
assert_file "$SKD/SKILL.md"
grep -q '^name: orchestrate' "$SKD/SKILL.md" && pass || fail "codex skill keeps the frontmatter name (skills standard)"
grep -q 'Codex dispatch addendum' "$SKD/SKILL.md" && pass || fail "codex skill carries the dispatch addendum (ADR-0017/0034)"
grep -q "export PATH=\"$SKD/runtime" "$SKD/SKILL.md" && pass || fail "addendum embeds the absolute runtime PATH line (ADR-0018)"
assert_file "$SKD/references/resume.md"
test -x "$SKD/runtime/ledger.sh" && pass || fail "codex ships ledger.sh executable inside the skill"
test -x "$SKD/runtime/dispatch-persona.sh" && pass || fail "codex ships dispatch-persona.sh executable (ADR-0017)"
for p in researcher planner implementer verifier actuator; do assert_file "$SKD/runtime/personas/$p.md"; done
# capability -> sandbox_mode mapping: any write- or run-capable persona = workspace-write.
# Under the disk-first read lane (ADR-0014) the researcher writes its own findings, so it
# is workspace-write at the OS layer and confined to findings/_quarantine by the
# write-scope hook (two layers, same posture as the planner). actuator (run) = workspace-write.
grep -q 'sandbox_mode = "workspace-write"' "$o/agents/researcher.toml" && pass || fail "codex researcher sandbox_mode=workspace-write (results-only, hook-scoped)"
grep -q 'sandbox_mode = "workspace-write"' "$o/agents/actuator.toml" && pass || fail "codex actuator sandbox_mode=workspace-write"
grep -qE '^[[:space:]]*network_access[[:space:]]*=[[:space:]]*true' "$o/config.toml" && pass || fail "codex config sets network_access=true (ADR-0017)"
# hooks.json points into the skill's runtime (single copy — no $CODEX_HOME/orchestrate-runtime)
grep -q "$SKD/runtime/hooks/" "$o/hooks.json" && pass || fail "codex hooks.json points at the skill's runtime hooks"
[ ! -d "$o/orchestrate-runtime" ] && pass || fail "codex no longer ships a second runtime copy at CODEX_HOME"
rm -rf "$o"
# opencode: five personas in agents/ (plural, docs-current), native skill, plugin,
# command parity — and no AGENTS.orchestrate.md
o="${TMPDIR:-/tmp}/p4oc.$$"; rm -rf "$o"; bash "$SK/scripts/install-opencode.sh" --scope project --dir "$o" >/dev/null 2>&1
SKD="$o/.agents/skills/orchestrate"
for p in researcher planner implementer verifier actuator; do assert_file "$o/agents/$p.md"; done
assert_no_file "AGENTS.orchestrate.md"
assert_no_file "$o/AGENTS.orchestrate.md"
assert_file "$SKD/SKILL.md"
grep -q 'OpenCode dispatch addendum' "$SKD/SKILL.md" && pass || fail "opencode skill carries its dispatch addendum (ADR-0034)"
test -x "$SKD/runtime/ledger.sh" && pass || fail "opencode ships ledger.sh executable inside the skill"
assert_file "$o/plugins/orchestrate.ts"
grep -q 'session.compacted' "$o/plugins/orchestrate.ts" && pass || fail "opencode plugin wires the documented session.compacted event"
grep -q "$SKD/runtime" "$o/plugins/orchestrate.ts" && pass || fail "opencode plugin points at the skill's runtime (single copy)"
for c in init status feedback; do assert_file "$o/commands/orchestrate-$c.md"; done
grep -q -- '--models=' "$o/commands/orchestrate-init.md" && pass || fail "opencode init command carries the --models flag contract"
# permission: layer emitted alongside deprecated tools: (read-only persona denies edit+bash)
grep -A3 '^permission:' "$o/agents/planner.md" | grep -q 'bash: deny' && pass || fail "opencode planner permission denies bash"
grep -A3 '^permission:' "$o/agents/implementer.md" | grep -q 'bash: allow' && pass || fail "opencode implementer permission allows bash"
rm -rf "$o"
cd /; rm -rf "$d"
