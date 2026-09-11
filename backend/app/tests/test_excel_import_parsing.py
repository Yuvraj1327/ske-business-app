"""Excel row parsing/validation logic, exercised against a real in-memory
.xlsx workbook (built with openpyxl) rather than mocked — this proves the
actual file-reading code path works, not just the validation rules in
isolation. Database inserts themselves aren't covered here (see
conftest.py's note on integration-test scope)."""
import io

import pytest
from openpyxl import Workbook, load_workbook

from app.services.import_service import _build_customer, _build_product, _json_safe


def _make_workbook(headers, rows):
    wb = Workbook()
    ws = wb.active
    ws.append(headers)
    for row in rows:
        ws.append(row)
    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    return load_workbook(buf, read_only=True, data_only=True)


def test_valid_customer_row_parses_correctly():
    wb = _make_workbook(["name", "phone", "email"], [["Acme Traders", "9876543210", "acme@example.com"]])
    rows = list(wb.active.iter_rows(values_only=True))
    headers = [str(h).lower() for h in rows[0]]
    raw = {headers[i]: rows[1][i] for i in range(len(headers))}

    customer, dedupe_key = _build_customer(raw, {}, rows[1])

    assert customer.name == "Acme Traders"
    assert customer.phone == "9876543210"
    assert dedupe_key == "9876543210"


def test_customer_row_missing_name_raises():
    wb = _make_workbook(["name", "phone"], [["", "1234567890"]])
    rows = list(wb.active.iter_rows(values_only=True))
    headers = [str(h).lower() for h in rows[0]]
    raw = {headers[i]: rows[1][i] for i in range(len(headers))}

    with pytest.raises(ValueError, match="name"):
        _build_customer(raw, {}, rows[1])


def test_product_row_with_non_numeric_price_raises():
    with pytest.raises(ValueError, match="default_price"):
        _build_product({"name": "Widget", "default_price": "not-a-number"}, {}, ())


def test_product_row_with_negative_price_raises():
    with pytest.raises(ValueError, match="greater than 0"):
        _build_product({"name": "Widget", "default_price": -5}, {}, ())


def test_valid_product_row_parses_correctly():
    product, dedupe_key = _build_product({"name": "Widget", "default_price": 49.99, "sku": "WID-001"}, {}, ())
    assert product.name == "Widget"
    assert product.default_price == 49.99
    assert dedupe_key == "WID-001"


def test_json_safe_stringifies_non_primitives():
    class Weird:
        def __str__(self):
            return "weird-value"

    safe = _json_safe({"a": 1, "b": None, "c": "text", "d": Weird()})
    assert safe == {"a": 1, "b": None, "c": "text", "d": "weird-value"}
