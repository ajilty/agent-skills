#!/usr/bin/env bash
# SessionStart(compact) / PostCompact: AUTOMATIC post-compaction recovery — inject
# the reconstructed board as authoritative context.
#
# Claude Code SessionStart contract: emit
#   {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
# (plain decision JSON is rejected). Build the text, JSON-encode it with jq, exit 0.
# Never aborts. (Codex/OpenCode wire this to their own compaction event; the plain
# fallback below covers the no-jq case.)
set -uo pipefail
RT="$(cd "$(dirname "$0")/.." && pwd)"
board="$(bash "$RT/ledger.sh" reground 2>&1)"; rc=$?
msg="ORCHESTRATE: context was compacted. The board below is AUTHORITATIVE — treat it
as ground truth over anything summarized. Resume open lanes per the reconciliation;
retry budgets are counted from disk (ledger.sh retries <ticket>), not memory.

$board"
[ "$rc" != 0 ] && msg="$msg

HALT: ambiguous in-flight writer after compaction. Do NOT dispatch — re-attach and
reconcile the worktree before continuing."
if command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
else
  printf '%s\n' "$msg"
fi
exit 0
