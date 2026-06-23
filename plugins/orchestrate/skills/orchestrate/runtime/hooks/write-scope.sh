#!/usr/bin/env bash
# PreToolUse (Write|Edit): confine each write-capable-but-not-a-writer persona to
# its OWN result path (agents.yaml `write_scope`, SKILL §5, ADR-0014; fail_closed):
#   planner     -> the committed spec/ADR + the per-ticket artifact dir
#   researcher  -> ONLY tickets/*/findings/_quarantine/*  (its RAW findings; the
#                  router reads from disk, runs the §4 gate, promotes to the trusted
#                  findings/<slug>.md — so the researcher must NOT write that path)
#   verifier    -> ONLY tickets/*/verdicts/*              (its verdict + reasoning)
# A write anywhere else (source tree, configs, prod, the other persona's lane) is
# refused. The two writers (implementer/actuator) are unaffected here — capability
# subtraction + branch_guard govern them.
#
# Input source: Claude Code delivers tool_input + agent_type on STDIN as JSON; we
# parse stdin (jq) and fall back to env for Codex/OpenCode (RESOLVED_PATH/PERSONA).
# Without jq under CC it degrades to allow (safe, not enforcing) — same posture as
# the sibling hooks.
#
# Contract (Claude Code): ALLOW = exit 0 with NO stdout; DENY = reason on stderr +
# exit 2. Self-guards on persona; never errors. Fail-closed: a write whose path
# can't be resolved falls through to deny, and any `..` is rejected (no climbing out
# of an allowed prefix). Accepted residual: prefixes are matched textually, so a
# path that merely *contains* an allowed segment is allowed — benign (still a
# result-shaped target, not source); the load-bearing denial is the source tree,
# which carries no such segment.
set -uo pipefail
in=""; [ -t 0 ] || in="$(cat 2>/dev/null || true)"
J(){ [ -n "$in" ] && command -v jq >/dev/null 2>&1 && printf '%s' "$in" | jq -r "$1 // empty" 2>/dev/null || true; }
persona="$(J .agent_type)"; [ -n "$persona" ] || persona="${PERSONA:-${CLAUDE_AGENT_TYPE:-${CODEX_AGENT:-}}}"
persona="${persona##*:}"   # strip plugin namespace: CC sends agent_type as <plugin>:<persona> (e.g. orchestrate:actuator)
case "$persona" in planner|researcher|verifier) ;; *) exit 0 ;; esac
p="$(J .tool_input.file_path)"; [ -n "$p" ] || p="$(J .tool_input.path)"
[ -n "$p" ] || p="${RESOLVED_PATH:-${CODEX_TOOL_PATH:-}}"
# Reject `..` traversal first: a textual prefix match can't be trusted once a path
# can climb out of it (findings/_quarantine/../../src/x). A result write never needs `..`.
case "$p" in
  ..|../*|*/..|*/../*) echo "orchestrate: $persona write path must not contain '..' (refused: $p)" >&2; exit 2 ;;
esac
case "$persona" in
  planner)
    case "$p" in
      docs/specs/*|*/docs/specs/*|docs/adr/*|*/docs/adr/*|.agents/runs/orchestrate/tickets/*|*/.agents/runs/orchestrate/tickets/*) exit 0 ;;
    esac
    echo "orchestrate: planner writes are confined to the spec/ADR artifact — docs/specs/, docs/adr/, or the per-ticket dir (refused: ${p:-<unresolved>})" >&2 ;;
  researcher)
    case "$p" in
      */tickets/*/findings/_quarantine/*) exit 0 ;;
    esac
    echo "orchestrate: researcher writes are confined to its RAW findings — tickets/<t>/findings/_quarantine/ (the router gates+promotes; refused: ${p:-<unresolved>})" >&2 ;;
  verifier)
    case "$p" in
      */tickets/*/verdicts/*) exit 0 ;;
    esac
    echo "orchestrate: verifier writes are confined to its verdict — tickets/<t>/verdicts/ (refused: ${p:-<unresolved>})" >&2 ;;
esac
exit 2
