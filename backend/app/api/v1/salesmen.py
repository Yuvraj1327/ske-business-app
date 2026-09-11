import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser, get_current_user
from app.db.session import get_db
from app.schemas.customer import CustomerListResponse
from app.schemas.salesman import (
    AssignCustomerRequest,
    SalesmanPerformanceResponse,
    SalesmanResponse,
    TaskCreateRequest,
    TaskListResponse,
    TaskResponse,
    TaskUpdateStatusRequest,
)
from app.services.salesman_service import SalesmanService, TaskService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(tags=["salesmen"])


@router.get("/salesmen", response_model=list[SalesmanResponse])
async def list_salesmen(
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("salesmen.manage")),
) -> list[SalesmanResponse]:
    service = SalesmanService(db)
    return await service.list_salesmen()


@router.get("/salesmen/{salesman_id}/customers", response_model=CustomerListResponse)
async def get_salesman_customers(
    salesman_id: uuid.UUID,
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("salesmen.manage")),
) -> CustomerListResponse:
    service = SalesmanService(db)
    items, total = await service.get_salesman_customers(salesman_id, pagination)
    return CustomerListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.post("/salesmen/{salesman_id}/assign-customer")
async def assign_customer(
    salesman_id: uuid.UUID,
    payload: AssignCustomerRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("salesmen.manage")),
):
    service = SalesmanService(db)
    return await service.assign_customer(salesman_id, payload)


@router.get("/salesmen/{salesman_id}/performance", response_model=SalesmanPerformanceResponse)
async def get_salesman_performance(
    salesman_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("salesmen.manage")),
) -> SalesmanPerformanceResponse:
    service = SalesmanService(db)
    return await service.get_performance(salesman_id)


@router.post("/salesmen/{salesman_id}/tasks", response_model=TaskResponse, status_code=201)
async def create_task_for_salesman(
    salesman_id: uuid.UUID,
    payload: TaskCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("salesmen.manage")),
) -> TaskResponse:
    # salesman_id in the path is authoritative — overrides any assigned_to
    # the client might have sent, so a task always lands on the salesman
    # whose URL it was created under.
    payload = payload.model_copy(update={"assigned_to": salesman_id})
    service = TaskService(db)
    return await service.create_task(payload, current_user)


@router.get("/tasks", response_model=TaskListResponse)
async def list_tasks(
    assigned_to: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> TaskListResponse:
    """Defaults to the caller's own tasks. Viewing another user's tasks
    requires `salesmen.manage` (enforced in the service layer)."""
    service = TaskService(db)
    items, total = await service.list_tasks(current_user, pagination, assigned_to, status)
    return TaskListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.patch("/tasks/{task_id}/status", response_model=TaskResponse)
async def update_task_status(
    task_id: uuid.UUID,
    payload: TaskUpdateStatusRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> TaskResponse:
    """The task's own assignee can update their own status (e.g. mark
    complete) without `salesmen.manage`; anyone else needs that permission."""
    service = TaskService(db)
    return await service.update_task_status(task_id, payload.status, current_user)
