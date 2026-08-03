---
name: working-with-slack-mcp
description: "Slack MCP search gotchas: from:<@U…> angle-bracket form (bare IDs return zero), include_context=false or blow the 25K cap, the real page cap is 20 not 100, invisible channels omitted silently, is:unread degrades to a keyword match, write tools can vanish while reads work. Use when searching Slack messages, building per-user or per-channel sweeps, or when search results look implausibly thin."
---

# Working with the Slack MCP — sharp edges

Search and read mechanics for the Slack MCP tools (`slack_search_*`, `slack_read_*`).

## Search query construction

- **`from:` filters need the angle-bracket mention form: `from:<@U0XXXXXXX>`.** A bare
  `from:U0XXXXXXX` returns zero results — the search index treats `from:` user-filters as
  mention tokens, not raw strings.
- **`on:YYYY-MM-DD` beats `after:`/`before:`** for day-scoped queries — the window forms are
  exclusive and invite off-by-one errors.
- **`include_context=false` is mandatory on sweeps.** The default `true` attaches surrounding
  messages and blows past the 25K-token response cap on busy days, and the context is rarely
  useful.

## Pagination reality

- **`slack_search_public_and_private` caps each page at 20 results**, regardless of what the
  docs or the `limit` param suggest. There is no broad call that returns a whole week.
- The efficient sweep is therefore **one search per day, fired in parallel** in a single turn,
  then a parallel second round of `cursor` fetches for any day that returned exactly 20. One or
  two rounds cover realistic volumes.
- **Dedupe the union by `(channel_id, ts)`** — results can overlap at page boundaries.

## Blind spots (silent, no errors)

- **Search silently omits channels the bot can't see.** Known-present text in an invisible
  channel returns zero with no error. If a report seems suspiciously thin, this is the likely
  cause; for known-priority private channels use direct `slack_read_channel` reads, and never
  treat search silence as absence.
- **`is:unread` silently degrades to a full-text keyword match** on the word "unread" — no
  unread endpoint is wrapped (`unread_count_display`, `client.counts`, `conversations.mark` are
  absent). Infer "likely unanswered" from thread content and label it as inference.
- **DMs and group DMs the integration can access DO surface in search.** Include them
  deliberately and flag them, or exclude them explicitly — don't be surprised by them.

## Threads and enrichment

- Classify messages from fields already present — standalone (`thread_ts` absent or equal to
  `ts` with `reply_count == 0`), thread start (`thread_ts == ts`, `reply_count > 0`), thread
  reply (`thread_ts != ts`).
- **Don't eagerly call `slack_read_thread` to fetch parents** — roughly 10s per call and it
  rarely changes a summary. Record the `thread_ts` pointer; fetch on demand.
- **Permalinks are constructible without extra calls:**
  `https://<workspace>.slack.com/archives/<CHANNEL_ID>/p<TS_WITHOUT_DOT>`, plus
  `?thread_ts=<parent_ts>&cid=<CHANNEL_ID>` for thread replies.

## Write tools may vanish while reads work

`slack_send_message` / `slack_send_message_draft` can return
`permission_error: This tool is not available` in a session where every read/search tool works —
session-scoped permission drift, not a bug to debug. Treat any send step as best-effort: emit
the paste-ready text and link in-band as the fallback, and never let a blocked send stall the
deliverable.

## What this skill does not cover

Workspace-specific facts (user/channel IDs, which private channels are visible) — resolve live
via `slack_search_users` / `slack_search_channels`.

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
