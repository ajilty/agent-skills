SK="$HERE/.."   # plugins/orchestrate
have_yq4 || { echo "(skip test_install: $YQ4_SKIP)"; return 0 2>/dev/null || true; }
d="$(mktemp_repo)"; cd "$d"
# codex: emits ALL five personas, honors --dir (no AGENTS.orchestrate.md in cwd), ships runtime
o="/tmp/p4cx.$$"; rm -rf "$o"; bash "$SK/scripts/install-codex.sh" --scope project --dir "$o" >/dev/null 2>&1
for p in researcher planner implementer verifier actuator; do assert_file "$o/agents/$p.toml"; done
assert_no_file "AGENTS.orchestrate.md"
test -x "$o/orchestrate-runtime/ledger.sh" && pass || fail "codex ships ledger.sh executable"
# capability -> sandbox_mode mapping: any write- or run-capable persona = workspace-write.
# Under the disk-first read lane (ADR-0014) the researcher writes its own findings, so it
# is workspace-write at the OS layer and confined to findings/_quarantine by the
# write-scope hook (two layers, same posture as the planner). actuator (run) = workspace-write.
grep -q 'sandbox_mode = "workspace-write"' "$o/agents/researcher.toml" && pass || fail "codex researcher sandbox_mode=workspace-write (results-only, hook-scoped)"
grep -q 'sandbox_mode = "workspace-write"' "$o/agents/actuator.toml" && pass || fail "codex actuator sandbox_mode=workspace-write"
# ADR-0017: per-persona launcher + injected bodies + router network egress so confined
# personas can be dispatched as their own `codex exec --cd <lane>` (OS-confined writes).
test -x "$o/orchestrate-runtime/dispatch-persona.sh" && pass || fail "codex ships dispatch-persona.sh executable (ADR-0017)"
for p in researcher planner implementer verifier actuator; do assert_file "$o/orchestrate-runtime/personas/$p.md"; done
grep -qE '^[[:space:]]*network_access[[:space:]]*=[[:space:]]*true' "$o/config.toml" && pass || fail "codex config sets network_access=true (ADR-0017)"
rm -rf "$o"
# opencode: emits ALL five personas AND honors --dir
o="/tmp/p4oc.$$"; rm -rf "$o"; bash "$SK/scripts/install-opencode.sh" --scope project --dir "$o" >/dev/null 2>&1
for p in researcher planner implementer verifier actuator; do assert_file "$o/agent/$p.md"; done
assert_no_file "AGENTS.orchestrate.md"
rm -rf "$o"
cd /; rm -rf "$d"
