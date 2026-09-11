import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.report import (
    CustomerReportResponse,
    ExpenseReportResponse,
    OutstandingReportResponse,
    PaymentReportResponse,
    SalesmanReportResponse,
    SalesReportResponse,
    TransactionReportResponse,
)
from app.services.report_service import ReportService
from app.utils.date_ranges import resolve_range
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/reports", tags=["reports"])


def _resolve(range_key: str, date_from: date | None, date_to: date | None) -> tuple[date, date]:
    return resolve_range(range_key, date_from, date_to)


@router.get("/sales", response_model=SalesReportResponse)
async def sales_report(
    range: str = Query(default="month"),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    customer_id: uuid.UUID | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("reports.view")),
) -> SalesReportResponse:
    start, end = _resolve(range, date_from, date_to)
    service = ReportService(db)
    return await service.sales_report(pagination, start, end, customer_id)


@router.get("/customers", response_model=CustomerReportResponse)
async def customer_report(
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("reports.view")),
) -> CustomerReportResponse:
    service = ReportService(db)
    return await service.customer_report(pagination)


@router.get("/payments", response_model=PaymentReportResponse)
async def payment_report(
    range: str = Query(default="month"),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("reports.view")),
) -> PaymentReportResponse:
    start, end = _resolve(range, date_from, date_to)
    service = ReportService(db)
    return await service.payment_report(pagination, start, end)


@router.get("/outstanding", response_model=OutstandingReportResponse)
async def outstanding_report(
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("reports.view")),
) -> OutstandingReportResponse:
    service = ReportService(db)
    return await service.outstanding_report(pagination)


@router.get("/expenses", response_model=ExpenseReportResponse)
async def expense_report(
    range: str = Query(default="month"),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("reports.view")),
) -> ExpenseReportResponse:
    start, end = _resolve(range, date_from, date_to)
    service = ReportService(db)
    return await service.expense_report(pagination, start, end)


@router.get("/salesmen", response_model=SalesmanReportResponse)
async def salesman_report(
    range: str = Query(default="month"),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("reports.view")),
) -> SalesmanReportResponse:
    start, end = _resolve(range, date_from, date_to)
    service = ReportService(db)
    return await service.salesman_report(start, end)


@router.get("/transactions", response_model=TransactionReportResponse)
async def transaction_report(
    range: str = Query(default="month"),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("reports.view")),
) -> TransactionReportResponse:
    start, end = _resolve(range, date_from, date_to)
    service = ReportService(db)
    return await service.transaction_report(start, end)
