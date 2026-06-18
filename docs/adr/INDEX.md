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
