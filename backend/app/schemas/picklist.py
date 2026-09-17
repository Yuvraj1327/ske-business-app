import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator

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
    status: str  # pending | cash | online | credit
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
            collected_at=item.collected_at,
        )


class PicklistSummaryCounts(BaseModel):
    total: int
    pending: int
    cash: int
    online: int
    credit: int


class PicklistResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    picklist_no: str
    delivery_agent_id: uuid.UUID
    delivery_agent_name: str
    psr_route: str | None
    total_amount: str
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


class PicklistItemConfirmRequest(BaseModel):
    status: str  # cash | online | credit

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in {"cash", "online", "credit"}:
            raise ValueError("status must be one of: cash, online, credit")
        return v
