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
/orchestrate:init <goal>     # start a goal of any altitude
/orchestrate:init            # no args → resume open lanes (regrounds first)
```

Export `HELDOUT_ROOT` (the path where held-out tests / live-probe oracles live,
outside the writer's tree) before running an ops or held-out lane — the
held-out-deny hook fails closed against reads under it.

## What ships

- **`commands/init.md`** — the `/orchestrate:init` entry point (thin wrapper; the
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

## Field feedback → improving the plugin (ADR-0028)

Every run journals its own review, durably and version-stamped, in the **target** repo
(gitignored axis): `.agents/runs/orchestrate/eval/feedback.jsonl` — one row per run with
the metrics snapshot (shipped / friction / verify_coverage / `model_mix` /
`plugin_version`) — plus the full qualitative review in `eval/reviews/<UTC-ts>.md`, each
point tied to a specific dispatch with evidence.

To improve the plugin from the field, harvest those files **read-only** from the live
repos on this machine (no command needed — this is a convention, not an artifact):

1. Gather: `ls ~/gits/**/.agents/runs/orchestrate/eval/feedback.jsonl` + the review
   sidecars the notes point at.
2. Correlate each improvement item against `docs/adr/INDEX.md` and `TODO.md`: already
   fixed (name the ADR/version), ticketed, NEW, or a **recurrence** — recurrence of a
   ticketed item promotes it to a fix (precedent: ADR-0026).
3. Watch the standing drift signals: `model_mix` all-flagship (ADR-0024), all-sonnet
   researchers with no judgment-shaped output (ADR-0025), `verify_coverage` dropping on
   code-bearing lanes (ADR-0022), `denials` rising — read the board's `denied` rows to
   split "persona missing its boundary context" (ADR-0031) from "hook misfiring"
   (ADR-0032), and check `model_policy` on the goal vs the `model_mix` actually spent
   (ADR-0033).
4. Propose ranked changes (SKILL prose / hook / tier table / test), each with an ADR call.

## Known limitations & filing bugs

Some Claude Code harness behaviors (subagent result notifications, worktree
isolation) are outside a plugin's reach; orchestrate compensates for them by
design. Before filing a bug, skim [KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md) to
tell a harness behavior from an orchestrate defect — the issue template's first
question is exactly that triage.
