---
description: Operator status update — glanceable, zoomed-out to detail, surfaces only what needs you.
---
Give the **operator** a re-entry status update for the current orchestrate run, read **only
from durable disk state** so it survives a context switch or compaction. Do not rely on
conversation memory. This is a **read-only projection: write nothing** (no `STATUS.md`).

Gather — keep raw output OUT of your reply (§2a′: glance, don't dump):
- `ledger.sh reground` — open lanes, the `goal` anchor (north star + plan pointer), and any
  ambiguous-writer HALT.
- `ledger.sh metrics` — shipped / dispatches / forks / rejects / verify_coverage (pace + health).
- `.agents/runs/orchestrate/board.jsonl` — per-lane `intake`(tier)/`dispatched`/`returned`/
  `verdict`/`fork`/`decision`/`done`, and the run-level `goal` event.
- Only for lanes that are active or need input: the ticket file behind them
  (`tickets/<ticket>/fork.md`, verdicts, `work-item.md`) and the writer worktree's commits-ahead.

Render top-down and glanceable, with these emojis —
🎯 goal · 📋 plan · 🌳 lanes · 🙋 needs you · ⏭️ next · 📄 file;
pace 🟢 moving · 🟡 slow · 🔴 stalled; lane ✅ done · 🔄 running · 🚧 blocked · ⏳ queued · ❌ rejected(retrying):

1. 🎯 **Headline** — the goal (from the `goal` event), pace (🟢/🟡/🔴 from event recency +
   done-ratio), progress (`N done / M lanes`), and 📋 the plan pointer (spec/ADR path).
2. 🌳 **Lanes** — a tree, one node per ticket with its status glyph; parallel lanes are
   siblings; writer lanes show worktree commits-ahead.
3. 🙋 **Needs you** — render this section **only if non-empty**: halted `DECISION_FORK`s,
   clarify-halts, pending pre-apply prod acks, `INCONSISTENT_ORACLE`, reground ambiguous-writer
   HALTs. Each is one line (the ask) + 📄 pointer to the ticket file. If nothing is pending,
   omit the section and say `nothing needs you`.
4. ⏭️ **Next** — what's coming, from the plan's remaining tasks + current lane states.

Edge cases: no board → `no orchestrate run in this repo`. A clean board with a `goal` and no
open lanes → report it, but add the ADR-0020 caveat: a clean board is **not** "done" until the
plan is complete. Keep it skimmable; drill-in happens conversationally if the operator asks.
