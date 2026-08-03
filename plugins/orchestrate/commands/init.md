---
description: "Standing operator loop — feed a goal of any altitude; re-run with no args to resume. Flags: --models=dynamic|quick|inherit"
argument-hint: "[--models=dynamic|quick|inherit] [goal…]"
---
You are running the **orchestrate** standing operator loop. Use the `orchestrate`
skill — its `SKILL.md` is the router brain. Drive the numbered loop exactly:
reground (always first) → intake → baseline + right-size → drive lanes
(Researcher / Planner / Implementer / Actuator / Verifier) → verify, resolve,
merge, close. Escalate forks and quarantine to the operator; never thrash.

**Flags** — strip these from the work item before intake; they are directives to
you, not goal text:

- `--models=dynamic|quick|inherit` — the §2a′ dispatch model policy (ADR-0033).
  Journal it as the goal anchor's 4th arg (`ledger.sh goal "<note>" [spec] [base]
  <policy>`) so it survives compaction; every dispatch after follows it. Any other
  `--models=` value: ask, don't guess. Absent flag on a **fresh goal** → `dynamic`;
  absent on a **resume** → keep the policy already on the board's latest goal.

Work item for intake (loop step 1) follows. If it is empty (after flag
stripping), this is a **resume**: run step 0 (`ledger.sh reground`) and continue
the open lanes instead of starting new work.

$ARGUMENTS
