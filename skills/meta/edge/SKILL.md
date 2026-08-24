---
name: edge
description: Harvest this session's tool-call learnings and submit new or improved working-with-<tool> edges as a PR to the edges library.
disable-model-invocation: true
argument-hint: "[tool] [: observation or direction, e.g. 'new skill' / 'fold into existing']"
---

# Edge

Turn what this session learned the hard way into a contribution to the edges
library (the `working-with-<tool>` sharp-edge skills of the `edges` plugin,
repo `ajilty/agentic`).

## 1. Harvest

Scan this session's tool calls for edge candidates: verbatim error strings
that forced a workaround, retry-until-worked sequences, misleading flags or
parameters, response shapes that surprised. Sharp edges only — a gotcha
documentation does not carry; anything a docs lookup answers is not a
candidate.

With no arguments, sweep the whole session. An argument names the tool to
focus on; prose after it is the observation itself or direction ("new skill",
"fold into the existing one"), and the user's direction binds.

Redact as you collect: no user, company, tenant, or dated incident specifics;
keep error strings otherwise verbatim.

## 2. Confirm

Present the candidates: for each, the observation, the target (extend an
existing `working-with-<tool>` skill, or create a new one — decided by what
exists in the library, overridable by the user), and the proposed edge text.
Ask which to submit before touching anything.

## 3. Contribute

The authoring rules live with the plugin, not here: Read `CONTRIBUTING.md` at
this plugin's root (`../../CONTRIBUTING.md` relative to this file) and follow
it for edge shape, size, description triggers, redaction, symlink wiring,
validation, and commit style.

Then: clone `https://github.com/ajilty/agentic` into scratch space, branch,
activate the leak guard per CONTRIBUTING.md, apply the edits under
`skills/knowledge/` (never the plugin symlink views), validate, commit, push,
and open the PR. Without push rights, file the redacted observations as an
edge-report issue instead — CONTRIBUTING.md has the link.
