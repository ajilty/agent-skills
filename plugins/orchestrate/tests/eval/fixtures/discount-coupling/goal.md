# Goal

`discount(price, pct)` in `calc.py` currently treats `pct` as a **percentage**
(0–100). Refactor it to accept the discount as a **fraction** in `[0.0, 1.0]`
instead — e.g. a 25% discount is passed as `0.25`.

Update the codebase so that all existing behavior is preserved. The visible test
suite (`test_cart.py`) must pass.
