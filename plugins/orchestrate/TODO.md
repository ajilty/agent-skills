# orchestrate — backlog (open items)

What to pick up next, captured so we don't lose the thread. As of 2026-06-22.
The orchestrate plugin (packaging + enforcement hooks) is merged to `main` and
published via the repo's self-marketplace. Tests: `tests/run.sh` (176/176, zero-dep)
+ `tests/integration/run.sh` (real-CLI / live-agent, FS-isolated, gated).

## Process lesson — do this every batch (not optional)

**Run a fresh-context, whole-range review before calling any batch "done."** It has
caught a **Critical three times** during this build — each a cross-cutting or
runtime bug that inline self-review *and* the green unit suite missed:

- P1 — `lease-release` was wired nowhere (dead half of a lifecycle).
- P3 — the pre-apply gate was bound to `SubagentStart`, a *non-blocking* event, so
  it enforced nothing on Claude Code / Codex.
- P2 — `adr.sh reindex` aborted under `set -e` on body-prose "supersede" and
  truncated the index — **green in tests, broken on the real repo.**

Inline implementation is fast and fine; the adversarial whole-view pass is the
gate. This mirrors the skill's own thesis (single writer + independent
fresh-context Verifier) — validated on its own construction.

## High priority

- ✅ **DONE — Hooks read CC's stdin JSON (not env); PreToolUse enforcement is REAL
  under CC.** Landed part-1 (03a3ced, stdin parse) + part-2 (40bcf5b, ADR-0006
  on-disk active-writer record); the live smoke test (2026-06-19) confirmed all 3
  PreToolUse hooks fire on a dispatched writer's Bash call. _Original problem (kept
  for history):_ CC delivers
  the hook payload on **stdin** (`tool_name`, `tool_input`, `session_id`, `cwd`,
  and inside a subagent `agent_id`/`agent_type`). There is **no `CLAUDE_AGENT_TYPE`
  env var** (only `$CLAUDE_EFFORT`). Our hooks read `PERSONA`/`RESOLVED_PATH`/
  `TOOL_INPUT` env, which CC never sets → the PreToolUse hooks (held-out,
  branch-guard, prod-gate) always hit the "not a writer" path and **allow** — they
  no-op under CC (safe, but not enforcing). Fix: parse stdin JSON
  (`agent_type` for persona, `tool_input.command` for Bash, `tool_input.file_path`
  for Read), keeping the env reads as the Codex/OpenCode fallback. Match
  `agent_type` against the agent's frontmatter `name`.
  - **Per-dispatch context is the harder half (ADR-worthy).** The prod-gate needs
    `PROD_TARGETS` and branch-guard needs `ASSIGNED_BRANCH` *per dispatch* — set by
    the router as env, but CC subagent hooks receive only the stdin payload, not
    router-set env. So the hooks must read orchestrate's **on-disk artifacts**
    (the ticket spec's `mutation_targets`/`consequence`, the assigned branch)
    keyed by `agent_id`/`cwd` — "disk is the source of truth" applied to the hook
    layer. With this: held-out works once stdin-parsed (HELDOUT_ROOT is
    session-global); gate + off-branch-commit need the disk lookup.
  - **Still holds regardless of the hook layer:** capability allowlists (native CC
    per-agent `tools:`) and the filesystem held-out isolation — the load-bearing
    guarantees never depended on these hooks.
  - History: the env-var assumption first crashed the session (bare `${VAR:?}`),
    then (after the exit-code fix) was found to silently no-op. The generalized
    `test_hooks_safety.sh` floor catches the crash class; making enforcement real
    needs the stdin-parse + disk-lookup above.

- **Codex / OpenCode command parity (still open).** The Claude Code plugin ships
  `commands/start.md` → `/orchestrate:start`; the other two harnesses don't yet.
  Add a Codex prompt (`~/.codex/prompts/orchestrate.md`) and an OpenCode command
  so the typed entry point works everywhere. (`SKILL.md` is already the shared
  brain; these are thin wrappers.)

## Part-2 follow-ups (verifier-flagged)

- ✅ **DONE — `reground` HALTs on a dangling `active-writer.json`.** reground block
  (d) surfaces a leftover record (router crashed between `writer-ctx set` and
  `clear`) as an ambiguous in-flight writer → HALT (exit 3); the operator/router
  clears it on reconcile. Chose HALT over auto-clear because at compaction the
  record may belong to a live writer. Closes the stale-ack gate-bypass window.
- ✅ **DONE — overwrite test** for `writer-ctx set` (the per-dispatch refresh).
- **active-writer `persona` field is written but never read** (minor). Either use
  it as a gate cross-check (`record.persona == actuator` before applying its
  prod_targets) or drop the field. Benign under single-writer; currently dead.

## Medium

- ✅ **DONE — portable hook paths (Claude Code).** The plugin auto-registers hooks
  via `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}`-relative commands — machine-
  independent and committed, no `settings.json`/`settings.local.json` snippet to
  paste. The Codex/OpenCode installers still print absolute paths in their config
  snippets (their `${...}` equivalents remain a follow-up for those harnesses).


- **Subagent instances must be well-named (descriptive, consistent pattern) —
  especially under Claude Code; never the generic `general-purpose`.** Every
  dispatched subagent should carry a clear, consistent label/type so the operator
  can tell at a glance which lane/persona is running (e.g. `orchestrate:researcher`,
  `verify:test-suite`) rather than an opaque `general-purpose`. The plugin's five
  personas are already named; this convention must also cover any helper/verification
  dispatches the loop or its tooling spawns. Define the naming pattern and apply it
  wherever the router (or supporting scripts/workflows) dispatches a subagent.

- **Standard `/orchestrate:status` command — read-only board/WIP summary for
  returning operators.** A slash command (sibling to `/orchestrate:start`) that
  prints the current work-board at a glance *without dispatching or advancing any
  lane*: open lanes + their persona/column, in-flight writer(s), halted
  `DECISION_FORK`s / quarantines awaiting the operator, held leases, and anything
  needing an ack/decision. Build on the existing `ledger.sh reground` + `board.jsonl`
  primitives (read-only view, not the full loop). **Rationale:** the operator runs
  many things at once and may have long gaps between check-ins — today re-grounding
  means running the loop or reading the ledger by hand; a one-shot status view lets
  them re-orient instantly. Mirror to Codex/OpenCode per the command-parity item.

- **Lease acquire atomicity (TOCTOU).** `ledger.sh lease-acquire` is
  check-then-write; two concurrent acquires of a free target could both win.
  Replace with an atomic claim (`mkdir` lockdir, or `set -C`/noclobber `O_EXCL`).
  **Required before lifting "single router per repo"** (SKILL §15) — today the
  single-router + lease-check-before-dispatch model makes the window unreachable,
  which is why it's deferred, not fixed.

## Low (deferred-with-ticket from the P1 whole-branch review)

- **`TARGETS` comma-split.** `on-writer-dispatch.sh` word-splits on whitespace
  only, but the interface doc said "space- or comma-separated." Normalize
  (`tr ',' ' '`) or pin the contract to space-only — **do it when the router
  emitter that populates `TARGETS` lands**, so both ends agree. Currently
  unreachable (nothing emits `TARGETS` yet).
- **Lease-key JSON escaping.** Lease files and the `gate-blocked`/`lease-conflict`/
  `decision` events embed `$key` via unescaped `printf`. Safe for the
  `<kind>:<scope>` charset today; add escaping (or reject out-of-charset keys at
  the boundary) **only if keys ever become free-form/user-supplied.**
- **`adr.sh` `add` / `reindex` double-maintenance.** `add` appends an INDEX row
  incrementally *and* `reindex` rebuilds from files; harmless when they agree, but
  the index header differs by which ran last. Optionally make `add` call `reindex`
  so there's a single index-maintenance path ("files are source of truth").
- **Generated vs hand-authored ADR body format.** `adr.sh add` writes
  `_Status: active_`; hand-authored ADRs use `## Status` / no status line. Cosmetic
  (supersede/reindex key on the status line, not the format), but worth aligning.

## Plugin-validation follow-ups (Task 8, 2026-06-18)

- ⚠️ **CONFIRMED (live test 2026-06-19) — `SubagentStart` does NOT fire under Claude
  Code** (CC 2.1.181). A real subagent dispatch (`claude --plugin-dir … --debug`)
  shows the 3 PreToolUse hooks firing on the writer's Bash call, but `SubagentStart`
  never appears in the debug log — so the write-ahead `on-writer-dispatch.sh`
  (deterministic `dispatched` event + lease) does **not** run via hook on CC.
  **Not a safety hole:** the safety floors (capability allowlist, held-out deny,
  branch guard, prod gate) all ride PreToolUse, which works. **Fix:** move the
  write-ahead to a `PreToolUse` matcher on the writer `Task` dispatch, or have the
  router do it in-loop (the installers' fallback comment already notes this).
  Codex/OpenCode subagent-start event names still need confirming per harness.
- ✅ **DONE — stale `scripts/install-<harness>.sh` refs in internal comments fixed.**
  Persona bodies (`references/personas/*.md`) and `references/agents.yaml` now say
  "the per-harness generators (build.sh / install-*.sh)" instead of a nonexistent
  install script; `agents/` rebuilt so the compiled prompts match (drift green).

## Testing coverage (tiers)

**Tier 1 — zero-dep bash suite** (`tests/run.sh`, 176/176, CI). Runtime logic (A);
generation/contract — allowlist, drift, hook-path, contract-parity, manifest (B);
dependency/reference integrity — persona `body:` existence + SKILL/persona nav-ref
resolution (`test_integrity.sh`); installer smoke — all 5 personas + codex
sandbox_mode mapping (`test_install.sh`); and the namespaced-persona regression
(`test_hooks_safety.sh`). Hermetic, no `claude`/API.

**Tiers 2 + 3 — integration suite** (`tests/integration/run.sh`; NOT on the per-push
gate; self-skips without `claude`/auth). Filesystem-isolated at the **HOME + cwd**
level — never via harness config knobs (CLAUDE_CONFIG_DIR/--scope only redirect user
config, so a `claude` run inside a project still writes a project-scope `.claude/`):
- **Tier 2 plugin-install smoke** (`test_plugin_install.sh`) — real `claude` CLI:
  validate + marketplace add + install + details inventory. Sandboxed HOME, no API.
- **Tier 3a mechanical invocation** (`test_invocation.sh`) — live dispatch: actuator
  dispatched, Bash lane works, allowlist excludes Write/Edit, SubagentStart sentinel.
- **Tier 3b safety eval** (`test_safety_gate.sh`) — live: the pre-apply gate blocks a
  real actuator prod mutation (hard-gate; skips on model-decline). **This eval caught
  the namespaced-`agent_type` bug** that left ALL hook enforcement hollow under the
  plugin (now fixed — git 355c153).

A containerized variant (Docker + pinned `claude` + version matrix) is a future
hardening for fully-hermetic CI of Tiers 2/3; the local FS-isolated form is the
current vehicle. Live tiers need OAuth (real ~/.claude) or `ANTHROPIC_API_KEY`.

Not yet built:
- **Effectiveness A/B eval (Tier 3c).** Golden fixtures {seed, goal, held-out
  oracle, safety invariants} run through the pattern vs a naive single-agent baseline;
  score outcomes vs the oracle and count safety violations. Safety = hard gate,
  quality = threshold/trend. Heaviest; needs fixture format + scoring runner + baseline.

- ✅ **RESOLVED/WATCH — Issue B (`orchestrate:*` agents don't survive resume/reload).**
  Not reproducible on CC 2.1.186: interactive probe returns RESEARCHER_OK on fresh +
  post-`/exit` + resumed sessions, `/reload-plugins` shows the full 21 agents (no drop);
  headless suite passes. Likely a since-fixed harness bug or transient. Runbook retained
  to re-verify if it recurs. Original investigation below (kept for context):
  Observed (CC 2.1.x, interactive): the plugin's five agents register only at the
  first session-start after install; on resume they drop ("no longer available"), and
  `/reload-plugins` reloads skills+hooks but NOT agents (deltas 21→16 agents, 11→10
  plugins — the −5 are the personas). `subagent_type: orchestrate:researcher` → "not
  found" on resume.
  **INVESTIGATED (2026-06-23) — narrowed to the interactive harness, NOT the plugin.**
  Built `tests/integration/test_resume_registration.sh` (installed plugin in a
  credential-cloned sandbox HOME → `claude -p` session 1 → `claude -p -c` resume →
  dispatch `orchestrate:researcher`). Result: resume **kept** the agent dispatchable
  (RESEARCHER_OK both sessions); a stale `enabledPlugins:{orchestrate@ghost}` entry did
  **not** break the real install/load. So it does NOT reproduce headlessly — because
  each `claude -p` is a fresh process that re-initialises plugins and re-registers
  agents every time. That rules out the plugin artifacts/config and stale-enable as the
  cause and pins Issue B to the **interactive `--resume`/`--continue` TUI path** —
  agent-types register at interactive session-start and interactive resume doesn't
  re-run that step. **Likely a CC harness limitation, not an orchestrate fix.** Open:
  (a) confirm via claude-code-guide whether explicit agent enumeration in plugin.json
  (vs auto-discovery) changes interactive-resume registration, and whether
  `/reload-plugins` is meant to re-register agents; (b) the minimal operator step
  (a fresh interactive session re-registers — their evidence #1; `/reload-plugins` did
  not) — verify interactively by an actual dispatch (can't be done headlessly).
  **Interactive verification runbook (probes + results table):**
  `docs/issue-b-resume-registration-verification.md`.

## Watch (acceptable as-is, but depends on loop discipline)

- **`decision` event + ADR capture are router loop-steps, not hooks.** Like
  `returned`/`verdict`, they're appended by the router as it drives (now real
  callables: `ledger.sh decision`, `adr.sh add`), not enforced by a hook — because
  fork-resolution is operator-interactive. Acceptable, but if judgment memory ever
  fails to accumulate, this is the first place to look (the router skipped the step).

## Out of scope (plugin packaging v1 — deferred, spec §2)

- **Other-harness plugin manifests** (`.codex-plugin`, `.cursor-plugin`,
  `gemini-extension.json`, `.opencode`). Their schemas are unverified against
  current docs; Codex/OpenCode keep their existing `install-*.sh` installers
  untouched (ADR-0001 compile-per-harness model stays per harness).
- **Seed-dir / container / managed-image rollout** (`CLAUDE_CODE_PLUGIN_SEED_DIR`).
- **Official-directory submission** to `anthropics/claude-plugins-official`.

## Not skill work (operational)

- The orchestrate plugin is merged to `main` and pushed to `origin`
  (github.com/ajilty/agent-skills); installable in any repo via
  `/plugin marketplace add ajilty/agent-skills` then
  `/plugin install orchestrate@ajilty-agent-skills`.
