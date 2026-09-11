import uuid

from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payment import Payment
from app.utils.pagination import PaginationParams, paginate


class PaymentRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, payment_id: uuid.UUID) -> Payment | None:
        result = await self.db.execute(select(Payment).where(Payment.id == payment_id))
        return result.scalar_one_or_none()

    def _base_query(
        self,
        customer_id: uuid.UUID | None,
        sale_id: uuid.UUID | None,
        payment_method: str | None,
        status: str | None,
    ) -> Select:
        stmt = select(Payment)
        if customer_id:
            stmt = stmt.where(Payment.customer_id == customer_id)
        if sale_id:
            stmt = stmt.where(Payment.sale_id == sale_id)
        if payment_method:
            stmt = stmt.where(Payment.payment_method == payment_method)
        if status:
            stmt = stmt.where(Payment.status == status)
        return stmt.order_by(Payment.payment_date.desc(), Payment.created_at.desc())

    async def list_payments(
        self,
        pagination: PaginationParams,
        customer_id: uuid.UUID | None,
        sale_id: uuid.UUID | None,
        payment_method: str | None,
        status: str | None,
    ):
        stmt = self._base_query(customer_id, sale_id, payment_method, status)
        return await paginate(self.db, stmt, pagination)

    async def create(self, payment: Payment) -> Payment:
        self.db.add(payment)
        await self.db.flush()
        return payment
