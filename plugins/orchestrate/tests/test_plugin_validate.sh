# claude plugin validate --strict over every plugin plus the marketplace manifest.
# Mirrors the CI "Validate plugin and marketplace manifests" step for local runs.
ROOT="$HERE/../../.."   # repo root (tests run from arbitrary cwd; $HERE is absolute)
command -v claude >/dev/null 2>&1 || { echo "(skip test_plugin_validate: claude CLI absent)"; return 0 2>/dev/null || true; }
for p in "$ROOT"/plugins/*/; do
  out="$(claude plugin validate --strict "$p" 2>&1)" && pass || fail "claude plugin validate --strict $p: $out"
done
out="$(claude plugin validate --strict "$ROOT" 2>&1)" && pass || fail "claude plugin validate --strict (marketplace manifest): $out"
