# A valid oracle is an independent function probe; pair the Verifier by default

Field report (verifier-pairing): the Verifier was paired for a high-stakes refactor but
skipped for "routine" code-bearing live-rebuild fixes, which were self-verified via status
probes. Two shipped broken behind green — a `db-backup` red behind green infra, and (caught
by the ADR-0019 commit peek) a SHA whose commit lacked the fix. The operator's conclusion:
pair the Verifier by default, and a status probe the Implementer could satisfy *without the
feature working* does not count as the independent prong — it must be a **function probe**.

Analysis found two compounding doors (`SKILL.md §2`/`§2a`, `ledger.sh done`): (a) the
"oracle already exists" clause of T0 selection was satisfied by *any* named oracle, with no
function-vs-presence quality bar; (b) a routine single-file code fix legitimately qualifies
for **T0**, which skips both the Verifier persona and the fail-closed done-gate.

**Decision.** The fix is oracle **quality**, not code presence:

- A valid oracle (any tier) is a **function probe**: green only if the feature actually
  works, and independent of the writer. A presence/status probe (a file exists, a pod is
  `Running`, a status reads green) does not count — `#GAP(presence-probe)` (`SKILL.md §2`).
- T0 drops the independent Verifier *only* because its oracle certifies the change on its
  own; a presence-probe oracle fails that basis, so such a lane is **≥T1**, however routine
  it looks. **Pair the Verifier by default;** T0 is the exception justified by a genuine
  function probe, never by "looks routine" (`SKILL.md §2a`).
- When a Verifier runs, it rejects a presence-only probe to Planning (`verifier.md` step 1).

## Considered options
- **"Code-bearing ⇒ at least T1" (the initial recommendation)** — rejected: it overshoots
  and would eliminate legitimate T0 (a small code change whose oracle is real held-out
  tests). The failure mode is *presence-probe oracles*, not code per se, so the rule is
  keyed on oracle quality.
- **A hard mechanical floor (a hook/gate refusing a code-bearing T0 close)** — rejected as
  unsound. Oracle quality (function vs presence) is a **judgment not derivable from the
  board or a git diff**, so a mechanical gate would either break legitimate T0 or give false
  confidence. This is unlike the machine-checkable properties the plugin *does* gate on:
  the ADR-0019 committed-check (git state), and the fail-closed verdict gate (verdict
  presence). Enforcement stays at the judgment layer — the §2/§2a rule plus the Verifier's
  own presence-probe rejection.
- **Record each T0 lane's oracle on `intake` for auditability** (so reground/metrics can
  surface a suspicious self-exemption) — noted as a future option, not shipped here; it is
  the only *mechanizable* adjacent lever, and it aids review rather than hard-gating.

## Consequences
- `SKILL.md §2` gains the function-probe definition; `§2a` T0 row + note require an
  independent function probe and make "pair the Verifier by default" explicit; `verifier.md`
  rejects presence-only probes; `agents/verifier.md` regenerated.
- **No hard gate added** (see above): a discipline tightening enforced by the rule + the
  Verifier, complementing ADR-0019 (which hardened *what* a Verifier checks, not *whether*
  one runs).
- Trade-off: relies on the router honoring a judgment rule. Accepted — the alternative (a
  mechanical gate on an un-mechanizable property) is worse. If self-exemption recurs, add
  the intake-oracle-record auditability aid.

## Status

active
