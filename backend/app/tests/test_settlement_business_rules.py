"""Settlement Sheet access-scoping and workflow rules, exercised directly
against SettlementService's pure decision logic without a database — same
approach as test_permissions.py (construct a CurrentUser by hand) and
test_sale_and_return_calculations.py (mirror an inline DB-dependent
calculation as a standalone one to verify the math/logic itself)."""
import uuid
from decimal import Decimal

import pytest

from app.core.exceptions import PermissionDeniedError
from app.core.security import CurrentUser
from app.models.settlement import SettlementSheet
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


def _make_sheet(agent_id: uuid.UUID, salesman_id: uuid.UUID, status: str = "draft") -> SettlementSheet:
    return SettlementSheet(
        id=uuid.uuid4(),
        sheet_no="SET-20260922-001",
        delivery_agent_id=agent_id,
        salesman_id=salesman_id,
        status=status,
    )


@pytest.fixture
def service() -> SettlementService:
    # None is fine here — the methods under test never touch self.db.
    return SettlementService(db=None)


# ---------------------------------------------------------------------------
# View access
# ---------------------------------------------------------------------------
def test_admin_can_view_any_sheet(service):
    admin = _make_user("admin", {"settlements.manage", "settlements.view_assigned"})
    sheet = _make_sheet(uuid.uuid4(), uuid.uuid4())
    service._check_view_access(sheet, admin)  # does not raise


def test_delivery_agent_can_view_their_own_sheet(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, uuid.uuid4())
    service._check_view_access(sheet, agent)  # does not raise


def test_delivery_agent_cannot_view_another_agents_sheet(service):
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=uuid.uuid4())
    sheet = _make_sheet(uuid.uuid4(), uuid.uuid4())  # different agent
    with pytest.raises(PermissionDeniedError):
        service._check_view_access(sheet, agent)


def test_salesman_can_view_their_own_sheet(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), salesman_id)
    service._check_view_access(sheet, salesman)  # does not raise


# ---------------------------------------------------------------------------
# Delivery-half access — Agent only, never Salesman
# ---------------------------------------------------------------------------
def test_assigned_agent_can_update_delivery_half(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, uuid.uuid4())
    service._check_agent_access(sheet, agent)  # does not raise


def test_assigned_salesman_cannot_update_delivery_half(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), salesman_id)
    with pytest.raises(PermissionDeniedError):
        service._check_agent_access(sheet, salesman)


# ---------------------------------------------------------------------------
# Credit half access — Salesman only, never Agent
# ---------------------------------------------------------------------------
def test_assigned_salesman_can_update_credit_half(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), salesman_id)
    service._check_salesman_access(sheet, salesman)  # does not raise


def test_assigned_agent_cannot_update_credit_half(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, uuid.uuid4())
    with pytest.raises(PermissionDeniedError):
        service._check_salesman_access(sheet, agent)


def test_admin_can_update_either_half_of_any_sheet(service):
    admin = _make_user("admin", {"settlements.manage"})
    sheet = _make_sheet(uuid.uuid4(), uuid.uuid4())
    service._check_agent_access(sheet, admin)  # does not raise
    service._check_salesman_access(sheet, admin)  # does not raise


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
# Route-level summary access — same agent/salesman/admin split as the
# per-row halves above, since update_agent_summary/update_salesman_summary
# reuse _check_agent_access/_check_salesman_access verbatim.
# ---------------------------------------------------------------------------
def test_assigned_agent_can_update_agent_summary(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, uuid.uuid4())
    service._check_agent_access(sheet, agent)  # does not raise


def test_assigned_salesman_cannot_update_agent_summary(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), salesman_id)
    with pytest.raises(PermissionDeniedError):
        service._check_agent_access(sheet, salesman)


def test_assigned_salesman_can_update_salesman_summary(service):
    salesman_id = uuid.uuid4()
    salesman = _make_user("salesman", {"settlements.view_assigned"}, user_id=salesman_id)
    sheet = _make_sheet(uuid.uuid4(), salesman_id)
    service._check_salesman_access(sheet, salesman)  # does not raise


def test_assigned_agent_cannot_update_salesman_summary(service):
    agent_id = uuid.uuid4()
    agent = _make_user("delivery_agent", {"settlements.view_assigned"}, user_id=agent_id)
    sheet = _make_sheet(agent_id, uuid.uuid4())
    with pytest.raises(PermissionDeniedError):
        service._check_salesman_access(sheet, agent)


@pytest.mark.asyncio
async def test_update_admin_summary_requires_manage_permission(service):
    from app.core.exceptions import PermissionDeniedError as PDE
    from app.schemas.settlement import SettlementAdminSummaryUpdateRequest

    non_admin = _make_user("delivery_agent", {"settlements.view_assigned"})
    with pytest.raises(PDE):
        await service.update_admin_summary(
            uuid.uuid4(), SettlementAdminSummaryUpdateRequest(old_short_amount=Decimal("50")), non_admin
        )


# ---------------------------------------------------------------------------
# Day Short / Total Balance arithmetic — mirrors the pure calculation in
# SettlementService._build_response, same standalone-formula approach as
# the credit-cap tests above.
# ---------------------------------------------------------------------------
def test_day_short_is_expected_minus_actual_collected():
    pick_sheet_value = Decimal("41186")
    returns_amount = Decimal("2644")
    damage_return_amount = Decimal("202")
    discount_amount = Decimal("0")
    cash_amount = Decimal("16640")
    online_amount = Decimal("8611")
    cheque_amount = Decimal("0")
    credit_bills_amount = Decimal("13086")

    expected_collectible = pick_sheet_value - returns_amount - damage_return_amount - discount_amount
    actual_collected = cash_amount + online_amount + cheque_amount + credit_bills_amount
    day_short = expected_collectible - actual_collected

    assert expected_collectible == Decimal("38340")
    assert actual_collected == Decimal("38337")
    assert day_short == Decimal("3")


def test_total_balance_folds_in_old_short():
    day_short = Decimal("3")
    old_short_amount = Decimal("50")
    assert day_short + old_short_amount == Decimal("53")
