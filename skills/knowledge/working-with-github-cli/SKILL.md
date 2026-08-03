---
name: working-with-github-cli
description: "gh CLI across a SAML-protected GitHub enterprise: endpoint-to-scope table, per-org SSO PAT authorization behind 403 \"protected by organization SAML enforcement\", code-search limits (default branches only), contents-API idioms, per-user activity pitfalls (contributionsCollection lies for non-self). Use when hunting across org repos, runners, packages, or audit logs, or when a user's activity numbers look implausibly low."
---

# Working with the GitHub CLI — sharp edges (enterprise hunting)

How to drive `gh` across SAML-protected orgs for fan-out hunting, inventory, and per-user
activity lookups.

## Token scopes — know which endpoint needs what

| Endpoint | Required scope |
|---|---|
| `/orgs/<org>/audit-log` | `admin:org` **+** `read:audit_log` (classic PAT) |
| `/orgs/<org>/dependabot/alerts` | `security_events` |
| `/orgs/<org>/packages` | `read:packages` |
| `/orgs/<org>/actions/runners` | `admin:org` |

- Add scopes with `gh auth refresh -h github.com -s <scope>` (interactive — the user completes
  the browser/device step).
- **SAML wall:** orgs return `403 "protected by organization SAML enforcement"` even with the
  right scope until the PAT is **SSO-authorized per org** (GitHub → Developer settings → PAT →
  Configure SSO → Authorize, per org). Some orgs also 403 simply because the caller is not an
  admin there. Record which orgs were queryable vs blocked.
- **Audit-log bypass:** if your org streams GitHub enterprise audit events into a SIEM, querying
  there gives enterprise-wide visibility that bypasses every per-org SAML wall — far better than
  iterating `/orgs/<org>/audit-log`.

## Efficiency

- **Code search is heavily rate-limited (~10/min per token)** and unscoped by default (returns
  public-GitHub noise) — always `--owner=<org>`-scope it, and prefer the git-trees + contents
  API (`/repos/<o>/<r>/git/trees/<branch>?recursive=1`, 5000/hr) for exhaustive sweeps.
- Code search only indexes **default branches**; feature branches, PRs, and archived repos are
  not covered — note that as a residual gap when scope matters.
- `gh search code` substring matches yield benign lookalikes — confirm exact path/name.
- **Issue search can be stale per-repo** — a dated `gh search issues` query can return empty for
  an issue that plainly matches. The verification path is plain
  `gh issue list --repo <r> --state all` + client-side filter; treat search emptiness as
  unverified, not as absence.
- Enumerate orgs with `gh api user/orgs --jq '.[].login'` — **but it does NOT list every
  accessible org.** An org reachable via `gh repo list <org>` can be absent from the list; when
  you suspect an org exists, probe it directly.

## Code-audit idioms (fast fan-out across many repos)

- **`gh search code --owner <org> '<pattern>'` audits many repos fast** (tens of repos across
  orgs in minutes). Returns ~30 results/call as **~3-line fragments**, not whole files — follow
  up on a hit with `gh api repos/<o>/<r>/contents/<path> --jq .content | base64 -d`.
- **Search fragments come back literal-escaped** (`\n` as two characters, not a newline). Add
  `| gsub("\n";" ")` in the `--jq` to flatten them into readable single lines.
- **`gh api …/contents/<path>` returns object-for-file vs array-for-dir.** Shape-check `type`
  before indexing — a blind `.content` access dies on a directory path.
- **Fetch a file by branch/SHA on a private repo via the contents API, not raw.**
  `raw.githubusercontent.com/<o>/<r>/<branch>/<path>` 404s when the branch name contains slashes
  (can't disambiguate branch from path) and again on private repos (curl carries no auth). Use
  `gh api repos/<o>/<r>/contents/<path>?ref=<sha-or-branch> --jq .content | base64 -d`.

## Per-user activity lookups

- **`contributionsCollection` lies for non-self queries.** Querying *another* user's
  contributions silently zeroes private-repo activity the requester can't see. Never report
  "user had 0 commits" from it without that caveat.
- **Search visibility ≠ contribution visibility.** Search results respect *repo* visibility from
  the requester's vantage; contribution counts respect the *target user's* privacy settings.
  Prefer search-derived counts and label contributions-derived numbers as such.
- **Treat a zero-activity result for a believed-active user as a resolution failure, not a true
  zero.** Login conventions vary wildly — org-suffixed (`jdoe-acme`), unrelated handles, or
  display-cased bare names — and a naive guess (e.g. stripping dots from `first.last`) silently
  returns zero for an active user. Cheapest exact resolution: `gh pr view <n> --repo <o>/<r>
  --json author` on a PR you know they authored; else match display names via
  `gh api orgs/<org>/members`. Record resolved mappings somewhere durable so you never re-derive.
- **One GraphQL request beats five REST calls** for activity rollups: search-by-author,
  by-commenter, by-reviewer, contributionsCollection, and rate-limit info fit in a single
  query.
- **Don't sum `commits.total` against per-repo numbers expecting agreement** — the API total is
  subject to privacy, per-repo numbers reflect what the requester can see; they legitimately
  differ.
- **Don't use `gh search prs --author=<x>` alone** for a person's footprint — it scopes to
  listable repos, misses cross-org results, and skips review/comment surfaces.
- **Don't paginate beyond 100 per surface** — narrow the window and declare truncation instead.
- **External-org activity counts.** A PR in an unexpected org still belongs in a person's rollup
  if they authored or reviewed it. On a 404/permissions error, surface a missing-access item —
  never silently skip the org and report a false zero.
- **The org audit log bypasses user privacy settings** (events are org-scoped, not user-scoped) —
  a useful fallback when a user's activity is privacy-hidden but you hold org audit access.

## What this skill does not cover

Modifying repos, runners, packages, or settings — read-only hunting only. It holds no org
inventory; pull live with `gh api`.

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
