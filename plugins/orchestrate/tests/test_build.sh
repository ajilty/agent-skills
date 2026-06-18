SK="$HERE/.."   # plugins/orchestrate

# --- Compiled tool-allowlist (safety-critical): each generated agent carries
#     exactly the tools agents.yaml implies. Positive + negative assertions.
declare -A WANT=(
  [researcher]='Read,Grep,Glob,WebSearch,WebFetch'
  [planner]='Read,Grep,Glob,Write'
  [implementer]='Read,Grep,Glob,Write,Edit,Bash'
  [verifier]='Read,Grep,Glob,Bash'
  [actuator]='Read,Grep,Glob,Bash'
)
for p in "${!WANT[@]}"; do
  got="$(awk -F': ' '/^tools: /{print $2; exit}' "$SK/agents/$p.md" 2>/dev/null)"
  assert_eq "$got" "${WANT[$p]}" "allowlist $p"
done
# Negatives: read-only/run-only personas must NOT carry source-write tools.
for p in researcher verifier actuator; do
  if grep -qE '^tools: .*(Write|Edit)' "$SK/agents/$p.md"; then fail "$p must not have Write/Edit"; else pass; fi
done

# --- Hook-path resolution: every ${CLAUDE_PLUGIN_ROOT}/... command in hooks.json
#     resolves to an executable script inside the plugin.
ok=1
while IFS= read -r rel; do
  [ -x "$SK/$rel" ] || { ok=0; echo "  unresolved/non-exec hook: $rel" >&2; }
done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^"]+\.sh' "$SK/hooks/hooks.json" | sed 's#${CLAUDE_PLUGIN_ROOT}/##' | sort -u)
[ "$ok" = 1 ] && pass || fail "hooks.json paths resolve to executable scripts"
