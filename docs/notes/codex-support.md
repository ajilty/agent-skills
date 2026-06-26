# Codex support: does the safety floor enforce, or only advise?

Status: **RESOLVED.** Verdict (live-probe verified, codex-cli 0.142.1, `codex exec`
headless): Codex's PreToolUse hooks **BLOCK for the MAIN agent's hooked tools** (exit 2
plus the stderr contract is honored; the wire shape is Claude-Code-shaped:
`tool_name`, `tool_input.command`). They do **NOT** fire inside a spawned subagent. So
this is **scoped enforcement, not full parity**: a spawned persona's confinement on Codex
rests on its role `sandbox_mode` + capability subtraction, not on the per-persona hooks.
Captured as ADR-0016; limitations in `plugins/orchestrate/KNOWN-LIMITATIONS.md`.

What bounds the claim:

- **PreToolUse does not fire in a spawned subagent (still open).** `write-scope`,
  `keep-on-branch`, and `deny-heldout-read` do not see a dispatched persona's own tool
  calls on Codex, so the per-persona hook floor is a **main-agent** floor here.
  Spawned-persona confinement is `sandbox_mode` + capability subtraction. Claude Code keeps
  the stronger per-persona floor (PreToolUse fires for subagent tool calls there).
- **`apply_patch` — RESOLVED (0.7.1).** The matcher now includes `apply_patch` and
  `write-scope.sh` parses the patch body to confine every target (any out-of-scope target
  denies the patch); verified live. This closed the main-agent bypass; a spawned persona's
  `apply_patch` is still unhooked (the gap above).

Installer status (0.7.0–0.7.1):

1. **`.toml` schema + tiers — DONE.** The installer emits `developer_instructions` (not
   `instructions`) plus `model` and `model_reasoning_effort` per persona. This is the
   **only** carrier of the tiers on Codex, since SubagentStart is inert in `codex exec`
   headless. Map: model `economy → gpt-5.4-mini`, `standard → gpt-5.4`, `premium →
   gpt-5.5`; effort `low/medium/high/xhigh`, `max → xhigh` (no Codex `max`, so the
   Verifier's max-effort lane degrades to `xhigh`). Validated live under `codex exec
   --strict-config` (zero malformed-role errors; the old schema reproduces the bug).
2. **Hook trust — SEEDED + self-verified (DONE).** A wired Codex hook fails OPEN unless
   trusted in `[hooks.state]`. The installer now seeds trust automatically, and **never
   guesses the hash**: it asks codex for the value codex itself computes (`codex
   app-server` → `hooks/list` → `currentHash`), then **self-verifies** that a hook
   actually fires with no `--dangerously-bypass-hook-trust`. On drift (key/hash format
   change) it strips the seeds and falls back loudly to the manual paths — structurally
   incapable of silently failing open. `docs-only` when codex/auth is absent at install.
3. **`apply_patch` matcher + parser — DONE (0.7.1).** Matcher widened to include
   `apply_patch`; `write-scope.sh` parses the patch body (`*** Add/Update/Delete File:`,
   `*** Move to:`) to confine every target, fail-closed on any out-of-scope path. The same
   change made `write-scope` tool-aware (the shared Codex matcher no longer makes it deny a
   confined persona's reads/test-runs). Verified live end-to-end (out-of-scope apply_patch
   write blocked with trust seeded, no bypass).

The `.command` held-out fix already shipped (0.6.1): `deny-heldout-read.sh` inspects
`tool_input.command`, denying a Writer reading the oracle by shelling out around the
Read-tool path. Harness-neutral. Per the spawned-subagent gap, on Codex this covers only
the main agent; a spawned persona's shell reads are bounded by `sandbox_mode`.

The plan body below is the original trail, kept for the reasoning and the wiring detail.

---

## Goal

Confirm whether the orchestrate plugin's harness-neutral contract (`agents.yaml`
compiled by `scripts/install-codex.sh`) reaches the **same fail-closed guarantees**
on Codex that it has on Claude Code, or whether Codex can only run the floor in an
advisory mode. The single-writer leases, the pre-apply gate, held-out-read denial,
and write/run-scope confinement are all enforced by **PreToolUse hooks** that, on
Claude Code, block a tool call by exiting non-zero with a stderr contract. The whole
question reduces to: does a wired PreToolUse hook on Codex **block**, or only log?

## What the installer compiles today

`install-codex.sh` compiles the portable skill into `~/.codex`:

- one `agents/<persona>.toml` per persona (sandbox derived from
  read/write/run capabilities: `read-only` when write and run are both `none`, else
  `workspace-write`),
- the runtime payload (`ledger.sh` + the hook scripts) under
  `orchestrate-runtime/`,
- the router brain as `AGENTS.orchestrate.md` for inclusion into `AGENTS.md`,
- and printed `config.toml` stanzas wiring the PreToolUse / SubagentStart /
  PostCompact hooks.

The PreToolUse matcher is `^(Read|Edit|Write|Bash)$`, fronting
`deny-heldout-read.sh`, `keep-on-branch.sh`, `gate-prod-apply.sh`, `write-scope.sh`,
and `run-scope.sh`. Writer write-ahead (`on-writer-dispatch.sh`) is wired on
SubagentStart for `implementer|actuator`; compaction recovery
(`on-compaction.sh`) on PostCompact.

## The probe

Wire a PreToolUse hook on Codex, have it exit 2 with a stderr message, and check
whether the gated tool call is refused or proceeds, both for the **main agent** and for
a **spawned subagent**; also check which tools the matcher sees and whether
SubagentStart fires headlessly.

Results (codex-cli 0.142.1, `codex exec` headless):

- **Main-agent hooked tool: refused.** Codex honors exit 2 + stderr, and the JSON it
  passes the hook is Claude-Code-shaped, so the hooks read it unchanged. Load-bearing
  for the main agent's hooked tools, subject to hook trust (below).
- **Spawned-subagent tool call: not seen.** PreToolUse does **not** fire inside a
  spawned subagent, so `write-scope`/`keep-on-branch`/`deny-heldout-read` do not confine
  a dispatched persona's own calls. That confinement is `sandbox_mode` + capability
  subtraction only.
- **`apply_patch`: not matched.** Codex top-level writes surface as `apply_patch`, which
  the `^(Read|Edit|Write|Bash)$` matcher misses, so main-agent `apply_patch` writes
  bypass `write-scope`.
- **SubagentStart: inert headlessly.** It does not fire in `codex exec`, so the
  per-subagent model-override hook is dead; the role `.toml` `model` field sets the tier
  instead (verified working).

## Open installer work

1. **Hook trust.** Codex gates hook execution on a sha256 trust list in
   `[hooks.state]`; an untrusted hook fails open. The installer must persist trust at
   install time so the floor is live on first run rather than after a manual step.
2. **Widen the PreToolUse matcher** to include `apply_patch` so main-agent writes are
   scoped.
3. **`.toml` schema.** Switch `instructions` → `developer_instructions`; add `model`
   and `model_reasoning_effort` from the persona `tier:` (model `economy/standard/
   premium → gpt-5.4-mini/gpt-5.4/gpt-5.5`; effort `low/medium/high/xhigh`, `max →
   xhigh`). This is the only carrier of the tiers, since SubagentStart is inert headlessly.
4. **Held-out `.command` read**: already shipped in 0.6.1.

The spawned-subagent PreToolUse gap is **not** an installer fix: it is a Codex behavior.
On Codex the per-persona hook floor is a main-agent floor, and a spawned persona is
confined by its role `sandbox_mode` + capability subtraction. Claude Code keeps the
stronger per-persona floor.

## Notes and residuals

- `sandbox_mode` is coarse (`workspace-write`). For the main agent, results-only
  confinement is carried by `write-scope.sh` and `writable_roots` can narrow it. For a
  spawned persona, `sandbox_mode` is the primary confinement (the hook does not fire).
- Actuator credential confinement stays advisory on Codex as on every harness
  (ADR-0002); lease serialization is the only guaranteed layer.
- The runtime hooks and the `agents.yaml` contract are unchanged by any of this: the
  Codex-specific work is entirely in the installer.
