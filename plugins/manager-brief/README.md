# manager-brief

An output style for research-heavy sessions: when a response reports technical
research, it leads with a brief written for a busy technical manager (the
answer, the fork with a recommendation, what's needed from the reader), then
gives the full findings with claims labeled verified or inferred. Routine
edits and status updates keep their normal shape.

The style ships in `output-styles/manager-brief.md` and is auto-discovered
when the plugin is enabled. It does not set `force-for-plugin`: installing the
plugin makes the style available, it never switches your session to it.

## Install

```
/plugin marketplace add ajilty/agent-skills
/plugin install manager-brief@ajilty-agent-skills
```

Then `/reload-plugins` (or restart the session), and activate via `/config`
under **Output style**, or set in settings.json:

```json
{ "outputStyle": "Manager brief" }
```

Note: the standalone `/output-style` command was removed in Claude Code
v2.1.91; `/config` and settings.json are the activation paths.

## Migrating from a user-level copy

If you previously kept this style at `~/.claude/output-styles/manager-brief.md`,
move that file aside after installing: precedence between a same-named user
style and plugin style is undocumented, so don't rely on shadowing. Your
existing `outputStyle: "Manager brief"` setting carries over unchanged, since
the plugin style keeps the same name.
