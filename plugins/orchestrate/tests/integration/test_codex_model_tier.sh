# Tier 3 (Codex model tiers, live-capable) — the compiled per-persona model tiers must be
# DIFFERENTIATED and correct in the generated Codex roles. The portable contract (agents.yaml)
# names abstract tiers (economy/standard/premium); install-codex.sh maps them to concrete
# Codex models. Target mapping: premium -> gpt-5.5, standard -> gpt-5.4, economy -> gpt-5.4-mini.
# So verifier.toml (premium) must carry model = "gpt-5.5" and researcher.toml (economy)
# model = "gpt-5.4-mini" — proving the spend lands on adversarial review, not on the cheap
# reduction lane. TOML inspection is the assertion; a live model self-report is a bonus.
#
# NOTE (this worktree): the OLD install-codex.sh emits NO `model` line, so this SKIPs here.
# It goes green after the installer-rewrite merge. We assert the TARGET mapping.
if ! have_codex; then
  skip "codex model-tier: codex CLI not on PATH"
else
  ch="$(mk_codex_home)"
  codex_install "$ch"
  vf="$ch/agents/verifier.toml"; rf="$ch/agents/researcher.toml"
  if [ ! -f "$vf" ] || [ ! -f "$rf" ]; then
    skip "codex model-tier: installer produced no verifier/researcher role (awaiting installer merge)"
  else
    _model(){ grep -E '^[[:space:]]*model[[:space:]]*=' "$1" | head -1 | sed -E 's/.*=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'; }
    vm="$(_model "$vf")"; rm="$(_model "$rf")"
    if [ -z "$vm" ] || [ -z "$rm" ]; then
      skip "codex model-tier: roles carry no model line (OLD installer in this worktree — awaiting merge)"
    else
      assert_eq "$vm" "gpt-5.5"      "codex model-tier: verifier model"
      assert_eq "$rm" "gpt-5.4-mini" "codex model-tier: researcher model"
      # Differentiation guard: the two tiers must not collapse to the same model.
      [ "$vm" != "$rm" ] && pass || fail "codex model-tier: verifier and researcher collapsed to the same model ($vm)"
    fi
  fi
  cd /
fi
