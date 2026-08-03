# manager-brief plugin: first plugin-distributed output style

**Date:** 2026-08-03
**Status:** Approved

## Goal

Ship the existing user-level `Manager brief` output style
(`~/.claude/output-styles/manager-brief.md`) as a Claude Code plugin from this
repo's self-marketplace, deliberately minimal, to test whether plugin delivery
of output styles works and is worth building on.

## Design

Three files plus a marketplace entry:

```
plugins/manager-brief/
├── .claude-plugin/plugin.json     # name, version 0.1.0, description
├── output-styles/manager-brief.md # verbatim copy of the user-level style
└── README.md                      # install, activation, A/B test procedure
```

Decisions, all biased simple:

- **Verbatim style copy.** The test measures plugin delivery, not style
  quality. Any style edits happen after delivery is proven.
- **No `outputStyles` manifest field.** The default `output-styles/` directory
  auto-discovers. The manifest field exists for custom paths and *replaces*
  the default scan, so omitting it is simpler and safer.
- **No `force-for-plugin` frontmatter.** That flag auto-applies the style
  whenever the plugin is enabled, overriding the user's `outputStyle` setting.
  Activation stays opt-in via `/config` or settings.
- **Same style name, `Manager brief`.** Existing `outputStyle` settings carry
  over unchanged.

## Value test

1. Install: `/plugin install manager-brief@ajilty-agent-skills`, then
   `/reload-plugins` (or restart the session).
2. Move `~/.claude/output-styles/manager-brief.md` aside.
3. Start a session, trigger a research-shaped response, confirm the brief
   format still applies and `Manager brief` still appears in the `/config`
   Output style picker.
4. If yes: delete the local file; the plugin is now the source of truth.

## Known caveat

Name-collision precedence between a same-named user style and plugin style is
undocumented (verified against `code.claude.com/docs/en/output-styles.md` and
`plugins-reference.md`, 2026-08-03). The test procedure moves the local file
aside rather than trusting shadowing. Note: the `/output-style` command was
removed in v2.1.91; activation is `/config` or the `outputStyle` settings
field.

## Revision, 2026-08-03 (same day)

The verbatim-copy style was replaced wholesale after a two-stage UAT: transcript
grading showed the original's brief shape fired once in ~14 eligible turns with
four manual "busy manager" escalations, and a six-round preference elicitation
on real turns converged on a different design: business-outcome voice,
outcome-only leads, no findings sections (depth on request), narrative numbered
decisions with a recommendation, verdict-exposure-next research answers, and
Done/Doing/Next progress updates. One document by necessity: Claude Code allows
a single active output style per session, so turn-type dispatch lives inside
the style.

## Outcome, 2026-08-03 (final)

Plugin withdrawn. The delivery mechanism proved out (auto-discovery, strict
validation, CI), but the elicited style is a personal-preference artifact and
per the no-personal-identity principle it moved to private dotfiles as the
user-level `ajilty` style. This PR keeps the repo-wide test/validation harness
(ADR-0038) and the orchestrate frontmatter fix; the manager-brief plugin and
its marketplace entry are removed.
