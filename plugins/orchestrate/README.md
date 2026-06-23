# orchestrate (Claude Code plugin)

A standing operator loop you feed goals of any altitude (from "bump the conn
limit" to "deploy app A on cluster B" to "ensure prod restores from backup"). It
decomposes and executes them with enforced discipline — capability-subtracted
personas, single-writer leasing, a fail-closed held-out oracle, and a pre-apply
consequence gate — survives interruption, and remembers its judgment across goals.

## Install

From this repo's self-marketplace:

```
/plugin marketplace add ajilty/agent-skills
/plugin install orchestrate@ajilty-agent-skills
```

## Use

```
/orchestrate:start <goal>     # start a goal of any altitude
/orchestrate:start            # no args → resume open lanes (regrounds first)
```

Export `HELDOUT_ROOT` (the path where held-out tests / live-probe oracles live,
outside the writer's tree) before running an ops or held-out lane — the
held-out-deny hook fails closed against reads under it.

## What ships

- **`commands/start.md`** — the `/orchestrate:start` entry point (thin wrapper; the
  router brain is `skills/orchestrate/SKILL.md`).
- **`agents/{researcher,planner,implementer,verifier,actuator}.md`** — the five
  capability-subtracted subagents. **Generated** (see below).
- **`hooks/hooks.json`** — held-out-deny, branch-guard, the pre-apply gate +
  write-ahead (`SubagentStart`), and compaction-recovery (`SessionStart`). These
  **auto-register** when the plugin is enabled; their command paths are
  `${CLAUDE_PLUGIN_ROOT}`-relative, so they are machine-independent. **Generated.**
- **`skills/orchestrate/`** — the harness-neutral source of truth: `SKILL.md` (the
  router brain), `references/` (`agents.yaml` + persona bodies), and `runtime/`
  (`ledger.sh`, `adr.sh`, and the enforcement/lifecycle hook scripts).

## Generated artifacts (build step)

`agents/*.md` and `hooks/hooks.json` are **build output**, not hand-authored. They
are generated from `skills/orchestrate/references/agents.yaml` (the single
capability contract) by `scripts/build.sh` and committed — a marketplace install
runs no build. After editing `agents.yaml` or any persona body, regenerate:

```
scripts/build.sh
```

A drift-guard unit check (`tests/test_build.sh`) fails if the committed artifacts
diverge from a fresh build, so this can't be silently forgotten. `yq` (v4,
mikefarah) is required at build time only; the installed plugin needs just git +
coreutils. The static manifest (`.claude-plugin/plugin.json`) and the repo-root
marketplace catalog are hand-authored, not generated.

> A `CLAUDE.md` placed inside this plugin would be ignored by Claude Code —
> persistent instructions for the loop live in `skills/orchestrate/SKILL.md`.

## Other harnesses

Codex and OpenCode compile the same `agents.yaml` contract into their native
formats with `scripts/install-codex.sh` / `scripts/install-opencode.sh`
(`--scope user|project`). See the repo root README for details.

## Tests

```
tests/run.sh                  # zero-dependency suite: runtime behavior + allowlist + drift + manifest
tests/integration/run.sh      # live tier (real claude CLI + agent sessions); self-skips without auth
```

## Known limitations & filing bugs

Some Claude Code harness behaviors (subagent result notifications, worktree
isolation) are outside a plugin's reach; orchestrate compensates for them by
design. Before filing a bug, skim [KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md) to
tell a harness behavior from an orchestrate defect — the issue template's first
question is exactly that triage.
