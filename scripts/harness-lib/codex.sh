# harness-lib/codex.sh — compile the agents.yaml contract into Codex CLI native
# surfaces (agent TOMLs, hooks.json wiring, [hooks.state] trust seeding).
# Source common.sh first.
#
# Additional caller globals (set by the driver before calling into this file):
#   DEST        — Codex home being installed into ($CODEX_HOME or .codex)
#   CONFIG_TOML — $DEST/config.toml
#   HOOKS_JSON  — $DEST/hooks.json
#   HOOKS       — absolute path to the installed skill's runtime/hooks dir
# codex_derive_wiring sets PRE_MATCHER + PRE_HOOKS from the contract;
# codex_seed_hook_trust sets SEED_STATUS (seeded|seeded-unverified|verify-failed|docs-only).

# capability vocabulary -> sandbox_mode (any write- or run-capable persona is
# workspace-write at the OS layer; the hook floor confines the path on top)
codex_sandbox() { local p="$1" w r
  w="$(p_cap "$p" write)"; r="$(p_cap "$p" run)"
  if [ "$w" = none ] && [ "$r" = none ]; then echo read-only; else echo workspace-write; fi; }
# agents.yaml tier -> codex model id.  economy->mini, standard->5.4, premium->frontier.
codex_model() { case "$1" in
  economy)  echo gpt-5.4-mini ;;
  standard) echo gpt-5.4 ;;
  premium)  echo gpt-5.5 ;;
  *)        echo "" ;;   # unknown/empty tier -> omit model line (inherit session default)
esac; }
# agents.yaml effort -> codex model_reasoning_effort enum (low|medium|high|xhigh ONLY).
# `max` is NOT a valid codex value (API rejects it) -> map to the real ceiling, xhigh.
codex_effort() { case "$1" in
  low|medium|high|xhigh) echo "$1" ;;
  max)                   echo xhigh ;;
  *)                     echo "" ;;   # unknown/empty -> omit (inherit)
esac; }

# Derive the PreToolUse floor from the contract: every hook watching a tool-shaped
# class, in contract wire order. Codex funnels them all through ONE matcher group
# (apply_patch is the Codex top-level write tool; scripts self-guard, so
# over-matching is safe — same posture as CC's combined Read|Bash group).
codex_derive_wiring() {
  PRE_MATCHER='^(Read|Edit|Write|Bash|apply_patch)$'
  PRE_HOOKS="$(hooks_watching 'file-read|shell|file-write' | tr '\n' ' ')"
  PRE_HOOKS="${PRE_HOOKS% }"
}

SEED_BEGIN='# >>> orchestrate hook-trust (managed; do not edit by hand) >>>'
SEED_END='#   <<< orchestrate hook-trust (managed) <<<'

# Emit the managed hooks.json (CC-shaped — the shape codex reads from $CODEX_HOME/hooks.json).
# PreToolUse from PRE_HOOKS; dispatch-class hooks -> SubagentStart with the matcher
# derived from the contract's applies_to; post-compaction-class -> PostCompact.
# $1: extra PreToolUse matcher-group lines (used to append the self-verify probe group).
codex_write_hooks_json() { # [<extra_group_json>]
  local extra="${1:-}" pre_hooks_json="" h name
  for h in $PRE_HOOKS; do
    pre_hooks_json="${pre_hooks_json:+$pre_hooks_json, }{ \"type\": \"command\", \"command\": \"$HOOKS/$h\" }"
  done
  {
    printf '{ "hooks": {\n'
    printf '  "PreToolUse": [\n'
    printf '    { "matcher": "%s", "hooks": [ %s ] }%s\n' "$PRE_MATCHER" "$pre_hooks_json" "${extra:+,}"
    [ -n "$extra" ] && printf '    %s\n' "$extra"
    printf '  ],\n'
    for name in $(hooks_watching_names 'dispatch'); do
      printf '  "SubagentStart": [ { "matcher": "%s", "hooks": [ { "type": "command", "command": "%s/%s" } ] } ],\n' \
        "$(hook_matcher "$name")" "$HOOKS" "$(hook_script "$name")"
    done
    for name in $(hooks_watching_names 'post-compaction'); do
      printf '  "PostCompact": [ { "hooks": [ { "type": "command", "command": "%s/%s" } ] } ]\n' "$HOOKS" "$(hook_script "$name")"
    done
    printf '} }\n'
  } > "$HOOKS_JSON"
}

# The printed [[hooks.PreToolUse]] reference block for the install summary —
# GENERATED from the same PRE_HOOKS wire list, so it can never restate a stale
# floor (a hand-maintained copy drifted the moment a hook was added).
codex_print_pretooluse_toml() {
  local h
  printf '  [[hooks.PreToolUse]]\n  matcher = "%s"   # apply_patch is the Codex top-level write tool\n' "$PRE_MATCHER"
  printf '  # Floor hooks in contract wire order; each intent is documented in agents.yaml hooks:\n'
  for h in $PRE_HOOKS; do
    printf '  [[hooks.PreToolUse.hooks]]\n  type = "command"\n  command = "%s/%s"\n' "$HOOKS" "$h"
  done
}

# Ensure [features] hooks = true lands in config.toml (idempotent; never clobbers).
ensure_hooks_feature() { # <config.toml>
  local cfg="$1"
  [ -f "$cfg" ] || : > "$cfg"
  if ! grep -qE '^\s*hooks\s*=\s*true' "$cfg" 2>/dev/null; then
    printf '\n[features]\nhooks = true\n' >> "$cfg"
  fi
}

# Ensure the router's shell may reach the network (ADR-0017): a nested persona
# `codex exec` needs egress to reach the model; default workspace-write blocks it.
# Idempotent; never clobbers an operator's existing key.
ensure_network_access() { # <config.toml>
  local cfg="$1"
  [ -f "$cfg" ] || : > "$cfg"
  if ! grep -qE '^\s*network_access\s*=' "$cfg" 2>/dev/null; then
    printf '\n[sandbox_workspace_write]\nnetwork_access = true\n' >> "$cfg"
  fi
}

# Strip any prior managed seed block (idempotent re-install).
strip_seed_block() { # <config.toml>
  local cfg="$1"; [ -f "$cfg" ] || return 0
  awk -v b="$SEED_BEGIN" -v e="$SEED_END" '
    $0==b {drop=1; next} $0==e {drop=0; next} !drop {print}
  ' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
}

# Ask codex for the key->currentHash of every wired hook (deterministic oracle).
# Echoes lines "<key>\t<sha256:...>". Empty output -> oracle unavailable.
hook_trust_oracle() { # <CODEX_HOME>
  local ch="$1"
  { printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"orchestrate-install","version":"0"}}}\n'
    sleep 1
    printf '{"jsonrpc":"2.0","id":2,"method":"hooks/list","params":{}}\n'
    sleep 2
  } | CODEX_HOME="$ch" timeout 30 codex app-server 2>/dev/null | python3 -c '
import sys, json
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try: m=json.loads(line)
    except Exception: continue
    if m.get("id")==2 and isinstance(m.get("result"),dict):
        for inst in m["result"].get("data",[]):
            for h in inst.get("hooks",[]):
                k=h.get("key"); v=h.get("currentHash")
                if k and v: print(f"{k}\t{v}")
        break
' 2>/dev/null
}

# Write the managed [hooks.state] block from "<key>\t<hash>" lines on stdin.
write_seed_block() { # <config.toml>  (reads key\thash pairs on stdin)
  local cfg="$1" key hash any=0 tmp; tmp="$(mktemp)"
  printf '%s\n' "$SEED_BEGIN" >> "$tmp"
  printf '[hooks.state]\n' >> "$tmp"
  while IFS=$'\t' read -r key hash; do
    [ -n "$key" ] && [ -n "$hash" ] || continue
    any=1
    printf '[hooks.state."%s"]\ntrusted_hash = "%s"\nenabled = true\n' "$key" "$hash" >> "$tmp"
  done
  printf '%s\n' "$SEED_END" >> "$tmp"
  [ "$any" = 1 ] && cat "$tmp" >> "$cfg"
  rm -f "$tmp"
  return $((1-any))   # 0 if we wrote at least one entry
}

# SELF-VERIFY: with the floor seeded (no bypass), a deny probe must BLOCK. Returns 0 on
# proven-live, non-zero otherwise. Uses an isolated throwaway CODEX_HOME that MIRRORS the
# real seeding flow (same hooks.json + same oracle + same [hooks.state] mechanism) plus one
# extra deny hook — so a PASS proves the exact seeding recipe makes a wired hook fire, while
# never depending on the model running a real floor hook against real state.
selfverify_trust() { # echoes PASS|FAIL|SKIP
  command -v codex >/dev/null 2>&1 || { echo SKIP; return; }
  command -v python3 >/dev/null 2>&1 || { echo SKIP; return; }
  codex login status >/dev/null 2>&1 || [ -f "$HOME/.codex/auth.json" ] || { echo SKIP; return; }
  local sv ws deny oracle out
  sv="$(mktemp -d)"; ws="$(mktemp -d)"
  [ -f "$HOME/.codex/auth.json" ] && cp "$HOME/.codex/auth.json" "$sv/auth.json" 2>/dev/null
  ( cd "$ws" && git init -q ) 2>/dev/null
  deny="$sv/selfverify-deny.sh"
  printf '#!/usr/bin/env bash\necho "ORCH-SELFVERIFY-DENY" >&2\nexit 2\n' > "$deny"; chmod +x "$deny"
  # A single deny hook on Bash — the same hooks.json shape + same trust mechanism.
  printf '{ "hooks": { "PreToolUse": [ { "matcher": "^(Bash|Shell|apply_patch)$", "hooks": [ { "type": "command", "command": "%s" } ] } ] } }\n' "$deny" > "$sv/hooks.json"
  printf '[features]\nhooks = true\n' > "$sv/config.toml"
  oracle="$(hook_trust_oracle "$sv")"
  [ -n "$oracle" ] || { rm -rf "$sv" "$ws"; echo SKIP; return; }
  printf '%s\n' "$oracle" | write_seed_block "$sv/config.toml" >/dev/null || { rm -rf "$sv" "$ws"; echo SKIP; return; }
  out="$(printf 'Run the shell command: echo orch-probe. Report the result.' \
    | ( cd "$ws" && CODEX_HOME="$sv" timeout 180 codex exec -s workspace-write --skip-git-repo-check - ) 2>&1)"
  rm -rf "$sv" "$ws"
  if printf '%s' "$out" | grep -qi "ORCH-SELFVERIFY-DENY"; then echo PASS; else echo FAIL; fi
}

# Drive the seeding + self-verify, set SEED_STATUS for the printed summary.
codex_seed_hook_trust() {
  SEED_STATUS=unknown
  codex_write_hooks_json
  ensure_hooks_feature "$CONFIG_TOML"
  # Hermetic-install escape (tests/CI): skip the live codex oracle + self-verify
  # probe (minutes of real codex exec). Floor lands docs-only, like no-codex hosts.
  if [ -n "${ORCHESTRATE_NO_SELFVERIFY:-}" ]; then
    strip_seed_block "$CONFIG_TOML"; SEED_STATUS=docs-only; return 0
  fi
  strip_seed_block "$CONFIG_TOML"
  # Oracle unavailable (no codex/auth)? Leave docs-only; floor needs manual trust.
  if ! command -v codex >/dev/null 2>&1 \
     || ! command -v python3 >/dev/null 2>&1 \
     || { ! codex login status >/dev/null 2>&1 && [ ! -f "$HOME/.codex/auth.json" ]; }; then
    SEED_STATUS=docs-only
    return 0
  fi
  local oracle
  oracle="$(hook_trust_oracle "$DEST")"
  if [ -z "$oracle" ]; then SEED_STATUS=docs-only; return 0; fi
  if ! printf '%s\n' "$oracle" | write_seed_block "$CONFIG_TOML" >/dev/null; then
    SEED_STATUS=docs-only; return 0
  fi
  # Load-bearing safety gate: prove the seeding recipe actually makes a hook FIRE.
  local v; v="$(selfverify_trust)"
  case "$v" in
    PASS) SEED_STATUS=seeded ;;
    SKIP) SEED_STATUS=seeded-unverified ;;       # seeded, but couldn't run the live probe
    *)    strip_seed_block "$CONFIG_TOML"; SEED_STATUS=verify-failed ;;  # drift -> strip, fall back to docs
  esac
}
