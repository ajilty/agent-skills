def discount(price, pct):
    """Apply a discount. `pct` is a percentage in [0, 100]."""
    return price * (1 - pct / 100)
