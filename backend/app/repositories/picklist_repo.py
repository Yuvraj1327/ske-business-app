import uuid
from decimal import Decimal

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.picklist import Picklist, PicklistItem
from app.utils.pagination import PaginationParams, paginate


# Picklist collection mode -> the Settlement Sheet header field it syncs to.
# The sheet fields stay editable (until the next picklist change re-syncs
# them) and editing them never touches the picklist rows.
SETTLEMENT_FIELD_BY_MODE = {
    "cash": "cash_amount",
    "online": "online_amount",
    "credit": "credit_bills_amount",
    "cheque": "cheque_amount",
}


class PicklistRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, picklist_id: uuid.UUID) -> Picklist | None:
        result = await self.db.execute(
            select(Picklist).options(joinedload(Picklist.items)).where(Picklist.id == picklist_id)
        )
        return result.unique().scalar_one_or_none()

    async def get_by_picklist_no(self, picklist_no: str) -> Picklist | None:
        result = await self.db.execute(select(Picklist).where(Picklist.picklist_no == picklist_no))
        return result.scalar_one_or_none()

    async def lock_by_picklist_no(self, picklist_no: str) -> None:
        """Row-locks the picklist (held until the transaction ends) so two
        concurrent confirms on the same picklist recompute and write their
        settlement totals one after the other instead of the later commit
        carrying totals that miss the earlier one."""
        await self.db.execute(select(Picklist.id).where(Picklist.picklist_no == picklist_no).with_for_update())

    async def collection_totals_by_picklist_no(self, picklist_no: str | None) -> dict[str, Decimal]:
        """Totals saved on the picklist with this number, per collection mode
        (all 0 if there is no such picklist): cash / online / credit are the
        sums of the rows' amount payable marked that way, cheque the sum of
        the cheque amounts entered. A Settlement Sheet's `pick_sheet_no` is
        what links it to a picklist."""
        totals = {mode: Decimal("0") for mode in SETTLEMENT_FIELD_BY_MODE}
        if not picklist_no:
            return totals
        result = await self.db.execute(
            select(
                PicklistItem.status,
                func.coalesce(func.sum(PicklistItem.amount_payable), 0),
                func.coalesce(func.sum(PicklistItem.cheque_amount), 0),
            )
            .join(Picklist, Picklist.id == PicklistItem.picklist_id)
            .where(Picklist.picklist_no == picklist_no, PicklistItem.status.in_(list(totals)))
            .group_by(PicklistItem.status)
        )
        for status, payable, cheque in result.all():
            totals[status] = Decimal(cheque if status == "cheque" else payable)
        return totals

    async def items_by_picklist_no_and_status(self, picklist_no: str, status: str) -> list[PicklistItem] | None:
        """The picklist's rows saved with this collection status, in picklist
        order — None if there is no picklist with this number."""
        if await self.get_by_picklist_no(picklist_no) is None:
            return None
        result = await self.db.execute(
            select(PicklistItem)
            .join(Picklist, Picklist.id == PicklistItem.picklist_id)
            .where(Picklist.picklist_no == picklist_no, PicklistItem.status == status)
            .order_by(PicklistItem.row_no)
        )
        return list(result.scalars().all())

    async def total_amount_by_picklist_no(self, picklist_no: str | None) -> Decimal:
        """The picklist's imported total (sum of its invoice amounts, set at
        import) — what a Settlement Sheet's Pick Sheet Value starts from. 0
        if there is no picklist with this number."""
        if not picklist_no:
            return Decimal("0")
        result = await self.db.execute(select(Picklist.total_amount).where(Picklist.picklist_no == picklist_no))
        total = result.scalar_one_or_none()
        return Decimal(total) if total is not None else Decimal("0")

    async def list_picklists(self, pagination: PaginationParams, delivery_agent_id: uuid.UUID | None):
        stmt = select(Picklist).order_by(Picklist.created_at.desc())
        if delivery_agent_id:
            stmt = stmt.where(Picklist.delivery_agent_id == delivery_agent_id)
        return await paginate(self.db, stmt, pagination)

    def agent_sale_ids(self, agent_id: uuid.UUID) -> Select:
        """Sale ids linked to picklist items on this delivery agent's picklists."""
        return (
            select(PicklistItem.sale_id)
            .join(Picklist, Picklist.id == PicklistItem.picklist_id)
            .where(Picklist.delivery_agent_id == agent_id, PicklistItem.sale_id.is_not(None))
        )

    async def agent_has_sale(self, agent_id: uuid.UUID, sale_id: uuid.UUID) -> bool:
        result = await self.db.execute(self.agent_sale_ids(agent_id).where(PicklistItem.sale_id == sale_id).limit(1))
        return result.first() is not None

    async def create(self, picklist: Picklist) -> Picklist:
        self.db.add(picklist)
        await self.db.flush()
        return picklist

    async def get_item(self, item_id: uuid.UUID) -> PicklistItem | None:
        result = await self.db.execute(
            select(PicklistItem).options(joinedload(PicklistItem.picklist)).where(PicklistItem.id == item_id)
        )
        return result.unique().scalar_one_or_none()

    async def save_item(self, item: PicklistItem) -> PicklistItem:
        await self.db.flush()
        return item
