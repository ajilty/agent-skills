# Decision Index

Rebuilt from docs/adr/*.md by `adr.sh reindex`. The Planner reads this at
intake and does not re-litigate an active decision; a goal contradicting one
raises a DECISION_FORK citing it (supersede flow).

| ADR | Decision | Status |
|-----|----------|--------|
| [0001](0001-extend-orchestrate-not-augment-superpowers.md) | Extend orchestrate rather than augment superpowers | active |
| [0002](0002-single-writer-over-mutation-targets.md) | Single-writer is defined over mutation targets, not files | active |
| [0003](0003-judgment-memory-in-repo-not-harness.md) | Judgment memory is in-repo and tracked, never harness memory | active |
| [0004](0004-router-owns-sequencing.md) | Router owns sequencing; sub-skills are invoked for work, not control flow | active |
| [0005](0005-filesystem-two-axis-split.md) | Filesystem two-axis split — tracked docs/ vs gitignored .agents/ | active |
| [0006](0006-per-dispatch-context-via-on-disk-active-writer.md) | Per-dispatch enforcement context via an on-disk active-writer record | active |
| [0007](0007-plugin-is-generated-distribution-of-agents-yaml.md) | Plugin packaging is a generated distribution of the agents.yaml contract | active |
| [0008](0008-subdir-plugin-monorepo-over-repo-root.md) | Subdir-plugin monorepo over repo-root-as-plugin | active |
| [0009](0009-clarification-returns-pass-quarantine.md) | Clarification-skill returns pass the quarantine gate | active |
| [0010](0010-run-scope-denylist-not-allowlist.md) | Verifier run-scope is a best-effort mutation denylist, not an allowlist | active |
| [0011](0011-writeahead-on-pretooluse-dispatch-not-subagentstart.md) | Writer write-ahead fires on PreToolUse of the dispatch tool, not SubagentStart | active |
| [0012](0012-subagents-not-agent-teams.md) | Orchestrate dispatches capability-subtracted subagents, not agent-teams teammates | active |
| [0013](0013-shared-checkout-destructive-git-floor.md) | A universal floor refuses destructive git on the shared (primary) checkout | active |
| [0014](0014-disk-first-read-lane.md) | Read-only results are disk-first: durable, attributed, gated on read | active |
| [0015](0015-front-door-clarify-gate.md) | Clarification is a front-door gate keyed on a nameable oracle, not a post-Planner fallback | active |
| [0016](0016-codex-hook-enforcement-scope.md) | Codex enforces fail-closed hooks for the MAIN agent's hooked tools, not for spawned subagents or apply_patch | active |
