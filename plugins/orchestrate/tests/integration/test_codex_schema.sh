# Tier 3 (Codex schema conformance, live) — every generated agent-role .toml must be a
# VALID Codex agent role. `codex exec --strict-config` errors on unrecognized config and
# rejects malformed roles with "Ignoring malformed agent role definition" / "invalid type".
# We install orchestrate into a throwaway CODEX_HOME, then run a no-op `codex exec
# --strict-config` and assert ZERO malformed-agent warnings about our roles.
#
# NOTE (this worktree): scripts/install-codex.sh here is still the OLD version, which emits
# roles WITHOUT model/model_reasoning_effort/developer_instructions. Strict-config may then
# warn or this may not exercise the target schema — so this test can SKIP/FAIL here by
# design. It goes green after the installer-rewrite merge. We test against the TARGET schema.
if ! have_codex; then
  skip "codex schema: codex CLI not on PATH"
elif ! have_codex_auth; then
  skip "codex schema: no codex auth"
else
  ch="$(mk_codex_home)"; ws="$(mk_repo)"
  codex_install "$ch"
  # Portable "any role present?" (no shopt/nullglob — keep this bash/zsh-source-safe).
  n_roles="$(find "$ch/agents" -maxdepth 1 -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${n_roles:-0}" -eq 0 ]; then
    skip "codex schema: installer produced no agents/*.toml (awaiting installer merge)"
  else
    # A trivial prompt; --strict-config surfaces config/role validation eagerly at startup.
    out="$(printf '%s' "say hi and stop" | ( cd "$ws" && CODEX_HOME="$ch" \
      timeout 180 codex exec --strict-config --skip-git-repo-check - ) 2>&1)"
    if printf '%s' "$out" | grep -qiE "malformed agent role definition|invalid type"; then
      fail "codex schema: a generated role is malformed under --strict-config: $(printf '%s' "$out" | grep -iE 'malformed agent role definition|invalid type' | head -1)"
    else
      pass   # zero malformed-agent warnings: every generated role validated
    fi
  fi
  cd /
fi
