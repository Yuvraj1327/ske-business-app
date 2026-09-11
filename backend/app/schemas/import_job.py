import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class ImportJobResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    file_name: str
    entity_type: str
    status: str  # queued | processing | completed | failed
    total_rows: int | None
    success_rows: int
    failed_rows: int
    error_message: str | None
    created_at: datetime
    started_at: datetime | None
    completed_at: datetime | None


class ImportJobRowResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    row_number: int
    status: str  # success | failed
    error_message: str | None
    raw_data: dict[str, Any] | None


class ImportJobRowListResponse(BaseModel):
    items: list[ImportJobRowResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class ImportJobListResponse(BaseModel):
    items: list[ImportJobResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
