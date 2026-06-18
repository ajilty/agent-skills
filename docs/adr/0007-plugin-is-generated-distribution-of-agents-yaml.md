# Plugin packaging is a generated distribution of the agents.yaml contract

The Claude Code plugin's native artifacts (agents/*.md, hooks/hooks.json) are
build output, generated from references/agents.yaml by scripts/build.sh and
committed (a marketplace install runs no build). agents.yaml stays the single
source of truth — extends ADR-0001's compile-per-harness model to the plugin
form. The static manifest (plugin.json) and marketplace catalog are hand-authored.

## Considered options
- Hand-author agents/ + hooks/ directly — drifts from agents.yaml, breaks the
  one-contract-all-harnesses invariant.
- Generate at install time — impossible for marketplace installs (no build runs
  on the user's machine) and would require yq at runtime.

## Consequences
A drift-guard unit check enforces committed == fresh build. yq is build-time
only; the installed plugin needs git + coreutils.

## Status

active
