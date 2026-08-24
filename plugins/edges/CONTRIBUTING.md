# Contributing edges

The single source of truth for authoring `working-with-<tool>` knowledge
skills. The `/harvest` skill follows this file at contribution time; human
contributors follow the same rules. If guidance here conflicts with anything
else, fix this file.

## What an edge is (and is not)

An edge is a sharp piece of operating knowledge that documentation does not
carry: a gotcha, a failure mode, a misleading flag, a response shape that
surprises, a workaround with the exact working incantation. Docs lookup is
already served (context7, vendor plugins) — if a docs query answers it, it is
not an edge. The best edge starts from a raw observation: the verbatim error
string, the command that failed, the variant that worked.

Each edge entry is symptom, cause, and what works, in a few terse lines.
Quote error strings verbatim (minus identifiers). Prefer the runnable
incantation over a description of it.

## Shape and size

- One skill per tool surface, named `working-with-<tool>` (kebab-case), one
  `SKILL.md`, nothing else.
- Body is terse bullets grouped by operation area (auth, search, writes, ...),
  60-90 lines total for a mature skill. A new skill can start with 2-3 edges;
  a single contribution to an existing skill is often one bullet.
- **The description is the API.** These skills are auto-invoked: the
  description must carry "use when" triggers with the concrete error strings,
  command names, and jargon the model will actually see in-session. A great
  edge with a vague description never fires.
- Every skill ends with the report-link footer:

  ```
  ---
  Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
  ```

## Redaction (public repo, publishable tier)

Zero user, company, tenant, or person references, and no dated incident
anchors. Account IDs, hostnames, internal URLs, and case numbers are replaced
with placeholders; error strings stay otherwise verbatim. If an edge cannot be
written without naming an org or person, it belongs in private harness config,
not here.

Activate the leak guard in your clone before committing (identity allowlist +
private blocklist scan):

```sh
git config core.hooksPath scripts/githooks
```

## Where to edit

Edit `skills/knowledge/<skill>/` at the repo root — the library. The plugin's
`plugins/edges/skills/` entries are directory symlinks (views); `rg`/`grep -r`
do not follow them, and edits belong in the library. A new skill needs both
the library directory and the symlink:

```sh
ln -s ../../../skills/knowledge/working-with-<tool> plugins/edges/skills/working-with-<tool>
```

Add the new skill's row to the table in `plugins/edges/README.md` and bump the
plugin version in `plugins/edges/.claude-plugin/plugin.json`.

## Validate and submit

- `claude plugin validate plugins/edges --strict` must pass (CI runs it on
  every PR via `scripts/validate-plugins.sh`, ADR-0038).
- Commit with an `edges(<tool>): <edge>` subject (see `git log --oneline --
  skills/knowledge` for the style), branch, push, and open a PR. CI's review
  runs when the PR goes ready-for-review.
- No push rights, or the observation is not yet edge-shaped? File it instead:
  https://github.com/ajilty/agentic/issues/new?template=edge-report.yml — the
  raw redacted observation is a welcome contribution on its own.
