import uuid

from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.role import Role
from app.models.task import Task
from app.models.user import User
from app.utils.pagination import PaginationParams, paginate


class SalesmanRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_salesmen(self, is_active: bool | None = None) -> list[User]:
        stmt = select(User).join(Role).where(Role.name == "salesman")
        if is_active is not None:
            stmt = stmt.where(User.is_active == is_active)
        stmt = stmt.order_by(User.full_name)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_salesman(self, salesman_id: uuid.UUID) -> User | None:
        result = await self.db.execute(
            select(User).join(Role).where(User.id == salesman_id, Role.name == "salesman")
        )
        return result.scalar_one_or_none()


class TaskRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, task_id: uuid.UUID) -> Task | None:
        result = await self.db.execute(select(Task).where(Task.id == task_id))
        return result.scalar_one_or_none()

    def _base_query(self, assigned_to: uuid.UUID | None, status: str | None) -> Select:
        stmt = select(Task)
        if assigned_to:
            stmt = stmt.where(Task.assigned_to == assigned_to)
        if status:
            stmt = stmt.where(Task.status == status)
        return stmt.order_by(Task.due_date.asc().nulls_last(), Task.created_at.desc())

    async def list_tasks(self, pagination: PaginationParams, assigned_to: uuid.UUID | None, status: str | None):
        stmt = self._base_query(assigned_to, status)
        return await paginate(self.db, stmt, pagination)

    async def create(self, task: Task) -> Task:
        self.db.add(task)
        await self.db.flush()
        await self.db.refresh(task)
        return task

    async def save(self, task: Task) -> Task:
        await self.db.flush()
        await self.db.refresh(task)
        return task
