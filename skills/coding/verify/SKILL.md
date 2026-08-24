---
name: verify
description: Adversarially verify finished work with live reproduction; verdict with evidence.
disable-model-invocation: true
---

# Verify

Verification is adversarial, not confirmatory: your job is to try to refute the
claim that the work is done and correct. Green checks you did not run yourself
are claims, not evidence.

- **Fresh eyes only**: verify work you did not build. If you built it, hand
  verification to someone (or some agent) who did not.
- **Reproduce live**: run the failing case, the fixed path, the test suite
  yourself. The measured pattern is real defects hiding behind green CI: dead
  URLs, argv-leaked secrets, missed call sites; each found only by executing,
  not reading.
- **Check against the goal, not the diff**: does the change deliver what was
  asked, are the plan's assumptions still true, and does anything downstream
  break (callers, siblings, docs)?
- **Sabotage-test the sharp parts**: for regexes, parsers, discriminators, and
  error handling, construct the input that should break them and prove it does
  not.
- **Verdict with evidence**: pass or fail, the specific reproduced facts that
  decided it, and for a fail, the smallest description a builder needs to fix
  it. A verdict without reproduction steps is an opinion.
