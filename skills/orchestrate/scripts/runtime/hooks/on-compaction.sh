#!/usr/bin/env bash
# on-compaction.sh — AUTOMATIC post-compaction recovery (hands-off).
# Wired to the harness's post-compaction event (CC SessionStart[compact],
# Codex PostCompact, OpenCode plugin compaction event). It does NOT just point at
# the ledger — it reconstructs the board and injects it as authoritative state,
# because post-compaction "go re-read X" injection is unreliable.
set -euo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
echo "=================================================================="
echo "ORCHESTRATE: context was compacted. The board below is AUTHORITATIVE."
echo "Treat it as ground truth over anything summarized. Before any dispatch:"
echo "  - resume open lanes per the reconciliation,"
echo "  - if it says HALT, stop and ask the operator,"
echo "  - retry budgets are counted from disk, not memory (ledger.sh retries)."
echo "------------------------------------------------------------------"
if ! bash "$RT/ledger.sh" reground; then
  echo "------------------------------------------------------------------"
  echo "HALT: ambiguous in-flight writer after compaction. Do not dispatch;"
  echo "the operator should re-attach and reconcile the worktree."
  exit 2
fi
echo "=================================================================="
