#!/usr/bin/env bash
# manager-brief suite: the output style's frontmatter parses as strict YAML
# and carries the fields the plugin's behavior depends on.
set -euo pipefail
cd "$(dirname "$0")/.."

style=output-styles/manager-brief.md
yq --front-matter=extract -e '.name == "Manager brief"' "$style" >/dev/null
yq --front-matter=extract -e '.description | length > 0' "$style" >/dev/null
yq --front-matter=extract -e '.["keep-coding-instructions"] == true' "$style" >/dev/null
# force-for-plugin must stay absent: installing the plugin must never switch
# the user's session to this style.
yq --front-matter=extract -e 'has("force-for-plugin") | not' "$style" >/dev/null
echo "manager-brief: ok"
