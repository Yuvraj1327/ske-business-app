import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.invoice import Invoice
from app.models.payment import ChequeDetail
from app.repositories.report_repo import ReportRepository
from app.schemas.common import money_str
from app.schemas.expense import ExpenseResponse
from app.schemas.payment import ChequeDetailResponse, PaymentResponse
from app.schemas.report import (
    CustomerReportResponse,
    CustomerReportRow,
    ExpenseCategoryBreakdown,
    ExpenseReportResponse,
    OutstandingReportResponse,
    OutstandingReportRow,
    PaymentMethodBreakdown,
    PaymentReportResponse,
    SalesmanReportResponse,
    SalesmanReportRow,
    SalesReportResponse,
    TransactionReportBreakdown,
    TransactionReportResponse,
)
from app.schemas.sale import SaleListItemResponse
from app.utils.pagination import PaginationParams


class ReportService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.reports = ReportRepository(db)

    async def sales_report(
        self, pagination: PaginationParams, date_from: date, date_to: date, customer_id: uuid.UUID | None
    ) -> SalesReportResponse:
        count, total_amount, total_discount = await self.reports.sales_summary(date_from, date_to, customer_id)
        sales, total = await self.reports.sales_list(pagination, date_from, date_to, customer_id)

        # Reuse the same customer/invoice batching pattern as SaleService.list_sales
        customer_ids = {s.customer_id for s in sales}
        customers_by_id = {}
        if customer_ids:
            result = await self.db.execute(select(Customer).where(Customer.id.in_(customer_ids)))
            customers_by_id = {c.id: c for c in result.scalars().all()}

        sale_ids = [s.id for s in sales]
        invoices_by_sale = {}
        if sale_ids:
            result = await self.db.execute(select(Invoice).where(Invoice.sale_id.in_(sale_ids)))
            invoices_by_sale = {inv.sale_id: inv for inv in result.scalars().all()}

        items = [
            SaleListItemResponse(
                id=s.id,
                customer_id=s.customer_id,
                customer_name=customers_by_id.get(s.customer_id).name if s.customer_id in customers_by_id else "",
                sale_date=s.sale_date,
                total_amount=money_str(s.total_amount),
                outstanding_amount=money_str(s.total_amount - s.paid_amount),
                payment_status=s.payment_status,
                status=s.status,
                invoice_number=invoices_by_sale.get(s.id).invoice_number if s.id in invoices_by_sale else None,
            )
            for s in sales
        ]

        return SalesReportResponse(
            range_start=date_from,
            range_end=date_to,
            total_sales_count=count,
            total_sales_amount=money_str(total_amount),
            total_discount=money_str(total_discount),
            items=items,
            total=total,
            page=pagination.page,
            page_size=pagination.page_size,
            total_pages=max(1, -(-total // pagination.page_size)),
        )

    async def customer_report(self, pagination: PaginationParams) -> CustomerReportResponse:
        rows, total = await self.reports.customer_report(pagination)
        items = [
            CustomerReportRow(
                customer_id=r.id,
                customer_name=r.name,
                sales_count=r.sales_count,
                sales_total=money_str(r.sales_total),
                outstanding=money_str(r.outstanding),
            )
            for r in rows
        ]
        return CustomerReportResponse(
            items=items,
            total=total,
            page=pagination.page,
            page_size=pagination.page_size,
            total_pages=max(1, -(-total // pagination.page_size)),
        )

    async def payment_report(self, pagination: PaginationParams, date_from: date, date_to: date) -> PaymentReportResponse:
        breakdown_rows = await self.reports.payments_breakdown(date_from, date_to)
        payments, total = await self.reports.payments_list(pagination, date_from, date_to)

        customer_ids = {p.customer_id for p in payments}
        customers_by_id = {}
        if customer_ids:
            result = await self.db.execute(select(Customer).where(Customer.id.in_(customer_ids)))
            customers_by_id = {c.id: c for c in result.scalars().all()}

        payment_service_helper = _PaymentResponseBuilder(self.db)
        items = [await payment_service_helper.build(p, customers_by_id.get(p.customer_id)) for p in payments]

        return PaymentReportResponse(
            range_start=date_from,
            range_end=date_to,
            breakdown_by_method=[
                PaymentMethodBreakdown(payment_method=row[0], count=row[1], total=money_str(row[2])) for row in breakdown_rows
            ],
            items=items,
            total=total,
            page=pagination.page,
            page_size=pagination.page_size,
            total_pages=max(1, -(-total // pagination.page_size)),
        )

    async def outstanding_report(self, pagination: PaginationParams) -> OutstandingReportResponse:
        rows, total, grand_total = await self.reports.outstanding_report(pagination)
        items = [
            OutstandingReportRow(customer_id=r.id, customer_name=r.name, phone=r.phone, outstanding=money_str(r.outstanding))
            for r in rows
        ]
        return OutstandingReportResponse(
            items=items,
            total=total,
            page=pagination.page,
            page_size=pagination.page_size,
            total_pages=max(1, -(-total // pagination.page_size)),
            grand_total_outstanding=money_str(grand_total),
        )

    async def expense_report(self, pagination: PaginationParams, date_from: date, date_to: date) -> ExpenseReportResponse:
        breakdown_rows = await self.reports.expenses_breakdown(date_from, date_to)
        expenses, total = await self.reports.expenses_list(pagination, date_from, date_to)
        items = [ExpenseResponse.from_model(e) for e in expenses]

        return ExpenseReportResponse(
            range_start=date_from,
            range_end=date_to,
            breakdown_by_category=[
                ExpenseCategoryBreakdown(category_name=row[0], count=row[1], total=money_str(row[2])) for row in breakdown_rows
            ],
            items=items,
            total=total,
            page=pagination.page,
            page_size=pagination.page_size,
            total_pages=max(1, -(-total // pagination.page_size)),
        )

    async def salesman_report(self, date_from: date, date_to: date) -> SalesmanReportResponse:
        rows = await self.reports.salesman_report(date_from, date_to)
        items = [
            SalesmanReportRow(
                salesman_id=r.id,
                salesman_name=r.full_name,
                customers_count=r.customers_count,
                sales_count=r.sales_count,
                sales_total=money_str(r.sales_total),
                outstanding_total=money_str(r.outstanding_total),
            )
            for r in rows
        ]
        return SalesmanReportResponse(range_start=date_from, range_end=date_to, items=items)

    async def transaction_report(self, date_from: date, date_to: date) -> TransactionReportResponse:
        rows = await self.reports.transactions_breakdown(date_from, date_to)
        breakdown = [
            TransactionReportBreakdown(transaction_type=row[0], direction=row[1], count=row[2], total=money_str(row[3]))
            for row in rows
        ]
        total_in = sum((row[3] for row in rows if row[1] == "in"), 0)
        total_out = sum((row[3] for row in rows if row[1] == "out"), 0)
        return TransactionReportResponse(
            range_start=date_from,
            range_end=date_to,
            breakdown=breakdown,
            total_in=money_str(total_in),
            total_out=money_str(total_out),
            net=money_str(total_in - total_out),
        )


class _PaymentResponseBuilder:
    """Tiny local helper mirroring PaymentService._build_response, without
    importing the full PaymentService (which would pull in payment-creation
    dependencies the read-only report doesn't need)."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def build(self, payment, customer) -> PaymentResponse:
        cheque_response = None
        if payment.payment_method == "cheque":
            cheque_result = await self.db.execute(select(ChequeDetail).where(ChequeDetail.payment_id == payment.id))
            cheque = cheque_result.scalar_one_or_none()
            if cheque:
                cheque_response = ChequeDetailResponse(
                    cheque_number=cheque.cheque_number,
                    cheque_date=cheque.cheque_date,
                    bank_name=cheque.bank_name,
                    cleared_date=cheque.cleared_date,
                )

        return PaymentResponse(
            id=payment.id,
            customer_id=payment.customer_id,
            customer_name=customer.name if customer else "",
            sale_id=payment.sale_id,
            amount=money_str(payment.amount),
            payment_method=payment.payment_method,
            payment_date=payment.payment_date,
            status=payment.status,
            notes=payment.notes,
            cheque_detail=cheque_response,
            created_at=payment.created_at,
        )
