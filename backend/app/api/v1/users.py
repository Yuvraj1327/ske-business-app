import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.user import UserCreateRequest, UserListResponse, UserResponse, UserUpdateRequest
from app.services.user_service import UserService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=UserListResponse)
async def list_users(
    search: str | None = Query(default=None),
    role_id: uuid.UUID | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("users.manage")),
) -> UserListResponse:
    service = UserService(db)
    items, total = await service.list_users(pagination, search, role_id, is_active)
    return UserListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.post("", response_model=UserResponse, status_code=201)
async def create_user(
    payload: UserCreateRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("users.manage")),
) -> UserResponse:
    service = UserService(db)
    return await service.create_user(payload)


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("users.manage")),
) -> UserResponse:
    service = UserService(db)
    return await service.get_user(user_id)


@router.patch("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: uuid.UUID,
    payload: UserUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("users.manage")),
) -> UserResponse:
    service = UserService(db)
    return await service.update_user(user_id, payload)


@router.patch("/{user_id}/activate", response_model=UserResponse)
async def activate_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("users.manage")),
) -> UserResponse:
    service = UserService(db)
    return await service.set_active_status(user_id, True, current_user)


@router.patch("/{user_id}/deactivate", response_model=UserResponse)
async def deactivate_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("users.manage")),
) -> UserResponse:
    service = UserService(db)
    return await service.set_active_status(user_id, False, current_user)
