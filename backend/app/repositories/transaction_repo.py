import uuid
from datetime import date

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.transaction import Transaction
from app.utils.pagination import PaginationParams, paginate


class TransactionRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    def _base_query(
        self,
        transaction_type: str | None,
        direction: str | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Select:
        stmt = select(Transaction)
        if transaction_type:
            stmt = stmt.where(Transaction.transaction_type == transaction_type)
        if direction:
            stmt = stmt.where(Transaction.direction == direction)
        if date_from:
            stmt = stmt.where(Transaction.transaction_date >= date_from)
        if date_to:
            stmt = stmt.where(Transaction.transaction_date <= date_to)
        return stmt.order_by(Transaction.transaction_date.desc(), Transaction.created_at.desc())

    async def list_transactions(
        self,
        pagination: PaginationParams,
        transaction_type: str | None,
        direction: str | None,
        date_from: date | None,
        date_to: date | None,
    ):
        stmt = self._base_query(transaction_type, direction, date_from, date_to)
        items, total = await paginate(self.db, stmt, pagination)

        # Totals across the same filtered set (not just the current page) —
        # a single extra aggregate query, cheap compared to loading all rows.
        totals_stmt = select(Transaction.direction, func.coalesce(func.sum(Transaction.amount), 0))
        if transaction_type:
            totals_stmt = totals_stmt.where(Transaction.transaction_type == transaction_type)
        if date_from:
            totals_stmt = totals_stmt.where(Transaction.transaction_date >= date_from)
        if date_to:
            totals_stmt = totals_stmt.where(Transaction.transaction_date <= date_to)
        totals_stmt = totals_stmt.group_by(Transaction.direction)
        totals_result = await self.db.execute(totals_stmt)
        totals = {row[0]: row[1] for row in totals_result.all()}

        return items, total, totals.get("in", 0), totals.get("out", 0)

    async def create(self, transaction: Transaction) -> Transaction:
        self.db.add(transaction)
        await self.db.flush()
        await self.db.refresh(transaction)
        return transaction
