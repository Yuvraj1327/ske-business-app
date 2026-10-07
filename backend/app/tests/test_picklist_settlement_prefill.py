"""Picklist -> Settlement pre-fill of Cash / Online / Credit Bills / Cheque.
The sheet values are editable starting points: synced only while untouched,
and never written back to the picklist. In-memory only (no DB)."""
import uuid
from decimal import Decimal
from types import SimpleNamespace

import pytest
from pydantic import ValidationError as PydanticValidationError

from app.repositories.picklist_repo import SETTLEMENT_FIELD_BY_MODE
from app.schemas.settlement import SettlementSheetCreateRequest, SettlementSheetUpdateRequest
from app.services.picklist_service import PicklistService
from app.services.settlement_service import SettlementService

D = Decimal


def _totals(cash="0", online="0", credit="0", cheque="0"):
    return {"cash": D(cash), "online": D(online), "credit": D(credit), "cheque": D(cheque)}


def _sheet(cash="0", online="0", credit_bills="0", cheque="0", **extra):
    return SimpleNamespace(
        cash_amount=D(cash),
        online_amount=D(online),
        credit_bills_amount=D(credit_bills),
        cheque_amount=D(cheque),
        **extra,
    )


def test_mode_to_settlement_field_mapping():
    assert SETTLEMENT_FIELD_BY_MODE == {
        "cash": "cash_amount",
        "online": "online_amount",
        "credit": "credit_bills_amount",
        "cheque": "cheque_amount",
    }


def test_create_request_omitted_amounts_are_unset_but_explicit_zero_is_kept():
    base = dict(sheet_date="2026-10-07", delivery_agent_id=uuid.uuid4(), salesman_ids=[uuid.uuid4()])
    omitted = SettlementSheetCreateRequest(**base)
    for field in SETTLEMENT_FIELD_BY_MODE.values():
        assert getattr(omitted, field) is None
    explicit = SettlementSheetCreateRequest(**base, cash_amount="0", online_amount="5")
    assert explicit.cash_amount == D("0")
    assert explicit.online_amount == D("5")
    with pytest.raises(PydanticValidationError):
        SettlementSheetCreateRequest(**base, credit_bills_amount="-1")


def _service_with_repos(monkeypatch, current, new, sheets):
    """PicklistService whose repos return fixed totals/sheets; `current` is
    consumed by the sync as the 'after' totals."""

    async def fake_totals(self, picklist_no):
        return new

    async def fake_open(self, picklist_no):
        return sheets

    class _Db:
        async def flush(self):
            pass

    monkeypatch.setattr("app.services.picklist_service.SettlementRepository.list_open_by_pick_sheet_no", fake_open)
    service = PicklistService.__new__(PicklistService)
    service.db = _Db()
    service.picklists = SimpleNamespace(collection_totals_by_picklist_no=lambda no: fake_totals(None, no))
    return service


@pytest.mark.asyncio
async def test_sync_prefills_untouched_fields_only(monkeypatch):
    # Picklist went from {cash 100} to {cash 100, online 250, credit 50, cheque 400}.
    previous = _totals(cash="100")
    new = _totals(cash="100", online="250", credit="50", cheque="400")
    untouched = _sheet(cash="100")  # still the old pre-fill
    admin_edited = _sheet(cash="999", online="7", credit_bills="1", cheque="2")
    service = _service_with_repos(monkeypatch, None, new, [untouched, admin_edited])

    await service._sync_settlement_totals("PL-1", previous)

    assert (untouched.cash_amount, untouched.online_amount, untouched.credit_bills_amount, untouched.cheque_amount) == (
        D("100"), D("250"), D("50"), D("400"),
    )
    # Admin-edited values are never overwritten.
    assert (admin_edited.cash_amount, admin_edited.online_amount) == (D("999"), D("7"))
    assert (admin_edited.credit_bills_amount, admin_edited.cheque_amount) == (D("1"), D("2"))


@pytest.mark.asyncio
async def test_sync_does_not_touch_other_sheet_fields_or_picklist(monkeypatch):
    sheet = _sheet(returns_amount=D("10"), damage_return_amount=D("20"), discount_amount=D("30"), old_short_amount=D("40"))
    service = _service_with_repos(monkeypatch, None, _totals(cash="5"), [sheet])
    await service._sync_settlement_totals("PL-1", _totals())
    assert sheet.cash_amount == D("5")
    assert (sheet.returns_amount, sheet.damage_return_amount, sheet.discount_amount, sheet.old_short_amount) == (
        D("10"), D("20"), D("30"), D("40"),
    )


@pytest.mark.asyncio
async def test_update_sheet_edit_does_not_resync_or_write_picklist(monkeypatch):
    """Editing amounts through update_sheet only sets the sent fields."""
    sheet = SimpleNamespace(
        id=uuid.uuid4(), status="draft", pick_sheet_no="PL-1", cash_amount=D("100"), online_amount=D("0"),
        credit_bills_amount=D("0"), cheque_amount=D("0"), salesmen=[],
    )

    class _Sheets:
        async def get_by_id(self, _id):
            return sheet

        async def save(self, s):
            return s

    class _Db:
        async def commit(self):
            pass

    calls = []

    async def fake_totals(self, picklist_no):
        calls.append(picklist_no)
        return _totals()

    monkeypatch.setattr("app.services.settlement_service.PicklistRepository.collection_totals_by_picklist_no", fake_totals)
    service = SettlementService.__new__(SettlementService)
    service.db = _Db()
    service.sheets = _Sheets()

    async def fake_get_sheet(sheet_id, user):
        return "ok"

    service.get_sheet = fake_get_sheet
    user = SimpleNamespace(has_permission=lambda key: True)

    await service.update_sheet(sheet.id, SettlementSheetUpdateRequest(cash_amount="150"), user)

    assert sheet.cash_amount == D("150")
    assert (sheet.online_amount, sheet.credit_bills_amount, sheet.cheque_amount) == (D("0"), D("0"), D("0"))
    assert calls == []  # pick_sheet_no unchanged -> no picklist lookup at all


@pytest.mark.asyncio
async def test_update_sheet_repointing_picklist_carries_untouched_fields(monkeypatch):
    sheet = SimpleNamespace(
        id=uuid.uuid4(), status="draft", pick_sheet_no="PL-1", cash_amount=D("100"), online_amount=D("77"),
        credit_bills_amount=D("0"), cheque_amount=D("0"), salesmen=[],
    )
    totals = {"PL-1": _totals(cash="100"), "PL-2": _totals(cash="300", online="40", credit="9", cheque="8")}

    class _Sheets:
        async def get_by_id(self, _id):
            return sheet

        async def save(self, s):
            return s

    class _Db:
        async def commit(self):
            pass

    async def fake_totals(self, picklist_no):
        return totals[picklist_no]

    monkeypatch.setattr("app.services.settlement_service.PicklistRepository.collection_totals_by_picklist_no", fake_totals)
    service = SettlementService.__new__(SettlementService)
    service.db = _Db()
    service.sheets = _Sheets()

    async def fake_get_sheet(sheet_id, user):
        return "ok"

    service.get_sheet = fake_get_sheet
    user = SimpleNamespace(has_permission=lambda key: True)

    await service.update_sheet(sheet.id, SettlementSheetUpdateRequest(pick_sheet_no="PL-2", cheque_amount="1"), user)

    assert sheet.pick_sheet_no == "PL-2"
    assert sheet.cash_amount == D("300")  # was the old pre-fill -> carried across
    assert sheet.online_amount == D("77")  # Admin-edited -> kept
    assert sheet.credit_bills_amount == D("9")  # was 0 == PL-1's credit total -> carried across
    assert sheet.cheque_amount == D("1")  # explicitly sent -> kept
