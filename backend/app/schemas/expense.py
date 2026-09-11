import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import money_str


class ExpenseCategoryCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("name cannot be blank")
        return v


class ExpenseCategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    is_active: bool


class ExpenseCreateRequest(BaseModel):
    category_id: uuid.UUID
    amount: Decimal = Field(gt=0)
    expense_date: date | None = None
    description: str | None = None
    # If provided, also records a matching "cash out" entry in the unified
    # transactions ledger (see app/services/expense_service.py). Omit this
    # for expenses that haven't actually been paid yet (accrued/pending).
    payment_method: str | None = None  # cash | upi | bank


class ExpenseUpdateRequest(BaseModel):
    category_id: uuid.UUID | None = None
    amount: Decimal | None = Field(default=None, gt=0)
    expense_date: date | None = None
    description: str | None = None


class ExpenseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    category_id: uuid.UUID
    category_name: str
    amount: str
    expense_date: date
    description: str | None
    status: str  # active | voided
    created_at: datetime

    @classmethod
    def from_model(cls, expense) -> "ExpenseResponse":
        return cls(
            id=expense.id,
            category_id=expense.category_id,
            category_name=expense.category.name,
            amount=money_str(expense.amount),
            expense_date=expense.expense_date,
            description=expense.description,
            status=expense.status,
            created_at=expense.created_at,
        )


class ExpenseListResponse(BaseModel):
    items: list[ExpenseResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
    total_amount: str  # sum across the filtered set, not just the current page
