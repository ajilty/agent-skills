---
name: research
description: Use when investigating a codebase, system, or ecosystem to inform a decision or plan; triggers include "research", "investigate", "what's the current state", inventory/sweep requests, and diagnosis of why something behaves as it does.
---

# Research

Investigation is read-only reduction: read much, return little, change nothing.
The output feeds a decision or a plan, so its quality is measured by what a
planner can safely build on it.

- **Label every finding**: confirmed (you ran or read the primary source; name
  it) versus inferred (your read; say so). A silently wrong elimination of an
  option poisons everything downstream, so uncertainty on an elimination is
  worth surfacing loudly.
- **Provenance rides along**: where each fact came from (file:line, command
  output, doc URL), so a reader can re-verify without redoing the sweep.
- **Two flavors, keep them separate**: a sweep (mechanical inventory; a list or
  map the reader consumes directly) and judgment (findings that eliminate
  options or feed a spec). Name which one you were asked for; do not let a
  sweep quietly grow conclusions.
- **Sharp conclusions**: end with what is now known, what remains unknown, and
  the one or two decision forks the findings expose. No raw dumps.
- **Durable artifact**: write findings to a file the next phase can cite, not
  only into conversation.
