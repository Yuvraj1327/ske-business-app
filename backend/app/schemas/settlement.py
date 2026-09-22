import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import money_str

DELIVERY_STATUSES = {"pending", "delivered", "not_delivered"}
SHEET_STATUSES = {"draft", "in_progress", "completed"}


class SettlementItemCreateRequest(BaseModel):
    customer_id: uuid.UUID
    invoice_amount: Decimal = Field(default=Decimal("0"), ge=0)
    credit_amount: Decimal = Field(default=Decimal("0"), ge=0)


class SettlementItemAddRequest(BaseModel):
    """Add one customer row to an already-existing sheet — same shape as
    SettlementItemCreateRequest, used by SettlementService.add_item (Admin
    or the assigned Delivery Agent, while the sheet isn't 'completed')."""

    customer_id: uuid.UUID
    invoice_amount: Decimal = Field(default=Decimal("0"), ge=0)
    credit_amount: Decimal = Field(default=Decimal("0"), ge=0)


class SettlementSheetCreateRequest(BaseModel):
    sheet_date: date
    delivery_agent_id: uuid.UUID
    salesman_ids: list[uuid.UUID] = Field(min_length=1)
    notes: str | None = None
    # General / reconciliation fields — manually entered by Admin.
    pick_sheet_no: str | None = None
    pick_sheet_value: Decimal = Field(default=Decimal("0"), ge=0)
    returns_amount: Decimal = Field(default=Decimal("0"), ge=0)
    damage_return_amount: Decimal = Field(default=Decimal("0"), ge=0)
    discount_amount: Decimal = Field(default=Decimal("0"), ge=0)
    cash_amount: Decimal = Field(default=Decimal("0"), ge=0)
    online_amount: Decimal = Field(default=Decimal("0"), ge=0)
    cheque_amount: Decimal = Field(default=Decimal("0"), ge=0)
    credit_bills_amount: Decimal = Field(default=Decimal("0"), ge=0)
    old_short_amount: Decimal = Field(default=Decimal("0"), ge=0)
    # Customer rows are optional at creation — the Delivery Agent can add
    # them later via SettlementService.add_item.
    items: list[SettlementItemCreateRequest] = Field(default_factory=list)


class SettlementSheetUpdateRequest(BaseModel):
    """Admin-only partial update to a sheet's header/general fields. Every
    field is optional; only the ones provided are changed. Rejected once the
    sheet is 'completed' (see SettlementService.update_sheet)."""

    sheet_date: date | None = None
    delivery_agent_id: uuid.UUID | None = None
    salesman_ids: list[uuid.UUID] | None = None
    notes: str | None = None
    pick_sheet_no: str | None = None
    pick_sheet_value: Decimal | None = Field(default=None, ge=0)
    returns_amount: Decimal | None = Field(default=None, ge=0)
    damage_return_amount: Decimal | None = Field(default=None, ge=0)
    discount_amount: Decimal | None = Field(default=None, ge=0)
    cash_amount: Decimal | None = Field(default=None, ge=0)
    online_amount: Decimal | None = Field(default=None, ge=0)
    cheque_amount: Decimal | None = Field(default=None, ge=0)
    credit_bills_amount: Decimal | None = Field(default=None, ge=0)
    old_short_amount: Decimal | None = Field(default=None, ge=0)


class SettlementStatusUpdateRequest(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in SHEET_STATUSES:
            raise ValueError(f"status must be one of: {', '.join(sorted(SHEET_STATUSES))}")
        return v


class SettlementItemDeliveryUpdateRequest(BaseModel):
    """The Delivery Agent's (or Admin's) update to one row's delivery half.
    Amounts are split by mode since one delivery can be paid across several;
    `credit_amount` is the portion left as credit/udhaar for the Salesman to
    later collect against."""

    delivery_status: str
    cash_amount: Decimal = Field(default=Decimal("0"), ge=0)
    online_amount: Decimal = Field(default=Decimal("0"), ge=0)
    cheque_amount: Decimal = Field(default=Decimal("0"), ge=0)
    credit_amount: Decimal = Field(default=Decimal("0"), ge=0)
    agent_notes: str | None = None

    @field_validator("delivery_status")
    @classmethod
    def validate_delivery_status(cls, v: str) -> str:
        if v not in DELIVERY_STATUSES:
            raise ValueError(f"delivery_status must be one of: {', '.join(sorted(DELIVERY_STATUSES))}")
        return v


class SettlementItemCreditUpdateRequest(BaseModel):
    """The Salesman's (or Admin's) update to one row's Credit/Udhaar half.
    `credit_collected` is the new running-total amount collected so far
    (not a delta) — the service caps it at the row's `credit_amount`."""

    credit_collected: Decimal = Field(ge=0)
    salesman_notes: str | None = None


class SettlementItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    row_no: int
    customer_id: uuid.UUID
    customer_code: str | None
    customer_name: str
    assigned_salesman_id: uuid.UUID | None
    invoice_amount: str
    delivery_status: str
    cash_amount: str
    online_amount: str
    cheque_amount: str
    total_collected: str
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
            assigned_salesman_id=item.customer.assigned_salesman_id if item.customer else None,
            invoice_amount=money_str(item.invoice_amount),
            delivery_status=item.delivery_status,
            cash_amount=money_str(item.cash_amount),
            online_amount=money_str(item.online_amount),
            cheque_amount=money_str(item.cheque_amount),
            total_collected=money_str(item.cash_amount + item.online_amount + item.cheque_amount),
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


class SettlementSalesmanRef(BaseModel):
    id: uuid.UUID
    name: str


class SettlementSheetResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    sheet_no: str
    sheet_date: date
    delivery_agent_id: uuid.UUID
    delivery_agent_name: str
    salesmen: list[SettlementSalesmanRef]
    status: str
    notes: str | None
    # General / reconciliation fields — manually entered by Admin.
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
