#!/usr/bin/env bash
# PreToolUse (Bash): confine the VERIFIER's tests-only run capability
# (agents.yaml `run_scope`). The verifier may execute the held-out suite and
# inspect the tree read-only, but must not MUTATE the working tree or git state —
# the threat is gaming the oracle by editing tests/source so the suite passes.
# The verifier already lacks Write/Edit (capability subtraction); this closes the
# Bash-mutation path behind it.
#
# Posture: best-effort threat-model DENYLIST, not an exhaustive allowlist. Robustly
# scoping a shell to "only tests" is repo-specific; a determined escape (e.g. a
# language one-liner that opens a file for write) is accepted — same advisory
# posture as cred-scope (ADR-0002). Defense-in-depth, not a hard guarantee.
#
# Input source: Claude Code delivers tool_input + agent_type on STDIN as JSON; we
# parse stdin (jq) and fall back to env for Codex/OpenCode (TOOL_INPUT/PERSONA).
# Without jq under CC it degrades to allow (safe, not enforcing).
#
# Contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on stderr +
# exit 2. Self-guards on persona; never errors.
set -uo pipefail
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
persona="$(J .agent_type)"; [ -n "$persona" ] || persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
persona="${persona##*:}"   # strip plugin namespace: CC sends agent_type as <plugin>:<persona> (e.g. orchestrate:actuator)
[ "$persona" = verifier ] || exit 0
cmd="$(J .tool_input.command)"; [ -n "$cmd" ] || cmd="${TOOL_INPUT:-${CODEX_TOOL_INPUT:-}}"
[ -n "$cmd" ] || exit 0

deny() { echo "orchestrate: verifier is tests-only — workspace/git mutation is refused (run_scope): $cmd" >&2; exit 2; }

# Scratch carve-out (ADR-0026): rehearsal writes confined to throwaway scratch roots are
# legitimate verification work (stub binaries, probe scripts, result sentinels). Two live
# runs saw verifiers degrade — falling back to static analysis, assembling sentinels via
# chr(62) — because ANY write was refused. Scratch roots only; repo + git stay sealed.
is_scratch(){ case "$1" in /tmp/*|/var/tmp/*) return 0 ;; esac
  [ -n "${TMPDIR:-}" ] && case "$1" in "${TMPDIR%/}"/*) return 0 ;; esac; return 1; }

# Normalize shell separators to spaces and wrap in spaces, so verb checks are
# word-bounded (\" rm \" never matches \"confirm\"). Redirection is checked on raw.
norm=" ${cmd//[;|&()\`]/ } "
# git mutation: match the subcommand as a word anywhere after `git`, so inter-token
# options (git -C <dir> checkout, git -c k=v reset) can't slip past a contiguous
# "git checkout" match. Read-only subcommands (status/diff/log/show) stay allowed.
case "$norm" in
  *" git "*)
    case "$norm" in
      *" checkout "*|*" reset "*|*" restore "*|*" switch "*|*" branch "*|*" push "*|*" merge "*|*" rebase "*|*" apply "*|*" stash "*|*" commit "*|*" clean "*) deny ;;
    esac ;;
esac
# File-mutation verbs: allowed ONLY when every path-shaped argument (contains "/")
# resolves under a scratch root. A relative or repo path anywhere -> deny as before
# (fail-closed: an unparseable target reads as non-scratch).
case "$norm" in
  *" rm "*|*" rmdir "*|*" mv "*|*" truncate "*|*" dd "*|*" tee "*|*" sed -i"*|*" perl -i"*)
    saw_path=0; ok=1
    for w in $norm; do
      wq="${w%\"}"; wq="${wq#\"}"; wq="${wq%\'}"; wq="${wq#\'}"
      case "$wq" in -*|*=*) continue ;; esac
      case "$wq" in */*) saw_path=1; is_scratch "$wq" || ok=0 ;; esac
    done
    { [ "$saw_path" = 1 ] && [ "$ok" = 1 ]; } || deny ;;
esac

# Output redirection to a file = a write. Strip benign /dev/null + fd-dup forms; any
# remaining > (or >>) must target a scratch root, else deny.
red="$cmd"
red="${red//2>&1/}"; red="${red//&>\/dev\/null/}"; red="${red//2>\/dev\/null/}"
red="${red//1>\/dev\/null/}"; red="${red//>\/dev\/null/}"; red="${red//> \/dev\/null/}"
case "$red" in *">"*)
  ok=1; saw=0
  while IFS= read -r t; do
    [ -n "$t" ] || continue; saw=1
    t="${t%\"}"; t="${t#\"}"; t="${t%\'}"; t="${t#\'}"
    is_scratch "$t" || ok=0
  done <<< "$(printf '%s' "$red" | grep -oE '>>?[[:space:]]*[^[:space:]<>]+' | sed -E 's/^>>?[[:space:]]*//')"
  { [ "$saw" = 1 ] && [ "$ok" = 1 ]; } || deny ;;
esac

exit 0
