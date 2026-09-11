import uuid

from sqlalchemy import Select, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.role import Role
from app.models.user import User
from app.utils.pagination import PaginationParams, paginate


class UserRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: uuid.UUID) -> User | None:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_auth_user_id(self, auth_user_id: uuid.UUID) -> User | None:
        result = await self.db.execute(select(User).where(User.auth_user_id == auth_user_id))
        return result.scalar_one_or_none()

    def _base_query(self, search: str | None, role_id: uuid.UUID | None, is_active: bool | None) -> Select:
        stmt = select(User).join(Role)
        if search:
            like = f"%{search.strip()}%"
            stmt = stmt.where(or_(User.full_name.ilike(like), User.phone.ilike(like)))
        if role_id:
            stmt = stmt.where(User.role_id == role_id)
        if is_active is not None:
            stmt = stmt.where(User.is_active == is_active)
        return stmt.order_by(User.created_at.desc())

    async def list_users(
        self,
        pagination: PaginationParams,
        search: str | None = None,
        role_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ):
        stmt = self._base_query(search, role_id, is_active)
        return await paginate(self.db, stmt, pagination)

    async def create(self, user: User) -> User:
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def save(self, user: User) -> User:
        await self.db.flush()
        await self.db.refresh(user)
        return user
