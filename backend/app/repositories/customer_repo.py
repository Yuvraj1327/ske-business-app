import uuid

from sqlalchemy import Select, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.utils.pagination import PaginationParams, paginate


class CustomerRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, customer_id: uuid.UUID) -> Customer | None:
        result = await self.db.execute(select(Customer).where(Customer.id == customer_id))
        return result.scalar_one_or_none()

    def _base_query(
        self,
        search: str | None,
        assigned_salesman_id: uuid.UUID | None,
        is_active: bool | None,
    ) -> Select:
        stmt = select(Customer)
        if search:
            like = f"%{search.strip()}%"
            stmt = stmt.where(or_(Customer.name.ilike(like), Customer.phone.ilike(like)))
        if assigned_salesman_id:
            stmt = stmt.where(Customer.assigned_salesman_id == assigned_salesman_id)
        if is_active is not None:
            stmt = stmt.where(Customer.is_active == is_active)
        return stmt.order_by(Customer.name)

    async def list_customers(
        self,
        pagination: PaginationParams,
        search: str | None = None,
        assigned_salesman_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ):
        stmt = self._base_query(search, assigned_salesman_id, is_active)
        return await paginate(self.db, stmt, pagination)

    async def create(self, customer: Customer) -> Customer:
        self.db.add(customer)
        await self.db.flush()
        await self.db.refresh(customer)
        return customer

    async def save(self, customer: Customer) -> Customer:
        await self.db.flush()
        await self.db.refresh(customer)
        return customer
