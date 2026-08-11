# Shipyard research brief: what to incorporate next

**Date:** 2026-08-10
**Status:** Options for decision
**Method:** four parallel research tracks (efficacy evidence, user interaction
preferences, interaction forms, competitive landscape), sources linked in the
appendix. Confidence labels ride each claim.

## The verdict, first

- **The shape is validated, component by component.** Plan-first generation
  (+25% relative Pass@1), documentation-as-context (+83-220% on unfamiliar
  APIs), clarifying questions on underspecified asks, premortems (~30% more
  failure modes surfaced), structured decision process (~6x more predictive
  of outcome than analysis depth), and independent verification (builders
  self-report 20% faster while measuring 19% slower) each have direct
  evidence. Users across occupations, not just coders, prefer plan-first,
  checkpoint-gated collaboration with editable artifacts over both
  fire-and-forget autonomy and conversational drift.
- **The one proven enemy is the rubber stamp.** Humans approve ~93% of
  uniform prompts; evaluators defer 19 points more to AI recommendations,
  and well-argued memos make scrutiny worse, not better. No end-to-end
  scaffold beats direct prompting by default: the gates carry the value, and
  gates decay. Everything in the adopt-now tier hardens a gate or removes a
  reason to bypass one.
- **Market position: the middle is crowded, the ends are uncontested.**
  Kiro, Spec Kit, BMAD, Agent OS, and Task Master all live in
  spec-plan-tasks-implement. No shipped system does problem confirmation
  before solutioning or scored-options-returned-as-memo, and almost none
  does independent verification plus delta plus explicit acceptance.
  Shipyard's differentiation is decision quality at the two ends; the
  borrowable gaps are a consistency gate, a standards layer, and a
  sanctioned fast path.

## Options

| # | Change | Why (evidence) | Size | Tier |
|---|--------|----------------|------|------|
| 1 | **Delta-first gate artifacts**: every gate leads with intent recap, drift since last approval, and open decisions ranked by risk; re-review is a diff, not a re-read | 6x faster time-to-first-review and measurably less misalignment when intent+drift lead (ARCTIC) | S | Adopt now |
| 2 | **Active-choice ballot**: the memo's return block becomes checkboxes edited in the file (no copy-paste), and bare approval is not an option: the human strikes an option, amends, or writes one disconfirming condition; on Claude Code the enumerable choices also arrive as structured questions | Deference grows with better-argued memos (HBS); forced generative acts are the known counter; structured instruments beat unguided chat | S | Adopt now |
| 3 | **Cross-artifact consistency check at ship entry**: requirements trace to memo trace to problem statement; contradictions surface before build | Spec Kit's most-praised feature; shipyard currently only verifies post-build | S | Adopt now |
| 4 | **EARS syntax for requirements** | Operationalizes the ISO 29148 grounding already claimed; mechanically testable statements; industry canon | S | Adopt now |
| 5 | **A worked example per requirement**, piped into ship's context | Examples drive most of the documentation-as-context gain (83-220%); prose alone leaves it on the table | M | Adopt now |
| 6 | **Appetite on the memo**: the human's effort/time budget is a scored dimension of the pick; ship escalates on budget exhaustion | Shape Up's one durable idea: converts "build it" into a bounded bet with a non-quality stop condition | S | Adopt now |
| 7 | **Verifier-only delta report, explicit and non-optional** | Builder self-assessment is systematically optimistic (METR RCT); mostly already the design, make it unbypassable | S | Adopt now |
| 8 | **Natural-language on-ramp**: a plain ask routed through the router lands in the right segment; typed commands stay the power-user accelerator | Slash commands win on predictability for repeat use, natural language on discoverability; hybrid is the practitioner consensus | S | Adopt now |
| 9 | **Confidence and provenance labels on every recommendation**, with low-confidence flags | Transparency is the strongest preference driver; targeted low-confidence warnings beat blanket disclaimers | S | Adopt now |
| 10 | **Sanctioned fast path**: confirmed-trivial, reversible work collapses to one pass with acceptance as the only gate, chosen at the router | Without a legitimate fast lane users route around the method (Kiro Quick Spec; Devin's confidence gating) | M | Next |
| 11 | **Standing constitution file per project** that all segments read: conventions, stack, non-negotiables, settled once | Spec Kit constitution / Agent OS standards; keeps memos about the decision, complements ADR graduation | M | Next |
| 12 | **Outcome instrumentation**: per-run gate time, rework after ship, acceptance-vs-delta counts logged into the artifacts | Head-to-head scaffold evidence is mixed; shipyard's own claim needs its own data | M | Next |
| 13 | Model-confidence-triggered escalation (proceed on green, gate on yellow/red) | Devin reports it works; requires calibration trust shipyard can't verify yet | M | Hold |
| 14 | Complexity-scored, dependency-ordered build tasks in ship | Strong error-reduction result (Task Master), but ship often delegates to an orchestration system that owns this | M | Hold |
| 15 | Self-contained local HTML gate brief with form write-back | Worth it only if long-memo reading stays painful after 1-2; keep file-portable if built | M | Hold |
| 16 | Experience-scaled autonomy (wider absent-mode asserts, distinctly tagged) | Veterans demonstrably grant longer leashes over time; premature before instrumentation exists | S | Hold |
| 17 | Mid-run status artifact between gates | Users want visibility without gates; partially served by /shipyard today | S | Hold |

**Explicitly not recommended:** richer canvases for their own sake (the
measured wins come from restructured artifacts, not prettier surfaces); any
additional gates (fatigue evidence is unambiguous: fewer, harder); depending
on small markup tools like md-redline (treat as format inspiration);
"smarter" approval prompts (the fix for rubber-stamping is structural, not
verbal).

## What each track found

**Does it move the needle?** Yes for the components, unproven for ceremony.
Plan-first, docs-as-context, clarification, premortems, decision process,
and independent verification all carry direct measured support; full
scaffolds tested head-to-head are mixed and task-dependent, and DORA 2025
shows AI throughput gains converting to instability precisely where the
control layer is missing. The documented failure mode is the gate decaying
into approval theater.

**Is this how users want to interact?** Yes, and beyond coding: equal
partnership is the dominant desired agency level across occupations, workers
want more involvement than technologists assume, and users prefer
inspectable, editable plans over discovering agent actions through chat. The
two evidenced wants shipyard doesn't serve yet: visibility between gates,
and rigor that scales down for small work and seasoned users.

**What interaction forms are better?** Restructured review artifacts beat
richer surfaces: intent-and-drift-first documents, risk-ranked decision
lists, ballots edited in the file rather than copy-pasted, structured
question prompts at the gate. Everything in the adopt-now tier stays plain
markdown plus harness primitives.

**Who else is doing this?** The spec-driven middle is crowded and good;
worth taking are Spec Kit's consistency analysis and constitution, Kiro's
graduated rigor, Shape Up's appetite, and audit-grade gate records. Nobody
shipped scope/shape or verify/accept-with-delta; that is the moat.

## FAQ

**Doesn't this add ceremony?** No net gates are added; items 1-9
restructure artifacts and gate mechanics that already exist, and the
research argues for fewer, harder gates, which items 2 and 10 implement.

**Why not adopt Kiro or Spec Kit instead?** They own the middle of the
pipeline and end at "implement." Shipyard's value sits upstream (problem
confirmation, scored options) and downstream (independent verification,
delta, acceptance) where the field is empty. Borrowing their three best
parts costs days; abandoning the ends would surrender the differentiation.

**Didn't we just retire assignment?** The fast path (item 10) readmits
assignment's ergonomics inside the method as a sanctioned, router-chosen
rigor level, rather than a parallel skill that competes with it.

**How will we know it worked?** Item 12 instruments the runs; the per-skill
evals already encode behavioral expectations. Adopt-now items get the same
treatment as every prior change: eval expectations first, then wording.

## Decision block

```text
SHIPYARD RESEARCH BRIEF: mark and return
Adopt now (1-9):      [ ] all nine   [ ] all except: ___
Next tier (10-12):    [ ] 10 fast path  [ ] 11 constitution  [ ] 12 instrumentation
Hold items to promote (13-17): ___
One disconfirming condition that would change your mind on the adopt-now tier: ___
OVERALL: proceed | modify as marked | discuss first
```

## Sources by track

**Efficacy:** [Self-planning code generation](https://arxiv.org/abs/2303.06689) ·
[API docs as context](https://arxiv.org/abs/2503.15231) ·
[DORA 2025](https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report) ·
[METR developer RCT](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) ·
[Idea2Plan](https://arxiv.org/pdf/2510.24891) ·
[S2SServiceBench](https://arxiv.org/pdf/2602.14017) ·
[HITL rubber stamp](https://tianpan.co/blog/2026-04-15-human-in-the-loop-rubber-stamp) ·
[Approval fatigue](https://aipatternbook.com/approval-fatigue) ·
[Premortem study](https://idl.iscram.org/files/veinott/2010/1049_Veinott_etal2010.pdf) ·
[Decision process vs analysis](https://sloanreview.mit.edu/article/a-structured-approach-to-strategic-decisions/) ·
[Clarifying questions](https://arxiv.org/pdf/2410.13788) ·
[Alibaba HITL field RCT](https://arxiv.org/abs/2605.14830)

**Interaction preferences:** [Developers don't vibe, they control](https://arxiv.org/html/2512.14012) ·
[Stanford Future of Work audit](https://arxiv.org/html/2506.06576v3) ·
[Plan-then-execute (CHI 2025)](https://arxiv.org/pdf/2502.01390) ·
[Cocoa co-planning](https://arxiv.org/pdf/2412.10999) ·
[Oversight fatigue](https://arxiv.org/pdf/2606.08919) ·
[Why Johnny can't use agents](https://arxiv.org/pdf/2509.14528) ·
[Autonomy telemetry](https://arxiv.org/pdf/2606.07489) ·
[Trust calibration](https://arxiv.org/pdf/2402.07632) ·
[Transparency conjoint](https://arxiv.org/pdf/2606.18716) ·
[RedMonk agentic IDEs](https://redmonk.com/kholterhoff/2025/12/22/10-things-developers-want-from-their-agentic-ides-in-2025/) ·
[Slash commands](https://jxnl.co/writing/2025/08/29/context-engineering-slash-commands-subagents/)

**Interaction forms:** [Anthropic: containing Claude](https://www.anthropic.com/engineering/how-we-contain-claude) ·
[ARCTIC review study](https://arxiv.org/html/2607.29516v1) ·
[AI feedback in reviews](https://arxiv.org/html/2602.13817v1) ·
[Structured prompting](https://www.mdpi.com/2306-5729/10/11/172) ·
[spec-kit AskUserQuestion issue](https://github.com/github/spec-kit/issues/2181) ·
[md-redline](https://github.com/dejuknow/md-redline) ·
[md-review-plus](https://github.com/Seiraiyu/md-review-plus) ·
[gum](https://www.x-cmd.com/pkg/gum/)

**Landscape:** [Kiro specs](https://kiro.dev/docs/specs/) ·
[GitHub Spec Kit](https://github.com/github/spec-kit) ·
[BMAD method](https://github.com/bmad-code-org/BMAD-METHOD) ·
[Agent OS](https://buildermethods.com/agent-os) ·
[Claude Task Master](https://github.com/eyaltoledano/claude-task-master) ·
[OpenAI AgentKit](https://openai.com/index/introducing-agentkit/) ·
[Devin release notes](https://docs.devin.ai/release-notes/2025) ·
[LangGraph interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts) ·
[CrewAI human feedback](https://docs.crewai.com/en/learn/human-feedback-in-flows) ·
[shape-up-ai-native](https://github.com/sergiolindolfoferreira/shape-up-ai-native) ·
[McKinsey Lilli](https://venturebeat.com/ai/consulting-giant-mckinsey-unveils-its-own-generative-ai-tool-for-employees-lilli)
