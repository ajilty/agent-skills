#!/usr/bin/env bash
# One-command shipyard test ground: creates a fresh git-initialized
# playground under ~/tmp and launches Claude Code with the shipyard plugin
# loaded from this repo checkout (works from the main checkout or any
# worktree). Usage: scripts/shipyard-playground.sh [name]
set -euo pipefail
name="${1:-$(date +%m%d-%H%M%S)}"
dir="$HOME/tmp/shipyard-play-$name"
repo="$(cd "$(dirname "$0")/.." && pwd)"
if [ -e "$dir" ]; then
  echo "refusing: $dir already exists (pick another name or remove it)" >&2
  exit 1
fi
mkdir -p "$dir"
cd "$dir"
git init -q
echo "playground: $dir"
echo "plugin:     $repo/plugins/shipyard"
exec claude --plugin-dir "$repo/plugins/shipyard"
