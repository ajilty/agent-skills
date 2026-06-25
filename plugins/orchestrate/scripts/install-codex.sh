#!/usr/bin/env bash
# install-codex.sh — compile the portable orchestrate skill into Codex CLI.
#   ./install-codex.sh [--scope user|project] [--dir <path>]
#   user (default): ~/.codex (or $CODEX_HOME)    project: ./.codex
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/orchestrate" && pwd)"
AGENTS="$SKILL_DIR/references/agents.yaml"
# Web is BUILT IN to codex 0.142.1 (native Responses `web_search`, on by default).
# ORCHESTRATE_WEB_MCP is an ESCAPE HATCH only: set it to wire a custom web/doc MCP
# server name into the researcher role instead of using the built-in tool.
WEB_MCP="${ORCHESTRATE_WEB_MCP:-}"
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
# agents.yaml tier -> codex 0.142.1 model id.  economy->mini, standard->5.4, premium->frontier.
codex_model() { case "$1" in
  economy)  echo gpt-5.4-mini ;;
  standard) echo gpt-5.4 ;;
  premium)  echo gpt-5.5 ;;
  *)        echo "" ;;   # unknown/empty tier -> omit model line (inherit session default)
esac; }
# agents.yaml effort -> codex model_reasoning_effort enum (low|medium|high|xhigh ONLY).
# `max` is NOT a valid codex value (API rejects it) -> map to the real ceiling, xhigh.
codex_effort() { case "$1" in
  low|medium|high|xhigh) echo "$1" ;;
  max)                   echo xhigh ;;
  *)                     echo "" ;;   # unknown/empty -> omit (inherit)
esac; }
body() { awk 'f==2{print} /^---[[:space:]]*$/{f++}' "$1"; }

mkdir -p "$AGENTS_DEST" "$DEST/orchestrate-runtime"
cp -r "$SKILL_DIR/runtime/." "$DEST/orchestrate-runtime/"
chmod +x "$DEST"/orchestrate-runtime/*.sh "$DEST"/orchestrate-runtime/hooks/*.sh
{ echo "<!-- orchestrate router brain (generated) -->"; cat "$SKILL_DIR/SKILL.md"; } > "$BRAIN_DIR/AGENTS.orchestrate.md"

for p in $(yq '.personas | keys | .[]' "$AGENTS"); do
  desc="$(yq ".personas.$p.description" "$AGENTS")"; sandbox="$(codex_sandbox "$p")"
  web="$(yq ".personas.$p.capabilities.web" "$AGENTS")"; bsrc="$SKILL_DIR/references/$(yq ".personas.$p.body" "$AGENTS")"
  model="$(codex_model "$(yq ".personas.$p.tier.model" "$AGENTS")")"
  effort="$(codex_effort "$(yq ".personas.$p.tier.effort" "$AGENTS")")"
  {
    printf 'name = "%s"\n' "$p"
    printf 'description = "%s"\n' "${desc//\"/\\\"}"
    printf 'sandbox_mode = "%s"\n' "$sandbox"
    [ -n "$model" ]  && printf 'model = "%s"\n' "$model"                       # tier -> model id
    [ -n "$effort" ] && printf 'model_reasoning_effort = "%s"\n' "$effort"     # tier -> reasoning effort (low|medium|high|xhigh)
    # Persona body goes in developer_instructions (NOT `instructions`). Emit ALL
    # root-level keys (incl. this one) BEFORE any [table] header below, or the table
    # would capture them.
    printf 'developer_instructions = """\n'; body "$bsrc"; printf '"""\n'
    # Web: the built-in `web_search` tool is on by default (enabled at config level,
    # not per-role — see config block below). ORCHESTRATE_WEB_MCP escape hatch: if set,
    # wire that MCP server name for the researcher instead. (mcp_servers is a MAP table,
    # [mcp_servers.<name>], so the OLD `mcp_servers = ["web"]` sequence is GONE — it tripped
    # --strict-config with "invalid type: sequence, expected a map".) Table header LAST.
    if [ "$web" = true ] && [ -n "$WEB_MCP" ]; then
      printf '[mcp_servers.%s]\n# command/args for your web/doc MCP go here (escape hatch; built-in web_search is the default).\n' "$WEB_MCP"
    fi
  } > "$AGENTS_DEST/$p.toml"
  echo "  subagent -> $AGENTS_DEST/$p.toml   (sandbox: $sandbox, model: ${model:-default}, effort: ${effort:-default}, web: $web)"
done

cat <<EOF

Codex install complete ($SCOPE scope).
  subagents -> $AGENTS_DEST/{...}.toml
  runtime   -> $DEST/orchestrate-runtime/ (ledger.sh + hooks)
  brain     -> $BRAIN_DIR/AGENTS.orchestrate.md  (include into AGENTS.md)

Add to ${DEST}/config.toml (or project .codex/config.toml):

  # Hooks must be turned ON as a feature, or every [[hooks.*]] table below is inert.
  [features]
  hooks = true
  # Web search is BUILT IN and ON by default in codex 0.142.1; nothing to wire.
  # Uncomment ONLY to override the default mode (live|indexed|cached|disabled):
  #   web_search = "live"   # top-level, or under a [profiles.<name>]; per-role web_search is ignored.

  # NOTE on event names: the config TABLE names are PascalCase here
  # ([[hooks.PreToolUse]], SubagentStart, PostCompact). The wire \`hook_event_name\`
  # codex emits to the hook is also PascalCase. (Codex 0.142.1 has no snake_case
  # config table for these — unlike some harnesses. SubagentStart / PostCompact /
  # PreCompact are REAL events in this build, not stale.)

  [[hooks.PreToolUse]]
  matcher = "^(Read|Edit|Write|Bash)\$"
  [[hooks.PreToolUse.hooks]]
  type = "command"
  command = "$HOOKS/deny-heldout-read.sh"
  [[hooks.PreToolUse.hooks]]
  type = "command"
  command = "$HOOKS/keep-on-branch.sh"
  [[hooks.PreToolUse.hooks]]
  type = "command"
  command = "$HOOKS/guard-shared-checkout.sh"   # universal git-safety floor: refuse history-discarding ops on the PRIMARY shared checkout
  [[hooks.PreToolUse.hooks]]
  type = "command"
  command = "$HOOKS/guard-done.sh"               # done-gate hard floor: no \`done\` event without a Verifier verdict on the board
  [[hooks.PreToolUse.hooks]]
  type = "command"
  command = "$HOOKS/gate-prod-apply.sh"          # pre-apply gate hard floor (PreToolUse blocks; SubagentStart does not)
  [[hooks.PreToolUse.hooks]]
  type = "command"
  command = "$HOOKS/write-scope.sh"              # planner spec/ADR + researcher findings_quarantine + verifier verdicts confinement (self-guards; Write|Edit; ADR-0014)
  [[hooks.PreToolUse.hooks]]
  type = "command"
  command = "$HOOKS/run-scope.sh"                # verifier tests-only: deny workspace/git-mutating Bash (self-guards)

  # Write-ahead for both writers (deterministic ledger + lease; the gate's ledger half lives inside it):
  [[hooks.SubagentStart]]
  matcher = "implementer|actuator"
  [[hooks.SubagentStart.hooks]]
  type = "command"
  command = "$HOOKS/on-writer-dispatch.sh"

  # Automatic compaction recovery (hands-off):
  [[hooks.PostCompact]]
  [[hooks.PostCompact.hooks]]
  type = "command"
  command = "$HOOKS/on-compaction.sh"

>>> HOOK TRUST (READ THIS — fail-OPEN risk) <<<
A wired hook SILENTLY NO-OPS unless codex trusts it. These hooks are the fail-closed
security floor (held-out reads, branch guard, prod-apply gate, done-gate); a silent
no-op disarms them. Two ways to make them fire:
  1. Interactive: run codex once in the TUI and APPROVE the hooks when prompted —
     codex persists the trust (a per-hook \`trusted_hash\` under [hooks.state]) itself.
     This is the robust path; let codex compute the hash.
  2. Headless / CI: pass --dangerously-bypass-hook-trust to \`codex exec\`, e.g.
       codex exec --dangerously-bypass-hook-trust [PROMPT]
     This runs ALL enabled hooks without the persisted-trust check FOR THAT INVOCATION.
TRADEOFF: this installer does NOT pre-seed [hooks.state] trusted_hash entries. The
hash format is internal and version-coupled; a wrong/stale hash would fail OPEN
(silent no-op) — the exact catastrophe these hooks guard against. Letting codex hash
the trust (path 1) or explicitly bypassing per-run (path 2) is safer than shipping a
guessed hash. Pick path 1 for a workstation, path 2 only for vetted automation.

Actuator credential confinement is ADVISORY (ADR-0002): scope the actuator lane's
creds to its leased targets in your deployment; serialization (the lease) is the
only guaranteed layer — the skill cannot enforce "no creds for an unleased target".

No config file. Web is built in (web_search, on by default); set ORCHESTRATE_WEB_MCP
ONLY to wire a custom web/doc MCP as an escape hatch. Set HELDOUT_ROOT, then run
/orchestrate to start or resume. Compaction recovers automatically via PostCompact.
Codex spawns subagents only on explicit request; agents.max_depth defaults to 1.
Ledger: .agents/runs/orchestrate/board.jsonl.
EOF
