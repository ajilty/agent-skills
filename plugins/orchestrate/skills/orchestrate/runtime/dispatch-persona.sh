#!/usr/bin/env bash
# dispatch-persona.sh <persona> <ticket_dir> [<repo_root>]   (Codex only; ADR-0017)
#
# Codex's PreToolUse hooks do NOT fire inside an in-session `spawn_agent` subagent, and
# `spawn_agent` shares the session sandbox with no per-agent knob — so a spawned read-only
# persona is NOT lane-confined (it can write source in workspace-write). This launcher
# closes that gap: it runs the persona as its OWN top-level `codex exec` whose cwd is the
# persona's result subtree. Under `workspace-write` the OS sandbox confines writes to the
# cwd subtree, so source/prod/other-lane writes are refused at the syscall (sub-spawn-proof),
# AND the main-agent PreToolUse floor fires on top (defense-in-depth + finer lane checks).
#
# Contract: the TASK is read from STDIN; the persona body (its standing instructions) is
# injected from orchestrate-runtime/personas/<persona>.md. The persona writes its result to
# disk as its final action (ADR-0014); the router reads it from the known result path. The
# persona's own stdout is also forwarded. Per-persona model/effort come from agents/<p>.toml.
set -euo pipefail
persona="${1:?usage: dispatch-persona.sh <persona> <ticket_dir> [repo_root]}"
ticket_dir="${2:?ticket_dir}"; repo_root="${3:-$PWD}"
RT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"          # .../orchestrate-runtime
agents_dir="$(cd "$RT/../agents" 2>/dev/null && pwd || true)"  # sibling agents/ (model/effort)

# persona -> (cwd that bounds its OS-writable subtree, sandbox mode)
case "$persona" in
  researcher)  cwd="$ticket_dir/findings/_quarantine"; sb=workspace-write ;;
  verifier)    cwd="$ticket_dir/verdicts";             sb=workspace-write ;;
  planner)     cwd="$ticket_dir";                      sb=workspace-write ;;   # spec/ADR kept under the ticket dir
  implementer) cwd="$repo_root";                       sb=workspace-write ;;   # the writer: source is its lane
  actuator)    cwd="$repo_root";                       sb=read-only        ;;  # mutates live state via run, not files
  *) echo "dispatch-persona: unknown persona '$persona'" >&2; exit 64 ;;
esac
mkdir -p "$cwd"

# Per-persona tier from the compiled role (single-line keys, installer-controlled format).
margs=()
if [ -n "$agents_dir" ] && [ -f "$agents_dir/$persona.toml" ]; then
  m="$(sed -n 's/^model = "\(.*\)"/\1/p' "$agents_dir/$persona.toml" | head -1)"
  e="$(sed -n 's/^model_reasoning_effort = "\(.*\)"/\1/p' "$agents_dir/$persona.toml" | head -1)"
  [ -n "$m" ] && margs+=(-m "$m")
  [ -n "$e" ] && margs+=(-c "model_reasoning_effort=\"$e\"")
fi

body="$(cat "$RT/personas/$persona.md" 2>/dev/null || true)"
task="$(cat)"   # the dispatch task, on stdin
prompt="$body

# Execution context (Codex, ADR-0017)
- Repository root (readable): $repo_root
- Your writes are OS-confined to this subtree: $cwd
- Write your result here as your final action (the router reads it from disk).

# Task
$task"

# PERSONA/CODEX_AGENT let the hook floor identify the persona (no agent_type on a top-level run).
PERSONA="$persona" CODEX_AGENT="$persona" exec codex exec \
  -s "$sb" --cd "$cwd" --skip-git-repo-check "${margs[@]}" - <<<"$prompt"
