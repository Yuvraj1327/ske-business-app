"""Invoice financial-year boundary logic. See app/utils/invoice_number.py.
The atomic-upsert concurrency guarantee itself needs a real database to
verify (two concurrent transactions can't both get seq N) — documented as
an integration-test gap in conftest.py — but the pure date-to-FY mapping is
fully testable here."""
from datetime import date

from app.utils.invoice_number import financial_year_key


def test_financial_year_starts_april_1():
    assert financial_year_key(date(2026, 4, 1)) == "2627"


def test_financial_year_ends_march_31():
    assert financial_year_key(date(2026, 3, 31)) == "2526"


def test_financial_year_mid_year():
    assert financial_year_key(date(2025, 9, 9)) == "2526"


def test_financial_year_new_year_eve_and_day():
    # Jan 1 is still within the FY that started the previous April.
    assert financial_year_key(date(2026, 1, 1)) == "2526"
    assert financial_year_key(date(2025, 12, 31)) == "2526"
