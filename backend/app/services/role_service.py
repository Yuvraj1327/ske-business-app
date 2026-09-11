import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, ValidationError
from app.repositories.role_repo import RoleRepository
from app.schemas.role import PermissionResponse, RoleResponse


class RoleService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.roles = RoleRepository(db)

    async def list_roles(self) -> list[RoleResponse]:
        roles = await self.roles.list_roles()
        return [RoleResponse.from_model(r) for r in roles]

    async def list_permissions(self) -> list[PermissionResponse]:
        permissions = await self.roles.list_permissions()
        return [PermissionResponse.model_validate(p) for p in permissions]

    async def update_role_permissions(self, role_id: uuid.UUID, permission_ids: list[uuid.UUID]) -> RoleResponse:
        role = await self.roles.get_by_id(role_id)
        if role is None:
            raise NotFoundError("Role not found")

        permissions = await self.roles.get_permissions_by_ids(permission_ids)
        if len(permissions) != len(set(permission_ids)):
            raise ValidationError("One or more permission ids are invalid.")

        role = await self.roles.replace_role_permissions(role, permissions)
        await self.db.commit()
        await self.db.refresh(role, attribute_names=["permissions"])
        return RoleResponse.from_model(role)
