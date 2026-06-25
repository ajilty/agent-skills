# Codex support: does the safety floor enforce, or only advise?

Status: **RESOLVED.** Verdict (live-probe verified, codex-cli 0.142.1): Codex's
PreToolUse hooks **BLOCK**: exit 2 plus the stderr contract is honored, and the wire
shape handed to the hook is Claude-Code-shaped (`tool_name`, `tool_input.command`). So
the runtime hooks enforce on Codex without a per-harness fork, and **full fail-closed
parity is feasible**, not merely advisory parity. Captured as ADR-0016; Codex-specific
limitations in `plugins/orchestrate/KNOWN-LIMITATIONS.md`.

Feasible after **three installer fixes** (the hooks themselves are unchanged):

1. **Persist hook trust (the load-bearing fix).** A wired Codex hook silently
   NO-OPS (**fails OPEN**) unless its sha256 is recorded as trusted in
   `[hooks.state]` (or the session runs `--dangerously-bypass-hook-trust`). Until
   trust is persisted the whole fail-closed floor is **inert**. The installer must
   write the per-hook trust entries at install time, not leave it to the operator.
2. **Rewrite the agent-role `.toml` schema.** Codex expects `developer_instructions`
   (not `instructions`) plus `model` and `model_reasoning_effort`. The current
   installer emits `instructions` and no model/effort, so the per-persona tiers are
   dropped. Map them: model `economy → gpt-5.4-mini`, `standard → gpt-5.4`,
   `premium → gpt-5.5`; effort `low/medium/high/xhigh`, with `max → xhigh` (Codex has
   no `max`, so the Verifier's max-effort lane degrades to `xhigh`).
3. **The `.command` held-out fix is already shipped (0.6.1).** `deny-heldout-read.sh`
   inspects `tool_input.command`, so a Writer can no longer read the held-out oracle by
   shelling out around the Read-tool path. Harness-neutral; no further Codex work.

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

Wire a single PreToolUse hook on Codex and have it exit 2 with a stderr message; check
whether the gated tool call is refused or proceeds.

Result (codex-cli 0.142.1): the call is **refused**. Codex honors exit 2 + stderr, and
the JSON it passes the hook is Claude-Code-shaped, so the hooks read it unchanged. The
floor is load-bearing on Codex, subject to hook trust (below).

## Open installer work (the three fixes)

1. **Hook trust.** Codex gates hook execution on a sha256 trust list in
   `[hooks.state]`; an untrusted hook fails open. The installer must persist trust at
   install time so the floor is live on first run rather than after a manual step.
2. **`.toml` schema.** Switch `instructions` → `developer_instructions`; add `model`
   and `model_reasoning_effort` from the persona `tier:` (model `economy/standard/
   premium → gpt-5.4-mini/gpt-5.4/gpt-5.5`; effort `low/medium/high/xhigh`, `max →
   xhigh`).
3. **Held-out `.command` read**: already shipped in 0.6.1.

## Notes and residuals

- `sandbox_mode` is coarse (`workspace-write`); results-only confinement is carried by
  `write-scope.sh`, and `writable_roots` can narrow the writable surface.
- Actuator credential confinement stays advisory on Codex as on every harness
  (ADR-0002); lease serialization is the only guaranteed layer.
- The runtime hooks and the `agents.yaml` contract are unchanged by any of this: the
  Codex-specific work is entirely in the installer.
