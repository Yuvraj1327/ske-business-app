import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import money_str


class SalesmanResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    full_name: str
    phone: str | None
    is_active: bool


class AssignCustomerRequest(BaseModel):
    customer_id: uuid.UUID


class SalesmanPerformanceResponse(BaseModel):
    salesman_id: uuid.UUID
    salesman_name: str
    customers_count: int
    sales_count: int
    sales_total: str
    outstanding_total: str


class TaskCreateRequest(BaseModel):
    assigned_to: uuid.UUID
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    due_date: date | None = None

    @field_validator("title")
    @classmethod
    def strip_title(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("title cannot be blank")
        return v


class TaskUpdateStatusRequest(BaseModel):
    status: str  # pending | in_progress | completed | cancelled

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in {"pending", "in_progress", "completed", "cancelled"}:
            raise ValueError("Invalid task status")
        return v


class TaskResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    assigned_to: uuid.UUID
    assigned_to_name: str
    assigned_by: uuid.UUID
    assigned_by_name: str
    title: str
    description: str | None
    due_date: date | None
    status: str
    created_at: datetime


class TaskListResponse(BaseModel):
    items: list[TaskResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
