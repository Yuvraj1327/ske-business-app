import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.expense import Expense, ExpenseCategory
from app.models.payment import Payment
from app.models.role import Role
from app.models.sale import Sale
from app.models.transaction import Transaction
from app.models.user import User
from app.utils.pagination import PaginationParams, paginate


class ReportRepository:
    """Read-only aggregation queries backing the Reports module. Kept
    separate from the transactional repositories (sale_repo, payment_repo,
    etc.) since reports never write, and their queries are shaped around
    grouping/summaries rather than single-entity CRUD."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def sales_summary(self, date_from: date, date_to: date, customer_id: uuid.UUID | None):
        stmt = select(
            func.count(Sale.id), func.coalesce(func.sum(Sale.total_amount), 0), func.coalesce(func.sum(Sale.discount_amount), 0)
        ).where(Sale.status == "active", Sale.sale_date >= date_from, Sale.sale_date <= date_to)
        if customer_id:
            stmt = stmt.where(Sale.customer_id == customer_id)
        result = await self.db.execute(stmt)
        return result.one()

    async def sales_list(self, pagination: PaginationParams, date_from: date, date_to: date, customer_id: uuid.UUID | None):
        stmt = (
            select(Sale)
            .where(Sale.status == "active", Sale.sale_date >= date_from, Sale.sale_date <= date_to)
            .order_by(Sale.sale_date.desc())
        )
        if customer_id:
            stmt = stmt.where(Sale.customer_id == customer_id)
        return await paginate(self.db, stmt, pagination)

    async def customer_report(self, pagination: PaginationParams):
        """Per-customer sales_count/sales_total/outstanding, one row per
        active customer, computed with a single grouped query rather than
        N+1 lookups.

        NOTE: this returns multiple columns (not a single ORM entity), so it
        can't use the shared `paginate()` helper — that helper calls
        `.scalars()`, which only extracts the first column of each row and
        would silently corrupt this result. Pagination is done manually here
        with `.all()` instead.
        """
        stmt = (
            select(
                Customer.id,
                Customer.name,
                func.count(Sale.id).label("sales_count"),
                func.coalesce(func.sum(Sale.total_amount), 0).label("sales_total"),
                func.coalesce(func.sum(Sale.total_amount - Sale.paid_amount), 0).label("outstanding"),
            )
            .select_from(Customer)
            .outerjoin(Sale, (Sale.customer_id == Customer.id) & (Sale.status == "active"))
            .where(Customer.is_active.is_(True))
            .group_by(Customer.id, Customer.name)
            .order_by(Customer.name)
        )

        count_stmt = select(func.count()).select_from(stmt.subquery())
        total = (await self.db.execute(count_stmt)).scalar_one()

        result = await self.db.execute(stmt.offset(pagination.offset).limit(pagination.page_size))
        rows = result.all()
        return rows, total

    async def payments_breakdown(self, date_from: date, date_to: date):
        stmt = (
            select(Payment.payment_method, func.count(Payment.id), func.coalesce(func.sum(Payment.amount), 0))
            .where(Payment.status == "cleared", Payment.payment_date >= date_from, Payment.payment_date <= date_to)
            .group_by(Payment.payment_method)
        )
        result = await self.db.execute(stmt)
        return result.all()

    async def payments_list(self, pagination: PaginationParams, date_from: date, date_to: date):
        stmt = (
            select(Payment)
            .where(Payment.payment_date >= date_from, Payment.payment_date <= date_to)
            .order_by(Payment.payment_date.desc())
        )
        return await paginate(self.db, stmt, pagination)

    async def outstanding_report(self, pagination: PaginationParams):
        """Also multi-column (see note on customer_report) — manual
        pagination, not the shared `paginate()` helper."""
        stmt = (
            select(
                Customer.id,
                Customer.name,
                Customer.phone,
                func.coalesce(func.sum(Sale.total_amount - Sale.paid_amount), 0).label("outstanding"),
            )
            .select_from(Customer)
            .join(Sale, (Sale.customer_id == Customer.id) & (Sale.status == "active"))
            .group_by(Customer.id, Customer.name, Customer.phone)
            .having(func.coalesce(func.sum(Sale.total_amount - Sale.paid_amount), 0) > 0)
            .order_by(func.sum(Sale.total_amount - Sale.paid_amount).desc())
        )

        count_stmt = select(func.count()).select_from(stmt.subquery())
        total = (await self.db.execute(count_stmt)).scalar_one()

        result = await self.db.execute(stmt.offset(pagination.offset).limit(pagination.page_size))
        items = result.all()

        grand_total_stmt = select(func.coalesce(func.sum(Sale.total_amount - Sale.paid_amount), 0)).where(Sale.status == "active")
        grand_total = (await self.db.execute(grand_total_stmt)).scalar_one()

        return items, total, grand_total

    async def expenses_breakdown(self, date_from: date, date_to: date):
        stmt = (
            select(ExpenseCategory.name, func.count(Expense.id), func.coalesce(func.sum(Expense.amount), 0))
            .select_from(Expense)
            .join(ExpenseCategory, ExpenseCategory.id == Expense.category_id)
            .where(Expense.status == "active", Expense.expense_date >= date_from, Expense.expense_date <= date_to)
            .group_by(ExpenseCategory.name)
        )
        result = await self.db.execute(stmt)
        return result.all()

    async def expenses_list(self, pagination: PaginationParams, date_from: date, date_to: date):
        stmt = (
            select(Expense)
            .where(Expense.expense_date >= date_from, Expense.expense_date <= date_to)
            .order_by(Expense.expense_date.desc())
        )
        return await paginate(self.db, stmt, pagination)

    async def salesman_report(self, date_from: date, date_to: date):
        stmt = (
            select(
                User.id,
                User.full_name,
                func.count(func.distinct(Customer.id)).label("customers_count"),
                func.count(func.distinct(Sale.id)).label("sales_count"),
                func.coalesce(func.sum(Sale.total_amount), 0).label("sales_total"),
                func.coalesce(func.sum(Sale.total_amount - Sale.paid_amount), 0).label("outstanding_total"),
            )
            .select_from(User)
            .join(Role, Role.id == User.role_id)
            .outerjoin(Customer, Customer.assigned_salesman_id == User.id)
            .outerjoin(
                Sale,
                (Sale.salesman_id == User.id)
                & (Sale.status == "active")
                & (Sale.sale_date >= date_from)
                & (Sale.sale_date <= date_to),
            )
            .where(Role.name == "salesman", User.is_active.is_(True))
            .group_by(User.id, User.full_name)
            .order_by(User.full_name)
        )
        result = await self.db.execute(stmt)
        return result.all()

    async def transactions_breakdown(self, date_from: date, date_to: date):
        stmt = (
            select(Transaction.transaction_type, Transaction.direction, func.count(Transaction.id), func.coalesce(func.sum(Transaction.amount), 0))
            .where(Transaction.transaction_date >= date_from, Transaction.transaction_date <= date_to)
            .group_by(Transaction.transaction_type, Transaction.direction)
        )
        result = await self.db.execute(stmt)
        return result.all()
