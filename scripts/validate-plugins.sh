#!/usr/bin/env bash
# Validate the marketplace manifest and every plugin under plugins/.
# Runs locally and in CI; requires the Claude Code CLI (`claude`) on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
echo "== marketplace"
claude plugin validate --strict .claude-plugin/marketplace.json || fail=1
for p in plugins/*/; do
  echo "== ${p%/}"
  claude plugin validate --strict "$p" || fail=1
done
exit "$fail"
