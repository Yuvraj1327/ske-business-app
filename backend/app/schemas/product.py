import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import money_str


class ProductCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    sku: str | None = Field(default=None, max_length=50)
    unit: str = Field(default="pcs", max_length=20)
    default_price: Decimal = Field(gt=0)

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("name cannot be blank")
        return v


class ProductUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    sku: str | None = Field(default=None, max_length=50)
    unit: str | None = Field(default=None, max_length=20)
    default_price: Decimal | None = Field(default=None, gt=0)
    is_active: bool | None = None


class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    sku: str | None
    unit: str
    default_price: str
    is_active: bool
    created_at: datetime

    @classmethod
    def from_model(cls, product) -> "ProductResponse":
        return cls(
            id=product.id,
            name=product.name,
            sku=product.sku,
            unit=product.unit,
            default_price=money_str(product.default_price),
            is_active=product.is_active,
            created_at=product.created_at,
        )


class ProductListResponse(BaseModel):
    items: list[ProductResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
