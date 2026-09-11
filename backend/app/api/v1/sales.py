import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_any_permission, require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.sale import SaleCreateRequest, SaleListResponse, SaleResponse
from app.services.sale_service import SaleService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/sales", tags=["sales"])

_view_permission = require_any_permission("sales.view_all", "sales.view_assigned")


@router.post("", response_model=SaleResponse, status_code=201)
async def create_sale(
    payload: SaleCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("sales.create")),
) -> SaleResponse:
    service = SaleService(db)
    return await service.create_sale(payload, current_user)


@router.get("", response_model=SaleListResponse)
async def list_sales(
    customer_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(_view_permission),
) -> SaleListResponse:
    service = SaleService(db)
    items, total = await service.list_sales(current_user, pagination, customer_id, status, date_from, date_to)
    return SaleListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.get("/{sale_id}", response_model=SaleResponse)
async def get_sale(
    sale_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(_view_permission),
) -> SaleResponse:
    service = SaleService(db)
    return await service.get_sale(sale_id, current_user)


@router.patch("/{sale_id}/cancel", response_model=SaleResponse)
async def cancel_sale(
    sale_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("sales.cancel")),
) -> SaleResponse:
    service = SaleService(db)
    return await service.cancel_sale(sale_id, current_user)
