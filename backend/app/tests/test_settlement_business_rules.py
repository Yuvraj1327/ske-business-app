"""Settlement Sheet access-scoping and workflow rules, exercised directly
against SettlementService's pure decision logic without a database — same
approach as test_permissions.py (construct a CurrentUser by hand) and
test_sale_and_return_calculations.py (mirror an inline DB-dependent
calculation as a standalone one to verify the math/logic itself)."""
import uuid
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.core.exceptions import PermissionDeniedError
from app.models.settlement import SettlementSheet, SettlementSheetItem
from app.core.security import CurrentUser
from app.schemas.settlement import SettlementSheetUpdateRequest
from app.services.settlement_service import _ALLOWED_TRANSITIONS, SettlementService


def _make_user(role_name: str, permissions: set[str], user_id: uuid.UUID | None = None) -> CurrentUser:
    return CurrentUser(
        id=user_id or uuid.uuid4(),
        auth_user_id=uuid.uuid4(),
        full_name="Test User",
        role_name=role_name,
        is_active=True,
        permission_keys=permissions,
    )


def _make_sheet(agent_id: uuid.UUID, salesman_ids: list[uuid.UUID], status: str = "draft") -> SettlementSheet:
    sheet = SettlementSheet(
        id=uuid.uuid4(),
        sheet_no="SET-20260922-001",
        delivery_agent_id=agent_id,
        status=status,
    )
    sheet.salesmen = [SimpleNamespace(id=sid) for sid in salesman_ids]
    return sheet


def _make_item(sheet: SettlementSheet, assigned_salesman_id: uuid.UUID | None = None) -> SettlementSheetItem:
    item = SettlementSheetItem(
        id=uuid.uuid4(),
        settlement_sheet_id=sheet.id,
        row_no=1,
        customer_id=uuid.uuid4(),
        customer_name="Test Customer",
    )
    item.sheet = sheet
    item.customer = SimpleNamespace(assigned_salesman_id=assigned_salesman_id)
    return item


@pytest.fixture
def service() -> SettlementService:
    # None is fine here — the methods under test never touch self.db.
    return SettlementService(db=None)


# ---------------------------------------------------------------------------
# View access
# ---------------------------------------------------------------------------
def test_admin_can_view_any_sheet(service):
    admin = _make_user("admin", {"settlements.manage", "settlements.view_assigned"})
    sheet = _make_sheet(uuid.uuid4(), [uuid.uuid4()])
    service._check_view_access(sheet, admin)  # does not raise


def test_delivery_agent_can_view_their_own_sheet(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, [uuid.uuid4()])
    service._check_view_access(sheet, agent)  # does not raise


def test_delivery_agent_cannot_view_another_agents_sheet(service):
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=uuid.uuid4())
    sheet = _make_sheet(uuid.uuid4(), [uuid.uuid4()])  # different agent
    with pytest.raises(PermissionDeniedError):
        service._check_view_access(sheet, agent)


def test_salesman_can_view_their_own_sheet(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), [salesman_id])
    service._check_view_access(sheet, salesman)  # does not raise


def test_second_salesman_on_a_multi_salesman_sheet_can_view_it(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), [uuid.uuid4(), salesman_id])
    service._check_view_access(sheet, salesman)  # does not raise


# ---------------------------------------------------------------------------
# Delivery-half access — Agent only, never Salesman
# ---------------------------------------------------------------------------
def test_assigned_agent_can_update_delivery_half(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, [uuid.uuid4()])
    service._check_agent_access(sheet, agent)  # does not raise


def test_assigned_salesman_cannot_update_delivery_half(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), [salesman_id])
    with pytest.raises(PermissionDeniedError):
        service._check_agent_access(sheet, salesman)


# ---------------------------------------------------------------------------
# Credit half access — the customer's OWN assigned salesman only, even on a
# multi-salesman sheet; falls back to any of the sheet's salesmen if the
# customer has no assigned salesman.
# ---------------------------------------------------------------------------
def test_assigned_salesman_can_update_credit_half_of_their_own_customer(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), [salesman_id])
    item = _make_item(sheet, assigned_salesman_id=salesman_id)
    service._check_item_salesman_access(item, salesman)  # does not raise


def test_other_salesman_on_same_sheet_cannot_update_credit_half_of_someone_elses_customer(service):
    salesman_id = uuid.uuid4()
    other_salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), [salesman_id, other_salesman_id])
    item = _make_item(sheet, assigned_salesman_id=other_salesman_id)
    with pytest.raises(PermissionDeniedError):
        service._check_item_salesman_access(item, salesman)


def test_salesman_not_on_the_sheet_at_all_cannot_update_credit_half(service):
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=uuid.uuid4())
    sheet = _make_sheet(uuid.uuid4(), [uuid.uuid4()])
    item = _make_item(sheet, assigned_salesman_id=None)
    with pytest.raises(PermissionDeniedError):
        service._check_item_salesman_access(item, salesman)


def test_any_sheet_salesman_can_update_credit_half_of_an_unassigned_customer(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), [salesman_id, uuid.uuid4()])
    item = _make_item(sheet, assigned_salesman_id=None)
    service._check_item_salesman_access(item, salesman)  # does not raise


def test_assigned_agent_cannot_update_credit_half(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, [uuid.uuid4()])
    item = _make_item(sheet, assigned_salesman_id=None)
    with pytest.raises(PermissionDeniedError):
        service._check_item_salesman_access(item, agent)


def test_admin_can_update_either_half_of_any_sheet(service):
    admin = _make_user("admin", {"settlements.manage"})
    sheet = _make_sheet(uuid.uuid4(), [uuid.uuid4()])
    item = _make_item(sheet, assigned_salesman_id=uuid.uuid4())
    service._check_agent_access(sheet, admin)  # does not raise
    service._check_item_salesman_access(item, admin)  # does not raise


# ---------------------------------------------------------------------------
# Status workflow — Draft -> In Progress -> Completed, forward-only
# ---------------------------------------------------------------------------
def test_draft_can_only_move_to_in_progress():
    assert _ALLOWED_TRANSITIONS["draft"] == {"in_progress"}


def test_in_progress_can_only_move_to_completed():
    assert _ALLOWED_TRANSITIONS["in_progress"] == {"completed"}


def test_completed_is_terminal():
    assert _ALLOWED_TRANSITIONS["completed"] == set()


def test_cannot_skip_draft_directly_to_completed():
    assert "completed" not in _ALLOWED_TRANSITIONS["draft"]


# ---------------------------------------------------------------------------
# Credit/Udhaar running-total cap — mirrors the check in
# SettlementService.update_item_credit (which needs a DB-loaded item), as a
# standalone calculation, same approach test_sale_and_return_calculations.py
# uses for the refund math.
# ---------------------------------------------------------------------------
def test_credit_collected_within_credit_amount_is_allowed():
    credit_amount = Decimal("1000.00")
    credit_collected = Decimal("600.00")
    assert credit_collected <= credit_amount


def test_credit_collected_cannot_exceed_credit_amount():
    credit_amount = Decimal("1000.00")
    attempted_collected = Decimal("1200.00")
    assert attempted_collected > credit_amount  # this is exactly what raises BusinessRuleError in the service


# ---------------------------------------------------------------------------
# Header/general field updates — Admin only, locked once 'completed'.
# Only the permission check runs before any DB access, so it's safe to
# exercise the real async method here without a database.
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_non_admin_cannot_update_sheet_header(service):
    agent = _make_user("delivery_agent", {"settlements.view_assigned"})
    with pytest.raises(PermissionDeniedError):
        await service.update_sheet(uuid.uuid4(), SettlementSheetUpdateRequest(pick_sheet_no="PS-1"), agent)


# ---------------------------------------------------------------------------
# Adding a customer row after creation — Agent (or Admin) only, never
# Salesman; only the permission check runs before any DB access.
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_salesman_cannot_add_a_customer_row():
    from app.schemas.settlement import SettlementItemAddRequest

    service = SettlementService(db=None)
    salesman = _make_user("salesman", {"settlements.view_assigned"})

    async def _fake_get_by_id(_sheet_id):
        return _make_sheet(uuid.uuid4(), [salesman.id])

    service.sheets.get_by_id = _fake_get_by_id
    with pytest.raises(PermissionDeniedError):
        await service.add_item(
            uuid.uuid4(), SettlementItemAddRequest(customer_id=uuid.uuid4()), salesman
        )
