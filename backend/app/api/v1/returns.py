import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.sales_return import SalesReturnCreateRequest, SalesReturnListResponse, SalesReturnResponse
from app.services.sales_return_service import SalesReturnService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/returns", tags=["returns"])

# Note: the seed permission set (see database/migrations/001_initial_schema.sql)
# only defines `returns.create` — there's no separate `returns.view`. As a
# documented simplification, anyone who can create a return can also view
# returns; a finer-grained view-only permission can be added later purely as
# a data change if needed.


@router.post("", response_model=SalesReturnResponse, status_code=201)
async def create_return(
    payload: SalesReturnCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("returns.create")),
) -> SalesReturnResponse:
    service = SalesReturnService(db)
    return await service.create_return(payload, current_user)


@router.get("", response_model=SalesReturnListResponse)
async def list_returns(
    customer_id: uuid.UUID | None = Query(default=None),
    sale_id: uuid.UUID | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("returns.create")),
) -> SalesReturnListResponse:
    service = SalesReturnService(db)
    items, total = await service.list_returns(pagination, customer_id, sale_id)
    return SalesReturnListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.get("/{return_id}", response_model=SalesReturnResponse)
async def get_return(
    return_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("returns.create")),
) -> SalesReturnResponse:
    service = SalesReturnService(db)
    return await service.get_return(return_id)
