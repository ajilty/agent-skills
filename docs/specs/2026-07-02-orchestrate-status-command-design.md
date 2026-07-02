# Orchestrate status command (`/orchestrate:status`)

Date: 2026-07-02
Status: design approved (brainstorm) — spec pending user review

## Problem

When the operator context-switches back to a running, paused, or post-compaction
orchestrate loop, there is no fast way to re-orient: what is the goal, how is it going,
what needs me, what is next. Resumability has tended to live in ad-hoc prose (the
`STATUS.md` single-point-of-failure that ADR-0020 addressed on the durability side). We
need an on-demand, glanceable status projection over durable state.

## Goal

A slash command that renders a zoomed-out → detail status update from **durable disk
state only** (so it works post-compaction), surfaces **only** items needing the operator,
shows parallel lanes as a **tree**, conveys **pace**, and says **what is next**.

## Non-goals (YAGNI)

- Not interactive or live-updating — one-shot render; follow-ups happen conversationally.
- No new persisted artifact and no `STATUS.md` — it reads the ADR-0020 durable state and
  **writes nothing**.
- No new board event and no schema — it reads a board it already understands.
- No `--ticket` filter for now (add later only if wanted).

## Invocation

`commands/status.md` — a thin command like `start.md` / `feedback.md`, no args, operating
on the current repo's `.agents/runs/orchestrate/`. It instructs the router to synthesize
the render; it is a **read-only projection**.

## Data sources (all durable, on disk)

- `ledger.sh reground` — open lanes, the `goal` anchor (ADR-0020), ambiguous-writer HALTs.
- `board.jsonl` — per-lane `intake` (tier) / `dispatched` / `returned` / `verdict` /
  `fork` / `decision` / `done`, and the run-level `goal` event (north star + plan pointer).
- `ledger.sh metrics` — shipped / dispatches / forks / rejects / verify_coverage → pace + health.
- `tickets/<ticket>/` — `work-item.md`, `fork.md`, `verdicts/`, `findings/` for drill-in and
  the needs-you specifics.
- git `worktree-agent-*` worktrees — in-flight writer progress (commits ahead / dirty).

## Output — one-shot, top-down

Emoji legend (small, consistent):
`🎯 goal · 📋 plan · 🌳 lanes · 🙋 needs you · ⏭️ next · 📄 file`;
pace `🟢 moving · 🟡 slow · 🔴 stalled`;
lane `✅ done · 🔄 running · 🚧 blocked · ⏳ queued · ❌ rejected(retrying)`.

1. **Headline** — `🎯` goal · pace · progress (`N done / M lanes`) · `📋` plan pointer.
2. **`🌳` Lanes** — a tree, one node per ticket with a status glyph; parallel lanes are
   siblings; writer lanes show worktree progress (commits ahead).
3. **`🙋` Needs you** — *rendered only if non-empty*: halted `DECISION_FORK`s, clarify-halts,
   pending pre-apply prod acks, `INCONSISTENT_ORACLE`, and reground ambiguous-writer HALTs.
   Each is a one-line ask + a `📄` pointer to the ticket file. Empty → one line: `nothing needs you`.
4. **`⏭️` Next** — what is coming, from the plan's remaining tasks + current lane states.

Example:

```
🎯 Rebuild prod cluster from bare metal        🟢 ~70% · moving
   📋 docs/adr/0079-topology.md · 2 done · 1 active · 1 blocked

🌳 Lanes
├─ ✅ T1 backstage-db recovery   done (verified)
├─ ✅ T2 cf-access tunnel        done (verified)
├─ 🔄 T3 ESO / github-idp-id     implementer running (wt +14)
└─ 🚧 T4 image-SSM refactor      blocked → needs you

🙋 Needs you (1)
  • T4: fork — pin image via SSM param, or bake into the AMI?
        📄 tickets/T4/fork.md

⏭️ Next: T4 decision unblocks it → verify T3 → merge → close
```

## Generation discipline

LLM synthesis (no fixed schema). The status view is itself a **reduction** (§2a′): it runs
`reground` + `metrics`, glances only the ticket files behind needs-you / active lanes, and
keeps raw dumps out of the render.

## Edge cases

- No board → `no orchestrate run in this repo`.
- Clean board with a `goal` → `all lanes done — verify the plan is complete before concluding done`
  (the ADR-0020 caveat: a clean board is not "finished").
- Ambiguous-writer HALT from reground → surface at the top of **needs you**.
- Post-compaction → works, because it reads disk, not conversation memory.

## Testing

A live integration test (tier 3c, self-skips without `claude`/auth), mirroring
`test_clarify_gate_lane`: seed a board with a `goal` + a couple of lanes + a halted `fork`,
run the command headless, and assert the render surfaces (a) the goal text, (b) a lane
tree, (c) the fork under "needs you". The command file's presence is covered by the
existing install/build checks. The prose/emoji rendering itself is LLM output and is not
asserted verbatim.

## Status

Design approved in brainstorm; this spec is pending user review, then → writing-plans.
