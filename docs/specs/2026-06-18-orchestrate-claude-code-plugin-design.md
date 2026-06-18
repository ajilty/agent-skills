# Orchestrate → Claude Code Plugin — Design Spec

> Status: design, pending operator review. Terms: see [`/CONTEXT.md`](../../CONTEXT.md).
> Decisions: see [`docs/adr/`](../adr/). This spec is the implementation-facing
> consolidation; the *why* of load-bearing choices lives in the ADRs it cites.

## 1. Goal

Package the `orchestrate` skill — its router brain, five capability-subtracted
personas, enforcement hooks, runtime, and typed entry point — as an installable
**Claude Code plugin**, distributed from a self-marketplace in this repo. The
plugin is a *distribution* of the existing system, not a redesign:
`references/agents.yaml` remains the single source of truth ([ADR-0001](../adr/0001-extend-orchestrate-not-augment-superpowers.md)),
and the Claude-Code-native artifacts are **generated and committed** beside it by
a build step.

Two long-standing TODO items fall out for free:

- The manual `settings.json` hooks paste **disappears** — plugin hooks register
  automatically when the plugin is enabled.
- Hook command paths become **machine-independent** via `${CLAUDE_PLUGIN_ROOT}`,
  closing the "installer should emit relative hook paths" item (TODO §Medium).

## 2. Scope

**In scope (v1):**
- A self-marketplace monorepo: repo-root `.claude-plugin/marketplace.json` cataloguing
  one plugin under `plugins/orchestrate/`.
- Relocating the `orchestrate` source tree under `plugins/orchestrate/`,
  structure intact.
- Transforming `install-claude-code.sh`'s generation logic into a `build` step
  that emits committed plugin artifacts.
- Hooks auto-wiring via a generated `hooks/hooks.json`.
- Typed entry point `/orchestrate:start`.
- Four new/refactored unit checks (drift, compiled allowlist, hook-path
  resolution, manifest validity) plus a documented live smoke test.

**Out of scope (v1), captured in `TODO.md`:**
- Other-harness plugin manifests (`.codex-plugin`, `.cursor-plugin`,
  `gemini-extension.json`, `.opencode`) — their schemas are unverified against
  current docs; **Codex/OpenCode keep their existing `install-*.sh` installers
  untouched** ([ADR-0001](../adr/0001-extend-orchestrate-not-augment-superpowers.md)
  compile-per-harness model stays per harness).
- Seed-dir / container / managed-image rollout (`CLAUDE_CODE_PLUGIN_SEED_DIR`).
- Submission to the official `anthropics/claude-plugins-official` directory.

## 3. Architecture

```
agent-skills/                              # repo root = one marketplace
├── .claude-plugin/
│   └── marketplace.json                    # catalog: source "./plugins/orchestrate"
├── plugins/
│   └── orchestrate/                        # self-contained Claude Code plugin (= ${CLAUDE_PLUGIN_ROOT})
│       ├── .claude-plugin/
│       │   └── plugin.json                  # GENERATED — name: orchestrate, version, metadata
│       ├── commands/
│       │   └── start.md                     # /orchestrate:start  (thin wrapper; brain stays in SKILL.md)
│       ├── agents/                          # GENERATED from agents.yaml
│       │   ├── researcher.md  planner.md  implementer.md  verifier.md  actuator.md
│       ├── hooks/
│       │   └── hooks.json                   # GENERATED — ${CLAUDE_PLUGIN_ROOT}-relative commands
│       ├── skills/
│       │   └── orchestrate/                 # SOURCE, moved intact
│       │       ├── SKILL.md                  #   router brain — internal relative refs unchanged
│       │       ├── references/{agents.yaml, resume.md, personas/*.md}
│       │       └── runtime/{ledger.sh, adr.sh, hooks/*.sh}
│       ├── scripts/
│       │   ├── build.sh                      # was install-claude-code.sh generation logic
│       │   ├── install-codex.sh              # unchanged behavior
│       │   └── install-opencode.sh           # unchanged behavior
│       ├── tests/                            # moved; run.sh self-locates
│       ├── DESIGN.md  TODO.md  README.md
└── docs/  CONTEXT.md  README.md
```

**Why subdir, not repo-root-as-plugin.** The repo is "a home for homegrown
agentic tooling" — plural. A `plugins/<name>/` layout lets each future tool be an
independently-versioned, independently-installable plugin, catalogued by a single
root `marketplace.json` (operator decision, 2026-06-18). Superpowers'
repo-root-as-plugin model was the alternative; rejected to keep tools isolated.

**Cross-plugin sharing rule (documented, unused in v1).** Claude Code copies a
plugin directory to a cache on install, so a plugin may not reference files
outside its own directory via `../`. The first time two plugins share a skill,
it lives once under repo-root `shared/skills/<name>/` and is **symlinked** into
each plugin's `skills/`. Not created in v1 (orchestrate is the only skill); the
rule is recorded so the constraint isn't rediscovered later.

## 4. The relocate (structure-preserving move)

The entire `skills/orchestrate/` tree moves to `plugins/orchestrate/skills/orchestrate/`
**with internal structure preserved**. This is path-safe because every script
self-locates:

- Hook scripts resolve their runtime siblings via `RT="$(cd "$(dirname "$0")/.." && pwd)"`.
- `install-codex.sh` / `install-opencode.sh` compute `SKILL_DIR` via
  `$(dirname "${BASH_SOURCE[0]}")/..`.
- `tests/run.sh` self-locates via `HERE="$(dirname "$0")"`; `lib.sh` sets
  `SK="$HERE/.."`.

Each of these keeps working as long as the tree moves intact and the scripts
travel with it. Plugin-level dirs (`agents/`, `hooks/`, `commands/`,
`.claude-plugin/`) are added as **siblings of `skills/`**, per Claude Code's
fixed plugin layout — they are not nested inside the skill.

**Runtime script location.** The runtime (`ledger.sh`, `adr.sh`, `hooks/*.sh`)
stays inside the skill at `skills/orchestrate/runtime/`. The generated
`hooks/hooks.json` references them as
`${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/runtime/hooks/<name>.sh`. SKILL.md's own
references to the runtime are unchanged by the move and must remain so (any path
the SKILL assumes is preserved verbatim).

## 5. The build step (`scripts/build.sh`)

`install-claude-code.sh`'s **generation logic is retained verbatim** where it
already works — the `cc_tools()` capability→tool-allowlist mapping and the
persona-body assembly (`body()` + frontmatter). What changes is the *target*:
instead of copying the skill into `~/.claude` and printing a hooks snippet to
paste, `build.sh` writes **committed artifacts** into `plugins/orchestrate/`:

1. **`agents/<persona>.md`** — for each persona in `agents.yaml`, frontmatter
   `name` / `description` / `tools:` (compiled by `cc_tools()`) followed by the
   persona body. Unchanged from today's installer output, just written to the
   in-repo plugin tree.
2. **`hooks/hooks.json`** — the same event→hook mapping the current README snippet
   documents, emitted as JSON:
   - `PreToolUse` matcher `Read|Bash` → `deny-heldout-read.sh`,
     `keep-on-branch.sh`, `gate-prod-apply.sh`
   - `SubagentStart` matcher `implementer|actuator` → `on-writer-dispatch.sh`
   - `SessionStart` matcher `compact` → `on-compaction.sh`
   - every command path is `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/runtime/hooks/<name>.sh`
3. **`.claude-plugin/plugin.json`** — `name: orchestrate`, `version`, description,
   author, homepage/repository. (Generated so version/metadata stay in one place;
   may also be hand-maintained if simpler — implementation choice for the plan.)

**`yq` becomes build-time-only.** It is required to run `build.sh`; the *installed*
plugin (committed artifacts + git + coreutils runtime) needs no `yq`.

**Committed, not built-on-install.** A marketplace install runs no build on the
user's machine, so the generated artifacts MUST be committed. The drift guard
(§7) is what keeps committed output honest against `agents.yaml`.

## 6. Entry point, naming, and `HELDOUT_ROOT`

**Entry point.** Plugin `name: orchestrate` makes the command namespace
`/orchestrate:`. The entry command file is `commands/start.md`; the operator types
`/orchestrate:start <goal>` to start and `/orchestrate:start` (no args) to resume.
The body is the existing thin wrapper — it points at the `orchestrate` skill as
the router brain and drives the numbered loop. The `commands/` form is kept (a
documented, accepted legacy layout) rather than converting to a user-invoked
skill; both namespace identically, so this is a file-layout choice with no
behavioral difference.

**`HELDOUT_ROOT`.** With no installer, there is no installer-stdout to remind the
operator to export `HELDOUT_ROOT` (the held-out test / live-probe oracle root,
outside the writer's tree). No behavior change — the reminder relocates to: (a)
the existing fail-closed runtime path (held-out read-deny / reground warns when an
ops or held-out lane needs it and it is unset), and (b) the plugin `README.md` +
repo `README.md`. The variable is still operator-exported in their shell/env; the
plugin documents it but cannot set it.

## 7. Testing

**7a — unit / build (zero-dependency, in `tests/run.sh`).** The CC half of
`test_install.sh` is re-pointed from "assert a `.claude` install" to "assert the
build output," and three checks are added. All four:

| Check | Catches |
|---|---|
| **Drift guard** | `agents.yaml` (or a persona body) edited without rebuilding — committed artifacts must equal a fresh `build.sh` run. |
| **Compiled allowlist** *(safety-critical)* | Each generated `agents/<persona>.md` carries exactly the `tools:` line `agents.yaml` implies (e.g. researcher: Read/Grep/Glob/WebSearch/WebFetch, no Write/Bash; actuator: Bash, no Write/Edit). Proves the build encodes the right *policy*, which the drift guard alone does not. |
| **Hook-path resolution** | A `${CLAUDE_PLUGIN_ROOT}/...` command in `hooks.json` pointing at a moved/renamed/non-executable script (the relocate footgun). |
| **Manifest validity** | `plugin.json` and `marketplace.json` are valid JSON; plugin `name` matches the command namespace; `marketplace.json` `source` resolves to an existing dir. |

The existing Codex/OpenCode assertions in `test_install.sh` are unchanged.

**7b — plugin validation & live trigger (documented steps, not in `run.sh`).**
- `plugin-validator` agent → manifest / structure / naming / security.
- `skill-reviewer` agent → the `orchestrate` SKILL.md description and triggering.
- **Live smoke test:** `claude --plugin-dir plugins/orchestrate` →
  - `/orchestrate:start` is invokable;
  - each of the five subagents loads with the **correct compiled `tools:`
    allowlist** (the one property unit tests structurally cannot reach — it proves
    Claude Code *honors* the subtraction, not just that the generator emits it);
  - hooks fire under `claude --debug`, in particular the `PreToolUse` gate denying
    an Actuator apply against an unacked prod target.

## 8. Migration impact (files that change paths or content)

- **Move:** `skills/orchestrate/**` → `plugins/orchestrate/skills/orchestrate/**`
  (runtime, references, SKILL.md, personas, resume) and the scripts/tests/docs
  that travel with it (`scripts/install-codex.sh`, `install-opencode.sh`,
  `tests/`, `DESIGN.md`, `TODO.md`).
- **Transform:** `install-claude-code.sh` → `scripts/build.sh` (generation logic
  retained; target changed).
- **Generate (new, committed):** `plugins/orchestrate/agents/*.md`,
  `hooks/hooks.json`, `.claude-plugin/plugin.json`, and repo-root
  `.claude-plugin/marketplace.json`.
- **Rewrite:** the CC assertions in `tests/test_install.sh` (→ build/drift/
  allowlist/hook-path/manifest checks).
- **Doc updates:** path references in `README.md`, `CONTEXT.md`, and any ADR that
  points at `skills/orchestrate/...` (mechanical). Install instructions in
  `README.md` change to the marketplace flow (`/plugin marketplace add
  ajilty/agent-skills`, Git form only — relative `marketplace.json` paths fail
  when added by raw URL).

## 9. ADRs to add

- **Plugin packaging is a generated distribution of the agents.yaml contract.**
  The plugin's Claude-Code-native artifacts are build output committed to the
  repo; `agents.yaml` stays the single source of truth. (Extends ADR-0001 to the
  plugin form.)
- **Subdir-plugin monorepo over repo-root-as-plugin.** Each tool is an
  independently-versioned plugin under `plugins/<name>/`, catalogued by one root
  marketplace; cross-plugin skills shared via repo-root `shared/` + symlinks, never
  `../`.

## 10. Risks & mitigations

- **Committed generated files drift from source.** → Drift-guard unit check (§7a)
  fails CI if `agents.yaml` changes without a rebuild.
- **Relocate breaks a script's relative path.** → All known scripts self-locate
  (§4); hook-path-resolution check (§7a) and the full `run.sh` suite (56/56) guard
  the move.
- **Generated allowlist silently wrong but self-consistent.** → Compiled-allowlist
  check (§7a) tests policy independently of drift; live smoke test (§7b) confirms
  the harness honors it.
- **`marketplace.json` relative source fails on raw-URL add.** → Document Git-form
  install only.
