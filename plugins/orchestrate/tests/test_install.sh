SK="$HERE/.."   # skills/orchestrate
command -v yq >/dev/null 2>&1 || { echo "(skip test_install: yq absent)"; return 0 2>/dev/null || true; }
d="$(mktemp_repo)"; cd "$d"
# claude-code: emits the actuator subagent and ships runtime scripts executable
o="/tmp/p4cc.$$"; rm -rf "$o"; bash "$SK/scripts/install-claude-code.sh" --scope project --dir "$o" >/dev/null 2>&1
assert_file "$o/agents/actuator.md"
test -x "$o/skills/orchestrate/runtime/adr.sh" && pass || fail "cc ships adr.sh executable"
test -x "$o/skills/orchestrate/runtime/hooks/gate-prod-apply.sh" && pass || fail "cc ships gate hook executable"
rm -rf "$o"
# codex: emits actuator AND honors --dir (must NOT write AGENTS.orchestrate.md into cwd)
o="/tmp/p4cx.$$"; rm -rf "$o"; bash "$SK/scripts/install-codex.sh" --scope project --dir "$o" >/dev/null 2>&1
assert_file "$o/agents/actuator.toml"
assert_no_file "AGENTS.orchestrate.md"
rm -rf "$o"
# opencode: emits actuator AND honors --dir
o="/tmp/p4oc.$$"; rm -rf "$o"; bash "$SK/scripts/install-opencode.sh" --scope project --dir "$o" >/dev/null 2>&1
assert_file "$o/agent/actuator.md"
assert_no_file "AGENTS.orchestrate.md"
rm -rf "$o"
# symlink-vendored layout: DEST/skills/orchestrate resolves to the source
# (.claude/skills -> ../.agents/skills). The CC installer must NOT self-copy/error.
o="/tmp/p4sym.$$"; rm -rf "$o"; mkdir -p "$o/.agents/skills" "$o/.claude"
/usr/bin/cp -r "$SK" "$o/.agents/skills/orchestrate"
ln -s ../.agents/skills "$o/.claude/skills"
( cd "$o" && bash .agents/skills/orchestrate/scripts/install-claude-code.sh --scope project >/dev/null 2>&1 )
assert_eq "$?" "0" "CC installer survives .claude/skills->.agents/skills symlink (no self-copy)"
assert_file "$o/.claude/agents/actuator.md"
assert_file "$o/.claude/commands/orchestrate.md"
rm -rf "$o"
cd /; rm -rf "$d"
