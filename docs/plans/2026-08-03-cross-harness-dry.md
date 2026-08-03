# Cross-Harness DRY Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every fact shared across the three harnesses (Claude Code, Codex, OpenCode) has exactly one authoritative encoding, and every derived copy is machine-checked against it in CI.

**Architecture:** The existing compile model (harness-neutral `agents.yaml` contract + single-source SKILL.md/personas/runtime hooks, compiled by three generators) is correct and is now *validated by all three vendors*: Codex and OpenCode both natively discover `.agents/skills/` (agentskills.io standard), and Codex's hook JSON contract structurally mirrors Claude Code's. The failure is coverage, not architecture: the contract does not cover hook wiring, commands, or the operative tier table, and the parity tests only check the Claude Code emitter. This plan (1) fixes confirmed drift, (2) promotes the hook wire map into the contract and derives all three emitters from it via a shared generator lib, (3) extends the drift guard to all three harnesses, (4) batches the genuine design forks for a decision.

**Tech Stack:** bash + yq v4 (build-time only, per ADR-0007), the repo's zero-dep test harness (`plugins/orchestrate/tests/`), GitHub Actions.

## Global Constraints

- `agents.yaml` stays free of any harness's vocabulary (ADR-0007). Harness-neutral guard-point classes are allowed; tool names, event names, and vendor model IDs are not.
- Claude Code artifacts (`agents/*.md`, `hooks/hooks.json`) stay generated AND committed, with a working `committed == fresh build` drift guard (ADR-0007).
- Runtime hook bodies stay unforked, one copy for all harnesses (ADR-0016). All harness-specific work lives in the generators.
- Installed skill copies stay copies with an appended addendum, never symlinks (ADR-0034).
- Codex persona dispatch stays `dispatch-persona.sh` top-level `codex exec --cd <lane>` (ADR-0017). The persona→lane map is load-bearing safety.
- `yq` is build-time only; installed runtime needs git + coreutils only (ADR-0007).
- No em dashes in any authored prose.

## Verified harness facts this plan relies on (researched 2026-08-03)

| Fact | Source |
| --- | --- |
| OpenCode discovers skills at `.agents/skills/` and `~/.agents/skills/` natively; frontmatter name/description required | opencode.ai/docs/skills (live fetch) |
| OpenCode component dirs are now plural (`agents/`, `commands/`, `plugins/`); agent `tools:` deprecated in favor of `permission:`; permission keys include read, edit, glob, grep, list, bash, task, webfetch, websearch, skill | opencode.ai/docs/agents (live fetch) |
| Codex discovers `.agents/skills` (repo, walking up) and `~/.agents/skills`; `~/.codex/skills` deprecated | learn.chatgpt.com/docs/build-skills + core-skills loader.rs |
| Codex custom prompts (`~/.codex/prompts`) officially deprecated in favor of skills | learn.chatgpt.com/docs/custom-prompts |
| Codex hooks: hooks.json or `[[hooks.*]]` TOML; events include PreToolUse, SubagentStart, PostCompact; JSON stdin contract mirrors Claude Code's | learn.chatgpt.com/docs/hooks |
| Codex now has a plugin format `.codex-plugin/plugin.json` (skills + MCP + hooks), shared ChatGPT/Codex directory | learn.chatgpt.com/docs/build-plugins |
| Claude Code: commands merged into skills (`commands/` legacy); plugin manifest optional; unknown manifest fields ignored by design | code.claude.com/docs/en/plugins-reference, /skills |
| Claude Code does NOT scan `.agents/skills`; sanctioned bridge is `.claude/skills` or plugin packaging | code.claude.com/docs/en/skills (verified by omission) |
| Codex docs migrated: developers.openai.com/codex/* 308-redirects to learn.chatgpt.com/docs/* | live fetch |

---

## Phase 1: close confirmed drift (contract truth first)

Confirmed-diverged facts, worst first. Each task lands the contract change, the emitter change, and the test that would have caught it.

### Task 1: put `guard-merge-base` in the contract and wire it everywhere

The hook exists (`runtime/hooks/guard-merge-base.sh`, ADR-0027), is wired only on Claude Code, and is absent from `agents.yaml`, so the contract-parity test cannot see the gap. Codex and OpenCode currently do not deliver ADR-0027's floor.

**Files:**
- Modify: `plugins/orchestrate/skills/orchestrate/references/agents.yaml` (hooks block, after `shared_checkout_guard`)
- Modify: `plugins/orchestrate/scripts/install-codex.sh:147` (PRE_HOOKS)
- Modify: `plugins/orchestrate/scripts/install-opencode.sh:139-143` (bash branch of orchestrate.ts heredoc)
- Modify: `plugins/orchestrate/tests/test_build.sh` (HOOKFILE map)

**Interfaces:**
- Produces: contract entry `merge_base_guard` with `fail_closed: true`, consumed by Task 4's parity test.

- [ ] **Step 1: add the failing parity expectation**

In `tests/test_build.sh`, add to the `HOOKFILE` map:

```bash
  [merge_base_guard]=guard-merge-base.sh
```

- [ ] **Step 2: run the suite, verify it fails** (contract has no `merge_base_guard` key yet)

Run: `bash plugins/orchestrate/tests/run.sh`
Expected: FAIL in test_build contract-parity.

- [ ] **Step 3: add the contract entry**

In `agents.yaml` hooks block:

```yaml
  merge_base_guard:
    event: pre-tool-use
    applies_to: [all]              # router-level: merges happen in router context
    intent: >-
      Refuse a merge whose base is not the journaled goal-anchor base (ADR-0027):
      merges land on the base the ledger recorded at goal start, never on whatever
      HEAD drifted to. Denies `git merge` when the current branch's recorded base
      diverges from the journaled one.
    fail_closed: true
```

- [ ] **Step 4: wire Codex**

In `install-codex.sh`, add `guard-merge-base.sh` to `PRE_HOOKS` between `guard-done.sh` and `gate-prod-apply.sh` (mirrors the committed CC order):

```bash
PRE_HOOKS="deny-heldout-read.sh keep-on-branch.sh guard-shared-checkout.sh guard-merge-base.sh guard-done.sh gate-prod-apply.sh write-scope.sh run-scope.sh"
```

(The printed TOML reference block self-heals in Task 5 when it becomes generated from `PRE_HOOKS`; until then add the matching `[[hooks.PreToolUse.hooks]]` entry by hand.)

- [ ] **Step 5: wire OpenCode**

In the `orchestrate.ts` heredoc bash branch, alongside the Task 2 additions:

```ts
      if (tool === "bash") {
        await sh(`${RT}/hooks/deny-heldout-read.sh`, env);      // Bash cat/less of $HELDOUT_ROOT (Task 2)
        await sh(`${RT}/hooks/keep-on-branch.sh`, env);
        await sh(`${RT}/hooks/guard-shared-checkout.sh`, env);  // Task 2
        await sh(`${RT}/hooks/guard-merge-base.sh`, env);       // this task
        await sh(`${RT}/hooks/guard-done.sh`, env);             // Task 2
        await sh(`${RT}/hooks/gate-prod-apply.sh`, env);
        await sh(`${RT}/hooks/run-scope.sh`, env);
      }
```

- [ ] **Step 6: regenerate CC artifacts, run suite, commit**

Run: `bash plugins/orchestrate/scripts/build.sh && bash plugins/orchestrate/tests/run.sh`
Expected: PASS.

```bash
git add -A && git commit -m "fix(orchestrate): guard-merge-base joins the contract; wired on Codex + OpenCode"
```

### Task 2: deliver the fail-closed floor OpenCode is missing

`agents.yaml` declares `shared_checkout_guard` and `done_gate` as `applies_to: [all]`, `fail_closed: true`; `orchestrate.ts` wires neither. It also runs `deny-heldout-read.sh` only on read/grep/glob, so plain `bash cat "$HELDOUT_ROOT/..."` bypasses the held-out denial on OpenCode (Claude Code's `Read|Bash` matcher and Codex's `PRE_MATCHER` both cover Bash).

**Files:**
- Modify: `plugins/orchestrate/scripts/install-opencode.sh:138-147` (the tool.execute.before branches, combined with Task 1's edit above)
- Modify: `plugins/orchestrate/tests/test_install.sh` (assert the generated orchestrate.ts contains every fail-closed contract hook)

- [ ] **Step 1: failing test.** In `test_install.sh`, after the OpenCode install run, assert:

```bash
for h in deny-heldout-read keep-on-branch guard-shared-checkout guard-merge-base guard-done gate-prod-apply write-scope run-scope; do
  grep -q "hooks/$h.sh" "$OC_DEST/plugins/orchestrate.ts" \
    || fail "orchestrate.ts missing floor hook: $h"
done
```

- [ ] **Step 2: run, verify FAIL** (three hooks missing pre-Task-1/2 edits)
- [ ] **Step 3: apply the combined bash-branch edit shown in Task 1 Step 5** (it contains all of: deny-heldout-read on bash, guard-shared-checkout, guard-merge-base, guard-done)
- [ ] **Step 4: run suite, verify PASS, commit**

```bash
git add -A && git commit -m "fix(orchestrate): OpenCode floor parity — shared-checkout, done-gate, heldout-via-bash"
```

### Task 3: stop dropping the tier contract on OpenCode

`install-opencode.sh` emits no `model`/`effort`; `agents.yaml` `tier:` is a silent no-op there. DECISION D1 below picks the default mapping; this task implements the recommended option (emit `model:` from a table, overridable by env).

**Files:**
- Modify: `plugins/orchestrate/scripts/install-opencode.sh` (add `oc_model()`, emit in the persona loop)
- Modify: `plugins/orchestrate/tests/test_install.sh`

- [ ] **Step 1: failing test**

```bash
grep -q '^model: ' "$OC_DEST/agents/planner.md" || fail "OpenCode planner.md missing tier model emission"
```

- [ ] **Step 2: implement**

```bash
# agents.yaml tier -> OpenCode provider/model id. OpenCode model ids are
# provider-qualified; default to Anthropic, override per-tier via env
# (ORCHESTRATE_OC_MODEL_ECONOMY / _STANDARD / _PREMIUM) for non-Anthropic rigs.
oc_model() { case "$1" in
  economy)  echo "${ORCHESTRATE_OC_MODEL_ECONOMY:-anthropic/claude-haiku-4-5}" ;;
  standard) echo "${ORCHESTRATE_OC_MODEL_STANDARD:-anthropic/claude-sonnet-5}" ;;
  premium)  echo "${ORCHESTRATE_OC_MODEL_PREMIUM:-anthropic/claude-opus-5}" ;;
  *)        echo "" ;;
esac; }
```

In the persona loop, after `mode: subagent`:

```bash
  mt="$(yq ".personas.$p.tier.model" "$AGENTS")"
  m="$(oc_model "$mt")"; [ -n "$m" ] && printf 'model: %s\n' "$m"
```

Exact current Anthropic model ids in the defaults must be confirmed against opencode's models list at implementation time (models.dev registry); the env override is the escape hatch either way.

- [ ] **Step 3: run suite, PASS, commit**

### Task 4: extend the contract-parity test to all three emitters

Today parity is checked against CC's `hooks.json` only. Make one test enumerate `agents.yaml` hooks and assert each appears in (a) `hooks/hooks.json`, (b) the Codex `hooks.json` a hermetic install writes, (c) the generated `orchestrate.ts`. Hermetic installs already exist (`ORCHESTRATE_NO_SELFVERIFY=1`, `--dir` overrides), so this is a unit test, no live CLI.

**Files:**
- Modify: `plugins/orchestrate/tests/test_build.sh` (or new `tests/test_emitter_parity.sh` registered in `run.sh`)

- [ ] **Step 1: write the test**

```bash
# every contract hook must be wired by every emitter
tmp="$(mktemp -d)"
ORCHESTRATE_NO_SELFVERIFY=1 bash "$PLUGIN/scripts/install-codex.sh"    --scope project --dir "$tmp/cx" >/dev/null
bash "$PLUGIN/scripts/install-opencode.sh" --scope project --dir "$tmp/oc" >/dev/null
for name in $(yq '.hooks | keys | .[]' "$AGENTS"); do
  script="${HOOKFILE[$name]:-}"
  [ -n "$script" ] || fail "HOOKFILE map missing contract hook: $name"
  grep -q "$script" "$PLUGIN/hooks/hooks.json"        || fail "CC emitter missing $script"
  grep -q "$script" "$tmp/cx/.codex/hooks.json"       || fail "Codex emitter missing $script"
  grep -q "$script" "$tmp/oc/.opencode/plugins/orchestrate.ts" || fail "OpenCode emitter missing $script"
done
```

(Adjust the two install output paths to what `--dir` actually produces; `test_install.sh` already knows them. `compaction_reground` maps to `on-compaction.sh`, `writer_writeahead` to `on-writer-dispatch.sh`; on OpenCode `writer_writeahead` is a documented in-loop exception (ADR-0034), so exempt exactly that pair with a comment pointing at the addendum.)

- [ ] **Step 2: run, PASS (Tasks 1-2 landed), commit**

### Task 5: generate the Codex printed reference config from PRE_HOOKS

`install-codex.sh:332-354` hand-restates the hook list in TOML inside the summary heredoc; a hook added to `PRE_HOOKS` silently vanishes from the printed config operators may paste.

**Files:**
- Modify: `plugins/orchestrate/scripts/install-codex.sh` (replace the static `[[hooks.PreToolUse.hooks]]` lines with a loop)

- [ ] **Step 1: implement**

```bash
print_pretooluse_toml() { local h
  printf '  [[hooks.PreToolUse]]\n  matcher = "%s"\n' "$PRE_MATCHER"
  for h in $PRE_HOOKS; do
    printf '  [[hooks.PreToolUse.hooks]]\n  type = "command"\n  command = "%s/%s"\n' "$HOOKS" "$h"
  done
}
```

and in the summary heredoc replace the static block with `$(print_pretooluse_toml)`.

- [ ] **Step 2: eyeball a hermetic install's output, run suite, commit**

### Task 6: single-source the command descriptions

Three OpenCode command descriptions are hardcoded in `install-opencode.sh:101-103` and have all diverged from `commands/*.md` frontmatter. Parse the frontmatter instead.

**Files:**
- Modify: `plugins/orchestrate/scripts/install-opencode.sh:97-103`
- Modify: `plugins/orchestrate/tests/test_install.sh`

- [ ] **Step 1: failing test**

```bash
src_desc="$(yq --front-matter=extract '.description' "$PLUGIN/commands/status.md")"
grep -qF "description: $src_desc" "$OC_DEST/commands/orchestrate-status.md" \
  || fail "OpenCode status command description diverged from commands/status.md"
```

- [ ] **Step 2: implement**

```bash
oc_command() { # <src.md> <dest.md>
  local desc; desc="$(yq --front-matter=extract '.description' "$1")"
  { printf -- '---\ndescription: %s\n---\n' "$desc"; body "$1"; } > "$2"
  echo "  command  -> $2"
}
oc_command "$CMD_DIR/init.md"     "$CMDS_DEST/orchestrate-init.md"
oc_command "$CMD_DIR/status.md"   "$CMDS_DEST/orchestrate-status.md"
oc_command "$CMD_DIR/feedback.md" "$CMDS_DEST/orchestrate-feedback.md"
```

- [ ] **Step 3: run suite, PASS, commit**

### Task 7: drift-check the SKILL.md dispatch tier table

`SKILL.md` §2a′ hard-codes haiku/sonnet/opus per persona and is the OPERATIVE tier carrier on Claude Code (agent `model:` frontmatter is ignored at dispatch, per KNOWN-LIMITATIONS). Nothing checks it against `agents.yaml`. Minimum viable control: a unit test, not generation into the hand-authored SKILL.md (see DECISION D2).

**Files:**
- Create: `plugins/orchestrate/tests/test_skill_tier_table.sh` (register in `run.sh`)

- [ ] **Step 1: write the test**

```bash
# The §2a' dispatch table must agree with agents.yaml tiers (CC mapping:
# economy->haiku standard->sonnet premium->opus; effort passthrough).
cc_model() { case "$1" in economy) echo haiku;; standard) echo sonnet;; premium) echo opus;; esac; }
for p in $(yq '.personas | keys | .[]' "$AGENTS"); do
  want="$(cc_model "$(yq ".personas.$p.tier.model" "$AGENTS")")"
  line="$(grep -iE "^\|? *${p}" "$SKILL" | head -1)"   # the table row for this persona
  printf '%s' "$line" | grep -q "$want" \
    || fail "SKILL.md §2a' row for $p does not carry tier model '$want' (agents.yaml is authoritative)"
done
```

(Anchor the grep to the §2a′ section if persona names appear in other tables; extract the section with `awk '/§2a/{f=1} f' | head -40` first if needed.)

- [ ] **Step 2: run; if it FAILS, fix SKILL.md to match agents.yaml, not vice versa. Commit.**

### Task 8: fix stale docs

DONE in this PR already (doc-DRY): the root `README.md` is now brief and generic
(plugin list + short install pointer + doc map), and `plugins/orchestrate/README.md`
is the single source for install/use/safety detail across all three harnesses.
That restructure removed the stale `/orchestrate:start` references and the
circular "see the root README" pointer. Remaining:

**Files:**
- Modify: `plugins/orchestrate/DESIGN.md` (remove `scripts/install-claude-code.sh` refs at :159/:349, the nonexistent `scripts/runtime/` layout at :319/:355+, "the four hooks" count, the 4-persona file map missing Actuator)
- Modify: `docs/notes/codex-support.md` (note the docs migration: developers.openai.com/codex/* now redirects to learn.chatgpt.com/docs/*; content otherwise still accurate)

- [ ] **Step 1: make the edits; DESIGN.md corrections should describe the CURRENT layout (`scripts/build.sh`, 11 hooks, 5 personas), not add new design content**
- [ ] **Step 2: `grep -rn 'orchestrate:start' plugins/ docs/ README.md` returns nothing; commit**

---

## Phase 2: promote the wire map into the contract, share the generator lib

Phase 1 makes the copies agree; Phase 2 makes most of them derived so they cannot disagree again.

### Task 9: hook wire map in `agents.yaml` (harness-neutral)

Add two fields per contract hook: `script` (the runtime basename, today only encoded in tests and three generators) and `watch` (harness-neutral guard-point classes). Generators map classes to native matchers once each:

```yaml
  heldout_read_deny:
    script: deny-heldout-read.sh
    watch: [file-read, shell]      # shell too: `cat $HELDOUT_ROOT/..` is a read
    ...
```

Classes: `file-read`, `file-write`, `shell`, `dispatch`, `session-open`, `post-compaction`. Mapping per generator (single case statement each):

| class | Claude Code | Codex | OpenCode |
| --- | --- | --- | --- |
| file-read + shell | matcher `Read\|Bash` | one `PRE_MATCHER` group | read/grep/glob branch + bash branch |
| file-write | matcher `Write\|Edit` | same PRE_MATCHER group | write/edit/apply_patch branch |
| dispatch | matcher `Task\|Agent` | SubagentStart | in-loop (ADR-0034 exception) |
| session-open | SessionStart startup\|resume | (not wired) | (not wired) |
| post-compaction | SessionStart compact | PostCompact | session.compacted |

All three generators then build their hook emission by iterating `yq '.hooks'` instead of a hand-held list; `PRE_HOOKS`, the `build.sh` heredoc hook lines, and the `orchestrate.ts` branch bodies become loops over the contract. `tests/test_build.sh`'s `HOOKFILE` map is deleted (the contract now carries it) and the Task 4 parity test reads `script:` from the contract directly. This is contract-vocabulary-safe: guard-point classes name WHAT is being watched, not any harness's tool.

**Files:** `agents.yaml`, `scripts/build.sh`, `scripts/install-codex.sh`, `scripts/install-opencode.sh`, `tests/test_build.sh`, the Task 4 parity test.

- [ ] Step 1: add `script:` + `watch:` to all 9+1 contract hooks (including Task 1's `merge_base_guard`)
- [ ] Step 2: convert `build.sh` hooks.json emission to a loop grouped by watch-class; run `build.sh`; `git diff hooks/hooks.json` must be EMPTY (byte-identical output proves the refactor)
- [ ] Step 3: convert `install-codex.sh` (`PRE_HOOKS="$(yq -r '.hooks[] | select(.watch[] | test("file-|shell")) | .script' ...)"` or equivalent loop) and `install-opencode.sh` the same way; hermetic installs before/after must diff empty except intended Task 1/2 additions
- [ ] Step 4: delete `HOOKFILE`, point parity at contract `script:` fields; run suite; commit

### Task 10: `scripts/lib/common.sh`

Extract the boilerplate every generator repeats verbatim: the yq-v4 FATAL guard, `body()`, the `--scope/--dir` arg parser, the persona iteration helper, and the skill-copy + addendum-append step (parameterized by addendum heredoc). ~60 lines deduplicated across three files, and the next generator (or the next fix to `body()`) happens once.

**Files:**
- Create: `plugins/orchestrate/scripts/lib/common.sh`
- Modify: all three generators to `source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"`

- [ ] Step 1: create lib with the four functions moved verbatim (no behavior change)
- [ ] Step 2: after each generator conversion, hermetic install diff against a pre-refactor install must be empty; run suite; commit per generator

### Task 11: CI runs the hermetic installers

CI today runs unit tests only; both non-CC emitters are exercised by nothing on push. The Task 4 parity test plus `test_install.sh` are already hermetic; ensure `tests.yml` runs them (they live under `tests/`, so if `run.sh` includes them this is a no-op verification, otherwise register them).

- [ ] Step 1: confirm `run.sh` picks up `test_install.sh` and the parity test; push a branch, watch the workflow run them; commit any registration fix

---

## Phase 3: decision forks (batched, with recommendations)

These change surface area or defaults; they need your call before task-level detail is worth writing. Recommendation first in each row.

**D1. OpenCode tier default mapping (Task 3 implements the winner).**
Recommended: emit Anthropic-qualified ids by default with per-tier env overrides (as written in Task 3). Alternative A: omit `model:` unless env is set (no wrong default, but the tier contract stays dropped for anyone who doesn't read the docs). Alternative B: a `models.yaml` sibling next to `agents.yaml` mapping tier → id per harness (one more artifact; contradicts the simplicity bias for a 3-line-per-harness fact). The per-generator table is genuinely harness-specific vocabulary, so duplication across generators is correct; the table just must exist in all three.

**D2. SKILL.md §2a′ table: drift-check (recommended) or generate.**
Task 7 implements the drift-check. Generating the table into the hand-authored SKILL.md via markers would make it impossible to forget, but puts build output inside the one file that is deliberately hand-authored prose (ADR-0007 keeps generated artifacts separate). The test is the minimum viable control; upgrade to generation only if the test proves annoying in practice.

**D3. Close the "Codex has no commands" gap with skills, not prompts.**
Codex custom prompts are now officially deprecated in favor of skills, so the TODO's `~/.codex/prompts` route is dead. Recommended: `install-codex.sh` emits `.agents/skills/orchestrate-status/SKILL.md` and `orchestrate-feedback/SKILL.md` from the same `commands/*.md` sources OpenCode compiles (init is redundant on Codex: `$orchestrate` already invokes the main skill). Invocation: `$orchestrate-status`, description-triggered otherwise. Cost: ~15 lines in the installer reusing Task 6's frontmatter parsing. Risk: none identified; skills are the vendor-blessed surface.

**D4. Migrate Claude Code `commands/` to plugin `skills/`.**
Claude Code has merged commands into skills (`commands/` still works, labeled legacy). Migrating would leave ONE user-invocable format across all three harnesses (skills), with OpenCode commands and Codex skills both compiled from it. Recommended: yes, but as its own small change after Phase 2, since it touches user-visible invocation (`/orchestrate:init` remains the same name as a plugin skill) and the README. Not urgent; `commands/` is not deprecated-with-a-date yet.

**D5. Codex plugin packaging (`.codex-plugin/plugin.json`): defer.**
Codex now has a proper plugin format (skills + MCP + hooks, shared ChatGPT/Codex directory, marketplaces). It cannot yet replace the installer: trust seeding (`[hooks.state]`), `config.toml` edits (`network_access`, `[features] hooks`), and agent TOMLs are outside plugin scope, and the trust dance is the load-bearing part (fail-open otherwise). Recommended: journal as a note (`docs/notes/codex-plugin-packaging.md`) with a revisit trigger: "when Codex plugins can carry hook trust or hooks default-trusted for workspace plugins". Watch item, zero build now.

**D6. OpenCode permission emission: widen beyond edit/bash/webfetch.**
The permission key set is now documented as much richer (read, glob, grep, task, websearch, skill, external_directory...). Emitting a full deny-by-default permission map per persona would strengthen declarative subtraction and would also resolve ADR-0034's open probe ("permission-key coverage for write"). Recommended: yes, fold into Phase 2 as a small Task 9 follow-on, but verify key names against a live `opencode` first (the docs list and the deprecation of `tools:` are recent; keep emitting `tools:` for older builds as today).

**D7. `bin/` shim completeness test.**
Not cross-harness drift, but same failure class: a new runtime helper is silently PATH-invisible on Claude Code until someone hand-adds a fourth shim. A 6-line test asserting every `runtime/*.sh` (minus the documented Codex-only `dispatch-persona.sh`) has a `bin/` shim closes it. Recommended: yes, fold into Phase 1 as a freebie.

**Also flagged, no action proposed:** persona-file frontmatter `description:` is dead text every generator strips, already diverged from `agents.yaml`. Cheapest fix is deleting the field from `references/personas/*.md` so the contract's description is visibly the only one. Include in Task 8 if you agree.

---

## Explicit non-goals

- No shared "meta-manifest" or fourth artifact format describing all three plugins (simplicity bias: the contract + three thin emitters is the system; a generator-generator is complexity creep).
- No symlinking installed skills (ADR-0034 stands; installs stay generated copies).
- No forking runtime hook bodies per harness (ADR-0016 stands).
- No AGENTS.md concatenation layer (both non-CC harnesses read the skill natively; ADR-0034 stands).
- syntax-guard stays Claude-Code-only; it is fail-open by design and not part of the floor. Multi-harness syntax-guard is a separate decision if ever wanted.

## Gaps and unverified items

- Codex enum spellings (granular approval_policy keys, feature flags) came through a summarizing fetch; eyeball learn.chatgpt.com/docs/config-file/config-reference before hard-coding new config emission (only relevant to D5).
- Whether OpenCode still honors the singular `.opencode/plugin/` dirs is unconfirmed (docs show plural only; the installer already emits plural).
- `session.compacted` firing post-compaction on OpenCode remains the ADR-0034 open probe; Phase 1 does not change that.
- OpenCode model ids in Task 3 defaults need confirmation against the live models registry at implementation time.
