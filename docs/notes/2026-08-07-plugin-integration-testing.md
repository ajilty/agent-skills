# Plugin integration testing (learned building shipyard, 2026-08-07)

Four layers, cheapest first. The first two are CI; the last two cost model
spend and stay local/opt-in.

## 1. Schema (CI, no credentials)

`scripts/validate-plugins.sh`: `claude plugin validate --strict` on the
marketplace manifest and every `plugins/*/` directory (ADR-0038). Catches
manifest and frontmatter defects at PR time.

## 2. Contract (CI, no credentials)

`plugins/<name>/tests/run.sh` (ADR-0038, discovery-based): deterministic
assertions on the plugin's own invariants. shipyard's suite checks every
skill's frontmatter (`disable-model-invocation: true`), the Codex sidecars
(`policy.allow_implicit_invocation: false`), and the generic-seam rule
(orchestrate named in README only).

## 3. Harness integration (local, authenticated, verified 2026-08-07)

The real Claude Code CLI can be driven headlessly with an uninstalled plugin:

```sh
claude --plugin-dir ./plugins/<name> -p "/<plugin>:<skill> args" --max-turns 12
```

What was verified empirically with shipyard:

- `--plugin-dir` loads the plugin for that session only, and slash
  invocations work inside `-p` prompts, so a script can invoke a skill
  exactly as a user would and assert on the output.
- Positive contract: the shipyard router, invoked against a fixture
  work-slug in a temp directory, read the artifacts from disk, reported
  position, and named the next segment.
- Negative contract: a `-p` session asked to list every skill invocable via
  the Skill tool showed none of the `disable-model-invocation` skills, while
  explicit invocation (above) still worked. That is the explicit-only
  mechanic holding end-to-end.
- Iterating interactively: `/reload-plugins` picks up plugin edits without
  restarting the session.

Costs auth and tokens, so it is not in CI: shipyard encodes it as opt-in
`plugins/shipyard/tests/integration.sh`, hermetic in a temp dir, exiting 0
with SKIP when `claude` or auth is unavailable.

## 4. Behavioral (local, per the writing-skills TDD method)

Skill discipline is tested with subagent pressure probes: baseline the
failure without the skill (RED), write the skill against the observed
rationalizations, re-probe with it (GREEN). Worked example with findings:
`plugins/shipyard/tests/BASELINES.md`.

## Containers

Not needed for layers 1-4. A container (colima/docker) earns its place only
for hermetic no-user-config runs, because isolating config
(`CLAUDE_CONFIG_DIR`) also drops login; such a recipe must inject an API key
from your secrets tooling. Deferred until a plugin's behavior depends on the
absence of user config.
