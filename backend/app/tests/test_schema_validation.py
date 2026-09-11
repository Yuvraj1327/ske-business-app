"""Pydantic schema validation — runs entirely in-memory, no DB needed.
Covers the request-shape rules that guard the API before any business logic
or database access happens."""
import uuid

import pytest
from pydantic import ValidationError

from app.schemas.payment import PaymentCreateRequest
from app.schemas.sale import SaleCreateRequest
from app.schemas.salesman import TaskUpdateStatusRequest


def test_cheque_payment_requires_cheque_fields():
    with pytest.raises(ValidationError):
        PaymentCreateRequest(
            customer_id=uuid.uuid4(),
            amount=100,
            payment_method="cheque",
            # missing cheque_number / cheque_date / bank_name
        )


def test_cheque_payment_succeeds_with_all_fields():
    payload = PaymentCreateRequest(
        customer_id=uuid.uuid4(),
        amount=100,
        payment_method="cheque",
        cheque_number="123456",
        cheque_date="2026-01-01",
        bank_name="Test Bank",
    )
    assert payload.payment_method == "cheque"


def test_cash_payment_does_not_require_cheque_fields():
    payload = PaymentCreateRequest(customer_id=uuid.uuid4(), amount=100, payment_method="cash")
    assert payload.cheque_number is None


def test_invalid_payment_method_rejected():
    with pytest.raises(ValidationError):
        PaymentCreateRequest(customer_id=uuid.uuid4(), amount=100, payment_method="bitcoin")


def test_sale_requires_at_least_one_item():
    with pytest.raises(ValidationError):
        SaleCreateRequest(customer_id=uuid.uuid4(), items=[])


def test_sale_item_quantity_must_be_positive():
    with pytest.raises(ValidationError):
        SaleCreateRequest(
            customer_id=uuid.uuid4(),
            items=[{"product_id": uuid.uuid4(), "quantity": -1}],
        )


def test_task_status_must_be_valid_enum_value():
    with pytest.raises(ValidationError):
        TaskUpdateStatusRequest(status="not_a_real_status")

    valid = TaskUpdateStatusRequest(status="completed")
    assert valid.status == "completed"
