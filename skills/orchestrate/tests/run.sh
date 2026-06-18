#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
for t in "$HERE"/test_*.sh; do [ -e "$t" ] || continue; echo "== $t"; . "$t"; done
printf 'PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
