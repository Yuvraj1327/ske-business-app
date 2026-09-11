import uuid
from datetime import date

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.expense import Expense, ExpenseCategory
from app.utils.pagination import PaginationParams, paginate


class ExpenseCategoryRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, category_id: uuid.UUID) -> ExpenseCategory | None:
        result = await self.db.execute(select(ExpenseCategory).where(ExpenseCategory.id == category_id))
        return result.scalar_one_or_none()

    async def list_categories(self, is_active: bool | None = None) -> list[ExpenseCategory]:
        stmt = select(ExpenseCategory).order_by(ExpenseCategory.name)
        if is_active is not None:
            stmt = stmt.where(ExpenseCategory.is_active == is_active)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(self, category: ExpenseCategory) -> ExpenseCategory:
        self.db.add(category)
        await self.db.flush()
        await self.db.refresh(category)
        return category


class ExpenseRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, expense_id: uuid.UUID) -> Expense | None:
        result = await self.db.execute(select(Expense).where(Expense.id == expense_id))
        return result.scalar_one_or_none()

    def _base_query(
        self, category_id: uuid.UUID | None, status: str | None, date_from: date | None, date_to: date | None
    ) -> Select:
        stmt = select(Expense)
        if category_id:
            stmt = stmt.where(Expense.category_id == category_id)
        if status:
            stmt = stmt.where(Expense.status == status)
        if date_from:
            stmt = stmt.where(Expense.expense_date >= date_from)
        if date_to:
            stmt = stmt.where(Expense.expense_date <= date_to)
        return stmt.order_by(Expense.expense_date.desc(), Expense.created_at.desc())

    async def list_expenses(
        self,
        pagination: PaginationParams,
        category_id: uuid.UUID | None,
        status: str | None,
        date_from: date | None,
        date_to: date | None,
    ):
        stmt = self._base_query(category_id, status, date_from, date_to)
        items, total = await paginate(self.db, stmt, pagination)

        totals_stmt = select(func.coalesce(func.sum(Expense.amount), 0)).where(Expense.status == "active")
        if category_id:
            totals_stmt = totals_stmt.where(Expense.category_id == category_id)
        if date_from:
            totals_stmt = totals_stmt.where(Expense.expense_date >= date_from)
        if date_to:
            totals_stmt = totals_stmt.where(Expense.expense_date <= date_to)
        total_amount = (await self.db.execute(totals_stmt)).scalar_one()

        return items, total, total_amount

    async def create(self, expense: Expense) -> Expense:
        self.db.add(expense)
        await self.db.flush()
        await self.db.refresh(expense, attribute_names=["category"])
        return expense

    async def save(self, expense: Expense) -> Expense:
        await self.db.flush()
        await self.db.refresh(expense, attribute_names=["category"])
        return expense
