---
name: working-with-m365-connector
description: "Microsoft 365 / Outlook connector limits (mail, calendar, SharePoint): no binary downloads, unreadable .docx and nested .msg attachments, the deep-link-plus-re-upload fallback, Type-3-font PDF mojibake, search/flag/RSVP blind spots. Use when reading M365 content or asked to open an attachment surfaced through the connector."
---

# Working with the Microsoft 365 connector — sharp edges

What the M365 connector can and, more importantly, **cannot** do — so a request to read a
document's contents resolves into a working fallback rather than a stall or a guess.

## What it can do

- **Reads METADATA across mail, calendar, and SharePoint** — message and event names, senders,
  recipients, dates, sizes, folder/path structure, and the **thread text** of email bodies and
  calendar event descriptions. Searching and listing work well.
- Right tool for "find the thread about X", "who was on this meeting", "what's the subject/size
  of the attachment", "what files are in this SharePoint folder".

## What it cannot do — and the fallback

The connector is **metadata-and-text only**, with **no binary download** path:

- **It cannot render `.doc` / `.docx` contents.** It surfaces that a Word attachment exists, its
  name and size — not the document text inside it.
- **It cannot open nested Outlook `.msg` items.** A message attached to another message
  (forward-as-attachment, a phishing-report package that nests the original, a `.msg` saved to a
  file) is opaque — you see it exists, not what it says.

**Fallback for unreadable content:** surface the **deep-link** to the item (the SharePoint or
Outlook URL the connector returns) and **ask the user to re-upload the file** directly into the
conversation, where it can be read as an attachment. Do not stall, and do not infer contents from
the filename — state plainly that the connector can't render it and hand back the link plus the
re-upload ask.

## It is read-only

**No mail-send, no calendar-write.** Drafting a reply, proposing a meeting, or composing a message
is fine as text for the user to act on — but the connector cannot transmit it. Any send or
schedule is the user's action after they review and approve the draft.

## PDF gotcha: Type-3-font PDFs extract as mojibake

A PDF built with **Type-3 fonts carrying no Unicode CMap** has no text-to-character mapping, so
text extraction returns garbled glyphs even though the PDF looks fine to a human. When extracted
text is garbage but the document clearly has real content, **rasterize the pages and read them
visually** instead of trusting the broken text layer.

## Search and status limits (mail + calendar)

- **Free-text `query` cannot combine with date filters inside a named folder** — either date-bound
  the folder listing (no query) and page by `offset`, or run the free-text search unscoped and
  filter client-side.
- **Flag status is absent from SEARCH results, but a full message read (`read_resource` on the
  message) DOES return `flag.flagStatus`.** Use full-read as a per-message flag check on hot
  items; bulk "awaiting reply" judgments still come from thread-content inference, labeled as such.
- **Event accept/tentative status is not a field.** Infer from `showAs` (busy vs tentative) plus
  explicit "Accepted:" items in Sent Items; label it as a proxy.
- **Inbox-folder listings miss auto-filed threads.** Sender-scoped searches return in-window mail
  that the Inbox listing does not (rules and auto-filing move it) — an inbox-only sweep
  undercounts. Cross-check hot threads by sender before claiming "no mail from X".

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
