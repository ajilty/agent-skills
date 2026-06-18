# agent-skills

Home for homegrown agentic tooling. Currently: **`orchestrate`** — a standing
operator loop you feed goals of any altitude (from "bump the conn limit" to
"deploy app A on cluster B" to "ensure prod restores from backup"). It decomposes
and executes them with enforced discipline, survives interruption, remembers its
judgment across goals, and gates consequential actions before they touch prod.

- The plugin lives at [`plugins/orchestrate/`](plugins/orchestrate/); its skill brain
  (SKILL.md, references, runtime) is at [`plugins/orchestrate/skills/orchestrate/`](plugins/orchestrate/skills/orchestrate/).
- Design rationale: [`plugins/orchestrate/DESIGN.md`](plugins/orchestrate/DESIGN.md) ·
  spec: [`docs/specs/`](docs/specs/) · decisions: [`docs/adr/`](docs/adr/) ·
  glossary: [`CONTEXT.md`](CONTEXT.md).

## Requirements

- `git` and `yq` v4 (mikefarah). Runtime is pure git + coreutils — no other deps.

## Install

`orchestrate` ships as a Claude Code plugin from this repo's self-marketplace:

```
/plugin marketplace add ajilty/agent-skills
/plugin install orchestrate@ajilty-agent-skills
```

Then type `/orchestrate:start <goal>` to start, or `/orchestrate:start` (no args) to
resume. Export `HELDOUT_ROOT` (held-out test / live-probe oracle root, outside the
writer's tree) before running an ops or held-out lane. The hooks (held-out-deny,
branch-guard, the pre-apply gate + write-ahead, compaction-recovery) auto-register
with the plugin via `hooks/hooks.json` — no settings.json snippet to paste.

Codex and OpenCode keep their compile-step installers (one harness-neutral
capability contract → native enforcement):

```
plugins/orchestrate/scripts/install-codex.sh --scope user
plugins/orchestrate/scripts/install-opencode.sh --scope user
```

## Use

In a target repo, drive the loop with your goal. It is idempotent and
self-detecting: an empty ledger starts fresh, open lanes resume, and compaction
recovers automatically.

```
/orchestrate:start deploy app A on cluster B
```

The loop: reground (always first) → intake (clarify only if ambiguous) →
right-size → drive lanes (Researcher / Planner / Implementer / Actuator /
Verifier) → verify, resolve, merge, close. No config file — repo specifics are
discovered, defaulted, or set by env.

## Onboarding: new vs existing repos

First run on either is just `/orchestrate:start <goal>`. The difference is how much
context pre-exists:

| | New repo | Existing repo |
|---|---|---|
| `.agents/` | gitignore it (already done here) | add `.agents/` to `.gitignore` (one line) |
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

## Status

Phases P1–P4 are landed (see [`DESIGN.md` §17](plugins/orchestrate/DESIGN.md)).
Carried forward as deferred-with-ticket from the P1 whole-branch review: lease
acquire atomicity (TOCTOU → `mkdir`/`set -C` hardening), `TARGETS` comma-split,
and lease-key JSON escaping. Tests: `plugins/orchestrate/tests/run.sh` (zero
dependencies).
