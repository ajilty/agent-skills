# orchestrate — backlog (open items)

What to pick up next, captured so we don't lose the thread. As of 2026-06-18.
All landed work is on `main`; tests: `skills/orchestrate/tests/run.sh` (56/56).

## Process lesson — do this every batch (not optional)

**Run a fresh-context, whole-range review before calling any batch "done."** It has
caught a **Critical three times** during this build — each a cross-cutting or
runtime bug that inline self-review *and* the green unit suite missed:

- P1 — `lease-release` was wired nowhere (dead half of a lifecycle).
- P3 — the pre-apply gate was bound to `SubagentStart`, a *non-blocking* event, so
  it enforced nothing on Claude Code / Codex.
- P2 — `adr.sh reindex` aborted under `set -e` on body-prose "supersede" and
  truncated the index — **green in tests, broken on the real repo.**

Inline implementation is fast and fine; the adversarial whole-view pass is the
gate. This mirrors the skill's own thesis (single writer + independent
fresh-context Verifier) — validated on its own construction.

## High priority

- **Codex / OpenCode `/orchestrate` command parity.** Claude Code emits a
  `commands/orchestrate.md` slash command; the other two harnesses don't yet.
  Add a Codex prompt (`~/.codex/prompts/orchestrate.md`) and an OpenCode command
  so the typed entry point works everywhere. (`SKILL.md` is already the shared
  brain; these are thin wrappers.)

## Medium

- **Lease acquire atomicity (TOCTOU).** `ledger.sh lease-acquire` is
  check-then-write; two concurrent acquires of a free target could both win.
  Replace with an atomic claim (`mkdir` lockdir, or `set -C`/noclobber `O_EXCL`).
  **Required before lifting "single router per repo"** (SKILL §15) — today the
  single-router + lease-check-before-dispatch model makes the window unreachable,
  which is why it's deferred, not fixed.

## Low (deferred-with-ticket from the P1 whole-branch review)

- **`TARGETS` comma-split.** `on-writer-dispatch.sh` word-splits on whitespace
  only, but the interface doc said "space- or comma-separated." Normalize
  (`tr ',' ' '`) or pin the contract to space-only — **do it when the router
  emitter that populates `TARGETS` lands**, so both ends agree. Currently
  unreachable (nothing emits `TARGETS` yet).
- **Lease-key JSON escaping.** Lease files and the `gate-blocked`/`lease-conflict`/
  `decision` events embed `$key` via unescaped `printf`. Safe for the
  `<kind>:<scope>` charset today; add escaping (or reject out-of-charset keys at
  the boundary) **only if keys ever become free-form/user-supplied.**
- **`adr.sh` `add` / `reindex` double-maintenance.** `add` appends an INDEX row
  incrementally *and* `reindex` rebuilds from files; harmless when they agree, but
  the index header differs by which ran last. Optionally make `add` call `reindex`
  so there's a single index-maintenance path ("files are source of truth").
- **Generated vs hand-authored ADR body format.** `adr.sh add` writes
  `_Status: active_`; hand-authored ADRs use `## Status` / no status line. Cosmetic
  (supersede/reindex key on the status line, not the format), but worth aligning.

## Watch (acceptable as-is, but depends on loop discipline)

- **`decision` event + ADR capture are router loop-steps, not hooks.** Like
  `returned`/`verdict`, they're appended by the router as it drives (now real
  callables: `ledger.sh decision`, `adr.sh add`), not enforced by a hook — because
  fork-resolution is operator-interactive. Acceptable, but if judgment memory ever
  fails to accumulate, this is the first place to look (the router skipped the step).

## Not skill work (operational)

- The stack is committed locally on `main`; nothing pushed. Decide push/PR to the
  public remote when ready.
