#!/usr/bin/env bash
# shipyard harness-integration smoke, opt-in and NOT wired to CI: drives the
# real Claude Code CLI headlessly with the plugin loaded and asserts the
# invocation contract end-to-end. Needs an authenticated `claude` and spends
# model tokens; skips (exit 0) when the CLI or auth is unavailable so suites
# stay green without credentials. Recipe and rationale:
# docs/notes/2026-08-07-plugin-integration-testing.md.
set -euo pipefail
plugin="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not found"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/docs/shipyard/vuln-tracking-b"
cp "$plugin"/tests/fixtures/vuln-tracking-b/* "$tmp/docs/shipyard/vuln-tracking-b/"
cd "$tmp"

# Positive contract: explicit invocation works and the router reads the
# artifacts, reports position, and names the next segment.
if ! out=$(claude --plugin-dir "$plugin" -p "/shipyard:shipyard vuln-tracking-b" --max-turns 12 2>&1); then
  echo "SKIP: headless claude run failed (auth or environment)"
  exit 0
fi
if ! echo "$out" | grep -q '/shape'; then
  echo "FAIL: router did not name /shape as the next command. Output:"
  echo "$out"
  exit 1
fi

# Negative contract: disable-model-invocation removes every shipyard skill
# from the model-invocable set.
if ! neg=$(claude --plugin-dir "$plugin" -p "List the name of every skill you can invoke with the Skill tool right now, one per line. Just the list." --max-turns 4 2>&1); then
  echo "SKIP: negative-check run failed"
  exit 0
fi
for s in shipyard scope shape spec ship; do
  if echo "$neg" | grep -qE "(^|:)${s}\$"; then
    echo "FAIL: '$s' is model-invocable; disable-model-invocation not honored"
    exit 1
  fi
done

echo "shipyard integration: OK (router contract + explicit-only both hold)"
