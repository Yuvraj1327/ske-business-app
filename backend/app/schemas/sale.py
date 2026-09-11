import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import money_str


class SaleItemCreateRequest(BaseModel):
    product_id: uuid.UUID
    quantity: Decimal = Field(gt=0)
    unit_price: Decimal | None = Field(default=None, ge=0)  # defaults to product.default_price if omitted
    line_discount: Decimal = Field(default=Decimal("0"), ge=0)


class SaleCreateRequest(BaseModel):
    customer_id: uuid.UUID
    sale_date: date | None = None  # defaults to today
    items: list[SaleItemCreateRequest] = Field(min_length=1)
    discount_amount: Decimal = Field(default=Decimal("0"), ge=0)

    @field_validator("items")
    @classmethod
    def must_have_items(cls, v: list[SaleItemCreateRequest]) -> list[SaleItemCreateRequest]:
        if not v:
            raise ValueError("A sale must have at least one item")
        return v


class SaleItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    quantity: str
    unit_price: str
    line_discount: str
    line_total: str


class InvoiceSummary(BaseModel):
    id: uuid.UUID
    invoice_number: str
    invoice_date: date
    status: str


class SaleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    customer_id: uuid.UUID
    customer_name: str
    salesman_id: uuid.UUID | None
    sale_date: date
    subtotal: str
    discount_amount: str
    total_amount: str
    paid_amount: str
    outstanding_amount: str
    payment_status: str
    status: str
    items: list[SaleItemResponse]
    invoice: InvoiceSummary | None
    created_at: datetime


class SaleListItemResponse(BaseModel):
    id: uuid.UUID
    customer_id: uuid.UUID
    customer_name: str
    sale_date: date
    total_amount: str
    outstanding_amount: str
    payment_status: str
    status: str
    invoice_number: str | None


class SaleListResponse(BaseModel):
    items: list[SaleListItemResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
