"""
Settlement Sheet domain logic.

A Settlement Sheet is a manually-entered record of one Delivery Agent's
collection route for a given date (one agent + one salesman, multiple
customers), moved through Draft -> In Progress -> Completed by Admin, with
the two "halves" of each row filled in by two different people:

  - Delivery half (delivery_status / cash_amount / online_amount /
    cheque_amount / credit_amount / agent_notes) — the assigned Delivery
    Agent, only while 'in_progress'. The three collected amounts are split
    by mode since one delivery can be paid across several; credit_amount is
    whatever's left as credit/udhaar.
  - Credit/Udhaar half (credit_collected / salesman_notes) — the assigned
    Salesman, only while 'in_progress'.

Admin has full access throughout (creates the sheet in 'draft', can edit its
header/general fields via update_sheet up until it's 'completed', moves it
to 'in_progress', can also record either half if needed, and moves it to
'completed' once reviewed).

Distinct from PicklistService (see picklist_service.py's module docstring
for why): this does not create Sale/Invoice/Payment rows — it is its own
standalone record, not a payment-collection mechanism for the existing
outstanding/ledger screens.
"""
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, PermissionDeniedError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.settlement import SettlementSheet, SettlementSheetItem
from app.models.user import User
from app.repositories.settlement_repo import SettlementRepository
from app.schemas.common import money_str
from app.schemas.settlement import (
    SettlementItemCreditUpdateRequest,
    SettlementItemDeliveryUpdateRequest,
    SettlementSheetCreateRequest,
    SettlementSheetDetailResponse,
    SettlementSheetResponse,
    SettlementSheetSummary,
    SettlementSheetUpdateRequest,
    SettlementItemResponse,
)
from app.utils.pagination import PaginationParams

# Allowed forward-only status transitions. Admin drives every transition;
# there is no "reopen a completed sheet" or "go back to draft" path — if a
# mistake needs correcting once completed, that is a data-fix, not a status
# change, same spirit as picklist items never un-confirming.
_ALLOWED_TRANSITIONS = {
    "draft": {"in_progress"},
    "in_progress": {"completed"},
    "completed": set(),
}


class SettlementService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.sheets = SettlementRepository(db)

    # ------------------------------------------------------------------
    # Access helpers
    # ------------------------------------------------------------------
    def _can_manage(self, current_user: CurrentUser) -> bool:
        return current_user.is_admin or current_user.has_permission("settlements.manage")

    def _check_view_access(self, sheet: SettlementSheet, current_user: CurrentUser) -> None:
        if self._can_manage(current_user):
            return
        if current_user.has_permission("settlements.view_assigned") and current_user.id in (
            sheet.delivery_agent_id,
            sheet.salesman_id,
        ):
            return
        raise PermissionDeniedError("You do not have access to this settlement sheet.")

    def _check_agent_access(self, sheet: SettlementSheet, current_user: CurrentUser) -> None:
        """Only the sheet's assigned Delivery Agent, or Admin, may update
        the delivery half of its rows."""
        if self._can_manage(current_user):
            return
        if current_user.has_permission("settlements.view_assigned") and current_user.id == sheet.delivery_agent_id:
            return
        raise PermissionDeniedError("Only the assigned delivery agent can update delivery details for this sheet.")

    def _check_salesman_access(self, sheet: SettlementSheet, current_user: CurrentUser) -> None:
        """Only the sheet's assigned Salesman, or Admin, may update the
        Credit/Udhaar half of its rows."""
        if self._can_manage(current_user):
            return
        if current_user.has_permission("settlements.view_assigned") and current_user.id == sheet.salesman_id:
            return
        raise PermissionDeniedError("Only the assigned salesman can update credit/udhaar details for this sheet.")

    # ------------------------------------------------------------------
    # Reads
    # ------------------------------------------------------------------
    async def list_sheets(self, current_user: CurrentUser, pagination: PaginationParams, status: str | None):
        if not self._can_manage(current_user) and not current_user.has_permission("settlements.view_assigned"):
            raise PermissionDeniedError("You do not have permission to view settlement sheets.")

        scoped_user_id = None if self._can_manage(current_user) else current_user.id
        sheets, total = await self.sheets.list_sheets(pagination, scoped_user_id, status)
        responses = [await self._build_response(s) for s in sheets]
        return responses, total

    async def get_sheet(self, sheet_id: uuid.UUID, current_user: CurrentUser) -> SettlementSheetDetailResponse:
        sheet = await self.sheets.get_by_id(sheet_id)
        if sheet is None:
            raise NotFoundError("Settlement sheet not found")
        self._check_view_access(sheet, current_user)

        base = await self._build_response(sheet)
        items = [SettlementItemResponse.from_model(i) for i in sorted(sheet.items, key=lambda i: i.row_no)]
        return SettlementSheetDetailResponse(**base.model_dump(), items=items)

    async def _build_response(self, sheet: SettlementSheet) -> SettlementSheetResponse:
        agent_result = await self.db.execute(select(User).where(User.id == sheet.delivery_agent_id))
        agent = agent_result.scalar_one_or_none()
        salesman_result = await self.db.execute(select(User).where(User.id == sheet.salesman_id))
        salesman = salesman_result.scalar_one_or_none()

        total_invoice_amount = sum((i.invoice_amount for i in sheet.items), Decimal("0"))
        total_collected = sum(
            ((i.cash_amount + i.online_amount + i.cheque_amount) for i in sheet.items), Decimal("0")
        )
        total_credit_outstanding = sum(((i.credit_amount - i.credit_collected) for i in sheet.items), Decimal("0"))
        delivered = sum(1 for i in sheet.items if i.delivery_status == "delivered")
        not_delivered = sum(1 for i in sheet.items if i.delivery_status == "not_delivered")
        pending = sum(1 for i in sheet.items if i.delivery_status == "pending")

        return SettlementSheetResponse(
            id=sheet.id,
            sheet_no=sheet.sheet_no,
            sheet_date=sheet.sheet_date,
            delivery_agent_id=sheet.delivery_agent_id,
            delivery_agent_name=agent.full_name if agent else "",
            salesman_id=sheet.salesman_id,
            salesman_name=salesman.full_name if salesman else "",
            status=sheet.status,
            notes=sheet.notes,
            pick_sheet_no=sheet.pick_sheet_no,
            pick_sheet_value=money_str(sheet.pick_sheet_value),
            returns_amount=money_str(sheet.returns_amount),
            damage_return_amount=money_str(sheet.damage_return_amount),
            discount_amount=money_str(sheet.discount_amount),
            cash_amount=money_str(sheet.cash_amount),
            online_amount=money_str(sheet.online_amount),
            cheque_amount=money_str(sheet.cheque_amount),
            credit_bills_amount=money_str(sheet.credit_bills_amount),
            old_short_amount=money_str(sheet.old_short_amount),
            summary=SettlementSheetSummary(
                total_items=len(sheet.items),
                delivered=delivered,
                not_delivered=not_delivered,
                pending=pending,
                total_invoice_amount=money_str(total_invoice_amount),
                total_collected=money_str(total_collected),
                total_credit_outstanding=money_str(total_credit_outstanding),
            ),
            created_at=sheet.created_at,
            updated_at=sheet.updated_at,
        )

    # ------------------------------------------------------------------
    # Writes — Admin only (create + status transitions are structural)
    # ------------------------------------------------------------------
    async def create_sheet(
        self, payload: SettlementSheetCreateRequest, current_user: CurrentUser
    ) -> SettlementSheetDetailResponse:
        if not current_user.has_permission("settlements.manage"):
            raise PermissionDeniedError("Only an admin can create a settlement sheet.")

        agent = await self._require_user_with_role(payload.delivery_agent_id, "delivery_agent")
        salesman = await self._require_user_with_role(payload.salesman_id, "salesman")

        items: list[SettlementSheetItem] = []
        for row_no, item_payload in enumerate(payload.items, start=1):
            customer_result = await self.db.execute(select(Customer).where(Customer.id == item_payload.customer_id))
            customer = customer_result.scalar_one_or_none()
            if customer is None:
                raise ValidationError(f"Customer not found for row {row_no}.", field="items")

            items.append(
                SettlementSheetItem(
                    row_no=row_no,
                    customer_id=customer.id,
                    customer_code=customer.external_code,
                    customer_name=customer.name,
                    invoice_amount=item_payload.invoice_amount,
                    credit_amount=item_payload.credit_amount,
                )
            )

        sheet_no = await self._generate_sheet_no(payload.sheet_date)
        sheet = SettlementSheet(
            sheet_no=sheet_no,
            sheet_date=payload.sheet_date,
            delivery_agent_id=agent.id,
            salesman_id=salesman.id,
            status="draft",
            notes=payload.notes,
            pick_sheet_no=payload.pick_sheet_no,
            pick_sheet_value=payload.pick_sheet_value,
            returns_amount=payload.returns_amount,
            damage_return_amount=payload.damage_return_amount,
            discount_amount=payload.discount_amount,
            cash_amount=payload.cash_amount,
            online_amount=payload.online_amount,
            cheque_amount=payload.cheque_amount,
            credit_bills_amount=payload.credit_bills_amount,
            old_short_amount=payload.old_short_amount,
            created_by=current_user.id,
        )
        sheet.items = items

        sheet = await self.sheets.create(sheet)
        await self.db.commit()
        await self.db.refresh(sheet)
        return await self.get_sheet(sheet.id, current_user)

    async def _require_user_with_role(self, user_id: uuid.UUID, role_name: str) -> User:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None or not user.is_active:
            raise ValidationError(f"Selected {role_name.replace('_', ' ')} was not found or is inactive.")
        if user.role.name != role_name:
            raise ValidationError(f"Selected user is not an active {role_name.replace('_', ' ')}.")
        return user

    async def _generate_sheet_no(self, sheet_date) -> str:
        """SET-YYYYMMDD-NNN, sequential within the day. Not concurrency-safe
        against two simultaneous creates on the same date (same documented
        gap as elsewhere in this codebase without a real DB in front of the
        test suite — see tests/conftest.py) — acceptable for a low-volume,
        admin-only, manually-triggered creation flow."""
        count_today = await self.sheets.count_for_date(sheet_date)
        return f"SET-{sheet_date.strftime('%Y%m%d')}-{count_today + 1:03d}"

    async def update_sheet(
        self, sheet_id: uuid.UUID, payload: SettlementSheetUpdateRequest, current_user: CurrentUser
    ) -> SettlementSheetDetailResponse:
        """Admin-only partial update to a sheet's header/general fields —
        the only way to correct them once created. Locked once 'completed',
        same as the sheet as a whole becoming read-only at that point."""
        if not current_user.has_permission("settlements.manage"):
            raise PermissionDeniedError("Only an admin can edit a settlement sheet's details.")

        sheet = await self.sheets.get_by_id(sheet_id)
        if sheet is None:
            raise NotFoundError("Settlement sheet not found")

        if sheet.status == "completed":
            raise BusinessRuleError("A completed settlement sheet's details can no longer be edited.")

        if payload.delivery_agent_id is not None:
            agent = await self._require_user_with_role(payload.delivery_agent_id, "delivery_agent")
            sheet.delivery_agent_id = agent.id
        if payload.salesman_id is not None:
            salesman = await self._require_user_with_role(payload.salesman_id, "salesman")
            sheet.salesman_id = salesman.id

        updates = payload.model_dump(exclude={"delivery_agent_id", "salesman_id"}, exclude_unset=True)
        for field, value in updates.items():
            setattr(sheet, field, value)

        await self.sheets.save(sheet)
        await self.db.commit()
        return await self.get_sheet(sheet_id, current_user)

    async def update_status(
        self, sheet_id: uuid.UUID, new_status: str, current_user: CurrentUser
    ) -> SettlementSheetDetailResponse:
        if not current_user.has_permission("settlements.manage"):
            raise PermissionDeniedError("Only an admin can change a settlement sheet's status.")

        sheet = await self.sheets.get_by_id(sheet_id)
        if sheet is None:
            raise NotFoundError("Settlement sheet not found")

        allowed = _ALLOWED_TRANSITIONS.get(sheet.status, set())
        if new_status not in allowed:
            raise BusinessRuleError(
                f"Cannot move a settlement sheet from '{sheet.status}' to '{new_status}'."
            )

        if new_status == "completed":
            still_pending = [i for i in sheet.items if i.delivery_status == "pending"]
            if still_pending:
                raise BusinessRuleError(
                    "All rows must be marked delivered or not-delivered before completing this sheet."
                )

        sheet.status = new_status
        await self.sheets.save(sheet)
        await self.db.commit()
        return await self.get_sheet(sheet_id, current_user)

    # ------------------------------------------------------------------
    # Writes — per-row, Agent / Salesman (or Admin)
    # ------------------------------------------------------------------
    async def update_item_delivery(
        self, item_id: uuid.UUID, payload: SettlementItemDeliveryUpdateRequest, current_user: CurrentUser
    ) -> SettlementItemResponse:
        item = await self.sheets.get_item(item_id)
        if item is None:
            raise NotFoundError("Settlement sheet row not found")

        self._check_agent_access(item.sheet, current_user)

        if item.sheet.status != "in_progress":
            raise BusinessRuleError(
                "Delivery details can only be updated while the sheet is 'in_progress'."
            )

        new_credit_amount = Decimal("0") if payload.delivery_status == "not_delivered" else payload.credit_amount
        if new_credit_amount < item.credit_collected:
            raise BusinessRuleError(
                f"Credit amount ({money_str(new_credit_amount)}) cannot be reduced below what the "
                f"salesman has already collected against this row ({money_str(item.credit_collected)})."
            )

        if payload.delivery_status == "not_delivered":
            item.delivery_status = "not_delivered"
            item.cash_amount = Decimal("0")
            item.online_amount = Decimal("0")
            item.cheque_amount = Decimal("0")
            item.credit_amount = Decimal("0")
        else:
            if (
                payload.cash_amount <= 0
                and payload.online_amount <= 0
                and payload.cheque_amount <= 0
                and payload.credit_amount <= 0
            ):
                raise ValidationError(
                    "At least one of cash, online, cheque or credit amount must be greater than 0 "
                    "for a delivered row.",
                    field="cash_amount",
                )
            item.delivery_status = payload.delivery_status
            item.cash_amount = payload.cash_amount
            item.online_amount = payload.online_amount
            item.cheque_amount = payload.cheque_amount
            item.credit_amount = payload.credit_amount

        item.agent_notes = payload.agent_notes
        item.updated_at = datetime.utcnow()

        await self.sheets.save_item(item)
        await self.db.commit()
        await self.db.refresh(item)
        return SettlementItemResponse.from_model(item)

    async def update_item_credit(
        self, item_id: uuid.UUID, payload: SettlementItemCreditUpdateRequest, current_user: CurrentUser
    ) -> SettlementItemResponse:
        item = await self.sheets.get_item(item_id)
        if item is None:
            raise NotFoundError("Settlement sheet row not found")

        self._check_salesman_access(item.sheet, current_user)

        if item.sheet.status != "in_progress":
            raise BusinessRuleError(
                "Credit/Udhaar details can only be updated while the sheet is 'in_progress'."
            )

        if payload.credit_collected > item.credit_amount:
            raise BusinessRuleError(
                f"Credit collected ({money_str(payload.credit_collected)}) cannot exceed "
                f"the credit amount for this row ({money_str(item.credit_amount)})."
            )

        item.credit_collected = payload.credit_collected
        item.salesman_notes = payload.salesman_notes
        item.updated_at = datetime.utcnow()

        await self.sheets.save_item(item)
        await self.db.commit()
        await self.db.refresh(item)
        return SettlementItemResponse.from_model(item)
