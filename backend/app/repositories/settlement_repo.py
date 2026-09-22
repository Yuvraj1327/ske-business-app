import uuid
from datetime import date

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.settlement import SettlementSheet, SettlementSheetItem
from app.utils.pagination import PaginationParams, paginate


class SettlementRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, sheet_id: uuid.UUID) -> SettlementSheet | None:
        result = await self.db.execute(
            select(SettlementSheet)
            .options(joinedload(SettlementSheet.items))
            .where(SettlementSheet.id == sheet_id)
        )
        return result.unique().scalar_one_or_none()

    async def get_by_sheet_no(self, sheet_no: str) -> SettlementSheet | None:
        result = await self.db.execute(select(SettlementSheet).where(SettlementSheet.sheet_no == sheet_no))
        return result.scalar_one_or_none()

    async def count_for_date(self, sheet_date: date) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(SettlementSheet).where(SettlementSheet.sheet_date == sheet_date)
        )
        return result.scalar_one()

    async def list_sheets(
        self,
        pagination: PaginationParams,
        scoped_user_id: uuid.UUID | None,
        status: str | None,
    ):
        stmt = select(SettlementSheet).order_by(SettlementSheet.sheet_date.desc(), SettlementSheet.created_at.desc())
        if scoped_user_id is not None:
            stmt = stmt.where(
                or_(
                    SettlementSheet.delivery_agent_id == scoped_user_id,
                    SettlementSheet.salesman_id == scoped_user_id,
                )
            )
        if status:
            stmt = stmt.where(SettlementSheet.status == status)
        return await paginate(self.db, stmt, pagination)

    async def create(self, sheet: SettlementSheet) -> SettlementSheet:
        self.db.add(sheet)
        await self.db.flush()
        return sheet

    async def save(self, sheet: SettlementSheet) -> SettlementSheet:
        await self.db.flush()
        await self.db.refresh(sheet)
        return sheet

    async def get_item(self, item_id: uuid.UUID) -> SettlementSheetItem | None:
        result = await self.db.execute(
            select(SettlementSheetItem)
            .options(joinedload(SettlementSheetItem.sheet))
            .where(SettlementSheetItem.id == item_id)
        )
        return result.unique().scalar_one_or_none()

    async def save_item(self, item: SettlementSheetItem) -> SettlementSheetItem:
        await self.db.flush()
        return item
