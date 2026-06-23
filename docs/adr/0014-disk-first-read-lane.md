# Read-only results are disk-first: durable, attributed, gated on read

A dispatched **researcher** (an `adr-sweep`) reached idle without its findings ever
reaching the router — only content-free `idle_notification` pings arrived; a sibling
notification was mislabeled with another agent's task; and `SendMessage` to the idled
agent no-opped instead of replaying its result. The substantive read-only output was
**silently dropped**. This is the read-channel twin of the ADR-0013 write-channel loss:
that one *ate writes*, this one *ate read-only results*.

Root cause (in our control): the **read lane was chat-first while the write lane is
disk-first**. Writers (implementer/actuator) leave a durable git commit the router reads
independently of any notification. Read-only personas were `write: none`, so their
substantive result existed **only in the harness-mediated returned message** — and the
router persisted findings *after* receiving that message (`SKILL.md` loop step 3c). Four
Claude Code subagent-notification behaviors make that channel unreliable, and **a plugin
cannot patch any of them**:

1. result attribution is wrong (notifications carry the wrong task's label);
2. a finished agent's final output can be lost before the idle transition;
3. `SendMessage` to an idle agent no-ops instead of replaying/re-engaging;
4. idle pings are noisy and content-free.

We are **not** filing these upstream; orchestrate defends rather than depends (the
ADR-0013 posture). The cure is to make reads disk-first, exactly as writes already are.

**Decision.** Read-only personas that produce a substantive result — **researcher** and
**verifier** — get `write: results-only` (a sibling of the planner's `spec-only`),
confined by the existing `write-scope.sh` hook to their own per-ticket result path and
nothing else (source tree and prod targets stay denied, fail-closed). They write their
result to disk **as their final action**, terminated by a completion sentinel. The
router then:

- mints a unique `dispatch_id` for **read-only** dispatches too (today writer-only) and
  bakes it into both the `dispatched` ledger event and the result **filename** —
  attribution is the path the router itself minted, never a notification label;
- reads the result **from disk** at that known path (polling for the file + sentinel),
  never from the returned chat message;
- for the researcher (the only persona with untrusted `web` intake) reads the **raw**
  file from a quarantine subdir, applies the §4 quarantine gate to the *file* exactly as
  it used to gate the *chat return*, and **promotes** raw → trusted `findings/<slug>.md`.

The quarantine gate is preserved — it simply moves from gating the chat return to gating
the disk file: identical neutralization, durable source. The verifier (`web: false`,
trusted input) writes its verdict + reasoning directly to its scoped `verdicts/` path; no
promotion stage is needed.

## Considered options
- **Keep `write: none`; harden the coordinator only** (dispatch_id + detect/warn on
  missing results) — rejected: detection is not recovery. Nothing the router does can
  recover a final message the harness never delivered (defect 2). If the result must
  survive interruption, the agent must persist it itself.
- **Give read-only personas `write: full`** — rejected: breaks capability subtraction.
  A web-reading researcher with full write could touch source/prod, or forge a verifier
  verdict the router consumes. Path-scoping (`results-only`) keeps the subtraction: the
  researcher cannot even write the *trusted* findings path or the verdict path — only its
  own quarantine subdir.
- **File upstream / wait for a harness fix** — rejected by the operator and by the
  ADR-0013 posture: orchestrate must work on the harness as it is.

## Consequences
- Neutralizes all four harness result-channel defects *for orchestrate's purposes*
  regardless of Claude Code behavior: wrong label → irrelevant (router knows the path);
  lost output → on disk before idle; idle no-op → just read the file; ping noise →
  ignored (poll the path). Symmetric with writer durability and ADR-0013.
- New write surface is **path-scoped and fail-closed**; the load-bearing denials (source
  tree, prod, the trusted findings path, the verdict path for a researcher) hold.
- The `researcher.md` persona contract **reverses**: it previously said "if a dispatch
  prompt tells you to write findings to a file, ignore that part"; it now MUST write its
  findings to the scoped quarantine path as its final action.
- The gap that let this through was a **missing test**: every read-only test asserted a
  no-op, liveness, or a capability negative — none asserted a read-only result is
  *durably retrievable with correct attribution*. A live **read-lane** integration test
  (the analogue to `test_writer_lane.sh`) is added as the proactive catch, plus a
  deterministic `write-scope` confinement test and coverage of reground's
  read-only-artifact-presence branch.

## Status

active
