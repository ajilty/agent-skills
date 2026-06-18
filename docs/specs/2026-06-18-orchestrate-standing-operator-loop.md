# Orchestrate → Standing Operator Loop — Design Spec

> Status: design, pending operator review. Terms: see [`/CONTEXT.md`](../../CONTEXT.md).
> Decisions: see [`docs/adr/`](../adr/). This spec is the implementation-facing
> consolidation; ADRs hold the *why* of each load-bearing choice.

## 1. Goal

A single standing loop the operator feeds goals of any altitude — from "bump the
conn limit" to "deploy app A on cluster B" to "ensure prod restores from backup"
— that decomposes and executes them with discipline, survives interruption
without losing its place, remembers its judgment across goals, and gates
consequential actions before they touch prod.

This is an **augmentation of the existing `orchestrate` skill**
([`skills/orchestrate/`](../../skills/orchestrate)), not a new system
([ADR-0001](../adr/0001-extend-orchestrate-not-augment-superpowers.md)). The
throughline: one new persona (the Actuator) and one redefinition (single-writer
over *mutation targets*) absorb every requirement; the rest reuses rails
orchestrate already has.

## 2. Relationship to orchestrate and superpowers

- **orchestrate is the loop and the executor.** Its router, personas, capability
  compiler, hooks, ledger, reground, and trust quarantine are kept as-is and
  widened.
- **superpowers / mattpocock skills are borrowed by reference for the front-end**
  — interactive ambiguity resolution only. They are never executors, and their
  control-flow handoffs are suppressed
  ([ADR-0004](../adr/0004-router-owns-sequencing.md)).
- `superpowers:subagent-driven-development` and `executing-plans` are **not used**
  — orchestrate's enforced lanes replace them, which also keeps a single ledger.

## 3. Personas

Existing: Researcher (read+web), Planner (read+write-spec), Implementer
(read+write+run, single source writer), Verifier (read+run-tests). Added:

**Actuator** — the single writer for *downstream mutations* to a live
environment. Capabilities: `{ read: true, write: none, run: full, web: false }`
plus **target-scoped credentials injected per dispatch**. It edits no source (it
acts via `run`: `terraform apply`, `kubectl apply`, migrations); it holds creds
only for the targets it has leased. Renamed from "Operator" to avoid colliding
with the human **operator** (see `CONTEXT.md` flagged ambiguities).

`agents.yaml` gains an `actuator` persona block; the installers compile it like
the others (Claude Code: `tools: Read,Grep,Glob,Bash`; Codex: `workspace-write`
+ scoped env; OpenCode: per-agent allow). The `branch_guard` hook does not apply
to it (no worktree branch); its discipline is the lease + cred scoping.

## 4. Lanes

- **Coding lane** (unchanged): Researcher → Planner → Implementer → Verifier →
  merge. Deliverable: a reviewed diff merged by branch glob.
- **Ops lane** (new): Researcher → Planner → Actuator → Verifier. Deliverable:
  observed live state; no merge.
- **Two-phase IaC** (composition): a goal with infrastructure-as-code decomposes
  into `[Implementer: edit + commit manifests → reviewed diff]` then
  `[Actuator: apply to leased target → live-probe verified]`. The reviewable
  change is gated as a diff *before* the live mutation. Pure-ops goals (no source)
  skip the Implementer. The Planner decides which lanes a goal needs and expresses
  the apply-after-diff order via a new `depends_on` field on tasks.

## 5. Single-writer over mutation targets

[ADR-0002](../adr/0002-single-writer-over-mutation-targets.md). The rail is no
longer "one writer per disjoint file-set" but **one writer per disjoint mutation
target**.

- **Declare.** The Planner's spec gains `mutation_targets:` per task/group —
  e.g. `tfstate:prod/network`, `k8s:clusterB/app`, `db:orders-primary`. Lease key
  format is `<kind>:<scope>`; disjointness is set-disjointness over keys, checked
  like the existing grep-backed independence proof. Undeclared/undeterminable
  target → **fail-closed → serialize**.
- **Lease.** Generalize the per-ticket lease to per-target leases at
  `.agents/runs/orchestrate/leases/<key>`. The loop (via the extended
  `on-writer-dispatch.sh`, which now recognizes `{implementer, actuator}`)
  acquires every declared target's lease before dispatching a writer; an
  overlapping target serializes that writer. **Serialization is deterministic and
  guaranteed.**
- **Confine (best-effort).** The loop injects only the leased targets'
  credentials/backend config into the writer's dispatch. A writer cannot
  authenticate to an unleased target. This is **advisory, not guaranteed** — it
  depends on per-target credential isolation and a clean writer environment (no
  ambient creds), which is a deployment responsibility the spec states but cannot
  enforce, exactly like the §8 network boundary. Per-dispatch injection uses the
  best mechanism the harness offers (scoped profile / env-file / lease-checking
  broker); where unavailable, the spec declares confinement advisory.
- **Backstops.** Defense-in-depth, no single sufficient layer: lease + creds +
  the reviewed diff + the Verifier's independent probe + downstream-breakage
  check.

## 6. The ops oracle — live probe as held-out

[reuses orchestrate §7/§7a]. "Done" for an ops goal is proven by an executable
**acceptance probe** the Planner authors and the Verifier runs:

- The probe lives under `$HELDOUT_ROOT` (outside the Actuator's readable tree),
  handed to the Verifier only at dispatch — it **is** the held-out test, the live
  environment **is** the boundary the writer can't cross.
- The probe is self-contained (setup scratch → assert → teardown) and declares
  its **own** target lease (e.g. `scratch-ns`) so it cannot collide with the
  Actuator's targets. Its observation credentials are scoped to the Verifier lane
  only — the Actuator holds none.
- Verdicts are unchanged: `APPROVED` (exit 0) / `REJECTED` (exit ≠ 0, with
  captured output) / `INCONSISTENT_ORACLE` (probe contradicts the goal → human).

Example ("ensure prod restores from backup"): probe = restore latest backup into
a scratch namespace, assert row counts + checksums, tear down. The Actuator
performs the real restore drill on its leased targets; it cannot fake a result it
has no path to produce.

## 7. Intake: clarification step, skill stitching, ambiguity gate

- **Ambiguity-gated, not size-gated.** The loop always attempts intake
  autonomously. The Planner attempts sign-off (its existing bar: no open
  `#UNKNOWN`, oracle definable). A clear goal of *any* altitude proceeds without
  pausing.
- **Clarification step.** Only when intake leaves blocking `#UNKNOWN`s does the
  router invoke the configured clarification skill (preference order
  `grill-with-docs` → `grill-me` → `brainstorming` → inline), in the **router
  context** (only it talks to the operator), **scoped to those unknowns**.
- **Router-owned sequencing** ([ADR-0004](../adr/0004-router-owns-sequencing.md)):
  sub-skills are invoked for their work; their terminal handoffs are ignored.
- An irreducible call surfaces as `DECISION_FORK`, not clarification.

## 8. Pre-apply consequence gate

Distinct from intake; fires at **execution time**, right before the Actuator
mutates a target.

- The Planner tags each mutation target with a **consequence level**
  (`prod | safe`).
- Before the Actuator applies to a `prod`-level target, the loop **pauses for
  operator ack**, showing the planned action and the already-reviewed diff.
- `safe` targets proceed autonomously. **Fail-closed:** undeclared/unknown
  consequence is treated as `prod` → ack.
- This is independent of the deferred harness prod-classifier (§11); when that
  exists it can set the flag. Until then the Planner tags conservatively or the
  operator pre-declares prod targets.

## 9. Judgment memory

[ADR-0003](../adr/0003-judgment-memory-in-repo-not-harness.md). In-repo, tracked,
harness-neutral.

- **Home:** `docs/adr/` records + `docs/adr/INDEX.md` (one line per decision).
- **Capture:** every `DECISION_FORK` resolution and signed `#DECISION` is recorded
  to `board.jsonl` (machine, complete). Those meeting the ADR bar
  (hard-to-reverse + surprising + real trade-off) are **promoted to a tracked
  ADR**, operator-gated at fork-resolution: the loop proposes a pre-filled ADR;
  the operator accepts / edits / declines.
- **Recall:** the Planner reads the index at intake and does not re-litigate an
  active decision; a contradicting direction raises a `DECISION_FORK` citing the
  ADR (supersede flow).
- An ADR whose justification traces to `UNTRUSTED` provenance is invalid (§0
  rule).

## 10. Filesystem layout

[ADR-0005](../adr/0005-filesystem-two-axis-split.md).

```
docs/
  specs/YYYY-MM-DD-<topic>.md     TRACKED — brainstorming/clarification output (the record)
  adr/NNNN-slug.md + INDEX.md     TRACKED — judgment memory (cross-goal)
.agents/                          GITIGNORED — one entry; all machine/control state
  runs/orchestrate/board.jsonl    control ledger (single source of truth)
  runs/orchestrate/tickets/<t>/   per-ticket bus (read-only spec snapshot + plan, lease)
  runs/orchestrate/leases/<key>   per-mutation-target leases
  worktrees/<t>-<persona>/
```

## 11. Deferred & known limitations

- **Prod classifier deferred** to the harness; the pre-apply gate + reviewed diff
  recover most value meanwhile.
- **Confinement is advisory** (§5): structural credential isolation and a clean
  writer environment are deployment responsibilities; serialization is the only
  guaranteed part of the writer rail.
- **Single router per repo** (orchestrate §15) is unchanged; target leases live
  within one router's loop.
- **Per-dispatch credential injection** mechanism is harness-dependent; where a
  harness cannot inject scoped creds, confinement degrades to advisory and the
  spec must say so.

## 12. File-level change map (for writing-plans)

- `skills/orchestrate/references/agents.yaml` — add `actuator` persona;
  `mutation_targets` + `consequence` + `depends_on` to the Planner contract; lease
  vocabulary for targets; clarification-skill preference binding.
- `skills/orchestrate/references/personas/` — add `actuator.md`; extend
  `planner.md` (mutation_targets, consequence levels, ops oracle/probe authoring,
  folded writing-plans decomposition discipline) and `verifier.md` (run the live
  probe).
- `skills/orchestrate/SKILL.md` — intake clarification step + router-owned
  sequencing; ops lane + two-phase IaC; mutation-target leasing; pre-apply
  consequence gate; judgment-memory recall/capture; two-axis filesystem.
- `skills/orchestrate/scripts/runtime/hooks/on-writer-dispatch.sh` — recognize
  `actuator`; per-target leases.
- `skills/orchestrate/scripts/runtime/ledger.sh` — target-lease reground;
  decision recording helper.
- `skills/orchestrate/scripts/install-*.sh` — compile the `actuator` persona and
  any new capability/credential wiring per harness.
