import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import money_str

DELIVERY_STATUSES = {"pending", "delivered", "not_delivered"}
PAYMENT_MODES = {"cash", "online", "credit", "none"}
SHEET_STATUSES = {"draft", "in_progress", "completed"}


class SettlementItemCreateRequest(BaseModel):
    customer_id: uuid.UUID
    invoice_amount: Decimal = Field(default=Decimal("0"), ge=0)
    credit_amount: Decimal = Field(default=Decimal("0"), ge=0)


class SettlementSheetCreateRequest(BaseModel):
    sheet_date: date
    delivery_agent_id: uuid.UUID
    salesman_id: uuid.UUID
    notes: str | None = None
    pick_sheet_no: str | None = None
    pick_sheet_value: Decimal = Field(default=Decimal("0"), ge=0)
    items: list[SettlementItemCreateRequest] = Field(min_length=1)


class SettlementStatusUpdateRequest(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in SHEET_STATUSES:
            raise ValueError(f"status must be one of: {', '.join(sorted(SHEET_STATUSES))}")
        return v


class SettlementItemDeliveryUpdateRequest(BaseModel):
    """The Delivery Agent's (or Admin's) update to one row's delivery half."""

    delivery_status: str
    amount_collected: Decimal = Field(default=Decimal("0"), ge=0)
    payment_mode: str = "none"
    agent_notes: str | None = None

    @field_validator("delivery_status")
    @classmethod
    def validate_delivery_status(cls, v: str) -> str:
        if v not in DELIVERY_STATUSES:
            raise ValueError(f"delivery_status must be one of: {', '.join(sorted(DELIVERY_STATUSES))}")
        return v

    @field_validator("payment_mode")
    @classmethod
    def validate_payment_mode(cls, v: str) -> str:
        if v not in PAYMENT_MODES:
            raise ValueError(f"payment_mode must be one of: {', '.join(sorted(PAYMENT_MODES))}")
        return v


class SettlementItemCreditUpdateRequest(BaseModel):
    """The Salesman's (or Admin's) update to one row's Credit/Udhaar half.
    `credit_collected` is the new running-total amount collected so far
    (not a delta) — the service caps it at the row's `credit_amount`."""

    credit_collected: Decimal = Field(ge=0)
    salesman_notes: str | None = None


class SettlementAgentSummaryUpdateRequest(BaseModel):
    """The Delivery Agent's (or Admin's) route-level totals for the sheet
    itself (distinct from any one row) — the left-hand column of the paper
    settlement sheet."""

    returns_amount: Decimal = Field(default=Decimal("0"), ge=0)
    damage_return_amount: Decimal = Field(default=Decimal("0"), ge=0)
    discount_amount: Decimal = Field(default=Decimal("0"), ge=0)
    cash_amount: Decimal = Field(default=Decimal("0"), ge=0)
    online_amount: Decimal = Field(default=Decimal("0"), ge=0)
    cheque_amount: Decimal = Field(default=Decimal("0"), ge=0)


class SettlementSalesmanSummaryUpdateRequest(BaseModel):
    """The Salesman's (or Admin's) sheet-level Credit/Udhaar total."""

    credit_bills_amount: Decimal = Field(default=Decimal("0"), ge=0)


class SettlementAdminSummaryUpdateRequest(BaseModel):
    """Admin-only carry-forward figure from a prior unresolved sheet."""

    old_short_amount: Decimal = Field(default=Decimal("0"), ge=0)


class SettlementItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    row_no: int
    customer_id: uuid.UUID
    customer_code: str | None
    customer_name: str
    invoice_amount: str
    delivery_status: str
    amount_collected: str
    payment_mode: str
    agent_notes: str | None
    credit_amount: str
    credit_collected: str
    credit_outstanding: str
    salesman_notes: str | None
    updated_at: datetime

    @classmethod
    def from_model(cls, item) -> "SettlementItemResponse":
        return cls(
            id=item.id,
            row_no=item.row_no,
            customer_id=item.customer_id,
            customer_code=item.customer_code,
            customer_name=item.customer_name,
            invoice_amount=money_str(item.invoice_amount),
            delivery_status=item.delivery_status,
            amount_collected=money_str(item.amount_collected),
            payment_mode=item.payment_mode,
            agent_notes=item.agent_notes,
            credit_amount=money_str(item.credit_amount),
            credit_collected=money_str(item.credit_collected),
            credit_outstanding=money_str(item.credit_amount - item.credit_collected),
            salesman_notes=item.salesman_notes,
            updated_at=item.updated_at,
        )


class SettlementSheetSummary(BaseModel):
    total_items: int
    delivered: int
    not_delivered: int
    pending: int
    total_invoice_amount: str
    total_collected: str
    total_credit_outstanding: str


class SettlementSheetResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    sheet_no: str
    sheet_date: date
    delivery_agent_id: uuid.UUID
    delivery_agent_name: str
    salesman_id: uuid.UUID
    salesman_name: str
    status: str
    notes: str | None
    pick_sheet_no: str | None
    pick_sheet_value: str
    returns_amount: str
    damage_return_amount: str
    discount_amount: str
    cash_amount: str
    online_amount: str
    cheque_amount: str
    credit_bills_amount: str
    old_short_amount: str
    day_short: str
    total_balance: str
    summary: SettlementSheetSummary
    created_at: datetime
    updated_at: datetime


class SettlementSheetDetailResponse(SettlementSheetResponse):
    items: list[SettlementItemResponse]


class SettlementSheetListResponse(BaseModel):
    items: list[SettlementSheetResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
