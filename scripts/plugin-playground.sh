#!/usr/bin/env bash
# One-command plugin test ground: creates a fresh git-initialized playground
# under ~/tmp and launches Claude Code with the named plugin loaded from this
# repo checkout (works from the main checkout or any worktree).
# Usage: scripts/plugin-playground.sh [-e] <plugin> [name]
#   -e  open the playground in VS Code instead of launching Claude here;
#       run ./play in its integrated terminal (IDE integration only attaches
#       when claude starts inside the editor's terminal)
set -euo pipefail
editor=0
if [ "${1:-}" = "-e" ]; then
  editor=1
  shift
fi
repo="$(cd "$(dirname "$0")/.." && pwd)"
plugin="${1:-}"
if [ -z "$plugin" ] || [ ! -d "$repo/plugins/$plugin" ]; then
  echo "usage: scripts/plugin-playground.sh [-e] <plugin> [name]" >&2
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
printf '#!/usr/bin/env bash\nexec claude --plugin-dir "%s"\n' "$repo/plugins/$plugin" > play
chmod +x play
echo "play" > .git/info/exclude
echo "playground: $dir"
echo "plugin:     $repo/plugins/$plugin"
if [ "$editor" -eq 1 ]; then
  code "$dir"
  echo "opened in VS Code; run ./play in its integrated terminal"
  exit 0
fi
exec ./play
