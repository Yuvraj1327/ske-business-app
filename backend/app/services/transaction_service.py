from datetime import date
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import CurrentUser
from app.models.transaction import Transaction
from app.repositories.transaction_repo import TransactionRepository
from app.schemas.common import money_str
from app.schemas.transaction import TransactionCreateRequest, TransactionResponse
from app.utils.pagination import PaginationParams


class TransactionService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.transactions = TransactionRepository(db)

    async def create_transaction(self, payload: TransactionCreateRequest, current_user: CurrentUser) -> TransactionResponse:
        transaction = Transaction(
            transaction_type=payload.transaction_type,
            direction=payload.direction,
            amount=Decimal(str(payload.amount)),
            transaction_date=payload.transaction_date or date.today(),
            reference_note=payload.reference_note,
            created_by=current_user.id,
        )
        transaction = await self.transactions.create(transaction)
        await self.db.commit()
        return TransactionResponse.from_model(transaction)

    async def list_transactions(
        self,
        pagination: PaginationParams,
        transaction_type: str | None,
        direction: str | None,
        date_from: date | None,
        date_to: date | None,
    ):
        items, total, total_in, total_out = await self.transactions.list_transactions(
            pagination, transaction_type, direction, date_from, date_to
        )
        return (
            [TransactionResponse.from_model(t) for t in items],
            total,
            money_str(total_in),
            money_str(total_out),
        )
