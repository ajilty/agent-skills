# Durable router state & resume

The router holds board state, in-flight dispatches, the retry budget, and which
lanes are halted on a fork. The original design left that in the orchestrator's
context window — which interruption loses and **compaction silently corrupts**
(a summarized board with a wrong retry count breaks the "REJECTED → once → human"
no-loop guarantee). This applies the skill's own first principle — *contracts are
the bus; agent memory is never the source of truth* — to the **router itself**.

The orchestrator **is the driver**: there is no separate driver process and no
config file. `/orchestrate` is the single entry point for both starting work and
resuming an interrupted session; compaction recovers automatically.

## The ledger

`.agents/runs/orchestrate/board.jsonl` — an append-only event journal, the single
source of truth for control state **and** the metrics source (replay to derive
both). Append-only is deliberate: a crash mid-write costs at most a trailing
partial line, which the reader discards. The orchestrator appends events **as it
drives** (loop steps in SKILL.md, not background hooks).

**CANONICAL VOCABULARY — never invent event names.** The board is *machine-read*
(reground, `metrics`, `conformance` all match on these exact `event` values). An
event outside this set is **invisible** to every consumer — it neither reconstructs
on resume, counts in metrics, nor satisfies a conformance check. Journal **only**
these, via the `ledger.sh` helpers (`clarify` / `decision` / `append`); do not coin
ad-hoc events like `clarification_halt`. Use `intake` for work-item recording (it is
what the router naturally emits — adopted as canonical) and `clarify` for any
clarification (its `skill` records the mechanism actually used — `inline` when the
interactive grill skills can't run, e.g. a non-interactive session).

```
{"ts","ticket","event":"intake","tier","note"}                          # work item recorded + right-sized; tier = chosen lane (T0/T1/T2)
{"ts","ticket","event":"dispatched","persona","branch","dispatch_id","slug"}   # write-ahead: BEFORE the persona runs. branch: writer personas only; dispatch_id: EVERY dispatch (result→agent attribution, ADR-0014); slug: ticket-unique research topic, read-only personas only (RAW → findings/_quarantine/<slug>.<dispatch_id>.md, promoted → findings/<slug>.md)
{"ts","ticket","event":"returned","persona","status","artifact"}        # artifact: the PROMOTED findings path (read-only). The persona wrote the RAW quarantine file itself; the router read it from disk, gated, and promoted it (§5, ADR-0014)
{"ts","ticket","event":"verdict","verdict"}                             # APPROVED|REJECTED|INCONSISTENT_ORACLE
{"ts","ticket","event":"clarify","skill"}                              # §2b: router selected a clarification skill (first-present-wins) on intake ambiguity. ticket="intake" if pre-ticket
{"ts","ticket","event":"fork","state":"halted","fork_id"}
{"ts","ticket","event":"decision","fork_id","adr"}                      # fork resolved -> judgment memory (adr set iff promoted, §11)
{"ts","ticket","event":"lease-conflict","persona","key"}               # actuator denied: mutation target held by another lane
{"ts","ticket","event":"lane","state":"open|closed","branch"}
{"ts","ticket","event":"done"}
```

## Derived, never held

The retry budget is **counted from the ledger at each decision**
(`ledger.sh retries <ticket>` = number of `REJECTED` verdicts for that ticket),
not carried in context. So a lossy compaction cannot reset it — the no-loop bound
is a `grep` over disk. Lane status and halted forks are read the same way.

## Reground = ledger intent + git ground truth

`ledger.sh reground` reconstructs open lanes two ways and merges them:

1. **Ledger intent** — tickets whose last event is `dispatched`. A read-only
   persona is safe to re-dispatch if its **promoted result file is absent**; a
   writer is checked against its branch. The result is disk-first (ADR-0014): the
   persona itself writes the RAW `…/findings/_quarantine/<slug>.<dispatch_id>.md`,
   and the router gates+promotes it to `…/tickets/<ticket>/findings/<slug>.md` at the
   `slug` recorded on the `dispatched` event. Promoted file present ⇒ the persona
   delivered a durable, gated result, so don't re-dispatch. Disk is authoritative; it
   wins over the log — and over any completion notification, which may never arrive.
2. **Disk ground truth** — every live `worktree-agent-*` worktree with
   uncommitted work is an open writer lane to reconcile, *even if no ledger event
   exists for it* (missed append, crash mid-write). Disk wins over the log.

A `…/tickets/<ticket>/lease` (`{dispatch_id, session, pid, ts}`) gives
at-most-once writer dispatch: fresh ⇒ owned, don't double-dispatch; stale ⇒
reclaim and reconcile.

## Two resume paths, by cause

- **Interruption (crash / sleep / Ctrl-C) → operator.** Re-run `/orchestrate`.
  Step 0 is reground + reconcile, then continue from the reconstructed board.
- **Compaction → automatic, hands-off.** One hook on the harness's
  post-compaction event — Claude Code `SessionStart(source=compact)`, Codex
  `PostCompact`, OpenCode's plugin compaction event — runs `ledger.sh reground`
  and **injects the reconstructed board as authoritative state**. It does not say
  "go re-read the ledger" (post-compaction injection of pointers is unreliable);
  it hands back the reconstructed state so the model continues from ground truth.

## Fail closed

If reground finds an ambiguous in-flight writer (a `worktree-agent-*` worktree
with uncommitted work), it **halts for human re-attach** (exit 3) rather than
guess. The orchestrator must not dispatch past a HALT. A paused board beats a
wrong one — the same fail-closed posture as the rest of the design.

## Hooks, in total

Only what must be deterministic (research consensus: must-happen + failure you
can't tolerate belongs in a hook, not loop discipline):
- **Two enforcement hooks** (PreToolUse): held-out read-deny, branch-guard.
- **One write-ahead hook** (SubagentStart, implementer only): the `dispatched`
  event + lease, because a just-dispatched writer leaves no dirty worktree for
  reground to catch until it writes.
- **One compaction hook** (post-compaction): automatic reground + inject.

Everything else — `returned`/`verdict`, read-only dispatches, counting retries,
reconciling on `/orchestrate` — is the orchestrator driving its own loop.
