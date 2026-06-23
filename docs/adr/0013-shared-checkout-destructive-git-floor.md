# A universal floor refuses destructive git on the shared (primary) checkout

A real run lost an unpushed commit: a §9a base-correction `git reset --hard
origin/<base>` ran against the **shared main checkout** and discarded committed-but-
unpushed work. Two things combined: (1) an agent landed on the main checkout instead
of an isolated worktree — the Claude Code `isolation:worktree` "lands-on-main" harness
trap, which a skill cannot patch; (2) the only branch guard, `keep-on-branch.sh`, is
gated on `persona = implementer` and only denies branch-create / off-branch-commit —
so it never ran for the router (no `agent_type`) and never matched `reset --hard`.

**Decision.** Add a **persona-independent** PreToolUse(Bash) hook,
`guard-shared-checkout.sh`, that DENIES working-tree/history-discarding git ops
(`reset --hard`, `clean -f`, `checkout -f` / `checkout .` / `checkout -- `,
`switch --discard-changes`) whenever cwd is the **PRIMARY** worktree — detected
deterministically by `git rev-parse --git-dir == --git-common-dir`. It applies to the
router and every persona. A writer's *linked* worktree (git-dir ≠ git-common-dir) is
its own throwaway sandbox and is left alone. The legitimate §9a base-correction
(`git fetch` + `git worktree add`/recreate) is not destructive-to-main and stays allowed.

## Considered options
- **Extend `keep-on-branch.sh`** — rejected: it is implementer-gated, but the offender
  is usually the router; the floor must be persona-independent (a distinct concern,
  hence a distinct hook).
- **Rely on the harness `isolation:worktree`** — rejected: that is the *cause* (stale
  base + lands-on-main). Orchestrate defends rather than depends.

## Consequences
- Deterministic protection against the lands-on-main trap regardless of harness
  behavior: no agent can discard work on the shared checkout. Consistent across all
  lanes (persona-independent), resolving the "some refuse, some damage" inconsistency.
- This is the data-loss half. The stale-base half (mechanizing §9a worktree creation
  from a fetched `origin/$BASE_REF` into a runtime helper, so the router stops relying
  on `isolation:worktree`) is the complementary follow-on.
- The denylist is a focused, extensible best-effort set (same posture as run-scope,
  ADR-0010); a determined non-git escape is out of scope.

## Status

active
