import uuid

from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.product import Product
from app.utils.pagination import PaginationParams, paginate


class ProductRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, product_id: uuid.UUID) -> Product | None:
        result = await self.db.execute(select(Product).where(Product.id == product_id))
        return result.scalar_one_or_none()

    def _base_query(self, search: str | None, is_active: bool | None) -> Select:
        stmt = select(Product)
        if search:
            like = f"%{search.strip()}%"
            stmt = stmt.where(Product.name.ilike(like))
        if is_active is not None:
            stmt = stmt.where(Product.is_active == is_active)
        return stmt.order_by(Product.name)

    async def list_products(self, pagination: PaginationParams, search: str | None, is_active: bool | None):
        stmt = self._base_query(search, is_active)
        return await paginate(self.db, stmt, pagination)

    async def create(self, product: Product) -> Product:
        self.db.add(product)
        await self.db.flush()
        await self.db.refresh(product)
        return product

    async def save(self, product: Product) -> Product:
        await self.db.flush()
        await self.db.refresh(product)
        return product
