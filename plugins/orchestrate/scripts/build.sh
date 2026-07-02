#!/usr/bin/env bash
# build.sh — generate the Claude Code plugin's native artifacts from the
# harness-neutral agents.yaml. Run by the maintainer after editing agents.yaml or
# a persona body; the output (agents/, hooks/hooks.json) is COMMITTED. The static
# manifest (.claude-plugin/plugin.json) and marketplace catalog are NOT generated.
#   ./scripts/build.sh        # writes into the plugin this script lives in
set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$PLUGIN_ROOT/skills/orchestrate"
AGENTS="$SKILL_DIR/references/agents.yaml"
yq --version 2>/dev/null | grep -qE 'mikefarah|version v?4\.' || { echo "FATAL: yq (v4, mikefarah) required — the Python (kislyuk) yq emits JSON-quoted scalars and will not work." >&2; exit 1; }

cc_tools() { local p="$1" t=()
  [ "$(yq ".personas.$p.capabilities.read" "$AGENTS")" = true ] && t+=(Read Grep Glob)
  [ "$(yq ".personas.$p.capabilities.web"  "$AGENTS")" = true ] && t+=(WebSearch WebFetch)
  case "$(yq ".personas.$p.capabilities.write" "$AGENTS")" in full) t+=(Write Edit);; spec-only|results-only) t+=(Write);; esac
  case "$(yq ".personas.$p.capabilities.run" "$AGENTS")" in full|tests-only) t+=(Bash);; esac
  ( IFS=, ; echo "${t[*]}" ); }
body() { awk 'f==2{print} /^---[[:space:]]*$/{f++}' "$1"; }
# Abstract horsepower tier (agents.yaml, portable) -> concrete CC model. Effort passes
# through (low|medium|high|xhigh|max are CC-native). Keeps the contract free of vendor
# model IDs; each harness generator maps the same tier to its own models.
cc_model() { case "$1" in economy) echo haiku;; standard) echo sonnet;; premium) echo opus;; *) echo "";; esac; }

# 1) agents/<persona>.md — frontmatter (name/description/tools) + persona body
mkdir -p "$PLUGIN_ROOT/agents"
for p in $(yq '.personas | keys | .[]' "$AGENTS"); do
  desc="$(yq ".personas.$p.description" "$AGENTS")"
  bsrc="$SKILL_DIR/references/$(yq ".personas.$p.body" "$AGENTS")"
  mt="$(yq ".personas.$p.tier.model" "$AGENTS")"; ef="$(yq ".personas.$p.tier.effort" "$AGENTS")"
  extra=""
  [ "$mt" != null ] && [ -n "$mt" ] && extra="${extra}model: $(cc_model "$mt")\n"
  [ "$ef" != null ] && [ -n "$ef" ] && extra="${extra}effort: $ef\n"
  { printf -- '---\nname: %s\ndescription: %s\ntools: %s\n%b---\n\n' "$p" "$desc" "$(cc_tools "$p")" "$extra"; body "$bsrc"; } > "$PLUGIN_ROOT/agents/$p.md"
  echo "  agent  -> agents/$p.md   (tools: $(cc_tools "$p"), model: $(cc_model "$mt"), effort: ${ef})"
done

# 2) hooks/hooks.json — auto-registered when the plugin is enabled. Paths use
#    ${CLAUDE_PLUGIN_ROOT} so they are machine-independent. H stays literal
#    (single-quoted) so the token survives into the emitted JSON.
mkdir -p "$PLUGIN_ROOT/hooks"
H='${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/runtime/hooks'
cat > "$PLUGIN_ROOT/hooks/hooks.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read|Bash", "hooks": [
        { "type": "command", "command": "$H/deny-heldout-read.sh" },
        { "type": "command", "command": "$H/keep-on-branch.sh" },
        { "type": "command", "command": "$H/gate-prod-apply.sh" },
        { "type": "command", "command": "$H/run-scope.sh" },
        { "type": "command", "command": "$H/guard-shared-checkout.sh" },
        { "type": "command", "command": "$H/guard-done.sh" } ] },
      { "matcher": "Write|Edit", "hooks": [
        { "type": "command", "command": "$H/write-scope.sh" } ] },
      { "matcher": "Task|Agent", "hooks": [
        { "type": "command", "command": "$H/on-writer-dispatch.sh" } ] } ],
    "SessionStart": [ { "matcher": "compact", "hooks": [
        { "type": "command", "command": "$H/on-compaction.sh" } ] } ]
  }
}
JSON
echo "  hooks  -> hooks/hooks.json"
echo "build complete (agents/ + hooks/hooks.json regenerated from agents.yaml)"
