# Codex reaches full fail-closed parity because its PreToolUse hooks block, but only once hook trust is persisted

orchestrate's safety floor is a set of fail-closed PreToolUse hooks (held-out-read
denial, branch-keep, pre-apply gate, write-scope, run-scope). On Claude Code these
**block** a tool call by exiting non-zero with a stderr contract. The open question
for Codex was whether the same hooks are advisory (logged, ignored) or load-bearing
(actually deny the call). If Codex only logged them, Codex parity would top out at
advisory and the single-writer guarantees would be Claude-Code-only.

A live probe settles it (codex-cli 0.142.1). A wired PreToolUse hook on Codex
**blocks**: exit 2 plus a stderr message is honored, and the wire shape Codex hands
the hook is Claude-Code-shaped (`tool_name`, `tool_input.command`, the same JSON the
hooks already read). The runtime hooks need no per-harness fork to enforce. So
**full-guarantee parity is feasible on Codex**, not merely advisory parity.

It is feasible, not automatic. Three things stand between the current installer and a
live fail-closed Codex:

1. **Hook trust must be persisted (the load-bearing gap).** A wired Codex hook
   silently **NO-OPS (fails OPEN) unless its sha256 is recorded as trusted in
   `[hooks.state]`**, or the session runs with `--dangerously-bypass-hook-trust`.
   This is the inverse of Claude Code, where a wired hook runs as soon as it is
   referenced. Until trust is persisted, every fail-closed hook the installer prints
   is **inert**: the guarantee looks wired but does not fire. The installer must write
   the trust entries (sha256 per hook) at install time, not leave it to the operator.

2. **The agent-role `.toml` schema is wrong for Codex.** The installer currently
   emits `name` / `description` / `sandbox_mode` / `mcp_servers` / `instructions`.
   Codex's agent-role schema is `developer_instructions` (not `instructions`) plus
   `model` and `model_reasoning_effort`, so the per-persona model/effort tiers
   (agents.yaml `tier:`) are dropped on the floor today. The rewrite maps the tiers:
   `economy → gpt-5.4-mini`, `standard → gpt-5.4`, `premium → gpt-5.5`; effort
   `low/medium/high/xhigh`.

3. **`effort: max` has no Codex equivalent.** Codex tops out at `xhigh`, so the
   Verifier's `max`-effort adversarial lane degrades to `xhigh` on Codex. Documented,
   not blocking.

The held-out-read safety fix is already shipped: `deny-heldout-read.sh` now inspects
`tool_input.command`, so a Writer can no longer read the held-out oracle by shelling
out (`cat`/`sed`) around the Read-tool path. This landed in 0.6.1 and is harness-
neutral; it closes the Codex variant of that hole at the same time as the Claude Code
one.

## Considered options

- **Declare Codex advisory-only and stop.** Rejected by the probe: the hooks demonstrably
  block on Codex, so capping parity at advisory would understate what the harness can do
  and would leave the single-writer guarantees Claude-Code-only for no real reason.
- **Fork the runtime hooks per harness.** Rejected. The wire shape is Claude-Code-shaped;
  the hooks read the same JSON unchanged. The only Codex-specific work is in the
  **installer** (trust + `.toml` schema), not the hook bodies. Forking the hooks would
  add drift surface with no benefit.
- **Leave hook trust to the operator / rely on `--dangerously-bypass-hook-trust`.**
  Rejected. A guarantee the operator has to remember to arm is not fail-closed; the
  bypass flag defeats the trust model wholesale. The installer persists trust so the
  floor is live on first run.

## Consequences

- Codex full-guarantee parity is **feasible after three installer fixes** (persist hook
  trust; rewrite the `.toml` schema to `developer_instructions`/`model`/
  `model_reasoning_effort` with the tier map; the `.command` held-out fix already shipped
  in 0.6.1). The fixes are installer-local; the runtime hooks and `agents.yaml` contract
  are unchanged.
- The hook-trust requirement is a **new fail-open mode unique to Codex** and is recorded
  in `plugins/orchestrate/KNOWN-LIMITATIONS.md` so an un-armed install is read as an
  installer gap, not an orchestrate bug.
- `sandbox_mode` on Codex is coarse (`workspace-write`); results-only confinement is still
  carried by `write-scope.sh`, and `writable_roots` can narrow it. Unchanged by this ADR.
- Actuator credential confinement stays **advisory** (ADR-0002) on every harness, Codex
  included. Unchanged.

## Status

active
