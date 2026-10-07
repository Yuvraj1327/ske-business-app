import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.common import money_str


class PicklistItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    row_no: int
    invoice_number: str
    customer_code: str | None
    customer_name: str
    salesman_label: str | None
    amount_payable: str
    customer_id: uuid.UUID | None
    sale_id: uuid.UUID | None
    status: str  # pending | cash | online | credit | cheque
    cheque_amount: str
    credit_salesman_id: uuid.UUID | None = None
    credit_salesman_name: str | None = None
    collected_at: datetime | None

    @classmethod
    def from_model(cls, item) -> "PicklistItemResponse":
        return cls(
            id=item.id,
            row_no=item.row_no,
            invoice_number=item.invoice_number,
            customer_code=item.customer_code,
            customer_name=item.customer_name,
            salesman_label=item.salesman_label,
            amount_payable=money_str(item.amount_payable),
            customer_id=item.customer_id,
            sale_id=item.sale_id,
            status=item.status,
            cheque_amount=money_str(item.cheque_amount),
            credit_salesman_id=item.credit_salesman_id,
            credit_salesman_name=item.credit_salesman.full_name if item.credit_salesman else None,
            collected_at=item.collected_at,
        )


class PicklistSummaryCounts(BaseModel):
    total: int
    pending: int
    cash: int
    online: int
    credit: int
    cheque: int = 0


class PicklistResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    picklist_no: str
    delivery_agent_id: uuid.UUID
    delivery_agent_name: str
    psr_route: str | None
    total_amount: str
    # Sum of the cheque amounts entered on this picklist's rows — the value
    # a Settlement Sheet with this Pick Sheet No. starts its Cheque from.
    cheque_total: str
    created_at: datetime
    counts: PicklistSummaryCounts


class PicklistDetailResponse(PicklistResponse):
    items: list[PicklistItemResponse]


class PicklistListResponse(BaseModel):
    items: list[PicklistResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


PICKLIST_CONFIRM_STATUSES = {"cash", "online", "credit", "cheque"}


class PicklistItemConfirmRequest(BaseModel):
    status: str  # cash | online | credit | cheque
    # Required (and only allowed) when status is "cheque".
    cheque_amount: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    # Required (and only allowed) when status is "credit": the Salesman who
    # will handle this Credit/Udhaar customer.
    salesman_id: uuid.UUID | None = None

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in PICKLIST_CONFIRM_STATUSES:
            raise ValueError(f"status must be one of: {', '.join(sorted(PICKLIST_CONFIRM_STATUSES))}")
        return v

    @model_validator(mode="after")
    def validate_cheque_amount(self) -> "PicklistItemConfirmRequest":
        if self.status == "cheque" and self.cheque_amount is None:
            raise ValueError("cheque_amount is required when status is 'cheque'")
        if self.status != "cheque" and self.cheque_amount is not None:
            raise ValueError("cheque_amount is only allowed when status is 'cheque'")
        if self.status == "credit" and self.salesman_id is None:
            raise ValueError("salesman_id is required when status is 'credit'")
        if self.status != "credit" and self.salesman_id is not None:
            raise ValueError("salesman_id is only allowed when status is 'credit'")
        return self
