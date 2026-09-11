import uuid

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.sales_return import SalesReturn, SalesReturnItem
from app.utils.pagination import PaginationParams, paginate


class SalesReturnRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, return_id: uuid.UUID) -> SalesReturn | None:
        result = await self.db.execute(
            select(SalesReturn).options(joinedload(SalesReturn.items)).where(SalesReturn.id == return_id)
        )
        return result.unique().scalar_one_or_none()

    async def already_returned_quantity(self, sale_item_id: uuid.UUID) -> "float | int":
        """Sum of quantities already returned for a sale line, across all
        completed (non-cancelled) returns — used to prevent returning more
        than was actually sold."""
        result = await self.db.execute(
            select(func.coalesce(func.sum(SalesReturnItem.quantity), 0))
            .join(SalesReturn, SalesReturn.id == SalesReturnItem.sales_return_id)
            .where(SalesReturnItem.sale_item_id == sale_item_id, SalesReturn.status == "completed")
        )
        return result.scalar_one()

    def _base_query(self, customer_id: uuid.UUID | None, sale_id: uuid.UUID | None) -> Select:
        stmt = select(SalesReturn)
        if customer_id:
            stmt = stmt.where(SalesReturn.customer_id == customer_id)
        if sale_id:
            stmt = stmt.where(SalesReturn.sale_id == sale_id)
        return stmt.order_by(SalesReturn.return_date.desc(), SalesReturn.created_at.desc())

    async def list_returns(self, pagination: PaginationParams, customer_id: uuid.UUID | None, sale_id: uuid.UUID | None):
        stmt = self._base_query(customer_id, sale_id)
        return await paginate(self.db, stmt, pagination)

    async def create(self, sales_return: SalesReturn) -> SalesReturn:
        self.db.add(sales_return)
        await self.db.flush()
        return sales_return
