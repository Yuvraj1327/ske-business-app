import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, PermissionDeniedError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.invoice import Invoice
from app.models.payment import Payment
from app.models.product import Product
from app.models.sale import Sale, SaleItem
from app.repositories.sale_repo import SaleRepository
from app.schemas.common import money_str
from app.schemas.sale import (
    InvoiceSummary,
    SaleCreateRequest,
    SaleItemResponse,
    SaleListItemResponse,
    SaleResponse,
)
from app.utils.invoice_number import next_invoice_number
from app.utils.pagination import PaginationParams


def compute_payment_status(paid_amount: Decimal, total_amount: Decimal) -> str:
    """Shared by payment recompute and sales-return total adjustment — the
    payment_status derivation must stay identical wherever paid_amount or
    total_amount can change."""
    if paid_amount <= 0:
        return "unpaid"
    if paid_amount >= total_amount:
        return "paid"
    return "partial"


async def recompute_sale_paid_amount(db: AsyncSession, sale_id: uuid.UUID) -> None:
    """
    Recalculates a sale's paid_amount and payment_status from its cleared
    payments. Called by the payment service any time a payment is created or
    a cheque changes status. Does NOT commit — caller controls the
    transaction boundary so this can be composed with other writes.
    """
    sale_result = await db.execute(select(Sale).where(Sale.id == sale_id))
    sale = sale_result.scalar_one_or_none()
    if sale is None:
        return

    paid_result = await db.execute(
        select(Payment.amount).where(Payment.sale_id == sale_id, Payment.status == "cleared")
    )
    paid_amount = sum((row[0] for row in paid_result.all()), Decimal("0"))

    sale.paid_amount = paid_amount
    sale.payment_status = compute_payment_status(paid_amount, sale.total_amount)

    await db.flush()


class SaleService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.sales = SaleRepository(db)

    def _scope_salesman_id(self, current_user: CurrentUser) -> uuid.UUID | None:
        if current_user.is_admin or current_user.has_permission("sales.view_all"):
            return None
        if current_user.has_permission("sales.view_assigned"):
            return current_user.id
        raise PermissionDeniedError("You do not have permission to view sales.")

    async def create_sale(self, payload: SaleCreateRequest, current_user: CurrentUser) -> SaleResponse:
        customer_result = await self.db.execute(select(Customer).where(Customer.id == payload.customer_id))
        customer = customer_result.scalar_one_or_none()
        if customer is None or not customer.is_active:
            raise ValidationError("Selected customer does not exist or is inactive.", field="customer_id")

        sale_date = payload.sale_date or date.today()

        # Backend recomputes every monetary figure from scratch — the client
        # never gets to dictate subtotal/total, only quantities/prices per
        # line. This is the "backend validates all monetary calculations"
        # requirement, and keeps money math on Decimal end-to-end (no floats).
        sale_items: list[SaleItem] = []
        subtotal = Decimal("0")

        for item in payload.items:
            product_result = await self.db.execute(select(Product).where(Product.id == item.product_id))
            product = product_result.scalar_one_or_none()
            if product is None or not product.is_active:
                raise ValidationError(f"Product {item.product_id} does not exist or is inactive.", field="items")

            unit_price = item.unit_price if item.unit_price is not None else product.default_price
            line_total = (item.quantity * unit_price) - item.line_discount
            if line_total < 0:
                raise ValidationError("Line discount cannot exceed the line amount.", field="items")

            subtotal += line_total
            sale_items.append(
                SaleItem(
                    product_id=product.id,
                    quantity=item.quantity,
                    unit_price=unit_price,
                    line_discount=item.line_discount,
                    line_total=line_total,
                )
            )

        if payload.discount_amount > subtotal:
            raise ValidationError("Discount cannot exceed the sale subtotal.", field="discount_amount")

        total_amount = subtotal - payload.discount_amount

        sale = Sale(
            customer_id=customer.id,
            salesman_id=current_user.id if not current_user.is_admin else None,
            sale_date=sale_date,
            subtotal=subtotal,
            discount_amount=payload.discount_amount,
            total_amount=total_amount,
            paid_amount=Decimal("0"),
            payment_status="unpaid",
            status="active",
            created_by=current_user.id,
        )
        sale.items = sale_items

        try:
            sale = await self.sales.create(sale)
            await self.db.flush()  # assigns sale.id

            invoice_number = await next_invoice_number(self.db, sale_date)
            invoice = Invoice(
                sale_id=sale.id,
                invoice_number=invoice_number,
                invoice_date=sale_date,
                status="generated",
            )
            self.db.add(invoice)
            await self.db.flush()
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        return await self._build_sale_response(sale, customer, invoice)

    async def _build_sale_response(self, sale: Sale, customer: Customer, invoice: Invoice | None) -> SaleResponse:
        product_ids = [item.product_id for item in sale.items]
        products_by_id: dict[uuid.UUID, Product] = {}
        if product_ids:
            result = await self.db.execute(select(Product).where(Product.id.in_(product_ids)))
            products_by_id = {p.id: p for p in result.scalars().all()}

        item_responses = [
            SaleItemResponse(
                id=item.id,
                product_id=item.product_id,
                product_name=products_by_id.get(item.product_id).name if item.product_id in products_by_id else "",
                quantity=money_str(item.quantity),
                unit_price=money_str(item.unit_price),
                line_discount=money_str(item.line_discount),
                line_total=money_str(item.line_total),
            )
            for item in sale.items
        ]

        return SaleResponse(
            id=sale.id,
            customer_id=sale.customer_id,
            customer_name=customer.name,
            salesman_id=sale.salesman_id,
            sale_date=sale.sale_date,
            subtotal=money_str(sale.subtotal),
            discount_amount=money_str(sale.discount_amount),
            total_amount=money_str(sale.total_amount),
            paid_amount=money_str(sale.paid_amount),
            outstanding_amount=money_str(sale.total_amount - sale.paid_amount),
            payment_status=sale.payment_status,
            status=sale.status,
            items=item_responses,
            invoice=InvoiceSummary(
                id=invoice.id, invoice_number=invoice.invoice_number, invoice_date=invoice.invoice_date, status=invoice.status
            )
            if invoice
            else None,
            created_at=sale.created_at,
        )

    async def get_sale(self, sale_id: uuid.UUID, current_user: CurrentUser) -> SaleResponse:
        sale = await self.sales.get_by_id(sale_id)
        if sale is None:
            raise NotFoundError("Sale not found")

        scoped_salesman_id = self._scope_salesman_id(current_user)
        if scoped_salesman_id is not None and sale.salesman_id != scoped_salesman_id:
            raise NotFoundError("Sale not found")

        customer_result = await self.db.execute(select(Customer).where(Customer.id == sale.customer_id))
        customer = customer_result.scalar_one()
        invoice = await self.sales.get_invoice(sale_id)

        return await self._build_sale_response(sale, customer, invoice)

    async def list_sales(
        self,
        current_user: CurrentUser,
        pagination: PaginationParams,
        customer_id: uuid.UUID | None,
        status: str | None,
        date_from: date | None,
        date_to: date | None,
    ):
        scoped_salesman_id = self._scope_salesman_id(current_user)
        items, total = await self.sales.list_sales(pagination, customer_id, scoped_salesman_id, status, date_from, date_to)

        customer_ids = {s.customer_id for s in items}
        customers_by_id: dict[uuid.UUID, Customer] = {}
        if customer_ids:
            result = await self.db.execute(select(Customer).where(Customer.id.in_(customer_ids)))
            customers_by_id = {c.id: c for c in result.scalars().all()}

        sale_ids = [s.id for s in items]
        invoices_by_sale: dict[uuid.UUID, Invoice] = {}
        if sale_ids:
            result = await self.db.execute(select(Invoice).where(Invoice.sale_id.in_(sale_ids)))
            invoices_by_sale = {inv.sale_id: inv for inv in result.scalars().all()}

        responses = [
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
            for s in items
        ]
        return responses, total

    async def cancel_sale(self, sale_id: uuid.UUID, current_user: CurrentUser) -> SaleResponse:
        sale = await self.sales.get_by_id(sale_id)
        if sale is None:
            raise NotFoundError("Sale not found")
        if sale.status == "cancelled":
            raise BusinessRuleError("This sale is already cancelled.")

        # Simplifying assumption (documented): cancelling a sale does not
        # automatically reverse or refund any payments already recorded
        # against it — that requires a separate, explicit payment/refund
        # action by staff, matching the same principle used for returns.
        sale.status = "cancelled"
        await self.sales.save(sale)
        await self.db.commit()

        customer_result = await self.db.execute(select(Customer).where(Customer.id == sale.customer_id))
        customer = customer_result.scalar_one()
        invoice = await self.sales.get_invoice(sale_id)
        return await self._build_sale_response(sale, customer, invoice)
