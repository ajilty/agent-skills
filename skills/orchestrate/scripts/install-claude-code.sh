#!/usr/bin/env bash
# install-claude-code.sh — compile the portable orchestrate skill into Claude Code.
#   ./install-claude-code.sh [--scope user|project] [--dir <path>]
#   user (default): ~/.claude (or $CLAUDE_CONFIG_DIR)   project: ./.claude
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS="$SKILL_DIR/references/agents.yaml"
SCOPE=user; OVERRIDE=""
while [ $# -gt 0 ]; do case "$1" in
  --scope) SCOPE="${2:?}"; shift 2 ;;
  --dir)   OVERRIDE="${2:?}"; shift 2 ;;
  *) echo "usage: $0 [--scope user|project] [--dir <path>]" >&2; exit 64 ;;
esac; done

case "$SCOPE" in
  user)    DEST="${OVERRIDE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}" ;;
  project) DEST="${OVERRIDE:-$PWD/.claude}" ;;
  *) echo "scope must be user|project" >&2; exit 64 ;;
esac
command -v yq >/dev/null || { echo "FATAL: yq (v4, mikefarah) required." >&2; exit 1; }

SKILLS_DEST="$DEST/skills/orchestrate"; AGENTS_DEST="$DEST/agents"
HOOKS="$SKILLS_DEST/runtime/hooks"

cc_tools() { local p="$1" t=()
  [ "$(yq ".personas.$p.capabilities.read" "$AGENTS")" = true ] && t+=(Read Grep Glob)
  [ "$(yq ".personas.$p.capabilities.web"  "$AGENTS")" = true ] && t+=(WebSearch WebFetch)
  case "$(yq ".personas.$p.capabilities.write" "$AGENTS")" in full) t+=(Write Edit);; spec-only) t+=(Write);; esac
  case "$(yq ".personas.$p.capabilities.run" "$AGENTS")" in full|tests-only) t+=(Bash);; esac
  ( IFS=, ; echo "${t[*]}" ); }
body() { awk 'f==2{print} /^---[[:space:]]*$/{f++}' "$1"; }

mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"
cp "$SKILL_DIR/SKILL.md" "$SKILLS_DEST/SKILL.md"
cp -r "$SKILL_DIR/references" "$SKILLS_DEST/"
cp -r "$SKILL_DIR/scripts/runtime" "$SKILLS_DEST/"      # ledger + hooks travel with the skill
chmod +x "$SKILLS_DEST"/runtime/*.sh "$SKILLS_DEST"/runtime/hooks/*.sh
mkdir -p "$DEST/commands"                               # /orchestrate slash-command entry point (thin wrapper; brain stays in SKILL.md)
cp "$SKILL_DIR/commands/orchestrate.md" "$DEST/commands/orchestrate.md"

for p in $(yq '.personas | keys | .[]' "$AGENTS"); do
  desc="$(yq ".personas.$p.description" "$AGENTS")"
  bsrc="$SKILL_DIR/references/$(yq ".personas.$p.body" "$AGENTS")"
  { printf -- '---\nname: %s\ndescription: %s\ntools: %s\n---\n\n' "$p" "$desc" "$(cc_tools "$p")"; body "$bsrc"; } > "$AGENTS_DEST/$p.md"
  echo "  subagent -> $AGENTS_DEST/$p.md   (tools: $(cc_tools "$p"))"
done

cat <<EOF

Claude Code install complete ($SCOPE scope).
  skill     -> $SKILLS_DEST/SKILL.md
  subagents -> $AGENTS_DEST/{researcher,planner,implementer,verifier,actuator}.md
  runtime   -> $SKILLS_DEST/runtime/ (ledger.sh + adr.sh + enforcement & lifecycle hooks)
  command   -> $DEST/commands/orchestrate.md   (type /orchestrate <goal>, or /orchestrate to resume)

Add to $DEST/settings.json (two enforcement hooks + write-ahead + compaction recovery):
  "hooks": {
    "PreToolUse": [ { "matcher": "Read|Bash", "hooks": [
        { "type": "command", "command": "$HOOKS/deny-heldout-read.sh" },
        { "type": "command", "command": "$HOOKS/keep-on-branch.sh" },
        { "type": "command", "command": "$HOOKS/gate-prod-apply.sh" } ] } ],
    "SubagentStart": [ { "matcher": "implementer|actuator", "hooks": [
        { "type": "command", "command": "$HOOKS/on-writer-dispatch.sh" } ] } ],
    "SessionStart": [ { "matcher": "compact", "hooks": [
        { "type": "command", "command": "$HOOKS/on-compaction.sh" } ] } ]
  }

Actuator credential confinement is ADVISORY (ADR-0002): scope the actuator lane's
creds to its leased targets in your deployment; serialization (the lease) is the
only guaranteed layer — the skill cannot enforce "no creds for an unleased target".

No config file. Export HELDOUT_ROOT, then run /orchestrate in a repo to start or
to resume an interrupted session. Compaction recovers automatically (the
SessionStart[compact] hook regrounds). The board ledger lives per-repo at
.agents/runs/orchestrate/board.jsonl.
EOF
