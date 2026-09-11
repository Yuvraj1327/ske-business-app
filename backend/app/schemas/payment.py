import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.common import money_str


class PaymentCreateRequest(BaseModel):
    customer_id: uuid.UUID
    sale_id: uuid.UUID | None = None
    amount: Decimal = Field(gt=0)
    payment_method: str  # cash | upi | bank_transfer | cheque
    payment_date: date | None = None
    notes: str | None = None

    # cheque-only fields
    cheque_number: str | None = None
    cheque_date: date | None = None
    bank_name: str | None = None

    @model_validator(mode="after")
    def validate_method_specific_fields(self) -> "PaymentCreateRequest":
        valid_methods = {"cash", "upi", "bank_transfer", "cheque"}
        if self.payment_method not in valid_methods:
            raise ValueError(f"payment_method must be one of {sorted(valid_methods)}")

        if self.payment_method == "cheque":
            missing = [
                name
                for name, val in (
                    ("cheque_number", self.cheque_number),
                    ("cheque_date", self.cheque_date),
                    ("bank_name", self.bank_name),
                )
                if not val
            ]
            if missing:
                raise ValueError(f"Cheque payments require: {', '.join(missing)}")
        return self


class ChequeStatusUpdateRequest(BaseModel):
    status: str  # cleared | cancelled


class ChequeDetailResponse(BaseModel):
    cheque_number: str
    cheque_date: date
    bank_name: str
    cleared_date: date | None


class PaymentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    customer_id: uuid.UUID
    customer_name: str
    sale_id: uuid.UUID | None
    amount: str
    payment_method: str
    payment_date: date
    status: str
    notes: str | None
    cheque_detail: ChequeDetailResponse | None
    created_at: datetime


class PaymentListResponse(BaseModel):
    items: list[PaymentResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
