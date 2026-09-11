from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.transaction import TransactionCreateRequest, TransactionListResponse, TransactionResponse
from app.services.transaction_service import TransactionService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.post("", response_model=TransactionResponse, status_code=201)
async def create_transaction(
    payload: TransactionCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("transactions.manage")),
) -> TransactionResponse:
    service = TransactionService(db)
    return await service.create_transaction(payload, current_user)


@router.get("", response_model=TransactionListResponse)
async def list_transactions(
    transaction_type: str | None = Query(default=None),
    direction: str | None = Query(default=None),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("transactions.manage")),
) -> TransactionListResponse:
    service = TransactionService(db)
    items, total, total_in, total_out = await service.list_transactions(
        pagination, transaction_type, direction, date_from, date_to
    )
    return TransactionListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
        total_in=total_in,
        total_out=total_out,
    )
