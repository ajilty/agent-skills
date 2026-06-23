#!/usr/bin/env bash
# Integration suite runner — exercises the real `claude` CLI + live agent sessions.
# Separate from the zero-dep tests/run.sh (which is the per-push gate). Run locally
# or in a gated CI job. Tests self-skip when `claude`/auth is unavailable, so this
# never hard-fails for missing prerequisites — it reports skips.
#   bash tests/integration/run.sh
set -uo pipefail
INT_HERE="$(cd "$(dirname "$0")" && pwd)"
export INT_HERE
. "$INT_HERE/lib.sh"
for t in "$INT_HERE"/test_*.sh; do [ -e "$t" ] || continue; echo "== $t"; . "$t"; done
printf 'PASS=%s FAIL=%s SKIP=%s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" = 0 ]
