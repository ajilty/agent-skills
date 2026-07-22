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
have_api(){ [ -n "${ANTHROPIC_API_KEY:-}" ]; }
# Live auth that survives a HOME sandbox: an explicit ANTHROPIC_API_KEY, a copyable
# OAuth credential we clone into the sandbox, or env/FD-carried OAuth (managed/remote
# environments, e.g. Claude Code on the web: the token rides CLAUDE_CODE_OAUTH_TOKEN*
# env inherited by child processes, so no credential file exists and none needs
# copying — a probe `claude -p` just works). Checking only the file made the live
# tiers self-skip in exactly those environments (live 2026-07-02 finding).
# No auth -> live tiers skip.
have_live_auth(){ have_api || [ -f "$HOME/.claude/.credentials.json" ] \
  || [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || [ -n "${CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR:-}" ]; }

# --- Codex (codex-cli) tier ---------------------------------------------------
# Mirror of the Claude-side probes for the Codex harness. Same isolation contract:
# a throwaway CODEX_HOME (never the real ~/.codex) + a throwaway cwd, EXIT-trap
# cleaned. Tests self-skip when codex / its auth is absent.
have_codex(){ command -v codex >/dev/null 2>&1; }
# Live auth that survives a CODEX_HOME sandbox: `codex login status` succeeds, OR a
# copyable ~/.codex/auth.json we clone into the sandbox. No auth -> Codex live tiers skip.
have_codex_auth(){ codex login status >/dev/null 2>&1 || [ -f "$HOME/.codex/auth.json" ]; }

# Throwaway CODEX_HOME with ONLY the auth credential cloned in (never the real
# ~/.codex). Use as `CODEX_HOME=$(mk_codex_home)` for installed-plugin + live tests.
mk_codex_home(){ local h; h="$(mk_tmp)"; [ -f "$HOME/.codex/auth.json" ] && cp "$HOME/.codex/auth.json" "$h/auth.json" 2>/dev/null; printf '%s\n' "$h"; }

# Install the orchestrate skill into a CODEX_HOME (user scope, --dir override so it
# can't pollute a real ~/.codex). Echoes nothing; returns the installer's exit code.
codex_install(){ # <codex_home>
  local ch="$1"
  CODEX_HOME="$ch" bash "$PLUGIN_DIR/scripts/install-codex.sh" --scope user --dir "$ch" >/dev/null 2>&1
}

# Throwaway dirs with EXIT-trap cleanup.
_INT_TMP=()
_int_cleanup(){ cd "$REPO_ROOT" 2>/dev/null || cd / ; local d; for d in "${_INT_TMP[@]:-}"; do [ -n "${d:-}" ] && rm -rf "$d"; done; }
trap _int_cleanup EXIT
mk_tmp(){ local d; d="$(mktemp -d)"; _INT_TMP+=("$d"); printf '%s\n' "$d"; }
# Sandbox HOME (so the harness writes ALL its config/cache under here, not real ~).
mk_home(){ mk_tmp; }
# Isolated git repo with the orchestrate ledger dir pre-made (for ledger artifacts).
mk_repo(){ local d; d="$(mk_tmp)"; ( cd "$d" && git init -q && git config user.email t@t && git config user.name t && mkdir -p .agents/runs/orchestrate ); printf '%s\n' "$d"; }
# Sandbox HOME authenticated for LIVE dispatch: a fresh dir + ONLY the OAuth
# credential cloned in (keeps sandbox state controlled). With ANTHROPIC_API_KEY set,
# no copy is needed. Use for installed-plugin + live-dispatch tests.
mk_authed_home(){ local h; h="$(mk_home)"; mkdir -p "$h/.claude"; [ -f "$HOME/.claude/.credentials.json" ] && cp "$HOME/.claude/.credentials.json" "$h/.claude/" 2>/dev/null; printf '%s\n' "$h"; }

# --- OpenCode tier ---------------------------------------------------------
# Mirror of the Claude/Codex probes for the OpenCode harness (ADR-0034). OpenCode
# reads FIVE locations from the ambient environment: XDG_CONFIG_HOME (config),
# XDG_DATA_HOME (auth.json/db/log), XDG_CACHE_HOME (provider bin cache),
# XDG_STATE_HOME (frecency/locks), and HOME directly for skill discovery
# (~/.agents/skills, ~/.claude/skills — documented, HOME-based, NOT XDG-based).
#
# INCIDENT (this worktree, 2026-07-21): an ambient shell that already exports
# XDG_CONFIG_HOME/XDG_DATA_HOME (common — dotfiles, direnv, etc.) makes `HOME=...`
# alone NOT sandbox opencode: DEST resolution falls back to
# `${XDG_CONFIG_HOME:-$HOME/.config}`, so a pre-set XDG_CONFIG_HOME wins over the
# HOME override and opencode writes the REAL ~/.config/opencode. This happened
# live during this tier's own development and wrote real agents/plugins/commands
# files into a real ~/.config/opencode — see probe-results.md for the incident
# note and the exact cleanup. The fix: every opencode invocation below sets ALL
# FIVE vars EXPLICITLY inline on the command (never `export`/`unset`, so the
# isolation is request-scoped and can't leak between sourced test files, and
# never omitted, so no ambient value can win).
have_opencode(){ command -v opencode >/dev/null 2>&1; }
# Live auth: the host's opencode auth.json (from `opencode auth login` / `opencode
# providers`). No auth -> OpenCode live tiers skip. account.json is optional and
# cloned in too when present (some providers use it alongside auth.json).
have_opencode_auth(){ [ -f "$HOME/.local/share/opencode/auth.json" ]; }

# Cheapest usable model on this host's authenticated provider set (probed
# 2026-07-21): the `opencode` zen provider's models need a payment method,
# github-copilot models are unlicensed here, and openai's nano/mini tier names
# from `opencode models` don't exist under the openai/ prefix specifically —
# openai/gpt-5.4-fast is the cheap+fast tier that actually answers. Override via
# OC_MODEL if your environment differs. Live probes still keep prompts minimal
# regardless of model cost (per the work item).
OC_MODEL="${OC_MODEL:-openai/gpt-5.4-fast}"

# Throwaway OpenCode "home root": ONE dir holding all five sandboxed locations.
# ONLY auth.json (+ account.json if present) is cloned in from the host — never
# any other host opencode state (never the real config/agents/plugins/db/log).
# Use as `oc=$(mk_opencode_home)`.
mk_opencode_home(){
  local h; h="$(mk_tmp)"
  mkdir -p "$h/.config" "$h/.local/share/opencode" "$h/.cache" "$h/.local/state"
  [ -f "$HOME/.local/share/opencode/auth.json" ] && cp "$HOME/.local/share/opencode/auth.json" "$h/.local/share/opencode/auth.json" 2>/dev/null
  [ -f "$HOME/.local/share/opencode/account.json" ] && cp "$HOME/.local/share/opencode/account.json" "$h/.local/share/opencode/account.json" 2>/dev/null
  printf '%s\n' "$h"
}
# Run ANY command (opencode itself, or install-opencode.sh) fully sandboxed under
# an mk_opencode_home dir — all 5 vars set inline, every call site, no ambient
# leakage. NEVER invoke `opencode` or install-opencode.sh directly in this tier;
# always route through this. Usage: oc_run "$oc" timeout 90 opencode run ...
oc_run(){ # <oc_home> <cmd...>
  local h="$1"; shift
  XDG_CONFIG_HOME="$h/.config" XDG_DATA_HOME="$h/.local/share" \
  XDG_CACHE_HOME="$h/.cache" XDG_STATE_HOME="$h/.local/state" HOME="$h" \
  "$@"
}
# Install orchestrate into an mk_opencode_home dir (user scope — DEST/SKILLS_ROOT
# resolve from the sandboxed XDG_CONFIG_HOME/HOME set by oc_run, so this lands
# entirely inside $h; never the real ~/.config/opencode or ~/.agents/skills).
opencode_install(){ # <oc_home>
  oc_run "$1" bash "$PLUGIN_DIR/scripts/install-opencode.sh" --scope user >/dev/null 2>&1
}
