import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class CustomerCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    phone: str | None = Field(default=None, max_length=20)
    email: str | None = Field(default=None, max_length=200)
    address: str | None = None
    gst_number: str | None = Field(default=None, max_length=30)
    assigned_salesman_id: uuid.UUID | None = None

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("name cannot be blank")
        return v


class CustomerUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    phone: str | None = Field(default=None, max_length=20)
    email: str | None = Field(default=None, max_length=200)
    address: str | None = None
    gst_number: str | None = Field(default=None, max_length=30)
    assigned_salesman_id: uuid.UUID | None = None
    is_active: bool | None = None


class CustomerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    phone: str | None
    email: str | None
    address: str | None
    gst_number: str | None
    assigned_salesman_id: uuid.UUID | None
    assigned_salesman_name: str | None = None
    is_active: bool
    created_at: datetime

    @classmethod
    def from_model(cls, customer) -> "CustomerResponse":
        return cls(
            id=customer.id,
            name=customer.name,
            phone=customer.phone,
            email=customer.email,
            address=customer.address,
            gst_number=customer.gst_number,
            assigned_salesman_id=customer.assigned_salesman_id,
            assigned_salesman_name=None,
            is_active=customer.is_active,
            created_at=customer.created_at,
        )


class CustomerListResponse(BaseModel):
    items: list[CustomerResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class CustomerOutstandingResponse(BaseModel):
    customer_id: uuid.UUID
    total_sales: str
    total_paid: str
    total_returned: str
    outstanding: str


class LedgerEntry(BaseModel):
    entry_date: datetime
    entry_type: str  # 'sale' | 'payment' | 'return'
    reference_id: uuid.UUID
    reference_label: str
    debit: str   # increases outstanding (sales)
    credit: str  # decreases outstanding (payments, returns)


class CustomerLedgerResponse(BaseModel):
    customer_id: uuid.UUID
    entries: list[LedgerEntry]
    outstanding: str
