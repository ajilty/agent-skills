# Subdir-plugin monorepo over repo-root-as-plugin

Each tool is an independently-versioned plugin under plugins/<name>/, catalogued
by a single repo-root .claude-plugin/marketplace.json. Rejected superpowers'
repo-root-as-plugin model so tools stay isolated and separately installable.

## Considered options
- Repo root = one plugin (superpowers model) — simplest, but every skill ships
  together under one version; no per-tool isolation.

## Consequences
Cross-plugin skill reuse must use repo-root shared/ + symlinks (never ../),
because Claude Code copies a plugin dir to a cache on install. Unused in v1
(orchestrate is the only plugin); recorded so the constraint isn't rediscovered.

## Status

active
