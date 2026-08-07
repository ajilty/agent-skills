# shipyard

**Scope it, shape it, spec it, ship it.**

A four-segment delivery method that takes an idea, need, or problem from raw
ask to shipped result, engaging the human only at the points where engagement
matters: the pauses. Opinionated about two things: **pause at commitments,
not at effort**, and **assert, don't ask**.

Every skill is explicitly invoked; the model never auto-triggers any of them.
That makes the pauses structural: a segment ends by naming the next command,
and nothing advances until you type it.

## Commands

| Command | Segment | Ends at |
|---------|---------|---------|
| `/shipyard` | router: reports where work stands, names the next segment | n/a (read-only) |
| `/scope` | intake and discovery: raw ask to confirmed problem | Pause 1: "this is the right problem" |
| `/shape` | options and direction: scored options, commitment memo | Pause 2: the returned memo (the commitment event) |
| `/spec` | requirements and design: build-ready, testable | Pause 3: one-way doors approved |
| `/ship` | build, verify, deliver | Pause 4: explicit acceptance |

Low-stakes reversible work may enter at `/shape` and finish with `/ship`;
segments tolerate missing predecessor artifacts with an inline lite version of
the predecessor's work. Never fewer than two pauses.

Artifacts (problem statement, decision memo, specs, decision logs, delta
report) are written to `docs/shipyard/<work-slug>/` in the repo being worked;
the router locates position by reading them, so the flow survives sessions.

## Execution engines

`/ship` defaults to building in a single loop, in-session. At Pause 3 you may
instead hand the build spec to an installed orchestration system; in this
marketplace that is [orchestrate](../orchestrate/). The skills themselves stay
engine-neutral and never fail because a named capability is absent.

## Harness support

Each skill directory is self-contained standard skill packaging (`SKILL.md`
plus its `conventions.md` and Codex sidecar), so skills can be installed
individually on any harness that reads the format;
`references/conventions.md` is the canonical source the per-skill copies are
synced from (tests enforce the sync).

- **Claude Code**: install the plugin; every skill sets
  `disable-model-invocation: true`, so only you can invoke them.
- **Codex**: each skill ships an `agents/openai.yaml` sidecar with
  `allow_implicit_invocation: false`; invoke by mentioning the skill with `$`.
- **opencode**: no explicit-only flag exists; descriptions are worded to
  demand explicit invocation, which is a weaker guarantee (known gap).

## Design

Method and decisions: the design spec at
[`docs/specs/2026-08-07-shipyard-plugin-design.md`](../../docs/specs/2026-08-07-shipyard-plugin-design.md)
and [ADR-0039](../../docs/adr/0039-shipyard-product-plugin-structural-pauses.md).
Tests: `tests/run.sh` (ADR-0038 convention).
