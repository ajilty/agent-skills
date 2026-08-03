# 0036: Repo-wide plugin test and validation convention

**Status:** active
**Date:** 2026-08-03

## Context

CI ran only the orchestrate suite. Nothing validated the marketplace manifest
or the other plugins, and two frontmatter defects (unquoted colons in
`manager-brief`'s style and orchestrate's `init.md` command) shipped or nearly
shipped because validation happened only when someone thought to run it. The
Claude code-review workflow reviews semantics per PR; it is not a
deterministic schema gate.

## Decision

Two repo-wide conventions, both discovery-based so new plugins get coverage by
existing in the tree:

1. **Tests.** A plugin that has tests puts them at `plugins/<name>/tests/run.sh`,
   runnable from any cwd, exit code as verdict. CI's `plugin-tests` job runs
   every such script it finds; a plugin without the file is skipped, not
   failed. Suites own their own assertions and dependencies beyond the shared
   baseline (bash, coreutils, git, yq v4).
2. **Validation.** `scripts/validate-plugins.sh` runs
   `claude plugin validate --strict` on `.claude-plugin/marketplace.json` and
   every `plugins/*/` directory. CI's `validate-plugins` job runs it on every
   push and PR; it needs the Claude Code CLI but no credentials.

## Consequences

- Adding a plugin requires no CI edits: validation is automatic, tests are
  opt-in by dropping `tests/run.sh`.
- Strict mode fails on warnings, so unrecognized manifest fields and silently
  dropped frontmatter surface at PR time instead of at runtime.
- The old orchestrate-named CI job is gone; its suite now runs through the
  generic loop. No branch protection referenced the old job name.
