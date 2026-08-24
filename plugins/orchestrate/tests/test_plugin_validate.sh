# Mirrors the CI validate-plugins job for local runs: scripts/validate-plugins.sh
# validates the marketplace manifest and every plugin, dereferencing symlinked
# plugins first (ADR-0038; commit 7fe3b7e). Do NOT run claude plugin validate
# --strict directly against a symlinked plugin here — newer CLIs warn
# "symlinks ... were not read" and strict treats the warning as failure, even
# though a session loading the plugin follows the links fine.
ROOT="$HERE/../../.."   # repo root (tests run from arbitrary cwd; $HERE is absolute)
command -v claude >/dev/null 2>&1 || { echo "(skip test_plugin_validate: claude CLI absent)"; return 0 2>/dev/null || true; }
out="$(bash "$ROOT/scripts/validate-plugins.sh" 2>&1)" && pass || fail "scripts/validate-plugins.sh: $(printf '%s' "$out" | tail -6)"
