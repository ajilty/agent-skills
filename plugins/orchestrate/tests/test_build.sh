SK="$HERE/.."   # plugins/orchestrate

# --- Compiled tool-allowlist (safety-critical): each generated agent carries
#     exactly the tools agents.yaml implies. Positive + negative assertions.
declare -A WANT=(
  [researcher]='Read,Grep,Glob,WebSearch,WebFetch,Write'
  [planner]='Read,Grep,Glob,Write'
  [implementer]='Read,Grep,Glob,Write,Edit,Bash'
  [verifier]='Read,Grep,Glob,Write,Bash'
  [actuator]='Read,Grep,Glob,Bash'
)
for p in "${!WANT[@]}"; do
  got="$(awk -F': ' '/^tools: /{print $2; exit}' "$SK/agents/$p.md" 2>/dev/null)"
  assert_eq "$got" "${WANT[$p]}" "allowlist $p"
done

# --- Compiled model/effort tiers: horsepower right-sized by persona role. The abstract
#     contract tier (economy/standard/premium) compiles to a concrete CC model; effort
#     passes through. Judgment/correctness (planner/verifier) premium; reduction
#     (researcher) economy. (CLAUDE_CODE_SUBAGENT_MODEL=inherit can override model at
#     runtime — that's an operator env concern, not the compiled artifact.)
declare -A WANT_MODEL=( [researcher]=haiku [planner]=opus [implementer]=sonnet [verifier]=opus [actuator]=sonnet )
declare -A WANT_EFFORT=( [researcher]=medium [planner]=high [implementer]=high [verifier]=max [actuator]=high )
for p in "${!WANT_MODEL[@]}"; do
  gm="$(awk -F': ' '/^model: /{print $2; exit}' "$SK/agents/$p.md" 2>/dev/null)"
  ge="$(awk -F': ' '/^effort: /{print $2; exit}' "$SK/agents/$p.md" 2>/dev/null)"
  assert_eq "$gm" "${WANT_MODEL[$p]}" "model tier $p"
  assert_eq "$ge" "${WANT_EFFORT[$p]}" "effort tier $p"
done
# Negatives (disk-first read lane, ADR-0014): read-only personas now carry a
# PATH-SCOPED Write (results-only: findings/_quarantine for researcher, verdicts
# for verifier; enforced by write-scope.sh) so their results survive interruption.
# They must still NOT carry Edit (they create new result files, never edit source),
# and the actuator (writes live state via run, not source via Write) carries neither.
for p in researcher verifier; do
  if grep -qE '^tools: .*Edit' "$SK/agents/$p.md"; then fail "$p must not have Edit (results-only Write, no source edits)"; else pass; fi
done
if grep -qE '^tools: .*(Write|Edit)' "$SK/agents/actuator.md"; then fail "actuator must not have Write/Edit"; else pass; fi

# --- Hook-path resolution: every ${CLAUDE_PLUGIN_ROOT}/... command in hooks.json
#     resolves to an executable script inside the plugin.
ok=1
while IFS= read -r rel; do
  [ -x "$SK/$rel" ] || { ok=0; echo "  unresolved/non-exec hook: $rel" >&2; }
done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^"]+\.sh' "$SK/hooks/hooks.json" | sed 's#${CLAUDE_PLUGIN_ROOT}/##' | sort -u)
[ "$ok" = 1 ] && pass || fail "hooks.json paths resolve to executable scripts"

# --- Contract parity (root-cause guard): EVERY hook declared in agents.yaml's
#     hooks: block must be materialized (script exists + executable) AND wired into
#     hooks.json. The declared-name -> script-file map is explicit, so declaring a
#     new hook forces wiring it here too. This is the check that would have caught
#     write_scope being declared (fail_closed) but never filed or wired.
declare -A HOOKFILE=(
  [heldout_read_deny]=deny-heldout-read.sh
  [write_scope]=write-scope.sh
  [branch_guard]=keep-on-branch.sh
  [shared_checkout_guard]=guard-shared-checkout.sh
  [done_gate]=guard-done.sh
  [prod_apply_gate]=gate-prod-apply.sh
  [run_scope]=run-scope.sh
  [writer_writeahead]=on-writer-dispatch.sh
  [compaction_reground]=on-compaction.sh
)
if command -v yq >/dev/null 2>&1; then
  AG="$SK/skills/orchestrate/references/agents.yaml"
  HJ="$SK/hooks/hooks.json"
  HD="$SK/skills/orchestrate/runtime/hooks"
  for name in $(yq '.hooks | keys | .[]' "$AG"); do
    f="${HOOKFILE[$name]:-}"
    if [ -z "$f" ]; then fail "declared hook '$name' has no script mapping in test_build.sh (add it)"; continue; fi
    if [ ! -x "$HD/$f" ]; then fail "declared hook '$name' -> $f missing or non-executable"; continue; fi
    if grep -q "/$f\"" "$HJ"; then pass; else fail "declared hook '$name' ($f) not wired in hooks.json"; fi
  done
else
  echo "(skip contract-parity: yq absent)"
fi

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
