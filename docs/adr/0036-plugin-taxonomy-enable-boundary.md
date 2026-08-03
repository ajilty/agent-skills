# Plugins are enable boundaries; skills carry the trigger

New capability lands as a skill in an existing plugin by default. A new plugin
exists only when one of three tests passes: (1) distinct off-switch — you would
plausibly disable the whole set somewhere (work vs personal machine, lending the
marketplace to someone else); (2) runtime footprint — it ships hooks, MCP
config, or binaries (why syntax-guard is separate); (3) distinct release
cadence with external consumers (why orchestrate is separate).

The taxonomy this yields, beyond the existing orchestrate and syntax-guard:

- `playbook` — user-invoked workflows (`/playbook:grill`, `/playbook:retro`,
  `/playbook:day-prep`, `/playbook:assignment`, `/playbook:tdd`,
  `/playbook:review`, `/playbook:threat-model`). One plugin across office,
  coding, and security domains; skill descriptions route.
- `sharp-edges` — auto-invoked tool knowledge (`working-with-<tool>`), zero
  user or company references, the publishable tier.
- No preferences plugin: operator-specific interaction guidance (how to ask
  questions, how to report status) stays out of this public repo entirely, in
  private harness config — the global CLAUDE.md for one-line always-on rules,
  the private skills path for anything that outgrows a line.
- No meta plugin: skill creation/testing/finding is covered by installed
  third-party plugins (skill-creator, plugin-dev, find-skills); build one only
  if homegrown conventions accrete that those don't encode.

Naming: plugins are 1-2 word memorable nouns naming the boundary, never a
`-skills`/`-plugin` suffix. Workflow skills are the imperative phrase typed
after `/`; knowledge skills are `working-with-<tool>`.

## Considered options
- Per-domain workflow plugins (office/coding/security) — rejected: none has its
  own off-switch or runtime footprint today; split office out later only if
  day-prep grows hooks or work-only MCP wiring.
- One mega-plugin for everything — rejected: workflows and knowledge have
  different publishability and different invocation models, which is exactly an
  enable boundary.
- A preferences plugin in this repo — rejected by operator: operator identity
  and interaction preferences do not belong in a public repo under any name;
  they live in private harness config.
- Output styles for interaction guidance (ClaudeFire model) — rejected: output
  styles are Claude-Code-only; skills port across harnesses (opencode, Codex),
  which is binding.

## Consequences
The sorting test for new content is mechanical: mentions the operator or their
preferences → private config, not this repo; typed as a command → playbook;
generic tool knowledge → sharp-edges; hooks/binaries or external consumers →
its own plugin. The "no user or company references" rule applies to every
plugin in the repo, enforced by the public-repo decision.

## Status

active
