#!/usr/bin/env bash
# orchestrate runtime shim (ADR-0018). This file is <plugin>/bin/adr.sh; it resolves
# the real helper relative to the plugin root and execs it, so the LLM-facing bare
# `adr.sh ...` documented in SKILL.md / the Planner persona resolves on PATH. Claude
# Code auto-adds <plugin>/bin to PATH for the main agent AND spawned subagents — the
# contexts where ${CLAUDE_PLUGIN_ROOT} is NOT injected. Single source stays in runtime/.
# The cd runs in a subshell, so the exec'd helper keeps the caller's cwd (its docs/adr
# paths are relative to the repo, as intended).
exec "$(cd "$(dirname "$0")/../skills/orchestrate/runtime" && pwd)/adr.sh" "$@"
