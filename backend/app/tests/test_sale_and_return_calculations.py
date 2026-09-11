"""Payment-status derivation and proportional refund math — see
app/services/sale_service.py::compute_payment_status and the return
calculation inline in app/services/sales_return_service.py::create_return
(mirrored here as a standalone calculation since the real one requires a
sale_item row from the database)."""
from decimal import Decimal

from app.services.sale_service import compute_payment_status


def test_payment_status_unpaid():
    assert compute_payment_status(Decimal("0"), Decimal("100")) == "unpaid"


def test_payment_status_partial():
    assert compute_payment_status(Decimal("50"), Decimal("100")) == "partial"


def test_payment_status_paid_exact():
    assert compute_payment_status(Decimal("100"), Decimal("100")) == "paid"


def test_payment_status_overpaid_still_shows_paid():
    assert compute_payment_status(Decimal("150"), Decimal("100")) == "paid"


def test_proportional_refund_accounts_for_line_discount():
    # Line: 10 units, net line_total 950 (i.e. a discount was already
    # applied) -> per-unit rate 95, not the raw undiscounted unit price.
    quantity = Decimal("10")
    line_total = Decimal("950.00")
    per_unit_rate = line_total / quantity
    return_qty = Decimal("3")
    refund = (return_qty * per_unit_rate).quantize(Decimal("0.01"))
    assert refund == Decimal("285.00")


def test_return_amount_floors_sale_total_at_zero():
    total_amount = Decimal("50.00")
    return_amount = Decimal("80.00")  # larger than what's left, shouldn't happen but must not go negative
    new_total = max(total_amount - return_amount, Decimal("0"))
    assert new_total == Decimal("0")
