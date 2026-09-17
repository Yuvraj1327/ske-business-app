import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import CurrentUser, get_current_user
from app.db.session import get_db
from app.schemas.picklist import PicklistDetailResponse, PicklistItemConfirmRequest, PicklistItemResponse, PicklistListResponse
from app.services.picklist_service import PicklistService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/picklists", tags=["picklists"])

# Note: these routes use plain get_current_user rather than
# require_permission(...), because visibility is a mix of "view everything"
# (picklists.manage) vs. "view only your own" (picklists.view_assigned) —
# the same two-tier pattern already used by GET /tasks and PATCH
# /tasks/{id}/status (see api/v1/salesmen.py). The actual authorization
# decision is made inside PicklistService, which raises PermissionDeniedError
# for a user with neither permission, or who isn't the assigned agent for a
# specific picklist.


@router.get("", response_model=PicklistListResponse)
async def list_picklists(
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> PicklistListResponse:
    service = PicklistService(db)
    items, total = await service.list_picklists(current_user, pagination)
    return PicklistListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.get("/{picklist_id}", response_model=PicklistDetailResponse)
async def get_picklist(
    picklist_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> PicklistDetailResponse:
    service = PicklistService(db)
    return await service.get_picklist(picklist_id, current_user)


@router.patch("/items/{item_id}/confirm", response_model=PicklistItemResponse)
async def confirm_picklist_item(
    item_id: uuid.UUID,
    payload: PicklistItemConfirmRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> PicklistItemResponse:
    """The Delivery Agent's (or Admin's) confirm action: Cash / Online /
    Credit for one delivery. See PicklistService.confirm_item for what each
    outcome does."""
    service = PicklistService(db)
    return await service.confirm_item(item_id, payload.status, current_user)
