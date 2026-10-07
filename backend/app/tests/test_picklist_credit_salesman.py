"""Salesman selection on a Picklist Credit row — request rules, response
shape, and the assignment that feeds Settlement / Salesman credit views.
In-memory only (no DB), same approach as test_picklist_cheque.py."""
import uuid
from decimal import Decimal
from types import SimpleNamespace

import pytest
from pydantic import ValidationError as PydanticValidationError
from sqlalchemy.orm import configure_mappers

from app.models.picklist import PicklistItem
from app.schemas.picklist import PicklistItemConfirmRequest, PicklistItemResponse
from app.services.picklist_service import PicklistService


def test_mappers_configure_with_credit_salesman_relationship():
    configure_mappers()


def test_credit_requires_salesman():
    with pytest.raises(PydanticValidationError):
        PicklistItemConfirmRequest(status="credit")


def test_credit_accepts_salesman():
    salesman_id = uuid.uuid4()
    assert PicklistItemConfirmRequest(status="credit", salesman_id=salesman_id).salesman_id == salesman_id


@pytest.mark.parametrize("status,extra", [("cash", {}), ("online", {}), ("cheque", {"cheque_amount": "10"})])
def test_salesman_rejected_for_non_credit_statuses(status, extra):
    with pytest.raises(PydanticValidationError):
        PicklistItemConfirmRequest(status=status, salesman_id=uuid.uuid4(), **extra)


def _item(**kwargs) -> PicklistItem:
    return PicklistItem(
        id=uuid.uuid4(),
        row_no=1,
        invoice_number="INV1",
        customer_name="Acme",
        amount_payable=Decimal("1000"),
        cheque_amount=Decimal("0"),
        status=kwargs.pop("status", "credit"),
        **kwargs,
    )


def test_item_response_shows_existing_credit_salesman():
    salesman = SimpleNamespace(id=uuid.uuid4(), full_name="Ravi Kumar")
    item = _item(credit_salesman_id=salesman.id)
    item.credit_salesman = salesman
    response = PicklistItemResponse.from_model(item)
    assert response.credit_salesman_id == salesman.id
    assert response.credit_salesman_name == "Ravi Kumar"


def test_item_response_without_salesman():
    response = PicklistItemResponse.from_model(_item(status="pending"))
    assert response.credit_salesman_id is None
    assert response.credit_salesman_name is None


class _FakeResult:
    def __init__(self, value):
        self._value = value

    def scalar_one(self):
        return self._value


class _FakeDb:
    def __init__(self, *objs):
        self._objs = list(objs)

    async def execute(self, _stmt):
        return _FakeResult(self._objs.pop(0))

    async def flush(self):
        pass


@pytest.mark.asyncio
async def test_assign_credit_salesman_sets_item_customer_and_sale():
    salesman = SimpleNamespace(id=uuid.uuid4(), full_name="Ravi Kumar")
    customer = SimpleNamespace(assigned_salesman_id=None)
    sale = SimpleNamespace(salesman_id=None)
    item = _item(customer_id=uuid.uuid4(), sale_id=uuid.uuid4())

    service = PicklistService.__new__(PicklistService)
    service.db = _FakeDb(customer, sale)
    await service._assign_credit_salesman(item, salesman)

    assert item.credit_salesman is salesman
    assert customer.assigned_salesman_id == salesman.id
    assert sale.salesman_id == salesman.id


@pytest.mark.asyncio
async def test_sync_settlement_salesman_adds_only_when_missing(monkeypatch):
    salesman = SimpleNamespace(id=uuid.uuid4(), full_name="Ravi Kumar")
    other = SimpleNamespace(id=uuid.uuid4(), full_name="Other")
    has_him = SimpleNamespace(salesmen=[other, salesman])
    lacks_him = SimpleNamespace(salesmen=[other])

    async def fake_open(self, pick_sheet_no):
        assert pick_sheet_no == "PL-1"
        return [has_him, lacks_him]

    monkeypatch.setattr("app.services.picklist_service.SettlementRepository.list_open_by_pick_sheet_no", fake_open)

    service = PicklistService.__new__(PicklistService)
    service.db = _FakeDb()
    await service._sync_settlement_salesman("PL-1", salesman)

    assert has_him.salesmen == [other, salesman]
    assert lacks_him.salesmen == [other, salesman]
