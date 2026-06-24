# VISIBLE test — the only suite the implementer/naive agent sees. It covers ONLY the
# cart call site, so it stays green whether or not the hidden invoice caller is fixed.
from cart import cart_total


def main():
    assert cart_total(100) == 80, cart_total(100)
    print("cart ok")


if __name__ == "__main__":
    main()
