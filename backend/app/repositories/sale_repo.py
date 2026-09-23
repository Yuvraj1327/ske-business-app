import uuid

from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.invoice import Invoice
from app.models.sale import Sale
from app.utils.pagination import PaginationParams, paginate


class SaleRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, sale_id: uuid.UUID) -> Sale | None:
        result = await self.db.execute(
            select(Sale).options(joinedload(Sale.items)).where(Sale.id == sale_id)
        )
        return result.unique().scalar_one_or_none()

    async def get_invoice(self, sale_id: uuid.UUID) -> Invoice | None:
        result = await self.db.execute(select(Invoice).where(Invoice.sale_id == sale_id))
        return result.scalar_one_or_none()

    def _base_query(
        self,
        customer_id: uuid.UUID | None,
        salesman_id: uuid.UUID | None,
        status: str | None,
        date_from,
        date_to,
    ) -> Select:
        stmt = select(Sale)
        if customer_id:
            stmt = stmt.where(Sale.customer_id == customer_id)
        if salesman_id:
            stmt = stmt.where(Sale.salesman_id == salesman_id)
        if status:
            stmt = stmt.where(Sale.status == status)
        if date_from:
            stmt = stmt.where(Sale.sale_date >= date_from)
        if date_to:
            stmt = stmt.where(Sale.sale_date <= date_to)
        return stmt.order_by(Sale.sale_date.desc(), Sale.created_at.desc())

    async def list_sales(
        self,
        pagination: PaginationParams,
        customer_id: uuid.UUID | None,
        salesman_id: uuid.UUID | None,
        status: str | None,
        date_from,
        date_to,
    ):
        stmt = self._base_query(customer_id, salesman_id, status, date_from, date_to)
        return await paginate(self.db, stmt, pagination)

    async def create(self, sale: Sale) -> Sale:
        self.db.add(sale)
        await self.db.flush()
        return sale

    async def save(self, sale: Sale) -> Sale:
        await self.db.flush()
        return sale
