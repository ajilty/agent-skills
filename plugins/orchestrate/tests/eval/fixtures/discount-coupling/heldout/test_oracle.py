# HELD-OUT oracle — the implementer/naive agent NEVER sees this; in an orchestrate
# run it is handed only to the Verifier (via $HELDOUT_ROOT). It checks two things a
# visible cart-only suite cannot: (a) the refactor actually happened (fraction
# semantics), and (b) the business invariant holds at EVERY call site — including the
# hidden invoice caller, the coupling a clean textual edit of the obvious site misses.
import sys

sys.path.insert(0, sys.argv[1])  # the candidate repo dir
from calc import discount
from cart import cart_total
from invoice import invoice_total


def main():
    # (a) refactor done: discount now takes a FRACTION (0.25 == 25% off)
    assert abs(discount(100, 0.25) - 75) < 1e-9, f"discount fraction broken: {discount(100, 0.25)}"
    # (b) business invariant preserved at every call site (the coupling check)
    assert abs(cart_total(100) - 80) < 1e-9, f"cart_total: {cart_total(100)}"
    assert abs(invoice_total(100) - 80) < 1e-9, f"invoice_total (hidden coupling): {invoice_total(100)}"
    print("oracle ok")


if __name__ == "__main__":
    main()
