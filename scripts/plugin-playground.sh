#!/usr/bin/env bash
# One-command plugin test ground: creates a fresh git-initialized playground
# under ~/tmp and launches Claude Code with the named plugin loaded from this
# repo checkout (works from the main checkout or any worktree).
# Usage: scripts/plugin-playground.sh <plugin> [name]
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
plugin="${1:-}"
if [ -z "$plugin" ] || [ ! -d "$repo/plugins/$plugin" ]; then
  echo "usage: scripts/plugin-playground.sh <plugin> [name]" >&2
  echo "available plugins:" >&2
  ls -1 "$repo/plugins" >&2
  exit 1
fi
name="${2:-$(date +%m%d-%H%M%S)}"
dir="$HOME/tmp/${plugin}-play-$name"
if [ -e "$dir" ]; then
  echo "refusing: $dir already exists (pick another name or remove it)" >&2
  exit 1
fi
mkdir -p "$dir"
cd "$dir"
git init -q
echo "playground: $dir"
echo "plugin:     $repo/plugins/$plugin"
exec claude --plugin-dir "$repo/plugins/$plugin"
