---
name: working-with-wiz-mcp
description: Sharp edges for the Wiz MCP — SBOM/package inventory, malicious-package and malware findings, graph_search, secrets and network exposure. Use when assessing cloud/Kubernetes blast radius, checking whether a package or version is present anywhere, running CVE exploitability hunts, or interpreting fields like isAccessibleFromInternet and executionControllers.
---

# Working with the Wiz MCP — sharp edges (cloud/k8s blast radius)

How to drive the Wiz MCP tools for security hunts. If tools are deferred, load schemas first
(e.g. ToolSearch `select:mcp__wiz__list_sbom`). **Multi-tenant orgs:** separate MCP server
entries for each Wiz tenant share the same URL (`https://mcp.app.wiz.io`) — tenant selection is
scoped to the OAuth session, so one tenant never answers for another; run every hunt against
each tenant.

## Package / SBOM presence (the "are we affected" question)

- `list_sbom` with a name filter, `list_package_dependencies` for exact names, and
  `graph_search` for library nodes. Search across cloud workloads **and** container images.
- **Substring search lumps languages and yields benign lookalikes** (a search for `vapi` matches
  `vmware.vapi` and `vapi-client-bindings`). Always confirm the **exact** package name *and*
  version before flagging — and exclude the known lookalikes.
- **Prove scanning is live before trusting a negative.** Run a control query for a package you
  know is present (e.g. `express`) and confirm it returns; only then is a `totalCount: 0` a true
  negative rather than a scanner blind spot. (SBOM reflects the last scan, so a transient
  in-build pull can still be missed — pair with endpoint/CI telemetry.)
- Wiz "Malicious Package" detections surface via `list_vulnerability_findings`
  (malicious-package / component-name filter); also check `list_malware_findings`.

## Amplification context

- `list_secret_findings` (exposed creds an executed payload could harvest),
  `list_network_exposure` (internet-facing?), and identity/entitlement tools for blast radius.
- **The issue API returns no portal deep links** — render items as "link not captured"; never
  construct an `app.wiz.io` console URL by pattern.
- Treat specific findings as **transactional** — re-pull at query time rather than caching them
  as durable facts.

## CVE exploitability / blast-radius hunts (presence AND exposure)

*(Captured from a single CVE investigation; verify against your tenant before relying on the
finer details.)*

- **Split a CVE into presence vs exposure, then join — never rank on presence alone.** Presence =
  *is the vulnerable artifact here at all* (Vulnerability Findings); exposure = *can it be
  reached* (Security Graph). Ranking on presence alone over-counts internal assets and is
  decisively wrong for an unauth-RCE — join the two and rank on the intersection.
- **A multi-product CVE spans four inventory surfaces — enumerate each.** One vulnerable
  component can land as (1) an **OS package**, (2) an **image SBOM** entry, (3) a **K8s
  workload**, and (4) an **external connector** asset. A single CVE filter misses the
  K8s-controller and appliance variants — query all four surfaces.
- **Wiz does NOT parse application config.** Config-dependent reachability (e.g. an `nginx.conf`
  rewrite pattern that gates whether the CVE is actually hit) cannot be answered by Wiz —
  confirm it out-of-band, then re-import the result as a **custom asset tag** so the graph can
  use it.
- **`isAccessibleFromInternet: null` ≠ `false` — the single biggest lesson.** Wiz returns `null`
  when it can't fully chain a public path, *not* a confirmed "internal." Treat `null` as unknown
  and cross-check raw cloud load-balancer inventory before concluding an asset is not
  internet-facing.
- **Finding-level `executionControllers: []` underreports cross-account deploys.** An empty
  controller list at the finding level does not mean the image is undeployed — for
  centralized-registry patterns the deploy lives in another account. Use
  `list_container_image_execution_context` for the real execution context.
- **`list_kubernetes_clusters` rejects cloud account IDs.** It wants the internal Wiz
  **subscription UUID**, and the error on an AWS account ID is unhelpful. Translate account ID →
  subscription UUID via `list_subscriptions` first.
- **Pagination is not cleanly disjoint** (`first:20` max; a DESC then ASC pass only partially
  overlaps). For exhaustive enumeration use the **grouped endpoints** with
  `group_by=["VULNERABLE_ASSET"]` and accept multiple ordering passes rather than trusting one
  page.
- **Param naming is inconsistent across sibling tools** — fetch the exact schema first before
  composing a call; don't reuse a sibling's param name.
- **`list_issues` returns no assignee fields** — "unassigned" cannot be verified from a list
  call; carry a prior observation as unconfirmed, or fetch the single issue.
- **Wiz "Issues" lag — don't read "0 Issues" as low risk.** Fresh Vulnerability Findings may not
  yet have rolled up into Issues; a `0 Issues` count on a new CVE is a lag artifact, not an
  all-clear.

## What this skill does not cover

Creating findings, suppressions, or ignore rules — read-only hunting only.

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
