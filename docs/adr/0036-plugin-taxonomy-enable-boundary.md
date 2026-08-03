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

Layout: portable skills live in a repo-root library organized by category —
`skills/<category>/<skill-name>/SKILL.md` — and plugins are views over it,
shipping a skill via symlink (`plugins/<plugin>/skills/<name>` →
`../../../skills/<category>/<name>`). Claude Code dereferences symlinks when
copying a plugin to its install cache (verified empirically 2026-08-03: a
local-marketplace install produced real directories in the cache and the skill
appeared in the plugin's component inventory), so distribution is unaffected
and installed plugins are self-contained. Categories still do no work at
invocation time — the human routes typed skills, descriptions route
auto-invoked ones — and category folders inside a plugin's own `skills/` dir
would break discovery, which only scans immediate subdirectories; the library
tree is where category structure lives. Plugin-internal skills (orchestrate's)
are implementation detail of a versioned product and stay in-plugin.

The library generalizes to every primitive type, with one wiring rule:
**symlink directories, never files.** Component discovery follows directory
symlinks but skips symlinked files (verified empirically 2026-08-03: a
symlinked agent `.md` copied to cache but registered `Agents (0)`; a real file
and a symlinked `agents/` directory both registered correctly). So: skills are
per-skill directories and mix freely across categories via per-skill symlinks;
file-based primitives (agents, commands) live in the library as named set
directories (`agents/<set>/*.md`) and a plugin symlinks its whole component
dir to one set — needing to mix sets is the trigger to graduate to a generated
copy step (ADR-0007 precedent). A top-level library dir is instantiated when
its first artifact lands, not preemptively. Hooks config (`hooks.json`) stays
in-plugin — it is the runtime footprint that justifies the plugin existing;
only shared hook scripts would ever be library candidates. Output styles
remain rejected (Claude-Code-only; the same content ships portably as a
skill).

## Considered options
- Flat skills inside each plugin with a README category column — initially
  chosen, superseded by operator call: category browsing belongs in the
  filesystem, and the symlink-view scheme was verified distribution-safe.
- Name-prefix categories (`security-threat-model`) — rejected: worsens the
  typed command and churns names when a skill changes category.
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

`rg` and `grep -r` do not follow directory symlinks by default (verified
2026-08-03), so searching a plugin's `skills/` finds nothing: the library tree
at repo-root `skills/` is where editing and searching happen. Git-based
marketplace installs are inferred to dereference identically (same
clone-then-copy path as the verified local install) but have not been
separately tested.

## Status

active
