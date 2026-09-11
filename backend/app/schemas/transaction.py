import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import money_str


class TransactionCreateRequest(BaseModel):
    """
    Manual ledger entry — cash/UPI/bank money movement NOT already tied to a
    payment (those post automatically, see app/services/payment_service.py).
    Typical uses: owner cash infusion, petty cash withdrawal, a bank transfer
    between the business's own accounts.
    """

    transaction_type: str  # cash | upi | bank
    direction: str  # in | out
    amount: float = Field(gt=0)
    transaction_date: date | None = None
    reference_note: str | None = None

    @field_validator("transaction_type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        if v not in {"cash", "upi", "bank"}:
            raise ValueError("transaction_type must be one of: cash, upi, bank")
        return v

    @field_validator("direction")
    @classmethod
    def validate_direction(cls, v: str) -> str:
        if v not in {"in", "out"}:
            raise ValueError("direction must be 'in' or 'out'")
        return v


class TransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    transaction_type: str
    direction: str
    amount: str
    transaction_date: date
    related_payment_id: uuid.UUID | None
    related_expense_id: uuid.UUID | None
    reference_note: str | None
    created_at: datetime

    @classmethod
    def from_model(cls, txn) -> "TransactionResponse":
        return cls(
            id=txn.id,
            transaction_type=txn.transaction_type,
            direction=txn.direction,
            amount=money_str(txn.amount),
            transaction_date=txn.transaction_date,
            related_payment_id=txn.related_payment_id,
            related_expense_id=txn.related_expense_id,
            reference_note=txn.reference_note,
            created_at=txn.created_at,
        )


class TransactionListResponse(BaseModel):
    items: list[TransactionResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
    # Running totals for the *currently filtered* page range — handy for a
    # "Cash Balance" style header without a separate endpoint.
    total_in: str
    total_out: str
