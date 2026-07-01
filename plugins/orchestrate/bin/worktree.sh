#!/usr/bin/env bash
# orchestrate runtime shim (ADR-0018). This file is <plugin>/bin/worktree.sh; it resolves
# the real helper relative to the plugin root and execs it, so the LLM-facing bare
# `worktree.sh ...` documented in SKILL.md resolves on PATH. Claude Code auto-adds
# <plugin>/bin to PATH for the main agent AND spawned subagents — the contexts where
# ${CLAUDE_PLUGIN_ROOT} is NOT injected. Single source stays in runtime/. The cd runs in
# a subshell, so the exec'd helper keeps the caller's cwd.
exec "$(cd "$(dirname "$0")/../skills/orchestrate/runtime" && pwd)/worktree.sh" "$@"
