import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.role import Permission, Role


class RoleRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_roles(self) -> list[Role]:
        result = await self.db.execute(select(Role).order_by(Role.name))
        return list(result.scalars().all())

    async def get_by_id(self, role_id: uuid.UUID) -> Role | None:
        result = await self.db.execute(select(Role).where(Role.id == role_id))
        return result.scalar_one_or_none()

    async def list_permissions(self) -> list[Permission]:
        result = await self.db.execute(select(Permission).order_by(Permission.module, Permission.key))
        return list(result.scalars().all())

    async def get_permissions_by_ids(self, permission_ids: list[uuid.UUID]) -> list[Permission]:
        if not permission_ids:
            return []
        result = await self.db.execute(select(Permission).where(Permission.id.in_(permission_ids)))
        return list(result.scalars().all())

    async def replace_role_permissions(self, role: Role, permissions: list[Permission]) -> Role:
        role.permissions = permissions
        await self.db.flush()
        await self.db.refresh(role)
        return role
