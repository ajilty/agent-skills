# Clarification-skill returns pass the quarantine gate

ADR-0004 established that the router invokes clarification skills (grill-with-docs,
grill-me, brainstorming, inline) for the *work they produce* and ignores their
built-in control-flow handoffs. That settles **sequencing**. It does not settle
**content trust**: a clarification skill runs in the router's own context (only the
router talks to the operator), so its return re-enters with no persona boundary and
— before this decision — with no §4 quarantine pass. A clarification skill can
surface externally-sourced material mid-interview (a doc grill-with-docs read, a web
fact brainstorming cited), which would reach router context unneutralized. This was
the one inbound path that bypassed the trust model's quarantine boundary (§0/§4).

**Decision:** the §4 quarantine gate runs on clarification-skill returns too (§4a).
Because clarification skills are third-party and do not emit the Researcher's
`findings` / `untrusted_excerpts` region split, the router **separates the return on
consumption** into three buckets: the operator's substantive answers (`TRUSTED`),
the skill's procedural handoff (inert — the ADR-0004 rule), and any externally
sourced material the skill surfaced (`UNTRUSTED`, tagged `#EXTERNAL(... untrusted)`,
admissible to the spec only as `#ASSUMPTION`, never a `#DECISION`).

This **refines** ADR-0004 (control-flow scope) with a content-trust scope; it does
not supersede it. Both remain active.

## Consequences

- No new hook or script. §4 is router discipline mechanized only downstream; tagging
  bucket 3 `#EXTERNAL(... untrusted)` routes it into the **existing** §5 bounce
  (a `#DECISION` tracing to untrusted origin is invalid) and the Verifier provenance
  walk. The teeth that backstop the Researcher path now backstop this one — stated as
  advisory router discipline, not presented as a hook guarantee.
- The trust contract gains `clarification_return: quarantine` in `agents.yaml`'s
  `trust:` block as documentation. It is **not** compiled by `build.sh` (which reads
  only `personas.*`), so no generated artifact changes.
- Operator friction is unchanged for the common case: a clear answer with no external
  citation is `TRUSTED` and flows straight through. The gate only bites when a
  clarification skill imports outside material into the answer.
