SK="$HERE/.."   # plugins/orchestrate
command -v yq >/dev/null 2>&1 || { echo "(skip test_install: yq absent)"; return 0 2>/dev/null || true; }
d="$(mktemp_repo)"; cd "$d"
# codex: emits actuator AND honors --dir (must NOT write AGENTS.orchestrate.md into cwd)
o="/tmp/p4cx.$$"; rm -rf "$o"; bash "$SK/scripts/install-codex.sh" --scope project --dir "$o" >/dev/null 2>&1
assert_file "$o/agents/actuator.toml"
assert_no_file "AGENTS.orchestrate.md"
test -x "$o/orchestrate-runtime/ledger.sh" && pass || fail "codex ships ledger.sh executable"
rm -rf "$o"
# opencode: emits actuator AND honors --dir
o="/tmp/p4oc.$$"; rm -rf "$o"; bash "$SK/scripts/install-opencode.sh" --scope project --dir "$o" >/dev/null 2>&1
assert_file "$o/agent/actuator.md"
assert_no_file "AGENTS.orchestrate.md"
rm -rf "$o"
cd /; rm -rf "$d"
