import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.product import Product
from app.repositories.product_repo import ProductRepository
from app.schemas.product import ProductCreateRequest, ProductResponse, ProductUpdateRequest
from app.utils.pagination import PaginationParams


class ProductService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.products = ProductRepository(db)

    async def list_products(self, pagination: PaginationParams, search: str | None, is_active: bool | None):
        items, total = await self.products.list_products(pagination, search, is_active)
        return [ProductResponse.from_model(p) for p in items], total

    async def get_product(self, product_id: uuid.UUID) -> ProductResponse:
        product = await self.products.get_by_id(product_id)
        if product is None:
            raise NotFoundError("Product not found")
        return ProductResponse.from_model(product)

    async def create_product(self, payload: ProductCreateRequest) -> ProductResponse:
        product = Product(
            name=payload.name,
            sku=payload.sku,
            unit=payload.unit,
            default_price=payload.default_price,
            is_active=True,
        )
        self.db.add(product)
        try:
            await self.db.flush()
        except Exception as exc:
            await self.db.rollback()
            if "sku" in str(exc).lower():
                raise ConflictError("A product with this SKU already exists.", field="sku") from exc
            raise
        await self.db.refresh(product)
        await self.db.commit()
        return ProductResponse.from_model(product)

    async def update_product(self, product_id: uuid.UUID, payload: ProductUpdateRequest) -> ProductResponse:
        product = await self.products.get_by_id(product_id)
        if product is None:
            raise NotFoundError("Product not found")

        if payload.name is not None:
            product.name = payload.name.strip()
        if payload.sku is not None:
            product.sku = payload.sku
        if payload.unit is not None:
            product.unit = payload.unit
        if payload.default_price is not None:
            product.default_price = payload.default_price
        if payload.is_active is not None:
            product.is_active = payload.is_active

        product = await self.products.save(product)
        await self.db.commit()
        return ProductResponse.from_model(product)
