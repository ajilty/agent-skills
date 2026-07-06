#!/usr/bin/env bash
# SessionStart(startup|resume): agent-teams incompatibility warning (ADR-0023). Orchestrate's
# safety model — single-writer, no peer-to-peer control, control-state read only from disk
# (ADR-0012) — assumes dispatched personas run ISOLATED and return results via disk, not as
# peer-messaging teammates. Claude Code "agent teams"
# (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1) can turn dispatched agents into chatty teammates
# that relay control signals, silently undermining those guarantees — and there is no plugin
# opt-out (verified 2026-07-06 via claude-code-guide). Claude-Code-only: on Codex/OpenCode the
# variable is unset, so this is a silent no-op. Warn, don't block — the operator owns the risk.
# SessionStart stdout is injected as context, so the router sees this at the top of the run.
[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" = "1" ] || exit 0
cat <<'MSG'
⚠ orchestrate: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is enabled (agent teams).
Orchestrate's safety guarantees — single-writer, no peer-to-peer control, control-state only
from disk (ADR-0012) — assume ISOLATED dispatch-and-return subagents, NOT agent-teams
teammates. Under agent teams these guarantees are UNVERIFIED and may not hold: personas can
become peer-messaging teammates that relay control signals (halt/commit/redirect) the router
must never take secondhand. There is no plugin opt-out. RECOMMENDED: disable agent teams for
this repo (unset CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS, or remove it from .claude/settings.json)
before running orchestrate. Otherwise treat orchestrate's safety model as advisory this session.
MSG
exit 0
