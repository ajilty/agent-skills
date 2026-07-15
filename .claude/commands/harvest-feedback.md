---
description: Harvest orchestrate run feedback from local repos (feedback.jsonl + reviews) and turn it into plugin improvements.
---
Collect and digest orchestrate field feedback from the live repos on this machine, so the
operator never has to copy it into the dev session by hand (ADR-0028).

1. **Gather (read-only — never write into the live repos):**
   - `ls ~/gits/github.com/ajilty/*/.agents/runs/orchestrate/eval/feedback.jsonl`
   - For each hit: read the jsonl rows (small files) and any `eval/reviews/*.md` sidecars
     the notes point at. Also glance the repo's latest `metrics` fields already embedded
     in the rows (shipped / friction / verify_coverage / model_mix / plugin_version).

2. **Digest, decision-ready:**
   - Per run: rating, plugin_version, the metrics one-liner, and the improvement items.
   - **Correlate each improvement item against the current plugin**: already fixed (name
     the ADR/version), ticketed (TODO.md), or NEW. The interesting output is the NEW list
     and any RECURRENCE of a ticketed item (recurrence = promote to fix, per precedent).
   - Watch the standing drift signals: `model_mix` all-flagship (ADR-0024 regression),
     all-sonnet researchers with no judgment-shaped output (ADR-0025), verify_coverage
     dropping on code-bearing lanes (ADR-0022).

3. **Propose:** for each NEW/recurrent item, a concrete change (SKILL prose, hook, tier
   table, test) with effort + an ADR call, ranked. Ask before implementing unless the
   operator already said go.

If no feedback files have changed since the last harvest, say so in one line — don't
manufacture findings.
