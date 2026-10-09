"""Picklist -> Settlement sync of Cash / Online / Credit Bills / Cheque.
Every picklist save sets the open sheets' four fields to the picklist's current
totals (idempotent), and nothing is written back to the picklist. In-memory
only (no DB)."""
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


def _sheet(cash="0", online="0", credit_bills="0", cheque="0", pick_sheet_value="0", **extra):
    return SimpleNamespace(
        pick_sheet_value=D(pick_sheet_value),
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
    for field in (*SETTLEMENT_FIELD_BY_MODE.values(), "pick_sheet_value"):
        assert getattr(omitted, field) is None
    explicit = SettlementSheetCreateRequest(**base, cash_amount="0", online_amount="5")
    assert explicit.cash_amount == D("0")
    assert explicit.online_amount == D("5")
    with pytest.raises(PydanticValidationError):
        SettlementSheetCreateRequest(**base, credit_bills_amount="-1")


def _service_with_repos(monkeypatch, new, sheets, locked=None, total_amount="0"):
    """PicklistService whose repos return fixed totals/sheets."""

    async def fake_totals(no):
        return new

    async def fake_total_amount(no):
        return D(total_amount)

    async def fake_lock(no):
        if locked is not None:
            locked.append(no)

    async def fake_open(self, picklist_no):
        return sheets

    class _Db:
        async def flush(self):
            pass

    monkeypatch.setattr("app.services.picklist_service.SettlementRepository.list_open_by_pick_sheet_no", fake_open)
    service = PicklistService.__new__(PicklistService)
    service.db = _Db()
    service.picklists = SimpleNamespace(
        collection_totals_by_picklist_no=fake_totals,
        lock_by_picklist_no=fake_lock,
        total_amount_by_picklist_no=fake_total_amount,
    )
    return service


@pytest.mark.asyncio
async def test_sync_sets_all_four_fields_to_current_picklist_totals(monkeypatch):
    new = _totals(cash="2000", online="1000", credit="500", cheque="3000")
    in_step = _sheet(cash="2000")
    drifted = _sheet(cash="999", online="7", credit_bills="1", cheque="2")  # edited / out of step
    locked = []
    service = _service_with_repos(monkeypatch, new, [in_step, drifted], locked)

    await service._sync_settlement_totals("PL-1")

    for sheet in (in_step, drifted):
        assert (sheet.cash_amount, sheet.online_amount, sheet.credit_bills_amount, sheet.cheque_amount) == (
            D("2000"), D("1000"), D("500"), D("3000"),
        )
    assert locked == ["PL-1"]  # picklist locked before totals are computed


@pytest.mark.asyncio
async def test_sync_is_idempotent_and_follows_changes(monkeypatch):
    sheet = _sheet()
    service = _service_with_repos(monkeypatch, _totals(cash="100", online="50"), [sheet])
    await service._sync_settlement_totals("PL-1")
    await service._sync_settlement_totals("PL-1")  # repeated sync must not double count
    assert (sheet.cash_amount, sheet.online_amount) == (D("100"), D("50"))

    service = _service_with_repos(monkeypatch, _totals(cash="100", online="50", credit="30"), [sheet])
    await service._sync_settlement_totals("PL-1")
    assert (sheet.cash_amount, sheet.online_amount, sheet.credit_bills_amount) == (D("100"), D("50"), D("30"))


@pytest.mark.asyncio
async def test_sync_does_not_touch_other_sheet_fields(monkeypatch):
    sheet = _sheet(returns_amount=D("10"), damage_return_amount=D("20"), discount_amount=D("30"), old_short_amount=D("40"))
    service = _service_with_repos(monkeypatch, _totals(cash="5"), [sheet])
    await service._sync_settlement_totals("PL-1")
    assert sheet.cash_amount == D("5")
    assert (sheet.returns_amount, sheet.damage_return_amount, sheet.discount_amount, sheet.old_short_amount) == (
        D("10"), D("20"), D("30"), D("40"),
    )


@pytest.mark.asyncio
async def test_sync_fills_pick_sheet_value_only_when_zero(monkeypatch):
    empty, typed = _sheet(), _sheet(pick_sheet_value="123")
    service = _service_with_repos(monkeypatch, _totals(cash="5"), [empty, typed], total_amount="9000")
    await service._sync_settlement_totals("PL-1")
    assert empty.pick_sheet_value == D("9000")  # never synced before -> filled from the imported total
    assert typed.pick_sheet_value == D("123")  # Admin-entered -> kept


@pytest.mark.asyncio
async def test_sync_with_no_open_sheets_is_a_noop(monkeypatch):
    service = _service_with_repos(monkeypatch, _totals(cash="5"), [])
    await service._sync_settlement_totals("PL-1")  # e.g. only completed / no sheets: nothing to write


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
        credit_bills_amount=D("0"), cheque_amount=D("0"), pick_sheet_value=D("1000"), salesmen=[],
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

    async def fake_total_amount(self, picklist_no):
        return {"PL-1": D("1000"), "PL-2": D("2500")}[picklist_no]

    monkeypatch.setattr("app.services.settlement_service.PicklistRepository.collection_totals_by_picklist_no", fake_totals)
    monkeypatch.setattr("app.services.settlement_service.PicklistRepository.total_amount_by_picklist_no", fake_total_amount)
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
    assert sheet.pick_sheet_value == D("2500")  # was PL-1's imported total -> carried across
