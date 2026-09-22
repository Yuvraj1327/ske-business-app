"""Pydantic schema validation for Settlement Sheets — runs entirely
in-memory, no DB needed. Mirrors the style of test_schema_validation.py."""
import uuid
from decimal import Decimal

import pytest
from pydantic import ValidationError as PydanticValidationError

from app.schemas.settlement import (
    SettlementItemCreditUpdateRequest,
    SettlementItemDeliveryUpdateRequest,
    SettlementSheetCreateRequest,
    SettlementSheetUpdateRequest,
    SettlementStatusUpdateRequest,
)


def test_settlement_sheet_requires_at_least_one_item():
    with pytest.raises(PydanticValidationError):
        SettlementSheetCreateRequest(
            sheet_date="2026-09-22",
            delivery_agent_id=uuid.uuid4(),
            salesman_id=uuid.uuid4(),
            items=[],
        )


def test_settlement_sheet_accepts_minimal_valid_payload():
    payload = SettlementSheetCreateRequest(
        sheet_date="2026-09-22",
        delivery_agent_id=uuid.uuid4(),
        salesman_id=uuid.uuid4(),
        items=[{"customer_id": uuid.uuid4(), "invoice_amount": "500.00"}],
    )
    assert len(payload.items) == 1
    assert payload.items[0].credit_amount == 0


def test_settlement_item_invoice_amount_cannot_be_negative():
    with pytest.raises(PydanticValidationError):
        SettlementSheetCreateRequest(
            sheet_date="2026-09-22",
            delivery_agent_id=uuid.uuid4(),
            salesman_id=uuid.uuid4(),
            items=[{"customer_id": uuid.uuid4(), "invoice_amount": "-1"}],
        )


def test_delivery_status_must_be_valid():
    with pytest.raises(PydanticValidationError):
        SettlementItemDeliveryUpdateRequest(delivery_status="delivered_maybe")

    valid = SettlementItemDeliveryUpdateRequest(delivery_status="delivered", cash_amount="200")
    assert valid.delivery_status == "delivered"


def test_delivery_amounts_cannot_be_negative():
    with pytest.raises(PydanticValidationError):
        SettlementItemDeliveryUpdateRequest(delivery_status="delivered", cash_amount="-5")
    with pytest.raises(PydanticValidationError):
        SettlementItemDeliveryUpdateRequest(delivery_status="delivered", online_amount="-5")
    with pytest.raises(PydanticValidationError):
        SettlementItemDeliveryUpdateRequest(delivery_status="delivered", cheque_amount="-5")
    with pytest.raises(PydanticValidationError):
        SettlementItemDeliveryUpdateRequest(delivery_status="delivered", credit_amount="-5")


def test_settlement_sheet_update_request_accepts_partial_payload():
    payload = SettlementSheetUpdateRequest(pick_sheet_no="PS-100", cash_amount="500.00")
    assert payload.pick_sheet_no == "PS-100"
    assert payload.cash_amount == Decimal("500.00")
    assert payload.sheet_date is None
    assert payload.delivery_agent_id is None


def test_settlement_status_must_be_valid_enum_value():
    with pytest.raises(PydanticValidationError):
        SettlementStatusUpdateRequest(status="archived")

    valid = SettlementStatusUpdateRequest(status="in_progress")
    assert valid.status == "in_progress"


def test_credit_collected_cannot_be_negative():
    with pytest.raises(PydanticValidationError):
        SettlementItemCreditUpdateRequest(credit_collected="-10")

    valid = SettlementItemCreditUpdateRequest(credit_collected="0")
    assert valid.credit_collected == 0
