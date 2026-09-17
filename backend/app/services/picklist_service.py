"""
Delivery Picklist domain logic.

Two responsibilities live here, deliberately separate from
app/services/import_service.py (which only handles file parsing/job
orchestration):

  1. Turning one picklist Excel row into a real Customer + Sale + SaleItem +
     Invoice — called by import_service.py's background task while it's
     parsing the file. This is what makes "Credit / Udhaar" show up in the
     EXISTING Customer Outstanding/Ledger screens automatically: a credit
     picklist item is simply an unpaid Sale, computed by the exact same
     CustomerService.get_outstanding()/get_ledger() logic every other sale
     already goes through. No parallel "delivery ledger" was built.

  2. The Delivery Agent's "confirm this delivery" action (Cash / Online /
     Credit), which — for Cash/Online — creates a real Payment and reuses
     `recompute_sale_paid_amount` from sale_service.py, the exact same
     function every other payment in the app goes through.
"""
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, PermissionDeniedError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.invoice import Invoice
from app.models.payment import Payment
from app.models.picklist import Picklist, PicklistItem
from app.models.product import Product
from app.models.sale import Sale, SaleItem
from app.models.user import User
from app.repositories.picklist_repo import PicklistRepository
from app.schemas.common import money_str
from app.schemas.picklist import PicklistDetailResponse, PicklistItemResponse, PicklistResponse, PicklistSummaryCounts
from app.services.sale_service import recompute_sale_paid_amount
from app.utils.pagination import PaginationParams

_PICKLIST_PRODUCT_SKU = "PICKLIST-IMPORT"

# Delivery-agent-facing "Online" maps to our existing payment_method enum's
# 'upi' — the most common non-cash collection method for field delivery in
# this context. Documented assumption: the client's Excel format doesn't
# distinguish UPI vs. bank transfer, so a single mapping is used.
_STATUS_TO_PAYMENT_METHOD = {"cash": "cash", "online": "upi"}


async def find_or_create_customer(
    db: AsyncSession, customer_code: str | None, customer_name: str, created_by: uuid.UUID | None
) -> Customer:
    """Matches an existing customer by external_code; creates one if none
    exists. Never overwrites an existing customer's details — a picklist
    import only links to or creates, it doesn't edit."""
    if customer_code:
        result = await db.execute(select(Customer).where(Customer.external_code == customer_code))
        existing = result.scalar_one_or_none()
        if existing is not None:
            return existing

    customer = Customer(
        name=customer_name,
        external_code=customer_code,
        is_active=True,
        created_by=created_by,
    )
    db.add(customer)
    await db.flush()
    return customer


async def create_sale_for_picklist_row(
    db: AsyncSession,
    customer: Customer,
    invoice_number: str,
    amount: Decimal,
    sale_date: date,
    created_by: uuid.UUID | None,
) -> Sale:
    """Builds Sale + one synthetic SaleItem + Invoice for a single picklist
    row. Uses the picklist's OWN invoice number (not an auto-generated
    SKE/... one) since that's the authoritative reference for this
    workflow. Raises (propagated to the caller, which records it as a
    failed import row) if that invoice number was already imported."""
    existing_invoice = await db.execute(select(Invoice).where(Invoice.invoice_number == invoice_number))
    if existing_invoice.scalar_one_or_none() is not None:
        raise ValueError(f"Invoice '{invoice_number}' has already been imported.")

    product_result = await db.execute(select(Product).where(Product.sku == _PICKLIST_PRODUCT_SKU))
    product = product_result.scalar_one_or_none()
    if product is None:
        # Should already exist from the migration seed, but create
        # defensively so a picklist import never fails purely because of
        # missing setup.
        product = Product(name="Picklist Delivery", sku=_PICKLIST_PRODUCT_SKU, unit="invoice", default_price=0, is_active=True)
        db.add(product)
        await db.flush()

    sale = Sale(
        customer_id=customer.id,
        salesman_id=None,  # the Excel's "sales man"/route column is metadata, not a matched system user
        sale_date=sale_date,
        subtotal=amount,
        discount_amount=Decimal("0"),
        total_amount=amount,
        paid_amount=Decimal("0"),
        payment_status="unpaid",
        status="active",
        created_by=created_by,
    )
    sale.items = [
        SaleItem(product_id=product.id, quantity=Decimal("1"), unit_price=amount, line_discount=Decimal("0"), line_total=amount)
    ]
    db.add(sale)
    await db.flush()

    invoice = Invoice(sale_id=sale.id, invoice_number=invoice_number, invoice_date=sale_date, status="generated")
    db.add(invoice)
    await db.flush()

    return sale


class PicklistService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.picklists = PicklistRepository(db)

    def _can_view_all(self, current_user: CurrentUser) -> bool:
        return current_user.is_admin or current_user.has_permission("picklists.manage")

    async def list_picklists(self, current_user: CurrentUser, pagination: PaginationParams):
        if not self._can_view_all(current_user) and not current_user.has_permission("picklists.view_assigned"):
            raise PermissionDeniedError("You do not have permission to view picklists.")

        scoped_agent_id = None if self._can_view_all(current_user) else current_user.id
        items, total = await self.picklists.list_picklists(pagination, scoped_agent_id)
        responses = [await self._build_response(p) for p in items]
        return responses, total

    async def get_picklist(self, picklist_id: uuid.UUID, current_user: CurrentUser) -> PicklistDetailResponse:
        picklist = await self.picklists.get_by_id(picklist_id)
        if picklist is None:
            raise NotFoundError("Picklist not found")
        self._check_access(picklist, current_user)

        base = await self._build_response(picklist)
        item_responses = [PicklistItemResponse.from_model(i) for i in sorted(picklist.items, key=lambda i: i.row_no)]
        return PicklistDetailResponse(**base.model_dump(), items=item_responses)

    def _check_access(self, picklist: Picklist, current_user: CurrentUser) -> None:
        if self._can_view_all(current_user):
            return
        if current_user.has_permission("picklists.view_assigned") and picklist.delivery_agent_id == current_user.id:
            return
        raise PermissionDeniedError("You do not have access to this picklist.")

    async def _build_response(self, picklist: Picklist) -> PicklistResponse:
        agent_result = await self.db.execute(select(User).where(User.id == picklist.delivery_agent_id))
        agent = agent_result.scalar_one_or_none()

        counts = {"pending": 0, "cash": 0, "online": 0, "credit": 0}
        for item in picklist.items:
            counts[item.status] = counts.get(item.status, 0) + 1

        return PicklistResponse(
            id=picklist.id,
            picklist_no=picklist.picklist_no,
            delivery_agent_id=picklist.delivery_agent_id,
            delivery_agent_name=agent.full_name if agent else "",
            psr_route=picklist.psr_route,
            total_amount=money_str(picklist.total_amount),
            created_at=picklist.created_at,
            counts=PicklistSummaryCounts(total=len(picklist.items), **counts),
        )

    async def confirm_item(self, item_id: uuid.UUID, status: str, current_user: CurrentUser) -> PicklistItemResponse:
        item = await self.picklists.get_item(item_id)
        if item is None:
            raise NotFoundError("Picklist item not found")

        self._check_access(item.picklist, current_user)

        if item.status != "pending":
            raise BusinessRuleError(f"This delivery was already marked as '{item.status}' and cannot be changed.")

        if item.sale_id is None or item.customer_id is None:
            raise ValidationError("This picklist item has no linked sale to record a payment against.")

        try:
            if status in _STATUS_TO_PAYMENT_METHOD:
                payment = Payment(
                    customer_id=item.customer_id,
                    sale_id=item.sale_id,
                    amount=item.amount_payable,
                    payment_method=_STATUS_TO_PAYMENT_METHOD[status],
                    payment_date=date.today(),
                    status="cleared",
                    received_by=current_user.id,
                    notes=f"Collected via picklist delivery ({item.invoice_number})",
                )
                self.db.add(payment)
                await self.db.flush()
                await recompute_sale_paid_amount(self.db, item.sale_id)
                item.payment_id = payment.id
            # status == "credit": no payment created — the sale stays
            # unpaid/outstanding, which is exactly "keep the amount as
            # outstanding" (business rule from the task brief), reusing the
            # existing outstanding calculation with no extra code.

            item.status = status
            item.collected_by = current_user.id
            item.collected_at = datetime.utcnow()
            await self.picklists.save_item(item)
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        await self.db.refresh(item)
        return PicklistItemResponse.from_model(item)
