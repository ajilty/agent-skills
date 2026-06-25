# Known limitations

orchestrate runs **on** the host harness's subagent machinery (Claude Code's
`Task`/`Agent` dispatch, its notifications, its worktree isolation). A few harness
behaviors are outside a plugin's reach — orchestrate cannot patch them, so instead
it **compensates by design** and treats the harness channel as untrusted. They are
listed here so you can tell a harness behavior apart from an orchestrate bug, and
so you don't file the former as the latter.

If you hit one of these, it is **expected**: orchestrate already defends against
it. File a bug only if the *compensation* fails (e.g. a read-only result is lost
even though no `findings/<slug>.md` was ever written, or a writer mutated the
shared checkout) — see [the bug-report template](../../.github/ISSUE_TEMPLATE/bug_report.yml)
and the "is this a harness limitation?" classifier there.

## Subagent result / notification channel (Claude Code)

Observed on Claude Code 2.1.x. The substantive result of a dispatched subagent is
delivered through a notification channel that can be unreliable:

| # | Harness behavior | How orchestrate compensates |
|---|------------------|-----------------------------|
| 1 | A task-notification can carry the **wrong agent's label** (result attribution is wrong). | Every dispatch is keyed by a router-minted `dispatch_id` baked into the result **filename**; the router reads the exact path it minted, never a notification label (ADR-0014). |
| 2 | A finished agent's **final output can be lost** before the idle transition. | Read-only personas write their result to disk (`results-only` write, hook-scoped) as their final action; the router reads it **from disk**, so nothing depends on the final message arriving (ADR-0014). |
| 3 | `SendMessage` to an **idle agent no-ops** instead of replaying/re-engaging. | The result is already a durable file — the router never needs to re-fetch it from the agent. If the file is absent, the dispatch simply re-runs (reground keys on the file's presence). |
| 4 | Idle pings (`{"type":"idle_notification","idleReason":"available"}`) are **noisy and content-free**. | The router polls the scoped result path + its `<!-- orchestrate:complete -->` sentinel for completion, so idle pings are irrelevant to control flow. |

Net: a dispatched read-only agent (researcher/verifier) can complete and have its
result silently dropped by the channel — and orchestrate still recovers it, because
the result lives on disk, not in the notification. This is the read-channel twin of
the write-channel protection below.

## Worktree isolation lands on the main checkout (Claude Code)

The harness `isolation:worktree` can place an agent on the **primary checkout**
instead of an isolated worktree, and can cut a worktree from a **stale** default
branch (`origin/HEAD`) rather than your current branch. orchestrate compensates:

- A persona-independent floor (`guard-shared-checkout.sh`, ADR-0013) refuses
  working-tree/history-discarding git ops (`reset --hard`, `clean -f`,
  `checkout -f`/`.`/`--`, `switch --discard-changes`) against the primary checkout.
- The router creates worktrees via `runtime/worktree.sh`, cutting from the
  **current** branch (never `origin/HEAD`) and realigning `origin/HEAD` so the
  harness path benefits too.

Existing stale worktrees are not retroactively fixed; if you upgraded into the fix,
run `git remote set-head origin <your-canonical-branch>` and `git worktree prune`
once.

## Credential confinement is advisory (all harnesses)

The actuator's credential scoping is **advisory** (ADR-0002): orchestrate cannot
enforce "no credentials for an unleased target" from inside the harness. The
guaranteed layer is lease **serialization** (single-writer per target). Scope the
actuator lane's creds to its leased targets in your deployment.

## Codex-specific (codex-cli 0.142.1)

A live probe confirmed Codex's PreToolUse hooks **block** (exit 2 + stderr contract,
Claude-Code-shaped wire), so full fail-closed parity is feasible (ADR-0016). The
runtime hooks need no per-harness fork; the items below are Codex behaviors the
**installer** compensates for, plus one degraded effort tier. They are not orchestrate
bugs.

| # | Codex behavior | Status / how orchestrate compensates |
|---|----------------|--------------------------------------|
| 1 | A Writer could read the held-out oracle by shelling out (`cat`/`sed`) around the Read-tool path. | **Resolved in 0.6.1.** `deny-heldout-read.sh` now inspects `tool_input.command`, so the shell path is denied too. Harness-neutral; closes the Codex variant of the hole. |
| 2 | A wired hook silently **NO-OPS (fails OPEN)** unless its sha256 is trusted in `[hooks.state]` (or `--dangerously-bypass-hook-trust` is passed). | **Live limitation.** Until the installer persists trust, every fail-closed hook is **inert**: the guarantee looks wired but never fires. The installer must write the per-hook trust entries at install time (ADR-0016). Inverse of Claude Code, where a referenced hook runs immediately. |
| 3 | `effort: max` has **no Codex equivalent** (Codex tops out at `xhigh`). | **Live limitation.** The Verifier's max-effort adversarial lane runs at `xhigh` on Codex. Documented, not blocking. |
| 4 | Actuator credential confinement is **advisory** (ADR-0002), as on every harness. | Unchanged. Lease serialization is the only guaranteed layer; scope the actuator lane's creds in your deployment. |
| 5 | `sandbox_mode` is coarse (`workspace-write`). | **Live limitation.** The results-only confinement is carried by `write-scope.sh` (not the sandbox), and `writable_roots` can narrow it further. |

See `docs/notes/codex-support.md` for the verdict and the installer fixes still
required for a live fail-closed Codex.
