from calc import discount

# The standard discount applied to every invoice, expressed as a percentage.
STANDARD_DISCOUNT = 20


def invoice_total(price):
    return discount(price, STANDARD_DISCOUNT)
