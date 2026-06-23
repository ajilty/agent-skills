#!/usr/bin/env bash
# Integration-test helpers. These exercise the REAL `claude` CLI (and, for the
# invocation tier, a live local agent session) — so they live OUTSIDE the
# zero-dependency tests/run.sh suite and are NOT run on every push.
#
# Filesystem isolation is the core contract, and it does NOT rely on harness
# config knobs (CLAUDE_CONFIG_DIR / --scope): those only redirect *user* config,
# while a `claude` command run inside a project still writes a project-scope
# `.claude/`. Instead we isolate at the filesystem level — every `claude` runs
# with HOME pointed at a throwaway dir AND cwd in a throwaway dir, so *all* state
# (user config, project config, plugin cache, ledger artifacts) is contained and
# disposable. No containers needed; nothing touches the repo or the real ~/.claude.
set -uo pipefail

PASS=0; FAIL=0; SKIP=0
pass(){ PASS=$((PASS+1)); }
fail(){ FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1" >&2; }
skip(){ SKIP=$((SKIP+1)); printf '(skip: %s)\n' "$1"; }
assert_eq(){ [ "$1" = "$2" ] && pass || fail "${3:-} (got '$1' want '$2')"; }

# Locations (INT_HERE is exported by run.sh = tests/integration/).
PLUGIN_DIR="$(cd "$INT_HERE/../.." && pwd)"          # plugins/orchestrate
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"          # agent-skills (has .claude-plugin/marketplace.json)

have_claude(){ command -v claude >/dev/null 2>&1; }
# Live-invocation auth must come from the ENV (not a harness config file), so it
# survives the HOME sandbox: an explicit ANTHROPIC_API_KEY. No key -> Tier 3 skips.
have_api(){ [ -n "${ANTHROPIC_API_KEY:-}" ]; }

# Throwaway dirs with EXIT-trap cleanup.
_INT_TMP=()
_int_cleanup(){ cd "$REPO_ROOT" 2>/dev/null || cd / ; local d; for d in "${_INT_TMP[@]:-}"; do [ -n "${d:-}" ] && rm -rf "$d"; done; }
trap _int_cleanup EXIT
mk_tmp(){ local d; d="$(mktemp -d)"; _INT_TMP+=("$d"); printf '%s\n' "$d"; }
# Sandbox HOME (so the harness writes ALL its config/cache under here, not real ~).
mk_home(){ mk_tmp; }
# Isolated git repo with the orchestrate ledger dir pre-made (for ledger artifacts).
mk_repo(){ local d; d="$(mk_tmp)"; ( cd "$d" && git init -q && git config user.email t@t && git config user.name t && mkdir -p .agents/runs/orchestrate ); printf '%s\n' "$d"; }
