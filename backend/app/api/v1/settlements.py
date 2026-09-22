import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser, get_current_user
from app.db.session import get_db
from app.schemas.settlement import (
    SettlementItemCreditUpdateRequest,
    SettlementItemDeliveryUpdateRequest,
    SettlementItemResponse,
    SettlementSheetCreateRequest,
    SettlementSheetDetailResponse,
    SettlementSheetListResponse,
    SettlementStatusUpdateRequest,
)
from app.services.settlement_service import SettlementService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/settlements", tags=["settlements"])

# Note: list/get use plain get_current_user rather than require_permission(...),
# the same two-tier pattern as GET /picklists — "view everything"
# (settlements.manage) vs. "view only mine, as agent or salesman"
# (settlements.view_assigned). The actual authorization decision is made
# inside SettlementService, which raises PermissionDeniedError otherwise.


@router.get("", response_model=SettlementSheetListResponse)
async def list_settlement_sheets(
    status: str | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> SettlementSheetListResponse:
    service = SettlementService(db)
    items, total = await service.list_sheets(current_user, pagination, status)
    return SettlementSheetListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.post("", response_model=SettlementSheetDetailResponse, status_code=201)
async def create_settlement_sheet(
    payload: SettlementSheetCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("settlements.manage")),
) -> SettlementSheetDetailResponse:
    service = SettlementService(db)
    return await service.create_sheet(payload, current_user)


@router.get("/{sheet_id}", response_model=SettlementSheetDetailResponse)
async def get_settlement_sheet(
    sheet_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> SettlementSheetDetailResponse:
    service = SettlementService(db)
    return await service.get_sheet(sheet_id, current_user)


@router.patch("/{sheet_id}/status", response_model=SettlementSheetDetailResponse)
async def update_settlement_sheet_status(
    sheet_id: uuid.UUID,
    payload: SettlementStatusUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("settlements.manage")),
) -> SettlementSheetDetailResponse:
    """Admin-only: Draft -> In Progress -> Completed. See
    SettlementService.update_status for the allowed-transition rules."""
    service = SettlementService(db)
    return await service.update_status(sheet_id, payload.status, current_user)


@router.patch("/items/{item_id}/delivery", response_model=SettlementItemResponse)
async def update_settlement_item_delivery(
    item_id: uuid.UUID,
    payload: SettlementItemDeliveryUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> SettlementItemResponse:
    """The assigned Delivery Agent's (or Admin's) update to one row's
    delivery status / amount collected / payment mode."""
    service = SettlementService(db)
    return await service.update_item_delivery(item_id, payload, current_user)


@router.patch("/items/{item_id}/credit", response_model=SettlementItemResponse)
async def update_settlement_item_credit(
    item_id: uuid.UUID,
    payload: SettlementItemCreditUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> SettlementItemResponse:
    """The assigned Salesman's (or Admin's) update to one row's
    Credit/Udhaar collected amount."""
    service = SettlementService(db)
    return await service.update_item_credit(item_id, payload, current_user)
