import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.invoice import Invoice
from app.models.sale import Sale
from app.utils.pagination import PaginationParams, paginate


class InvoiceRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, invoice_id: uuid.UUID) -> Invoice | None:
        result = await self.db.execute(select(Invoice).where(Invoice.id == invoice_id))
        return result.scalar_one_or_none()

    async def list_invoices(
        self,
        pagination: PaginationParams,
        customer_id: uuid.UUID | None,
        scoped_salesman_id: uuid.UUID | None,
    ) -> tuple[list[tuple[Invoice, Sale]], int]:
        """Returns (invoice, sale) pairs so the caller can build a response
        without an N+1 lookup per row. `scoped_salesman_id` enforces the same
        row-level visibility rule as GET /sales for salesmen with only
        `sales.view_assigned`."""
        stmt = select(Invoice, Sale).join(Sale, Sale.id == Invoice.sale_id).order_by(Invoice.invoice_date.desc())
        if customer_id:
            stmt = stmt.where(Sale.customer_id == customer_id)
        if scoped_salesman_id:
            stmt = stmt.where(Sale.salesman_id == scoped_salesman_id)

        count_stmt = select(func.count()).select_from(stmt.subquery())
        total = (await self.db.execute(count_stmt)).scalar_one()

        result = await self.db.execute(stmt.offset(pagination.offset).limit(pagination.page_size))
        rows = [(row[0], row[1]) for row in result.all()]
        return rows, total
