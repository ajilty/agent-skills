# Delegate on context cost, not difficulty: a second-strike tripwire for diagnosis

Field report: subagents were used well for up-front open-ended investigation (a
rebuild-mapper, a tunnel-debugger that absorbed all the CF API probing and returned a
fix-spec). But once in a live rebuild, the router diagnosed each successive gap **inline**:
three same-class failures (an image-SSM gap, a `/shared/cf-access/github-idp-id` failure, a
backstage-db recovery loop) each cost 4–6 verbose Bash calls — SSM dumps, `terraform state
show`, ESO reconciler stacktraces, the full CNPG restore error — landing straight in the
router's context. The tell is the inconsistency: the failure that *looked* hard up front
got a debugger (clean); same-class failures that *looked* like one-liners got inline
grinding (bloat).

§2a′ already argues for context-economy delegation ("delegate when work-to-produce ≫
result-size, because the router's own context is the scarce resource"). But as a *heuristic*
it was honored for work that looked noisy up front and forgotten for a diagnosis that looked
like a one-liner but wasn't. The discipline was mis-framed as "delegate hard things."

**Decision.** Add a concrete, difficulty-independent **tripwire** to §2a′: hand a diagnosis
to a fresh Troubleshooter (Researcher in diagnostic mode) the moment **either** trips —
(a) it isn't resolved in ~2 inline tool calls, or (b) the next step would pull **raw verbose
output** (pod/reconciler logs, a stacktrace, `terraform state show`, an SSM dump, a DB
restore error) into the router's context. Delegate the whole *diagnose → fix-spec* loop and
keep only the **fix decision**. The discipline is **context cost, not difficulty** — the
same-class failure gets delegated whether it looks scary or looks like a quick grind.
`researcher.md`'s Troubleshooter mode is reinforced: the raw logs stay in its throwaway
context; it returns root cause + exact fix compactly.

## Considered options
- **Leave §2a′ as a heuristic** — rejected: the field report is a measured case of the
  heuristic applied inconsistently *because* it had no mechanical trigger.
- **A hard cap (a hook that blocks a 3rd inline Bash on a diagnosis)** — rejected: not
  mechanizable (the router's diagnostic calls are indistinguishable from legitimate driving)
  and disproportionate; the tripwire is a judgment rule like the rest of §2a′.
- **Keep the difficulty framing ("delegate hard things")** — rejected as the framing that
  *caused* the leak: easy-looking-but-bloaty failures are exactly the miss.

## Consequences
- §2a′ gains the tripwire; `researcher.md` Troubleshooter mode reinforced; `agents/researcher.md`
  regenerated from the body. No new test — this is router judgment, not scriptable (same class
  as the clarify-gate discipline).
- Trade-off recorded: the tripwire can over-delegate a trivial diagnosis (a dispatch for a
  2-call fix). Accepted — the measured failure is *under*-delegation bloating toward a
  fidelity-destroying compaction, the more expensive side.

## Status

active
