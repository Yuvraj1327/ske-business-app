import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.picklist import Picklist, PicklistItem
from app.utils.pagination import PaginationParams, paginate


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

    async def list_picklists(self, pagination: PaginationParams, delivery_agent_id: uuid.UUID | None):
        stmt = select(Picklist).order_by(Picklist.created_at.desc())
        if delivery_agent_id:
            stmt = stmt.where(Picklist.delivery_agent_id == delivery_agent_id)
        return await paginate(self.db, stmt, pagination)

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
