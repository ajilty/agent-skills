---
name: working-with-horizon3-mcp
description: Sharp edges for the Horizon3.ai / NodeZero MCP (autonomous pentest results) — pentests, weaknesses, proven impacts, attack paths, harvested credentials, and remediation. Use when reading NodeZero pentest results via MCP, digesting a completed pentest, hitting "Cannot query field" GraphQL errors, or answering "what did the pentest actually prove / how do we fix it".
---

# Working with the Horizon3 / NodeZero MCP — sharp edges

How to drive the Horizon3 MCP for reading autonomous-pentest results. The server is an HTTP MCP
at `mcp.horizon3ai.com`. If tools are deferred, load schemas first (e.g. ToolSearch
`select:mcp__horizon3__run_h3_graphql_request`). If the tools aren't present, call
`mcp__horizon3__authenticate` for an OAuth URL — but **`authenticate` itself may not be exposed
in a given session**, in which case re-auth requires reconnecting the connector interactively.
**Token TTL is ~24h in practice** — while a pentest's loot clock is live, expect re-auth to be a
near-daily task, and preflight this connector every run. Treat a dead Horizon3 connector as
**time-boxed loss**, not a cosmetic gap: pentest loot files expire ~5 days after completion.
Read-only: never call `run_pentest` or any mutation.

## Terminology gate (mandatory, and it's also your schema cheat-sheet)

- **Call `get_h3_terminology` FIRST, every session.** The MCP's own tool contracts require it,
  but the real reason is that it's the most reliable schema documentation available —
  introspection is broken (below). It defines the concept hierarchy *and* names field groupings
  (e.g. it reveals `remediation_guidance` decomposes into `fix_action` / `fix_action_description`
  / `fix_action_link`).
- Concepts that change how you report: **weakness** = *proven-exploitable* (not a theoretical
  vuln); **impact** = a business consequence NodeZero actually achieved; **attack_path** = a
  proven chain; **context_score** (0-10) = real-world exploitability — **rank on this, not CVSS
  base**.

## Reading a completed pentest

- **Easy path for locating + stats:** `get_pentest_details` (filter `text_search` /
  `completed_after` / `state`), then re-call with `include_vulnerabilities` /
  `include_attack_paths` / `include_credentials = true` on the `pentest_id`. Good for headline
  counts.
- **Query objects that exist:** `pentests_page`, `weaknesses_page(input:{op_id})`,
  `attack_paths_page(page_input)`, `credentials_page(input:{op_id})`. **There is NO
  `impacts_page` and NO `fix_actions_page`** — the `Query` type has neither (the "Did you mean"
  error confirms it). Read impacts via the pentest's `impacts_count` plus the attack-path
  objects, not a standalone page.
- **No API field returns a NodeZero console/portal URL** (`pentests_page` and
  `get_pentest_details` expose no link field). Hand a pentest to the user by `op_id` with "open
  it in the NodeZero Portal" — never a guessed console URL.

## Remediation — the trap that costs a re-run

- **Get remediation text from `weaknesses_page(input:{op_id}).weaknesses.vuln.description`.**
  That's where the usable fix guidance lives (e.g. a Jenkins CVE description spelling out the
  exploit mechanics and the fix version).
- **The `fix_action` / `fix_action_description` / `fix_action_link` fields are NOT exposed on the
  `Weakness` or `Vuln` GraphQL types** — despite `get_h3_terminology` advertising them.
  NodeZero's step-by-step fix actions are **portal/report-only**; don't promise them from the API.
- **Do NOT trust `get_vulnerability_details(include_remediation=true)`** — it reports remediation
  as "not available in current GraphQL schema," which mislabels the gap. The description *is*
  available via `weaknesses_page`; the helper just doesn't fetch it. Go to raw GraphQL.

## "Clean run" needs two corroborating fields, not one

A no-impact result is confirmed by **`impacts_count: 0` AND an empty `attack_paths` array
together** — treating either alone as "clean" risks reading a display/pagination gap as an
all-clear. NodeZero can reach 1,000+ hosts and harvest creds yet still chain zero proven impact;
that's the signal to report, with both fields cited.

## Pagination + filtering gotchas

- **`weaknesses_page` returns a default page (~20) — the full set can be several times larger.**
  Paginate for exhaustive enumeration; the severity *ceiling* and distinct classes are usually
  visible on page one, but counts are not.
- **`OpInput` (the `weaknesses_page` input) has `op_id` but no `severities` filter** — filter
  severity client-side after pulling.
- **Weakness fields that work:** `uuid`, `vuln_name`, `severity`, `score`, and nested
  `vuln { id name description }`. `Vuln` has `description`, NOT `remediation` (the error suggests
  "Did you mean 'description'?").

## Introspection is broken — discover fields by trial

- **`fetch_h3_graphql_docs` and GraphQL `__type` introspection error server-side** ("An
  unexpected error occurred. We are investigating."). You cannot browse the schema.
- Discover fields by **trial-and-error**: the query engine returns `Cannot query field 'X' on
  type 'Y'` and *sometimes* a `Did you mean 'Z'?` hint on scalar fields (not on every miss).
  Start from the known-good field lists above and add incrementally.

## Credentials + data

`credentials_page(input:{op_id})`, `cred_type` (e.g. `SNMP_COMMUNITY_STRING`, `STANDARD`).
**Report type and count only, never secret values.**

## Scope-awareness when reporting (don't overclaim)

An **internal network pentest** (e.g. "From <site> - 10.0.0.0/8") is **scope-disjoint from the
cloud-identity/control plane** — identity providers, cloud IAM roles, and CDN/WAF perimeter won't
appear and are outside its reach. A clean network pentest neither clears nor challenges those;
say so explicitly rather than letting "0 impacts" imply the identity plane is fine.

## What this skill does not cover

Running or scheduling pentests, writing findings, or investigating to a verdict — this is
read-only results reading.

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
