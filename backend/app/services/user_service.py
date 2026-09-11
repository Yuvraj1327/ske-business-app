import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, ValidationError
from app.core.security import CurrentUser
from app.core import supabase_admin
from app.models.user import User
from app.repositories.role_repo import RoleRepository
from app.repositories.user_repo import UserRepository
from app.schemas.user import UserCreateRequest, UserResponse, UserUpdateRequest
from app.utils.pagination import PaginationParams


class UserService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.users = UserRepository(db)
        self.roles = RoleRepository(db)

    async def list_users(
        self,
        pagination: PaginationParams,
        search: str | None,
        role_id: uuid.UUID | None,
        is_active: bool | None,
    ):
        items, total = await self.users.list_users(pagination, search, role_id, is_active)
        return (
            [UserResponse.from_model(u) for u in items],
            total,
        )

    async def get_user(self, user_id: uuid.UUID) -> UserResponse:
        user = await self.users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found")
        return UserResponse.from_model(user)

    async def create_user(self, payload: UserCreateRequest) -> UserResponse:
        role = await self.roles.get_by_id(payload.role_id)
        if role is None:
            raise ValidationError("The selected role does not exist.", field="role_id")

        # Step 1: create the Supabase Auth identity (source of truth for credentials).
        auth_user_id = supabase_admin.create_auth_user(
            email=payload.email, password=payload.password, full_name=payload.full_name
        )

        # Step 2: create the app-domain profile row. If this fails, roll back
        # the auth user we just created so we don't leave an orphaned account
        # with no profile (which would otherwise fail login forever).
        try:
            user = User(
                auth_user_id=auth_user_id,
                full_name=payload.full_name,
                phone=payload.phone,
                role_id=payload.role_id,
                is_active=True,
            )
            user = await self.users.create(user)
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            supabase_admin.delete_auth_user(auth_user_id)
            raise

        await self.db.refresh(user, attribute_names=["role"])
        return UserResponse.from_model(user)

    async def update_user(self, user_id: uuid.UUID, payload: UserUpdateRequest) -> UserResponse:
        user = await self.users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found")

        if payload.role_id is not None:
            role = await self.roles.get_by_id(payload.role_id)
            if role is None:
                raise ValidationError("The selected role does not exist.", field="role_id")
            user.role_id = payload.role_id

        if payload.full_name is not None:
            user.full_name = payload.full_name.strip()
        if payload.phone is not None:
            user.phone = payload.phone

        user = await self.users.save(user)
        await self.db.commit()
        await self.db.refresh(user, attribute_names=["role"])
        return UserResponse.from_model(user)

    async def set_active_status(self, user_id: uuid.UUID, is_active: bool, current_user: CurrentUser) -> UserResponse:
        user = await self.users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found")

        if user.id == current_user.id and not is_active:
            # Simplifying assumption: an admin cannot deactivate their own
            # account, to avoid accidentally locking themselves out with no
            # other admin available. Not specified in requirements, but a
            # sensible safety rail.
            raise BusinessRuleError("You cannot deactivate your own account.")

        user.is_active = is_active
        user = await self.users.save(user)
        await self.db.commit()
        await self.db.refresh(user, attribute_names=["role"])
        return UserResponse.from_model(user)
