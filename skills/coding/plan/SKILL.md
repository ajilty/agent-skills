---
name: plan
description: Turn findings into a spec with acceptance oracles, scored options, and operator decisions listed.
disable-model-invocation: true
---

# Plan

A plan is a contract the builder can execute without re-deriving your judgment,
and the verifier can check without asking you. The hard thinking happens here,
not in the build.

- **Acceptance oracle first**: every task states how success is checked
  (command, test, observable behavior). A task without an oracle is not ready;
  a thin work item produces design drift that no amount of builder skill buys
  back.
- **Smallest plan that ships the outcome**: tasks decomposed so each is one
  buildable unit; claimed independence between tasks is verified (grep for the
  shared file), not assumed.
- **Options before commitment**: where a real choice exists, present it scored
  against the accepted baseline (risk and effort as deltas from status quo,
  crediting existing controls) with a recommendation. Decisions that belong to
  the operator are listed, not made.
- **Assumptions are tagged**, not buried: anything taken for granted is written
  down where the verifier will find it.
- **Durable artifact**: the spec/plan is a committed file, not a conversation
  summary.
