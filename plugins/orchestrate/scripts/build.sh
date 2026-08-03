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
# Terminal accent for the subagent, Claude Code's `color:` frontmatter field. Presentation
# only — it grants nothing and subtracts nothing — so it lives HERE in the CC generator, not
# in agents.yaml: `color` is one harness's vocabulary (Codex/OpenCode agent frontmatter has
# no equivalent) and the contract stays free of it (ADR-0007).
#
# The accent is a COST HEAT read straight off the tier, so a fan-out board shows at a glance
# where the spend is going: cold = cheap, hot = expensive. Derived, never hand-assigned —
# retune a tier in agents.yaml and the color follows, so it cannot drift into a lie. Model
# tier is the dominant cost term; extended thinking (xhigh|max) bumps one rung because the
# reasoning tokens it buys are billed as output.
#   cyan   economy                        researcher
#   green  standard                       implementer, actuator
#   yellow premium                        planner
#   red    premium + extended thinking    verifier   <- the priciest dispatch in the system
# Same tier -> same color BY DESIGN: two personas that cost the same should look the same.
cc_color() { local c
  case "$1" in economy) c=1;; standard) c=2;; premium) c=3;; *) echo ""; return;; esac
  case "$2" in xhigh|max) c=$((c+1));; esac
  case "$c" in 1) echo cyan;; 2) echo green;; 3) echo yellow;; *) echo red;; esac; }

# 1) agents/<persona>.md — frontmatter (name/description/tools) + persona body
mkdir -p "$PLUGIN_ROOT/agents"
for p in $(yq '.personas | keys | .[]' "$AGENTS"); do
  desc="$(yq ".personas.$p.description" "$AGENTS")"
  bsrc="$SKILL_DIR/references/$(yq ".personas.$p.body" "$AGENTS")"
  mt="$(yq ".personas.$p.tier.model" "$AGENTS")"; ef="$(yq ".personas.$p.tier.effort" "$AGENTS")"
  cl="$(cc_color "$mt" "$ef")"
  extra=""
  [ "$mt" != null ] && [ -n "$mt" ] && extra="${extra}model: $(cc_model "$mt")\n"
  [ "$ef" != null ] && [ -n "$ef" ] && extra="${extra}effort: $ef\n"
  [ -n "$cl" ] && extra="${extra}color: $cl\n"
  { printf -- '---\nname: %s\ndescription: %s\ntools: %s\n%b---\n\n' "$p" "$desc" "$(cc_tools "$p")" "$extra"; body "$bsrc"; } > "$PLUGIN_ROOT/agents/$p.md"
  echo "  agent  -> agents/$p.md   (tools: $(cc_tools "$p"), model: $(cc_model "$mt"), effort: ${ef}, color: ${cl:-none})"
done

# 2) hooks/hooks.json — auto-registered when the plugin is enabled. Paths use
#    ${CLAUDE_PLUGIN_ROOT} so they are machine-independent. H stays literal
#    (single-quoted) so the token survives into the emitted JSON.
#
#    The wiring is DERIVED from the contract's hooks: block (script + watch, in
#    document order) — never a hand-held list. CC maps the watch classes to native
#    matchers here: file-read+shell -> one "Read|Bash" group (scripts self-guard,
#    over-matching is safe and saves a group), file-write -> "Write|Edit",
#    dispatch -> "Task|Agent" (PreToolUse on the dispatch tool, ADR-0011),
#    post-compaction -> SessionStart(compact). warn-agent-teams is CC-ONLY
#    (ADR-0023 detects a CC-specific feature) so it is wired here, not contracted.
mkdir -p "$PLUGIN_ROOT/hooks"
H='${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/runtime/hooks'
hooks_watching() { # <class-regex> -> contract-ordered script names watching any matching class
  yq ".hooks[] | select([.watch[] | test(\"^($1)$\")] | any) | .script" "$AGENTS"; }
hook_entries() { # <script>... -> JSON entry lines; last line closes its group (no newline)
  local i=0 n=$# s
  for s in "$@"; do i=$((i+1))
    if [ "$i" -lt "$n" ]; then printf '        { "type": "command", "command": "%s/%s" },\n' "$H" "$s"
    else printf '        { "type": "command", "command": "%s/%s" } ] }' "$H" "$s"; fi
  done; }
RB=($(hooks_watching 'file-read|shell')); WE=($(hooks_watching 'file-write'))
DP=($(hooks_watching 'dispatch'));        PC=($(hooks_watching 'post-compaction'))
{
  printf '{\n  "hooks": {\n    "PreToolUse": [\n'
  printf '      { "matcher": "Read|Bash", "hooks": [\n';        hook_entries "${RB[@]}"; printf ',\n'
  printf '      { "matcher": "Write|Edit", "hooks": [\n';       hook_entries "${WE[@]}"; printf ',\n'
  printf '      { "matcher": "Task|Agent", "hooks": [\n';       hook_entries "${DP[@]}"; printf ' ],\n'
  printf '    "SessionStart": [\n'
  printf '      { "matcher": "compact", "hooks": [\n';          hook_entries "${PC[@]}"; printf ',\n'
  printf '      { "matcher": "startup|resume", "hooks": [\n';   hook_entries "warn-agent-teams.sh"; printf ' ]\n'
  printf '  }\n}\n'
} > "$PLUGIN_ROOT/hooks/hooks.json"
echo "  hooks  -> hooks/hooks.json (derived from agents.yaml hooks: block)"
echo "build complete (agents/ + hooks/hooks.json regenerated from agents.yaml)"
