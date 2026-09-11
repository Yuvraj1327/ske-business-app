import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.role import PermissionResponse, RolePermissionsUpdateRequest, RoleResponse
from app.services.role_service import RoleService

router = APIRouter(tags=["roles"])


@router.get("/roles", response_model=list[RoleResponse])
async def list_roles(
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("roles.manage")),
) -> list[RoleResponse]:
    service = RoleService(db)
    return await service.list_roles()


@router.get("/permissions", response_model=list[PermissionResponse])
async def list_permissions(
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("roles.manage")),
) -> list[PermissionResponse]:
    service = RoleService(db)
    return await service.list_permissions()


@router.put("/roles/{role_id}/permissions", response_model=RoleResponse)
async def update_role_permissions(
    role_id: uuid.UUID,
    payload: RolePermissionsUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("roles.manage")),
) -> RoleResponse:
    service = RoleService(db)
    return await service.update_role_permissions(role_id, payload.permission_ids)
