# Filesystem two-axis split — tracked docs/ vs gitignored .agents/

Durable, human-facing records live **tracked** under `docs/{specs,adr}/`;
ephemeral machine/control state lives **gitignored** under `.agents/` (the board
ledger, per-ticket bus, leases, worktrees). The commit/gitignore boundary does
the semantic work: "would a human want to read this in six months?" → `docs/`;
"is this how the router remembers what it was doing this run?" → `.agents/`.

## Consequences

- The spec/ADR moves from orchestrate's original ephemeral per-ticket artifact to
  a **tracked `docs/` record** with a per-ticket working *snapshot* the personas
  read (`docs/` is source of truth; no drift).
- `.agents/` is a single `.gitignore` entry in any repo the loop operates on.
  In this repo the entry is `.agents/*` with a `!.agents/skills/` exception:
  vendored dev skills (installed via `npx skills`, pinned by `skills-lock.json`)
  are durable and shared, so they ride the tracked side of the split.
- superpowers' `.git/sdd` hiding trick is **not** adopted: orchestrate's reground
  must inspect that state, and visible-but-gitignored is more debuggable than
  hidden-in-`.git`.
