# guards

PostToolUse hook: after every `Edit`/`Write` of a `.json`, `.yaml`, or `.yml` file, parse it with `jq`/`yq`; for `.md` files, parse the YAML frontmatter block (the one machine-read region of a markdown file — fenced code snippets are illustrative prose and are never linted). On a syntax error the hook exits 2, which injects the parser's stderr back into the model's context as a blocking error — Claude sees the exact parse failure and fixes it in the same turn.

## Why not `git diff`-based validation

Validating "changed files" via `git diff --name-only` misses new untracked files (the primary `Write` case), scans unrelated dirty files on every edit, and breaks when the session cwd is not the repo root. This hook validates exactly the one file the tool just wrote, taken from the hook's stdin payload (`tool_input.file_path`), independent of git state.

## Behavior

| Case | Result |
|---|---|
| Valid JSON/YAML | Silent pass (exit 0) |
| Invalid JSON/YAML | Parser error fed back to Claude (exit 2) |
| Other extensions | Skipped |
| JSONC dialects (`tsconfig*.json`, `jsconfig*.json`, `.vscode/`, `devcontainer.json`) | Skipped — comments are legal there |
| `jq`/`yq` not installed | Silent pass (fail-open: lint assist, not a safety gate) |

## Dependencies

- `jq` (required for JSON and for reading the hook payload; without it the hook is a no-op)
- `yq` (optional; YAML checks are skipped without it — [mikefarah/yq](https://github.com/mikefarah/yq) and python-yq both work)

## Install

```
/plugin install guards@agentic
```

Or in settings: `"enabledPlugins": { "guards@agentic": true }`.

## Known limitations

- Multi-document YAML is validated as `yq` accepts it (all documents parsed).
- JSON5 and other comment-tolerant files not on the skip list will false-positive; add patterns to the `case` skip arm in `hooks/validate-syntax.sh` if you hit one.
