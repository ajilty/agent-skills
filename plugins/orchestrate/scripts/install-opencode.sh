#!/usr/bin/env bash
# install-opencode.sh — compile the portable orchestrate skill into OpenCode.
#   ./install-opencode.sh [--scope user|project] [--dir <path>]
#   user (default): ~/.config/opencode    project: ./.opencode
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/orchestrate" && pwd)"
AGENTS="$SKILL_DIR/references/agents.yaml"
SCOPE=user; OVERRIDE=""
while [ $# -gt 0 ]; do case "$1" in
  --scope) SCOPE="${2:?}"; shift 2 ;;
  --dir)   OVERRIDE="${2:?}"; shift 2 ;;
  *) echo "usage: $0 [--scope user|project] [--dir <path>]" >&2; exit 64 ;;
esac; done

case "$SCOPE" in
  user)    DEST="${OVERRIDE:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"; BRAIN_DIR="$DEST" ;;
  project) DEST="${OVERRIDE:-$PWD/.opencode}"; BRAIN_DIR="${OVERRIDE:-$PWD}" ;;   # honor --dir (don't pollute repo root)
  *) echo "scope must be user|project" >&2; exit 64 ;;
esac
yq --version 2>/dev/null | grep -qE 'mikefarah|version v?4\.' || { echo "FATAL: yq (v4, mikefarah) required — the Python (kislyuk) yq emits JSON-quoted scalars and will not work." >&2; exit 1; }

AGENTS_DEST="$DEST/agent"; PLUGIN_DEST="$DEST/plugin"; RUNTIME="$DEST/orchestrate-runtime"

oc_tools() { local p="$1" read web write run rd=false gp=false gl=false wf=false wr=false ed=false bash=false
  read="$(yq ".personas.$p.capabilities.read" "$AGENTS")"; web="$(yq ".personas.$p.capabilities.web" "$AGENTS")"
  write="$(yq ".personas.$p.capabilities.write" "$AGENTS")"; run="$(yq ".personas.$p.capabilities.run" "$AGENTS")"
  [ "$read" = true ] && { rd=true; gp=true; gl=true; }; [ "$web" = true ] && wf=true
  case "$write" in full) wr=true; ed=true;; spec-only|results-only) wr=true;; esac   # results-only: scoped Write, no Edit (ADR-0014); write-scope hook confines the path
  case "$run" in full|tests-only) bash=true;; esac
  printf '  read: %s\n  grep: %s\n  glob: %s\n  webfetch: %s\n  write: %s\n  edit: %s\n  bash: %s\n' "$rd" "$gp" "$gl" "$wf" "$wr" "$ed" "$bash"; }
body() { awk 'f==2{print} /^---[[:space:]]*$/{f++}' "$1"; }

mkdir -p "$AGENTS_DEST" "$PLUGIN_DEST" "$RUNTIME"
cp -r "$SKILL_DIR/runtime/." "$RUNTIME/"
chmod +x "$RUNTIME"/*.sh "$RUNTIME"/hooks/*.sh
{ echo "<!-- orchestrate router brain (generated) -->"; cat "$SKILL_DIR/SKILL.md"; } > "$BRAIN_DIR/AGENTS.orchestrate.md"

for p in $(yq '.personas | keys | .[]' "$AGENTS"); do
  desc="$(yq ".personas.$p.description" "$AGENTS")"; bsrc="$SKILL_DIR/references/$(yq ".personas.$p.body" "$AGENTS")"
  { printf -- '---\ndescription: %s\nmode: subagent\ntools:\n' "$desc"; oc_tools "$p"; printf -- '---\n\n'; body "$bsrc"; } > "$AGENTS_DEST/$p.md"
  echo "  subagent -> $AGENTS_DEST/$p.md"
done

# Plugin: per-agent allow/deny is real subtraction; the plugin enforces path/branch
# scope AND drives the durable ledger by shelling out to the single-source runtime.
cat > "$PLUGIN_DEST/orchestrate.ts" <<TS
// orchestrate.ts — calls the shared runtime so policy stays single-source.
import { execFileSync } from "node:child_process";
const RT = "$RUNTIME";
// Runtime helpers (ledger.sh/adr.sh/worktree.sh) resolve by bare name in persona/router
// Bash; the plugin loads once at session start, so prepend the runtime dir to PATH here
// (ADR-0018). Confirm env propagates to the bash tool in your OpenCode version.
process.env.PATH = \`\${RT}:\${process.env.PATH ?? ""}\`;
const sh = (p: string) => { try { execFileSync("bash", [p], { stdio: "inherit" }); } catch (e) { throw e; } };
export const orchestrate = async () => ({
  "tool.execute.before": async (input: any) => {
    const tool = input?.tool ?? "";
    process.env.RESOLVED_PATH = String(input?.args?.path ?? input?.args?.filePath ?? "");
    process.env.TOOL_INPUT = String(input?.args?.command ?? "");
    if (["read","grep","glob"].includes(tool)) sh(\`\${RT}/hooks/deny-heldout-read.sh\`);
    if (tool === "bash") { sh(\`\${RT}/hooks/keep-on-branch.sh\`); sh(\`\${RT}/hooks/gate-prod-apply.sh\`); sh(\`\${RT}/hooks/run-scope.sh\`); }  // gate is the hard floor; run-scope confines verifier Bash
    if (tool === "write" || tool === "edit") sh(\`\${RT}/hooks/write-scope.sh\`);  // planner spec/ADR + researcher findings_quarantine + verifier verdicts confinement (self-guards, ADR-0014)
  },
  // Write-ahead for the writer (deterministic): runs before an implementer subagent.
  // The script self-guards on persona=implementer. Confirm the event name for your
  // OpenCode version; if subagent-start isn't exposed, the orchestrator does this in-loop.
  "subagent.start": async () => sh(\`\${RT}/hooks/on-writer-dispatch.sh\`),
  // Automatic compaction recovery: reground + inject authoritative board; halt if ambiguous.
  // Wire to your OpenCode compaction/session-restored event; session.start is the fallback.
  "session.start": async () => sh(\`\${RT}/hooks/on-compaction.sh\`),
});
TS
echo "  plugin   -> $PLUGIN_DEST/orchestrate.ts"

cat <<EOF

OpenCode install complete ($SCOPE scope).
  subagents -> $AGENTS_DEST/{...}.md   (per-agent allow/deny = real subtraction)
  plugin    -> $PLUGIN_DEST/orchestrate.ts   (auto-loads; calls the runtime)
  runtime   -> $RUNTIME/ (ledger.sh + hooks)
  brain     -> $BRAIN_DIR/AGENTS.orchestrate.md

Actuator credential confinement is ADVISORY (ADR-0002): scope the actuator lane's
creds to its leased targets in your deployment; serialization (the lease) is the
only guaranteed layer.

Set HELDOUT_ROOT and ASSIGNED_BRANCH in the env OpenCode runs under. No config
file — run /orchestrate to start or resume; compaction recovers via the plugin's
compaction hook. Confirm the hook names ("tool.execute.before" + your compaction
event) against your OpenCode version. Ledger: .agents/runs/orchestrate/board.jsonl.
EOF
