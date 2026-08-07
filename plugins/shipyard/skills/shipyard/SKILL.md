---
name: shipyard
description: "Report where work stands in the Shipyard flow and name the next segment to run"
disable-model-invocation: true
---

# Shipyard router

Concierge for the Shipyard delivery method, never its driver. The human
invokes this to find footing, not to do work. Shared conventions live at
`../../references/conventions.md` relative to this skill's directory; read
them first.

1. **Locate the work.** Default home is `docs/shipyard/<work-slug>/` in this
   repo. An invocation argument names the slug; with no argument and several
   slugs, list them and ask which. With no argument and one slug, take it.
2. **Read what exists.** Problem statement, decision logs, decision memo,
   requirements and build specs, delta report. Disk is the source of truth,
   not conversation memory.
3. **Report position in a few lines.** Which segments are complete, which
   pause is open, and exactly what input the flow is waiting on. Surface
   staleness: assumptions past their deadline, an unreturned memo, a spec
   that drifted from its memo.
4. **Name the next command.** One of `/scope`, `/shape`, `/spec`, `/ship`.
   For brand-new work, recommend the entry segment by stakes per the scaling
   rule: high-stakes irreversible work starts at `/scope`; low-stakes
   reversible work may start at `/shape`.
5. **Stop.** This skill reads and reports only. When asked to continue the
   work from here, name the command the human should type instead.
