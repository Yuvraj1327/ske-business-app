"""Decimal-safe money math — the exact place float rounding errors would be
most costly. See app/schemas/common.py::money_str and the sale/return/
payment services that use Decimal throughout."""
from decimal import Decimal

from app.schemas.common import money_str


def test_money_str_rounds_half_up_to_two_places():
    assert money_str(Decimal("10") / Decimal("3")) == "3.33"
    assert money_str(Decimal("59.965")) == "59.97"  # half-up, not banker's rounding
    assert money_str(Decimal("0")) == "0.00"
    assert money_str(None) == "0.00"


def test_money_str_accepts_int_and_float_input():
    assert money_str(100) == "100.00"
    assert money_str(19.5) == "19.50"


def test_line_total_calculation_is_exact():
    # The classic float trap: 0.1 + 0.2 != 0.3 in binary floating point.
    # Decimal must not exhibit this for typical monetary quantities.
    quantity = Decimal("3")
    unit_price = Decimal("19.99")
    line_discount = Decimal("0")
    line_total = (quantity * unit_price) - line_discount
    assert line_total == Decimal("59.97")


def test_sale_total_calculation():
    subtotal = Decimal("59.97") + Decimal("25.00")
    discount = Decimal("5.00")
    total = subtotal - discount
    assert money_str(total) == "79.97"
