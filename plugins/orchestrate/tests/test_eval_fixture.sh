# Tier 3c, Layer 2 — fixture VALIDITY (deterministic, cheap, no live model). An A/B
# eval is only meaningful if its oracle can tell good work from bad. This proves the
# discount-coupling fixture discriminates three states, which is the precondition for
# the live A/B (eval/run.sh) to mean anything:
#   - seed (refactor not done)      -> held-out FAILS (oracle requires the change)
#   - correct (both call sites fixed) -> held-out PASSES
#   - naive-broken (visible green, hidden invoice caller left wrong) -> held-out FAILS
# The third row is the load-bearing one: visible-green != correct, which is exactly the
# coupling orchestrate's verifier exists to catch.
command -v python3 >/dev/null 2>&1 || { echo "(skip test_eval_fixture: python3 absent)"; return 0 2>/dev/null || true; }
EVAL="$HERE/eval"; FX="$EVAL/fixtures/discount-coupling"
SCORE="$EVAL/score.sh"; ORACLE="$FX/heldout/test_oracle.py"

# 1) seed: visible passes, held-out fails (the refactor has not happened yet)
t="$(mktemp -d)"; cp "$FX/seed/"*.py "$t/"
eval "$(bash "$SCORE" "$t" "$ORACLE")"
assert_eq "$visible" "1" "seed: visible suite passes"
assert_eq "$heldout" "0" "seed: held-out oracle FAILS (oracle requires the refactor)"
rm -rf "$t"

# 2) correct: discount -> fraction, BOTH call sites fixed -> held-out passes
t="$(mktemp -d)"
printf 'def discount(price, frac):\n    return price * (1 - frac)\n' > "$t/calc.py"
printf 'from calc import discount\ndef cart_total(price):\n    return discount(price, 0.20)\n' > "$t/cart.py"
printf 'from calc import discount\nSTANDARD_DISCOUNT = 0.20\ndef invoice_total(price):\n    return discount(price, STANDARD_DISCOUNT)\n' > "$t/invoice.py"
cp "$FX/seed/test_cart.py" "$t/"
eval "$(bash "$SCORE" "$t" "$ORACLE")"
assert_eq "$visible" "1" "correct: visible passes"
assert_eq "$heldout" "1" "correct: held-out oracle passes"
rm -rf "$t"

# 3) naive-broken: discount -> fraction, cart fixed, invoice constant LEFT at 20.
#    Visible suite is GREEN (false confidence); held-out catches the coupling break.
t="$(mktemp -d)"
printf 'def discount(price, frac):\n    return price * (1 - frac)\n' > "$t/calc.py"
printf 'from calc import discount\ndef cart_total(price):\n    return discount(price, 0.20)\n' > "$t/cart.py"
printf 'from calc import discount\nSTANDARD_DISCOUNT = 20\ndef invoice_total(price):\n    return discount(price, STANDARD_DISCOUNT)\n' > "$t/invoice.py"
cp "$FX/seed/test_cart.py" "$t/"
eval "$(bash "$SCORE" "$t" "$ORACLE")"
assert_eq "$visible" "1" "naive-broken: visible suite still GREEN (false confidence)"
assert_eq "$heldout" "0" "naive-broken: held-out catches the hidden-coupling break"
rm -rf "$t"
