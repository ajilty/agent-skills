# Problem: vulnerability remediation tracking (vuln-tracking-b)

Problem statement: six product teams track vulnerability remediation in
ad-hoc spreadsheets; SLA breaches surface late; the security team spends
roughly 10 hours a week manually chasing status.

Current state (from intake research, summarized): one scanner feeds
findings; each team keeps its own spreadsheet; there is no shared view of
open items, owners, or age; a 30-day SLA for critical/high severities exists
in policy.

Success looks like: every open critical/high finding has one owning team, a
visible SLA clock, and pre-breach alerting; security's chase time goes to
exceptions only.

Scope boundary:
- In: tracking and reporting for infra and app vulnerabilities from the
  existing scanner.
- Out: replacing the scanner; changing the patching process itself.

Assumption register:
- A1 (default): the existing ticketing system remains where teams actually
  work. Reversible.
- A2 (default): the 30-day SLA stands unless a policy review says otherwise.
  Reversible.
