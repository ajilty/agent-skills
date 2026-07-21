# Codex and OpenCode installs are skill-native via the cross-tool .agents/skills root

Both Codex CLI and OpenCode now support the Agent Skills standard, GA, and both read
the same cross-tool locations: `$REPO/.agents/skills/` (project) and `~/.agents/skills/`
(user), with progressive disclosure (name/description preloaded, full SKILL.md on
trigger). Verified against official docs 2026-07-20 (developers.openai.com/codex/skills,
opencode.ai/docs/skills). The generators' previous brain-delivery mechanism — concatenate
SKILL.md into an `AGENTS.orchestrate.md` the operator includes by hand — predates that
support: it loads the full router brain into every session unconditionally, needs a
manual include step, and duplicates the runtime.

**Decision.** `install-codex.sh` and `install-opencode.sh` install the skill natively:
one copy of `SKILL.md + references/ + runtime/` into the `.agents/skills/orchestrate/`
root for the chosen scope, SKILL.md copied verbatim first (a skill file must open with
its YAML frontmatter) with the harness dispatch addendum appended, and the addendum
embeds the absolute runtime path + PATH export (ADR-0018's bin/-on-PATH has no plugin
mechanism outside Claude Code). Harness config dirs keep only native surfaces: Codex —
agent TOMLs, hooks.json (pointing into the skill's runtime), config.toml trust seeds;
OpenCode — agents/ (plural, docs-current), plugins/orchestrate.ts (session.compacted
wired), commands/orchestrate-{init,status,feedback}.md for command parity. No
AGENTS.md concatenation, no second runtime copy, no legacy flag (older harness versions
pin plugin ≤0.8.19).

## Considered options
- **Keep the AGENTS.md concatenation** — rejected: always-loaded brain wastes every
  session's context; skills give on-demand loading and explicit invocation for free.
- **Ship a legacy fallback flag** — rejected: two brain-delivery paths to test forever;
  skills are GA in both harnesses and older versions can pin an older plugin release.
- **Symlink the source skill dir instead of copying** — rejected for the generators:
  the installed SKILL.md is a *generated distribution* (harness addendum appended,
  ADR-0007); a symlink would mutate the source on append.

## Consequences
- One skill directory serves Codex, OpenCode, and (same layout) the operator's
  Claude-side canonical installs; `.agents/` stays gitignored per ADR-0005, so installs
  are per-machine, matching plugin semantics.
- UNVERIFIED on live installs, carried as probe items in the installer output: skills
  loading inside `codex exec` / `opencode run` (matters for nested persona dispatch),
  OpenCode's `subagent.start` event name, and OpenCode permission-key coverage for
  `write`. First live run should confirm and report drift.

## Status

active
