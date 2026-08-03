---
name: working-with-playwright
description: Sharp edges for headless browser captures with Playwright in a uv-managed Python environment. Use when rendering a page or app to an image via Playwright inside a uv venv, or when the first render fails with "Executable doesn't exist" because the browser binary is missing.
---

# Working with Playwright — sharp edges

Operating knowledge for headless Playwright captures. What to screenshot and why belongs to the
task at hand; this covers the tool surface.

## The Chromium binary is NOT installed by the package

In a `uv`-managed venv, `uv add playwright` (or `uv pip install playwright`) installs the
**Python package only** — it does **not** download the Chromium browser binary. The first
headless render therefore fails ("Executable doesn't exist" at the browsers path) until the
browser is fetched once:

```
uv run playwright install chromium
```

Run this **once before any screenshot step** (idempotent; a no-op if already present). Treat it
as a setup precondition, not an error to debug — the first-run failure is expected when this step
was skipped, not a code bug.

---
Wrong, stale, or missing edge? File it: https://github.com/ajilty/agentic/issues/new?template=edge-report.yml
