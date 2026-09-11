import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.models.customer import Customer
from app.repositories.invoice_repo import InvoiceRepository
from app.schemas.common import money_str
from app.schemas.sale import SaleListItemResponse, SaleListResponse, SaleResponse
from app.services.sale_service import SaleService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/invoices", tags=["invoices"])


def _scope_salesman_id(current_user: CurrentUser) -> uuid.UUID | None:
    if current_user.is_admin or current_user.has_permission("sales.view_all"):
        return None
    return current_user.id


@router.get("", response_model=SaleListResponse)
async def list_invoices(
    customer_id: uuid.UUID | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("invoices.view")),
) -> SaleListResponse:
    """Lists invoices (thin rows, one join, no N+1). For full line-item
    detail on a single invoice, use GET /invoices/{invoice_id}."""
    repo = InvoiceRepository(db)
    scoped_salesman_id = _scope_salesman_id(current_user)
    rows, total = await repo.list_invoices(pagination, customer_id, scoped_salesman_id)

    customer_ids = {sale.customer_id for _, sale in rows}
    customers_by_id: dict[uuid.UUID, Customer] = {}
    if customer_ids:
        result = await db.execute(select(Customer).where(Customer.id.in_(customer_ids)))
        customers_by_id = {c.id: c for c in result.scalars().all()}

    items = [
        SaleListItemResponse(
            id=sale.id,
            customer_id=sale.customer_id,
            customer_name=customers_by_id.get(sale.customer_id).name if sale.customer_id in customers_by_id else "",
            sale_date=sale.sale_date,
            total_amount=money_str(sale.total_amount),
            outstanding_amount=money_str(sale.total_amount - sale.paid_amount),
            payment_status=sale.payment_status,
            status=sale.status,
            invoice_number=invoice.invoice_number,
        )
        for invoice, sale in rows
    ]

    return SaleListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.get("/{invoice_id}", response_model=SaleResponse)
async def get_invoice(
    invoice_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("invoices.view")),
) -> SaleResponse:
    repo = InvoiceRepository(db)
    invoice = await repo.get_by_id(invoice_id)
    if invoice is None:
        raise NotFoundError("Invoice not found")

    sale_service = SaleService(db)
    return await sale_service.get_sale(invoice.sale_id, current_user)
