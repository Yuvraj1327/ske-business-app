import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.payment import ChequeStatusUpdateRequest, PaymentCreateRequest, PaymentListResponse, PaymentResponse
from app.services.payment_service import PaymentService
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("", response_model=PaymentResponse, status_code=201)
async def create_payment(
    payload: PaymentCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("payments.create")),
) -> PaymentResponse:
    service = PaymentService(db)
    return await service.create_payment(payload, current_user)


@router.get("", response_model=PaymentListResponse)
async def list_payments(
    customer_id: uuid.UUID | None = Query(default=None),
    sale_id: uuid.UUID | None = Query(default=None),
    payment_method: str | None = Query(default=None),
    status: str | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("payments.create")),
) -> PaymentListResponse:
    service = PaymentService(db)
    items, total = await service.list_payments(pagination, customer_id, sale_id, payment_method, status)
    return PaymentListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.patch("/{payment_id}/status", response_model=PaymentResponse)
async def update_cheque_status(
    payment_id: uuid.UUID,
    payload: ChequeStatusUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("payments.manage_cheque_status")),
) -> PaymentResponse:
    service = PaymentService(db)
    return await service.update_cheque_status(payment_id, payload.status, current_user)
