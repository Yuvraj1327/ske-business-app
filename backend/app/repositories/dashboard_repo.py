from datetime import date
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.expense import Expense
from app.models.payment import Payment
from app.models.sale import Sale


class DashboardRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def count_customers(self) -> int:
        result = await self.db.execute(select(func.count()).select_from(Customer).where(Customer.is_active.is_(True)))
        return result.scalar_one()

    async def sales_summary(self, start: date, end: date) -> tuple[int, Decimal]:
        result = await self.db.execute(
            select(func.count(Sale.id), func.coalesce(func.sum(Sale.total_amount), 0))
            .where(Sale.status == "active", Sale.sale_date >= start, Sale.sale_date <= end)
        )
        count, total = result.one()
        return count, Decimal(total)

    async def payments_received(self, start: date, end: date) -> Decimal:
        result = await self.db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.status == "cleared", Payment.payment_date >= start, Payment.payment_date <= end
            )
        )
        return Decimal(result.scalar_one())

    async def outstanding_total(self) -> Decimal:
        """Point-in-time snapshot across ALL active sales — not scoped to a
        date range, since a customer's outstanding balance isn't a
        period-bound figure (see business rule #3 in the architecture doc)."""
        result = await self.db.execute(
            select(func.coalesce(func.sum(Sale.total_amount - Sale.paid_amount), 0)).where(Sale.status == "active")
        )
        return Decimal(result.scalar_one())

    async def expenses_total(self, start: date, end: date) -> Decimal:
        result = await self.db.execute(
            select(func.coalesce(func.sum(Expense.amount), 0)).where(
                Expense.status == "active", Expense.expense_date >= start, Expense.expense_date <= end
            )
        )
        return Decimal(result.scalar_one())
