import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.product import ProductCreateRequest, ProductListResponse, ProductResponse, ProductUpdateRequest
from app.services.product_service import ProductService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/products", tags=["products"])


@router.get("", response_model=ProductListResponse)
async def list_products(
    search: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("sales.create")),  # anyone who can sell can browse products
) -> ProductListResponse:
    service = ProductService(db)
    items, total = await service.list_products(pagination, search, is_active)
    return ProductListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.post("", response_model=ProductResponse, status_code=201)
async def create_product(
    payload: ProductCreateRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("products.manage")),
) -> ProductResponse:
    service = ProductService(db)
    return await service.create_product(payload)


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("sales.create")),
) -> ProductResponse:
    service = ProductService(db)
    return await service.get_product(product_id)


@router.patch("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: uuid.UUID,
    payload: ProductUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("products.manage")),
) -> ProductResponse:
    service = ProductService(db)
    return await service.update_product(product_id, payload)
