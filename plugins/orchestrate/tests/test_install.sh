SK="$HERE/.."   # plugins/orchestrate
command -v yq >/dev/null 2>&1 || { echo "(skip test_install: yq absent)"; return 0 2>/dev/null || true; }
d="$(mktemp_repo)"; cd "$d"
# codex: emits ALL five personas, honors --dir (no AGENTS.orchestrate.md in cwd), ships runtime
o="/tmp/p4cx.$$"; rm -rf "$o"; bash "$SK/scripts/install-codex.sh" --scope project --dir "$o" >/dev/null 2>&1
for p in researcher planner implementer verifier actuator; do assert_file "$o/agents/$p.toml"; done
assert_no_file "AGENTS.orchestrate.md"
test -x "$o/orchestrate-runtime/ledger.sh" && pass || fail "codex ships ledger.sh executable"
# capability -> sandbox_mode mapping: researcher (no write/run) = read-only; actuator (run) = workspace-write
grep -q 'sandbox_mode = "read-only"' "$o/agents/researcher.toml" && pass || fail "codex researcher sandbox_mode=read-only"
grep -q 'sandbox_mode = "workspace-write"' "$o/agents/actuator.toml" && pass || fail "codex actuator sandbox_mode=workspace-write"
rm -rf "$o"
# opencode: emits ALL five personas AND honors --dir
o="/tmp/p4oc.$$"; rm -rf "$o"; bash "$SK/scripts/install-opencode.sh" --scope project --dir "$o" >/dev/null 2>&1
for p in researcher planner implementer verifier actuator; do assert_file "$o/agent/$p.md"; done
assert_no_file "AGENTS.orchestrate.md"
rm -rf "$o"
cd /; rm -rf "$d"
