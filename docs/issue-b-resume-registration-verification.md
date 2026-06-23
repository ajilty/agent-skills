# Issue B — interactive verification runbook: `orchestrate:*` agents on resume

**Goal:** confirm whether the plugin's five subagents (`orchestrate:actuator/implementer/
planner/researcher/verifier`) stay dispatchable across an **interactive** resume, and
which operator step (if any) re-registers them. This must be done interactively — it is
**not reproducible headlessly** (see "What's already ruled out").

Fill in the **`[ ]` / RESULT:`__`** lines as you go and report the table in §3 back.

---

## What's already ruled out (headless, automated)

`plugins/orchestrate/tests/integration/test_resume_registration.sh` (run it:
`bash plugins/orchestrate/tests/integration/run.sh`) established, headlessly:

- Install → `claude -p` session 1 → `claude -p -c` **resume** → dispatch
  `orchestrate:researcher` **all succeed** (RESEARCHER_OK both sessions).
- A stale `enabledPlugins:{"orchestrate@ghost-marketplace":true}` does **not** break the
  real install/load (5 agents still load).

So the **plugin artifacts, manifest, config, and stale-enable handling are sound.** Each
`claude -p` is a fresh process that re-registers agents, which is *why* headless can't
see the drop. Issue B is therefore specific to the **interactive `--resume`/`--continue`
TUI path** — the focus of this runbook.

---

## 0. Setup (once)

In your test repo (any repo where you'd run orchestrate):

```
/plugin marketplace add ajilty/agent-skills
/plugin install orchestrate@ajilty-agent-skills
```

**The dispatch probe (used throughout)** — paste this as a message; it's unambiguous:

> Use the Task tool to dispatch a subagent of type `orchestrate:researcher` with the
> instruction: reply with exactly the token RESEARCHER_OK. Output its reply verbatim. If
> that agent type is not available, output exactly AGENT_NOT_FOUND.

`RESEARCHER_OK` = registered & dispatchable. `AGENT_NOT_FOUND` (or a harness "Agent type
'orchestrate:researcher' not found") = dropped.

Other signals to watch in the transcript:
- Harness injections: *"New agent types are now available: orchestrate:…"* (registered)
  vs *"The following agent types are no longer available: orchestrate:…"* (dropped).
- `/plugin` (status) — is `orchestrate@ajilty-agent-skills` listed + **enabled**?
- The `/agents` or "Available agents" list — are the `orchestrate:`-prefixed ones present
  (vs only unprefixed ones from the repo's own `.claude/agents/`)?

---

## 1. Reproduce the drop

1. **Fresh session right after install.**
   - [ ] Run the dispatch probe.  RESULT: `____` (expect RESEARCHER_OK)
   - [ ] Did you see *"New agent types are now available"*?  RESULT: `____`
   - [ ] Note whether it registered only **after** you launched `/orchestrate:start`
         (evidence #1 suggested the skill launch triggered it).  RESULT: `____`
2. **Exit and resume** (`/exit`, then resume that conversation — `claude --continue`/
   `claude --resume`, or your usual resume path).
   - [ ] On resume, any *"no longer available: orchestrate:…"* message?  RESULT: `____`
   - [ ] Run the dispatch probe.  RESULT: `____` (Issue B = AGENT_NOT_FOUND here)
   - [ ] `/plugin` — is orchestrate still listed + enabled? scope?  RESULT: `____`

If step 2's probe returns AGENT_NOT_FOUND while step 1 returned RESEARCHER_OK, the drop
is confirmed.

---

## 2. Candidate re-registration steps (test each in the **resumed** session)

After reproducing the drop (still in the resumed session), try each below **independently**
and re-run the dispatch probe after it. Record what re-registers.

| # | Operator step | Probe after | Re-registered? |
|---|---------------|-------------|----------------|
| A | `/reload-plugins` | run probe | RESULT: `____` (evidence #3 suggested NO) |
| B | Launch `/orchestrate:start` (then probe) | run probe | RESULT: `____` |
| C | `/plugin disable orchestrate@ajilty-agent-skills` then `/plugin enable …` | run probe | RESULT: `____` |
| D | Toggle enable scope: `/plugin enable … --scope local` (or project) | run probe | RESULT: `____` |
| E | **Start a brand-new session** (no resume) in the same repo | run probe | RESULT: `____` (evidence #1 = YES) |
| F | Fully quit the CLI, relaunch, new session | run probe | RESULT: `____` |

The **minimal** step that yields RESEARCHER_OK is the operator workaround to document.

---

## 3. Report back (paste this filled in)

```
CC version:            ____   (claude --version)
Repro confirmed?       ____   (step1 OK -> step2 AGENT_NOT_FOUND)
Drop message seen?     ____   ("no longer available …")
Re-registers via:      ____   (which of A–F worked, minimal)
/plugin shows enabled on resume? ____  (and at what scope)
Anything odd in /plugin status or settings.json (user vs project vs local)? ____
```

---

## 4. Diagnostic notes for the fix decision

- **Auto-discovery vs explicit enumeration:** `plugin.json` does **not** enumerate
  `agents/` — it relies on Claude Code auto-discovery (which works at install/first
  start). If the fix is "enumerate agents explicitly in the manifest," that's an
  orchestrate-side change; if registration is purely a harness session-start step that
  resume skips, it's a CC limitation (document + operator step E/F).
- **Enable-state persistence (observed during dev):** a project-scope
  *"orchestrate is enabled at `.claude/settings.json`"* record survived a marketplace
  removal — check on resume whether the enable points at a marketplace/version the
  loader can still resolve; a dangling enable is a prime suspect.
- If C, E, or F re-registers but A does not, that's a strong signal `/reload-plugins`
  has an agent-registration gap worth reporting upstream.
