# agentic

Home for homegrown agentic tooling, shipped to multiple harnesses (Claude Code,
Codex, OpenCode) from single-source contracts. Each plugin owns its full story
(install, use, design) in its own README; this file is just the map.

## Plugins

- **[`orchestrate`](plugins/orchestrate/)** — a standing operator loop you feed
  goals of any altitude. It decomposes and executes them with enforced
  discipline, survives interruption, remembers its judgment across goals, and
  gates consequential actions before they touch prod. Install, use, and safety
  model: [`plugins/orchestrate/README.md`](plugins/orchestrate/README.md).
- **[`syntax-guard`](plugins/syntax-guard/)** — a small Claude-Code-only
  PostToolUse hook that validates file syntax after writes.
  See [`plugins/syntax-guard/README.md`](plugins/syntax-guard/README.md).

## Install (short version)

Claude Code, from this repo's self-marketplace:

```
/plugin marketplace add ajilty/agentic
/plugin install orchestrate@ajilty
```

Codex and OpenCode use compile-step installers. Commands, scopes, and the
trust-seeding caveats live in the plugin README's
[install section](plugins/orchestrate/README.md#install).

## Requirements

- `git` and `yq` v4 (mikefarah) at build/install time. Installed runtime is pure
  git + coreutils, no other deps.

## Contributing setup

One-time per clone, activate the repo's git hooks (identity + content leak
guard on every commit; contributors without a private blocklist get a warn,
not a block):

```
git config core.hooksPath scripts/githooks
```

## Where things live

- Harness emitters (compile agents.yaml contracts to Claude Code / Codex /
  OpenCode surfaces, any plugin): [`scripts/harness-lib/`](scripts/harness-lib/) (ADR-0037)
- Design rationale: [`plugins/orchestrate/DESIGN.md`](plugins/orchestrate/DESIGN.md)
- Specs: [`docs/specs/`](docs/specs/) · decisions (ADRs): [`docs/adr/`](docs/adr/)
- Plans: [`docs/plans/`](docs/plans/) · glossary: [`CONTEXT.md`](CONTEXT.md)
- Tests: `plugins/orchestrate/tests/run.sh` (zero dependencies; CI-gated)
