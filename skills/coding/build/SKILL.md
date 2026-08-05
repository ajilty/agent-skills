---
name: build
description: Use when implementing a planned change in code; triggers include executing a spec or task list, "build this", "implement the plan", or any coding task whose plan and acceptance criteria already exist.
---

# Build

Execute the plan; do not re-litigate it. The hard judgment happened upstream,
so the craft here is fidelity and completeness.

- **One task, smallest correct change.** Scope creep in the build silently
  invalidates the plan's independence claims.
- **Tests pass against the committed HEAD**, not a green-but-unsaved working
  tree. The commit is the artifact: after committing, confirm the tree is clean
  and the commit's stat contains your change, and report the SHA plus file list
  so a reviewer reads proof instead of re-deriving it.
- **A mandated test is never weakened, replaced, or deleted silently.** If you
  believe a test is wrong, keep it failing and flag the conflict; rewriting the
  test so your code passes is carving the oracle to fit the code.
- **Sweep the defect class, not just the instance.** After fixing a defect,
  grep for every sibling instance of the same class (same pattern, same
  mistaken assumption, other call sites of the thing you fixed); fix the
  in-scope ones and list the rest in your result.
- **Deviations are reported, not absorbed**: anything the plan did not cover,
  and anything you assumed to proceed, is listed with the result.
