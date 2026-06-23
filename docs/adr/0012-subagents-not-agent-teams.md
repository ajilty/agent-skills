# Orchestrate dispatches capability-subtracted subagents, not agent-teams teammates

Claude Code has an experimental "agent teams" feature
(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`,
[docs](https://code.claude.com/docs/en/agent-teams)) that coordinates **multiple
full Claude Code sessions** — a lead plus *teammates*, each an independent session
with its own context, communicating via a shared task list + mailbox. It is tempting
to run orchestrate's five personas "as a team."

**Decision.** Orchestrate dispatches its personas as **subagents** via the ordinary
Task/Agent tool — NOT as agent-teams teammates — and does not depend on the
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag (plain subagent dispatch needs no setting;
verified empirically).

**Why:** orchestrate's guarantees are **subagent-scoped**, and a teammate is a *full
session*, not a capability-subtracted subagent:
- **Capability subtraction (ADR-0002) would be lost.** The per-persona `tools:`
  allowlist (researcher can't Bash, actuator can't Write/Edit) is a subagent property;
  a teammate runs with full session tools.
- **Hook enforcement** (held-out deny, branch guard, prod gate, write/run scope,
  write-ahead) is applied at the subagent/tool-use layer; its applicability to
  independent teammate sessions is not guaranteed.
- The docs note a persona-run-as-teammate ignores `mcpServers`/`skills` frontmatter,
  and plugin subagents already ignore `hooks`/`permissionMode` frontmatter.

So running the personas as teammates would hand each one a full, unrestricted session —
defeating exactly the guarantees the plugin exists to provide.

## Considered options
- **Enable agent teams for inter-persona messaging / shared task list.** Rejected:
  bypasses capability subtraction + the fail-closed enforcement. A teams-based variant
  is possible but would require re-establishing every guarantee for full-session
  teammates first — a separate spec/ADR, not a flag flip.

## Consequences
- No experimental-flag dependency; the plugin works with default settings. Tests
  exercise the subagent dispatch path. If a teams-based orchestrate is ever pursued,
  this ADR is the decision to supersede.

## Status

active
