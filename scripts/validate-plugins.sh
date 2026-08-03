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
  # The validator does not follow directory symlinks, so symlinked components
  # (e.g. skills linked from the repo-root libraries) are silently skipped.
  # Validate a dereferenced copy — the same layout the install cache gets.
  if find "$p" -type l | grep -q .; then
    tmp=$(mktemp -d)
    cp -RL "$p" "$tmp/plugin"
    echo "== ${p%/} (dereferenced)"
    claude plugin validate --strict "$tmp/plugin" || fail=1
    rm -rf "$tmp"
  fi
done
exit "$fail"
