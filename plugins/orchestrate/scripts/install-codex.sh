#!/usr/bin/env bash
# install-codex.sh — compile the portable orchestrate skill into Codex CLI.
#   ./install-codex.sh [--scope user|project] [--dir <path>]
#   user (default): ~/.codex (or $CODEX_HOME)    project: ./.codex
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/orchestrate" && pwd)"
AGENTS="$SKILL_DIR/references/agents.yaml"
WEB_MCP="${ORCHESTRATE_WEB_MCP:-web}"
SCOPE=user; OVERRIDE=""
while [ $# -gt 0 ]; do case "$1" in
  --scope) SCOPE="${2:?}"; shift 2 ;;
  --dir)   OVERRIDE="${2:?}"; shift 2 ;;
  *) echo "usage: $0 [--scope user|project] [--dir <path>]" >&2; exit 64 ;;
esac; done

case "$SCOPE" in
  user)    DEST="${OVERRIDE:-${CODEX_HOME:-$HOME/.codex}}"; BRAIN_DIR="$DEST" ;;
  project) DEST="${OVERRIDE:-$PWD/.codex}"; BRAIN_DIR="${OVERRIDE:-$PWD}" ;;   # honor --dir (don't pollute repo root on smoke installs)
  *) echo "scope must be user|project" >&2; exit 64 ;;
esac
command -v yq >/dev/null || { echo "FATAL: yq (v4, mikefarah) required." >&2; exit 1; }

AGENTS_DEST="$DEST/agents"; HOOKS="$DEST/orchestrate-runtime/hooks"

codex_sandbox() { local p="$1" w r; w="$(yq ".personas.$p.capabilities.write" "$AGENTS")"; r="$(yq ".personas.$p.capabilities.run" "$AGENTS")"
  if [ "$w" = none ] && [ "$r" = none ]; then echo read-only; else echo workspace-write; fi; }
body() { awk 'f==2{print} /^---[[:space:]]*$/{f++}' "$1"; }

mkdir -p "$AGENTS_DEST" "$DEST/orchestrate-runtime"
cp -r "$SKILL_DIR/runtime/." "$DEST/orchestrate-runtime/"
chmod +x "$DEST"/orchestrate-runtime/*.sh "$DEST"/orchestrate-runtime/hooks/*.sh
{ echo "<!-- orchestrate router brain (generated) -->"; cat "$SKILL_DIR/SKILL.md"; } > "$BRAIN_DIR/AGENTS.orchestrate.md"

for p in $(yq '.personas | keys | .[]' "$AGENTS"); do
  desc="$(yq ".personas.$p.description" "$AGENTS")"; sandbox="$(codex_sandbox "$p")"
  web="$(yq ".personas.$p.capabilities.web" "$AGENTS")"; bsrc="$SKILL_DIR/references/$(yq ".personas.$p.body" "$AGENTS")"
  [ "$web" = true ] && mcp="mcp_servers = [\"$WEB_MCP\"]" || mcp="mcp_servers = []"
  { printf 'name = "%s"\n' "$p"; printf 'description = "%s"\n' "${desc//\"/\\\"}"
    printf 'sandbox_mode = "%s"\n%s\ninstructions = """\n' "$sandbox" "$mcp"; body "$bsrc"; printf '"""\n'
  } > "$AGENTS_DEST/$p.toml"
  echo "  subagent -> $AGENTS_DEST/$p.toml   (sandbox: $sandbox, web: $web)"
done

cat <<EOF

Codex install complete ($SCOPE scope).
  subagents -> $AGENTS_DEST/{...}.toml
  runtime   -> $DEST/orchestrate-runtime/ (ledger.sh + hooks)
  brain     -> $BRAIN_DIR/AGENTS.orchestrate.md  (include into AGENTS.md)

Add to ${DEST}/config.toml (or project .codex/config.toml):
  [[hooks.PreToolUse]]
  matcher = "^(Read|Bash)\$"
  [[hooks.PreToolUse.hooks]]
  type = "command"; command = "$HOOKS/deny-heldout-read.sh"
  [[hooks.PreToolUse.hooks]]
  type = "command"; command = "$HOOKS/keep-on-branch.sh"
  [[hooks.PreToolUse.hooks]]
  type = "command"; command = "$HOOKS/gate-prod-apply.sh"   # pre-apply gate hard floor (PreToolUse blocks; SubagentStart does not)

  # Write-ahead for both writers (deterministic ledger + lease; the gate's ledger half lives inside it):
  [[hooks.SubagentStart]]
  matcher = "implementer|actuator"
  [[hooks.SubagentStart.hooks]]
  type = "command"; command = "$HOOKS/on-writer-dispatch.sh"

  # Automatic compaction recovery (hands-off):
  [[hooks.PostCompact]]
  [[hooks.PostCompact.hooks]]
  type = "command"; command = "$HOOKS/on-compaction.sh"

Actuator credential confinement is ADVISORY (ADR-0002): scope the actuator lane's
creds to its leased targets in your deployment; serialization (the lease) is the
only guaranteed layer — the skill cannot enforce "no creds for an unleased target".

No config file. Set ORCHESTRATE_WEB_MCP to your web/doc MCP (default "$WEB_MCP")
and HELDOUT_ROOT, then run /orchestrate to start or resume. Compaction recovers
automatically via PostCompact. Codex spawns subagents only on explicit request;
agents.max_depth defaults to 1. Ledger: .agents/runs/orchestrate/board.jsonl.
EOF
