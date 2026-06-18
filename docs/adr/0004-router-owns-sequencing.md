# Router owns sequencing; sub-skills are invoked for work, not control flow

orchestrate's router invokes other skills — grill-with-docs, brainstorming, the
writing-plans discipline — for the *work they produce*, but ignores their
built-in terminal handoffs (brainstorming → writing-plans → SDD). The router
retains control of its own loop. This lets us borrow superpowers / mattpocock
skills without inheriting their opinionated control flow, and stops a sub-skill
from hijacking the loop.

## Consequences

- Interactive, operator-facing skills (the **Clarification step**) run in the
  **router context**, because only the router talks to the operator; personas are
  non-interactive and cannot grill the human.
- The portable `SKILL.md` references the clarification **role**, not a concrete
  skill, with a deployment-bound preference order
  (`grill-with-docs` → `grill-me` → `brainstorming` → inline Q&A), using whichever
  is present — same philosophy as "one capability contract, three compilers."
- The clarification is **scoped to the open `#UNKNOWN`s**, not an open-ended design
  interview, so it stays proportional to the ambiguity.
