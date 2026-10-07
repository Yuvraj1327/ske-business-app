"""Cheque option on Picklist items — schema rules, response shape, and how
the picklist's cheque total flows into a Settlement Sheet. In-memory only
(no DB), same approach as test_settlement_business_rules.py."""
import uuid
from decimal import Decimal
from types import SimpleNamespace

import pytest
from pydantic import ValidationError as PydanticValidationError

from app.models.picklist import PicklistItem
from app.schemas.picklist import PicklistItemConfirmRequest, PicklistItemResponse
from app.schemas.settlement import SettlementSheetCreateRequest
from app.services.picklist_service import PicklistService


def test_confirm_request_accepts_cheque_with_amount():
    payload = PicklistItemConfirmRequest(status="cheque", cheque_amount="1250.50")
    assert payload.cheque_amount == Decimal("1250.50")


def test_confirm_request_cheque_requires_amount():
    with pytest.raises(PydanticValidationError):
        PicklistItemConfirmRequest(status="cheque")


@pytest.mark.parametrize("amount", ["0", "-5"])
def test_confirm_request_cheque_amount_must_be_positive(amount):
    with pytest.raises(PydanticValidationError):
        PicklistItemConfirmRequest(status="cheque", cheque_amount=amount)


@pytest.mark.parametrize("status", ["cash", "online"])
def test_confirm_request_existing_statuses_unchanged(status):
    payload = PicklistItemConfirmRequest(status=status)
    assert payload.cheque_amount is None
    assert payload.salesman_id is None


@pytest.mark.parametrize("status", ["cash", "online", "credit"])
def test_confirm_request_cheque_amount_rejected_for_other_statuses(status):
    with pytest.raises(PydanticValidationError):
        PicklistItemConfirmRequest(status=status, cheque_amount="100", salesman_id=uuid.uuid4())


def test_confirm_request_rejects_unknown_status():
    with pytest.raises(PydanticValidationError):
        PicklistItemConfirmRequest(status="barter")


def test_item_response_includes_cheque_amount():
    item = PicklistItem(
        id=uuid.uuid4(),
        row_no=1,
        invoice_number="INV1",
        customer_name="Acme",
        amount_payable=Decimal("1000"),
        status="cheque",
        cheque_amount=Decimal("400"),
    )
    response = PicklistItemResponse.from_model(item)
    assert response.status == "cheque"
    assert response.cheque_amount == "400.00"


@pytest.mark.asyncio
async def test_picklist_response_counts_and_totals_cheque_rows():
    def row(status, cheque):
        return SimpleNamespace(status=status, cheque_amount=Decimal(cheque))

    picklist = SimpleNamespace(
        id=uuid.uuid4(),
        picklist_no="PL-1",
        delivery_agent_id=uuid.uuid4(),
        psr_route=None,
        total_amount=Decimal("3000"),
        created_at="2026-10-07T00:00:00Z",
        items=[row("cheque", "400"), row("cheque", "600.50"), row("cash", "0"), row("pending", "0")],
    )
    service = PicklistService.__new__(PicklistService)
    response = await service._build_response(picklist, {})
    assert response.cheque_total == "1000.50"
    assert response.counts.cheque == 2
    assert response.counts.cash == 1
    assert response.counts.pending == 1
    assert response.counts.total == 4


def test_settlement_create_cheque_defaults_to_unset_so_picklist_total_applies():
    payload = SettlementSheetCreateRequest(
        sheet_date="2026-10-07", delivery_agent_id=uuid.uuid4(), salesman_ids=[uuid.uuid4()]
    )
    assert payload.cheque_amount is None


def test_settlement_create_explicit_cheque_is_kept_and_non_negative():
    base = dict(sheet_date="2026-10-07", delivery_agent_id=uuid.uuid4(), salesman_ids=[uuid.uuid4()])
    assert SettlementSheetCreateRequest(**base, cheque_amount="0").cheque_amount == Decimal("0")
    with pytest.raises(PydanticValidationError):
        SettlementSheetCreateRequest(**base, cheque_amount="-1")
