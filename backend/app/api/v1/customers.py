import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_any_permission, require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.customer import (
    CustomerCreateRequest,
    CustomerLedgerResponse,
    CustomerListResponse,
    CustomerOutstandingResponse,
    CustomerResponse,
    CustomerUpdateRequest,
)
from app.services.customer_service import CustomerService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/customers", tags=["customers"])

_view_permission = require_any_permission("customers.view_all", "customers.view_assigned")


@router.get("", response_model=CustomerListResponse)
async def list_customers(
    search: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(_view_permission),
) -> CustomerListResponse:
    service = CustomerService(db)
    items, total = await service.list_customers(current_user, pagination, search, is_active)
    return CustomerListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.post("", response_model=CustomerResponse, status_code=201)
async def create_customer(
    payload: CustomerCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("customers.create")),
) -> CustomerResponse:
    service = CustomerService(db)
    return await service.create_customer(payload, current_user)


@router.get("/{customer_id}", response_model=CustomerResponse)
async def get_customer(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(_view_permission),
) -> CustomerResponse:
    service = CustomerService(db)
    return await service.get_customer(customer_id, current_user)


@router.patch("/{customer_id}", response_model=CustomerResponse)
async def update_customer(
    customer_id: uuid.UUID,
    payload: CustomerUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("customers.edit")),
) -> CustomerResponse:
    service = CustomerService(db)
    return await service.update_customer(customer_id, payload, current_user)


@router.get("/{customer_id}/outstanding", response_model=CustomerOutstandingResponse)
async def get_customer_outstanding(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(_view_permission),
) -> CustomerOutstandingResponse:
    service = CustomerService(db)
    return await service.get_outstanding(customer_id, current_user)


@router.get("/{customer_id}/ledger", response_model=CustomerLedgerResponse)
async def get_customer_ledger(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(_view_permission),
) -> CustomerLedgerResponse:
    service = CustomerService(db)
    return await service.get_ledger(customer_id, current_user)
