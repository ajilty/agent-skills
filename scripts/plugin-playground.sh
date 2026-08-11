#!/usr/bin/env bash
# One-command plugin test ground: creates a fresh git-initialized playground
# under ~/tmp and launches Claude Code with the named plugin loaded. The
# plugin is either a name from this repo's plugins/ directory or a path to
# any plugin directory (works from the main checkout or any worktree).
# Usage: scripts/plugin-playground.sh [-e] <plugin-name-or-path> [name]
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
if [ -n "$plugin" ] && [ -d "$repo/plugins/$plugin" ]; then
  plugdir="$repo/plugins/$plugin"
elif [ -n "$plugin" ] && [ -d "$plugin" ]; then
  plugdir="$(cd "$plugin" && pwd)"
  plugin="$(basename "$plugdir")"
else
  echo "usage: scripts/plugin-playground.sh [-e] <plugin-name-or-path> [name]" >&2
  echo "plugins in this repo:" >&2
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
printf '#!/usr/bin/env bash\nexec claude --plugin-dir "%s"\n' "$plugdir" > play
chmod +x play
echo "play" > .git/info/exclude
echo "playground: $dir"
echo "plugin:     $plugdir"
if [ "$editor" -eq 1 ]; then
  code "$dir"
  echo "opened in VS Code; run ./play in its integrated terminal"
  exit 0
fi
exec ./play
