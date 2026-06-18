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

# --- Drift guard: committed artifacts must equal a fresh build. Copy the plugin
#     to a temp tree, rebuild there, diff the generated files. Skips without yq.
if command -v yq >/dev/null 2>&1; then
  t="$(mktemp -d)"; cp -r "$SK/." "$t/"
  ( bash "$t/scripts/build.sh" >/dev/null 2>&1 )
  for f in agents/researcher.md agents/planner.md agents/implementer.md agents/verifier.md agents/actuator.md hooks/hooks.json; do
    if diff -q "$SK/$f" "$t/$f" >/dev/null 2>&1; then pass; else fail "drift: committed $f != fresh build (run scripts/build.sh)"; fi
  done
  rm -rf "$t"
else
  echo "(skip drift guard: yq absent)"
fi

# --- Manifest validity: plugin.json + marketplace.json parse; names align;
#     marketplace source resolves to a real dir. Skips without yq.
if command -v yq >/dev/null 2>&1; then
  pj="$SK/.claude-plugin/plugin.json"
  mp="$(cd "$SK/../.." && pwd)/.claude-plugin/marketplace.json"
  assert_eq "$(yq -p=json -r '.name' "$pj")" "orchestrate" "plugin.json name"
  assert_eq "$(yq -p=json -r '.plugins[0].name' "$mp")" "orchestrate" "marketplace plugin name"
  src="$(yq -p=json -r '.plugins[0].source' "$mp")"
  rdir="$(cd "$SK/../.." && pwd)/${src#./}"
  if [ -d "$rdir" ] && [ -f "$rdir/.claude-plugin/plugin.json" ]; then pass; else fail "marketplace source '$src' does not resolve to a plugin dir"; fi
else
  echo "(skip manifest validity: yq absent)"
fi
