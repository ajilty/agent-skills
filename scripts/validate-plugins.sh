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
  # The validator does not follow directory symlinks: for a plugin with
  # symlinked components (e.g. skills linked from the repo-root libraries) the
  # in-place pass only *warns* that it skipped them — which --strict treats as
  # an error — without reading them, so it adds no coverage. Validate the
  # dereferenced copy instead (the same layout the install cache gets), which
  # reads the real files strictly. Plugins without symlinks are validated in
  # place.
  if find "$p" -type l | grep -q .; then
    tmp=$(mktemp -d)
    cp -RL "$p" "$tmp/plugin"
    echo "== ${p%/} (dereferenced)"
    claude plugin validate --strict "$tmp/plugin" || fail=1
    rm -rf "$tmp"
  else
    claude plugin validate --strict "$p" || fail=1
  fi
done
exit "$fail"
