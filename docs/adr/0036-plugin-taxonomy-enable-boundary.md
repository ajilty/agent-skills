# Plugins are enable boundaries; skills carry the trigger

New capability lands as a skill in an existing plugin by default. A new plugin
exists only when one of three tests passes: (1) distinct off-switch — you would
plausibly disable the whole set somewhere (work vs personal machine, lending the
marketplace to someone else); (2) runtime footprint — it ships hooks, MCP
config, or binaries (why syntax-guard is separate); (3) distinct release
cadence with external consumers (why orchestrate is separate).

The taxonomy this yields, beyond the existing orchestrate and syntax-guard:

- `working-with-alex` — auto-invoked interaction preferences (asking-questions,
  giving-updates). Personal by definition: if a skill cannot be written without
  naming the operator, it lands here.
- `playbook` — user-invoked workflows (`/playbook:grill`, `/playbook:retro`,
  `/playbook:day-prep`, `/playbook:assignment`, `/playbook:tdd`,
  `/playbook:review`, `/playbook:threat-model`). One plugin across office,
  coding, and security domains; skill descriptions route.
- `sharp-edges` — auto-invoked tool knowledge (`working-with-<tool>`), zero
  user or company references, the publishable tier.
- No meta plugin: skill creation/testing/finding is covered by installed
  third-party plugins (skill-creator, plugin-dev, find-skills); build one only
  if homegrown conventions accrete that those don't encode.

Naming: plugins are 1-2 word memorable nouns naming the boundary, never a
`-skills`/`-plugin` suffix. Workflow skills are the imperative phrase typed
after `/`; knowledge skills are `working-with-<tool>`; preference skills are
the gerund of the interaction moment they fire at.

CLAUDE.md vs preference skill: CLAUDE.md keeps the one-line always-on
constraint (it pays context rent every turn); the skill holds the elaboration
and examples, fired at the moment it applies. CLAUDE.md lines shrink to
pointers as skills absorb them.

## Considered options
- Per-domain workflow plugins (office/coding/security) — rejected: none has its
  own off-switch or runtime footprint today; split office out later only if
  day-prep grows hooks or work-only MCP wiring.
- One mega-plugin for everything personal — rejected: preferences and knowledge
  have different publishability (personal vs generic), which is exactly an
  enable boundary.
- Private companion repo for the personal plugins — rejected by operator: repo
  stays public, all plugins scrubbed of company references; personal style
  preferences and workflow shapes are accepted as low-sensitivity.
- Output styles for preferences (ClaudeFire model) — rejected: output styles
  are Claude-Code-only; skills port across harnesses (opencode, Codex), which
  is binding.

## Consequences
The sorting test for new content is mechanical: names the operator →
working-with-alex; typed as a command → playbook; generic tool knowledge →
sharp-edges; hooks/binaries or external consumers → its own plugin. The
"no company references" rule extends from knowledge skills to every plugin in
the repo, enforced by the public-repo decision.

## Status

active
