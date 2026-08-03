# orchestrate (Claude Code plugin)

A standing operator loop you feed goals of any altitude (from "bump the conn
limit" to "deploy app A on cluster B" to "ensure prod restores from backup"). It
decomposes and executes them with enforced discipline — capability-subtracted
personas, single-writer leasing, a fail-closed held-out oracle, and a pre-apply
consequence gate — survives interruption, and remembers its judgment across goals.

## Install

**Claude Code** — from this repo's self-marketplace:

```
/plugin marketplace add ajilty/agent-skills
/plugin install orchestrate@ajilty-agent-skills
```

Everything ships in the plugin: the five persona agents, the hook floor
(`hooks/hooks.json` auto-registers — no settings.json snippet to paste), the
skill, commands, and `bin/` shims. Nothing runs at install time; artifacts are
pre-built and committed (see "Generated artifacts" below).

**Codex / OpenCode** — compile-step installers (one harness-neutral capability
contract → native enforcement):

```
plugins/orchestrate/scripts/install-codex.sh    --scope user   # or --scope project
plugins/orchestrate/scripts/install-opencode.sh --scope user   # or --scope project
```

Both install ONE copy of the skill (SKILL.md + references/ + runtime/, with a
harness dispatch addendum appended) into the cross-tool `.agents/skills/` root
(`~/.agents/skills/` at user scope, `<repo>/.agents/skills/` at project scope) —
both harnesses auto-discover it there (ADR-0034; no AGENTS.md include step).
Harness config dirs get only native surfaces:

- **Codex** (`~/.codex` or `.codex/`): persona TOMLs (sandbox, model, effort),
  `hooks.json` wiring the floor, config.toml edits (hooks feature + network
  access), and hook **trust seeding** with a live self-verify — an untrusted
  Codex hook silently fails OPEN, so read the HOOK TRUST status the installer
  prints before relying on the floor.
- **OpenCode** (`~/.config/opencode` or `.opencode/`): persona agents, the
  `/orchestrate-{init,status,feedback}` commands, and a generated enforcement
  plugin (`plugins/orchestrate.ts`) that runs the shared hook scripts on tool
  events.

Installers are idempotent; `yq` v4 (mikefarah) is required at install time only.

## Use

```
/orchestrate:init <goal>                  # start a goal of any altitude
/orchestrate:init --models=quick <goal>   # dispatch policy: dynamic (default) | quick | inherit (ADR-0033)
/orchestrate:init                         # no args → resume open lanes (regrounds first)
```

Export `HELDOUT_ROOT` (the path where held-out tests / live-probe oracles live,
outside the writer's tree) before running an ops or held-out lane — the
held-out-deny hook fails closed against reads under it.

The loop is idempotent and self-detecting: an empty ledger starts fresh, open
lanes resume, and compaction recovers automatically. Reground (always first) →
intake (clarify only if ambiguous) → right-size → drive lanes (Researcher /
Planner / Implementer / Actuator / Verifier) → verify, resolve, merge, close.
No config file — repo specifics are discovered, defaulted, or set by env.

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
capability contract, which also carries the hook wire map: `script:` + `watch:`
per hook) by `scripts/build.sh` and committed — a marketplace install runs no
build. All harness mapping logic lives in the repo-level `scripts/harness-lib/`
(ADR-0037), shared by this and the Codex/OpenCode installers. After editing `agents.yaml` or any persona body, regenerate:

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

## Onboarding: new vs existing repos

First run on either is just `/orchestrate:init <goal>`. The difference is how
much context pre-exists:

| | New repo | Existing repo |
|---|---|---|
| `.agents/` | gitignore it | add `.agents/` to `.gitignore` (one line) |
| Oracle | Planner authors spec-derived acceptance checks | discovers existing tests; set `HELDOUT_ROOT` to enforce held-out isolation |
| Judgment memory | `docs/adr/` starts empty, accumulates | optionally seed `docs/adr/` so the Planner recalls prior decisions instead of re-litigating |
| Ops creds | scope per leased target (advisory) when the first ops goal appears | same |
| Discovery | nothing to find | base branch, coverage, mutation targets discovered at runtime |

## How state is laid out (two-axis split, ADR-0005)

- **Tracked, human-facing →** `docs/specs/` (designs) and `docs/adr/` (cross-goal
  decisions; the judgment memory). These travel with the repo.
- **Gitignored, machine state →** `.agents/` (the board ledger, per-ticket bus,
  mutation-target leases, worktrees). One `.gitignore` entry.

## Safety model (what's guaranteed vs advisory)

- **Guaranteed:** capability subtraction per persona (compiled to native tool
  allowlists), single-writer over *mutation targets* via deterministic leases,
  fail-closed held-out read-deny, branch-guard, and the pre-apply consequence gate
  (a `PreToolUse` floor denies the Actuator's commands until a prod-tagged target
  is acked — on Claude Code / Codex via hooks, on OpenCode via its plugin).
- **Advisory (deployment responsibility):** credential confinement of the Actuator
  to its leased targets, and any live-environment/network boundary — the skill
  states these but cannot enforce them in every harness (ADR-0002, §8).

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

## Status

Phases P1–P4 are landed (see [`DESIGN.md` §17](DESIGN.md)). Carried forward as
deferred-with-ticket from the P1 whole-branch review: lease acquire atomicity
(TOCTOU → `mkdir`/`set -C` hardening), `TARGETS` comma-split, and lease-key JSON
escaping.

## Known limitations & filing bugs

Some Claude Code harness behaviors (subagent result notifications, worktree
isolation) are outside a plugin's reach; orchestrate compensates for them by
design. Before filing a bug, skim [KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md) to
tell a harness behavior from an orchestrate defect — the issue template's first
question is exactly that triage.
