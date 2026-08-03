# manager-brief

An output style for a busy, context-switching technical manager: every message
lands its point in the first sentence, work is translated into outcomes and
impact rather than mechanics, and technical depth stays in the work products
until asked for. One style, five shapes dispatched by turn type: completed
work, researched answers, diagnoses, decisions (numbered outcome-named options
with a recommendation), and Done/Doing/Next progress updates. The shapes were
elicited through preference rounds on real session transcripts, not designed
in the abstract.

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
