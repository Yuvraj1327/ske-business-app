import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class SalesReturnItemCreateRequest(BaseModel):
    sale_item_id: uuid.UUID
    quantity: Decimal = Field(gt=0)


class SalesReturnCreateRequest(BaseModel):
    sale_id: uuid.UUID
    items: list[SalesReturnItemCreateRequest] = Field(min_length=1)
    reason: str | None = None


class SalesReturnItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    sale_item_id: uuid.UUID
    product_name: str
    quantity: str
    amount: str


class SalesReturnResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    sale_id: uuid.UUID
    customer_id: uuid.UUID
    customer_name: str
    return_date: date
    total_return_amount: str
    reason: str | None
    status: str
    items: list[SalesReturnItemResponse]
    created_at: datetime


class SalesReturnListResponse(BaseModel):
    items: list[SalesReturnResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
