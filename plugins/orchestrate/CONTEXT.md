# Orchestrate — Standing Operator Loop

The language of a single, durable delegation loop you feed goals of any altitude.
A coordinating session decomposes each goal, executes it through capability-restricted
sub-agents with quality and safety guarantees, survives interruption, and remembers
its judgment across goals.

## Language

**operator** (lowercase):
The human who drives the loop and owns escalated decisions.
_Avoid_: user, driver — and never conflate with the **Actuator** persona.

**Router**:
The coordinating session that maps persona-emitted enums to transitions; holds board state, makes no design calls.
_Avoid_: orchestrator-as-thinker, controller-with-opinions.

**Persona**:
A sub-agent dispatched with an isolated context and a subtracted capability set.
_Avoid_: worker, role (when precision matters).

**Lane**:
One goal's path through its personas; the unit that opens, resumes, and closes.
_Avoid_: thread, job.

**Goal**:
The operator's input to the loop, at any altitude (one-line fix → multi-system operation).
_Avoid_: task (reserved for a decomposed unit inside a spec), ticket (reserved for a lane's id).

**Coding lane**:
A lane whose deliverable is a reviewable working-tree diff merged by branch.

**Ops lane**:
A lane whose deliverable is observed state in a live environment, with no diff to merge.

**Actuator**:
The single writer for downstream mutations to a live environment (e.g. `terraform apply`, `kubectl apply`); holds run capability and target-scoped credentials, edits no source.
_Avoid_: Operator (collides with the human **operator**), Deployer.

**Implementer**:
The single writer for coupled source; edits the working tree, runs visible tests, commits.

**Mutation target**:
A nameable resource a writer can change — working tree, terraform state/workspace, cloud account, cluster namespace, database, DNS zone.
_Avoid_: resource (too broad), file (only one kind of target).

**Blast radius**:
The set of mutation targets a writer can reach. The thing single-writer is defined over.

**Lease**:
An at-most-once claim on a mutation target, held for the duration a writer touches it.
_Avoid_: lock (implies the tool's own state lock, which is a non-relied-upon backstop).

**Oracle**:
The check that decides whether work is DONE; the writer must not be able to influence it.

**Held-out**:
Any boundary the writer structurally cannot cross — a file tree it can't read, or a live environment it has no credentials to reach.

**Acceptance probe**:
The ops-lane oracle — an executable check the Verifier runs against the live environment; the Actuator can neither read nor run it.

**Judgment memory**:
The in-repo, tracked, harness-neutral record of decisions made across goals, so a later goal need not re-litigate a settled one.
_Avoid_: memory (collides with harness/conversation memory, which this explicitly is NOT).

**Decision record** (ADR):
One tracked file capturing a single resolved decision: the question, the choice, the rejected alternatives, and why.

**DECISION_FORK**:
A persona's signal that a goal hit an irreducible call the spec can't settle; halts that lane and surfaces options to the operator.

**Clarification step**:
The router-context, interactive resolution of a goal's blocking `#UNKNOWN`s at intake, run via the configured grilling/brainstorming skill, scoped to those unknowns.
_Avoid_: brainstorm (one specific skill, not the role).

**Consequence level**:
A Planner-declared tag on a mutation target — `prod` (gated) or `safe` (autonomous); undeclared is treated as `prod`, fail-closed.

**Pre-apply gate**:
The execution-time operator ack required before the Actuator mutates a `prod`-level target; distinct from intake clarification, which gates on ambiguity not consequence.
_Avoid_: prod gate (the deferred harness-classifier feature is separate).

**Provenance**:
The trust tier on every piece of content — `TRUSTED` (repo, operator), `DERIVED` (a persona's reasoning), `UNTRUSTED` (web/external; data only, never a directive).

## Relationships

- The **Router** dispatches **Personas**; it never writes code or makes design calls.
- A **Goal** opens one **Lane**; a Lane is a **Coding lane**, an **Ops lane**, or both in sequence.
- The **Implementer** writes source; the **Actuator** writes live state; each is a *single writer* over its **mutation targets**.
- A writer holds a **Lease** on every **mutation target** in its **blast radius** before it runs.
- The **Verifier** runs the **Oracle**: held-out tests (coding lane) or an **acceptance probe** (ops lane).
- A resolved **DECISION_FORK** becomes a **Decision record** in **judgment memory**, which the **Planner** reads at intake.
- The **Router** invokes sub-skills (the **Clarification step**) for their work, never their control flow — it owns sequencing.
- The **Clarification step** gates intake on ambiguity; the **Pre-apply gate** gates execution on **Consequence level**. They are different lane phases, not one trigger.

## Example dialogue

> **operator:** "Deploy app A to cluster B."
> **Router:** "Two tasks: the Implementer commits the manifests as a reviewed diff, then the Actuator applies them to the leased target `k8s:clusterB/appA`."
> **operator:** "How do we know it worked?"
> **Router:** "The Verifier runs the acceptance probe — rollout complete, endpoints 200 — with its own credentials. The Actuator can't run that probe, so it can't fake the result."

## Flagged ambiguities

- "operator" was used for both the human driver and the new live-environment persona — resolved: the human is the lowercase **operator**; the persona is the **Actuator**.
- "writer" meant both source-editor and live-mutator — resolved: a **writer** is any single-writer persona over its targets; the **Implementer** writes source, the **Actuator** writes live state.
- "memory" was overloaded with harness/conversation memory — resolved: **judgment memory** is in-repo and tracked, explicitly NOT harness memory.
- "target" / "resource" / "lock" — resolved to **mutation target**, **blast radius**, and **lease** respectively.
