import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.expense import (
    ExpenseCategoryCreateRequest,
    ExpenseCategoryResponse,
    ExpenseCreateRequest,
    ExpenseListResponse,
    ExpenseResponse,
    ExpenseUpdateRequest,
)
from app.services.expense_service import ExpenseCategoryService, ExpenseService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(tags=["expenses"])


@router.get("/expenses/categories", response_model=list[ExpenseCategoryResponse])
async def list_expense_categories(
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("expenses.manage")),
) -> list[ExpenseCategoryResponse]:
    service = ExpenseCategoryService(db)
    return await service.list_categories()


@router.post("/expenses/categories", response_model=ExpenseCategoryResponse, status_code=201)
async def create_expense_category(
    payload: ExpenseCategoryCreateRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("expenses.manage")),
) -> ExpenseCategoryResponse:
    service = ExpenseCategoryService(db)
    return await service.create_category(payload)


@router.get("/expenses", response_model=ExpenseListResponse)
async def list_expenses(
    category_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("expenses.manage")),
) -> ExpenseListResponse:
    service = ExpenseService(db)
    items, total, total_amount = await service.list_expenses(pagination, category_id, status, date_from, date_to)
    return ExpenseListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
        total_amount=total_amount,
    )


@router.post("/expenses", response_model=ExpenseResponse, status_code=201)
async def create_expense(
    payload: ExpenseCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("expenses.manage")),
) -> ExpenseResponse:
    service = ExpenseService(db)
    return await service.create_expense(payload, current_user)


@router.patch("/expenses/{expense_id}", response_model=ExpenseResponse)
async def update_expense(
    expense_id: uuid.UUID,
    payload: ExpenseUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("expenses.manage")),
) -> ExpenseResponse:
    service = ExpenseService(db)
    return await service.update_expense(expense_id, payload)


@router.patch("/expenses/{expense_id}/void", response_model=ExpenseResponse)
async def void_expense(
    expense_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("expenses.manage")),
) -> ExpenseResponse:
    service = ExpenseService(db)
    return await service.void_expense(expense_id)
