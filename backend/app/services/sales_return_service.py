import uuid
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, PermissionDeniedError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.invoice import Invoice
from app.models.picklist import Picklist, PicklistItem
from app.models.product import Product
from app.models.sale import Sale, SaleItem
from app.models.sales_return import SalesReturn, SalesReturnItem
from app.repositories.picklist_repo import PicklistRepository
from app.repositories.sales_return_repo import SalesReturnRepository
from app.repositories.settlement_repo import SettlementRepository
from app.schemas.common import money_str
from app.schemas.sales_return import SalesReturnCreateRequest, SalesReturnItemResponse, SalesReturnResponse
from app.services.sale_service import compute_payment_status
from app.utils.pagination import PaginationParams


class SalesReturnService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.returns = SalesReturnRepository(db)
        self.picklists = PicklistRepository(db)

    async def _check_sale_access(self, sale_id: uuid.UUID, current_user: CurrentUser) -> None:
        """A Delivery Agent may only return against sales on their own
        picklists; other roles keep their existing unrestricted access."""
        if current_user.is_picklist_agent and not await self.picklists.agent_has_sale(current_user.id, sale_id):
            raise PermissionDeniedError("You can only manage returns for sales on your own picklists.")

    async def create_return(self, payload: SalesReturnCreateRequest, current_user: CurrentUser) -> SalesReturnResponse:
        # Row-locked so two simultaneous returns on one sale validate and
        # deduct one after the other (no over-return, no lost total update).
        sale_result = await self.db.execute(select(Sale).where(Sale.id == payload.sale_id).with_for_update())
        sale = sale_result.scalar_one_or_none()
        if sale is None:
            raise ValidationError("Sale does not exist.", field="sale_id")
        await self._check_sale_access(sale.id, current_user)
        if sale.status != "active":
            raise BusinessRuleError("Cannot create a return against a cancelled sale.")

        return_items: list[SalesReturnItem] = []
        total_return_amount = Decimal("0")

        for item in payload.items:
            sale_item_result = await self.db.execute(
                select(SaleItem).where(SaleItem.id == item.sale_item_id, SaleItem.sale_id == sale.id)
            )
            sale_item = sale_item_result.scalar_one_or_none()
            if sale_item is None:
                raise ValidationError(f"Sale item {item.sale_item_id} does not belong to this sale.", field="items")

            already_returned = await self.returns.already_returned_quantity(sale_item.id)
            already_returned = Decimal(str(already_returned))
            returnable = sale_item.quantity - already_returned

            if item.quantity > returnable:
                raise BusinessRuleError(
                    f"Cannot return {item.quantity} units — only {returnable} of "
                    f"{sale_item.quantity} sold units remain returnable for this line."
                )

            # The line's effective charge: its net line total, scaled by the
            # sale-level discount (total = subtotal - discount) so a full
            # return refunds exactly what the customer was charged, never
            # more. Picklist sales have no header discount (ratio 1).
            effective_line_total = sale_item.line_total
            if sale.discount_amount and sale.subtotal:
                effective_line_total = (sale_item.line_total * (sale.subtotal - sale.discount_amount) / sale.subtotal).quantize(
                    Decimal("0.01"), rounding=ROUND_HALF_UP
                )
            if item.quantity == returnable:
                # Last units of the line: refund whatever is left of the line
                # so partial returns that were rounded individually still sum
                # to exactly the line total (no cent drift).
                already_amount = Decimal(str(await self.returns.already_returned_amount(sale_item.id)))
                item_amount = max(effective_line_total - already_amount, Decimal("0"))
            else:
                per_unit_rate = effective_line_total / sale_item.quantity if sale_item.quantity else Decimal("0")
                item_amount = (item.quantity * per_unit_rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

            total_return_amount += item_amount
            return_items.append(SalesReturnItem(sale_item_id=sale_item.id, quantity=item.quantity, amount=item_amount))

        sales_return = SalesReturn(
            sale_id=sale.id,
            customer_id=sale.customer_id,
            return_date=date.today(),
            total_return_amount=total_return_amount,
            reason=payload.reason,
            status="completed",
            created_by=current_user.id,
        )
        sales_return.items = return_items

        try:
            sales_return = await self.returns.create(sales_return)
            await self.db.flush()

            # Business rule #6: a return reduces the sale's effective total
            # and therefore its outstanding balance, but never touches
            # already-received payments — any actual cash refund is a
            # separate, explicit action staff record manually (documented
            # assumption, see architecture doc).
            sale.total_amount = max(sale.total_amount - total_return_amount, Decimal("0"))
            sale.payment_status = compute_payment_status(sale.paid_amount, sale.total_amount)
            await self.db.flush()

            await self._reduce_pending_picklist_amount(sale.id, total_return_amount)
            await self._sync_settlement_returns(sale.id)

            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        return await self._build_response(sales_return, sale)

    async def _reduce_pending_picklist_amount(self, sale_id: uuid.UUID, returned: Decimal) -> None:
        """A return lowers the amount still to be collected on the sale's
        picklist row so the agent can't record the full original invoice as
        cash. Only rows still 'pending' are touched — once a delivery is
        marked cash/online/credit/cheque its amount was already collected or
        recorded. Never below zero. The picklist's imported total_amount (the
        Pick Sheet Value) is deliberately NOT changed: returns are deducted
        separately on the settlement sheet, so changing both would deduct
        twice."""
        if returned <= 0:
            return
        result = await self.db.execute(
            select(PicklistItem).where(PicklistItem.sale_id == sale_id, PicklistItem.status == "pending")
        )
        for item in result.scalars().all():
            item.amount_payable = max(item.amount_payable - returned, Decimal("0"))
        await self.db.flush()

    async def _sync_settlement_returns(self, sale_id: uuid.UUID) -> None:
        """Sets Returns Goods / Damage Return on every open Settlement Sheet
        linked (by Pick Sheet No.) to a picklist containing this sale. The
        values are recomputed from the persisted returns and assigned, never
        added, so repeating this can't deduct twice. Completed sheets are
        never touched."""
        result = await self.db.execute(
            select(Picklist.picklist_no)
            .join(PicklistItem, PicklistItem.picklist_id == Picklist.id)
            .where(PicklistItem.sale_id == sale_id)
            .distinct()
        )
        for picklist_no in result.scalars().all():
            await self.picklists.lock_by_picklist_no(picklist_no)
            returns_total, damage_total = await self.picklists.return_totals_by_picklist_no(picklist_no)
            for sheet in await SettlementRepository(self.db).list_open_by_pick_sheet_no(picklist_no):
                sheet.returns_amount = returns_total
                sheet.damage_return_amount = damage_total
        await self.db.flush()

    async def _build_response(
        self, sales_return: SalesReturn, sale: Sale, customer: Customer | None = None
    ) -> SalesReturnResponse:
        if customer is None:
            customer_result = await self.db.execute(select(Customer).where(Customer.id == sale.customer_id))
            customer = customer_result.scalar_one()

        sale_item_ids = [i.sale_item_id for i in sales_return.items]
        product_names: dict[uuid.UUID, str] = {}
        if sale_item_ids:
            si_result = await self.db.execute(select(SaleItem).where(SaleItem.id.in_(sale_item_ids)))
            sale_items = {si.id: si for si in si_result.scalars().all()}
            product_ids = [si.product_id for si in sale_items.values()]
            if product_ids:
                p_result = await self.db.execute(select(Product).where(Product.id.in_(product_ids)))
                products = {p.id: p.name for p in p_result.scalars().all()}
                product_names = {
                    si_id: products.get(si.product_id, "") for si_id, si in sale_items.items()
                }

        item_responses = [
            SalesReturnItemResponse(
                id=item.id,
                sale_item_id=item.sale_item_id,
                product_name=product_names.get(item.sale_item_id, ""),
                quantity=money_str(item.quantity),
                amount=money_str(item.amount),
            )
            for item in sales_return.items
        ]

        return SalesReturnResponse(
            id=sales_return.id,
            sale_id=sales_return.sale_id,
            customer_id=sales_return.customer_id,
            customer_name=customer.name,
            return_date=sales_return.return_date,
            total_return_amount=money_str(sales_return.total_return_amount),
            reason=sales_return.reason,
            status=sales_return.status,
            items=item_responses,
            created_at=sales_return.created_at,
        )

    async def get_return(self, return_id: uuid.UUID, current_user: CurrentUser) -> SalesReturnResponse:
        sales_return = await self.returns.get_by_id(return_id)
        if sales_return is None:
            raise NotFoundError("Return not found")
        await self._check_sale_access(sales_return.sale_id, current_user)
        sale_result = await self.db.execute(select(Sale).where(Sale.id == sales_return.sale_id))
        sale = sale_result.scalar_one()
        return await self._build_response(sales_return, sale)

    async def list_returns(
        self,
        pagination: PaginationParams,
        customer_id: uuid.UUID | None,
        sale_id: uuid.UUID | None,
        current_user: CurrentUser,
    ):
        agent_sale_ids = self.picklists.agent_sale_ids(current_user.id) if current_user.is_picklist_agent else None
        items, total = await self.returns.list_returns(pagination, customer_id, sale_id, agent_sale_ids)
        sales_by_id: dict[uuid.UUID, Sale] = {}
        customers_by_id: dict[uuid.UUID, Customer] = {}
        if items:
            sales_result = await self.db.execute(select(Sale).where(Sale.id.in_({r.sale_id for r in items})))
            sales_by_id = {s.id: s for s in sales_result.scalars().all()}
            customers_result = await self.db.execute(
                select(Customer).where(Customer.id.in_({s.customer_id for s in sales_by_id.values()}))
            )
            customers_by_id = {c.id: c for c in customers_result.scalars().all()}

        responses = []
        for sales_return in items:
            sale = sales_by_id.get(sales_return.sale_id)
            if sale is None:
                sale_result = await self.db.execute(select(Sale).where(Sale.id == sales_return.sale_id))
                sale = sale_result.scalar_one()
            responses.append(await self._build_response(sales_return, sale, customers_by_id.get(sale.customer_id)))
        return responses, total

    async def export_rows(
        self, customer_id: uuid.UUID | None, sale_id: uuid.UUID | None, current_user: CurrentUser
    ) -> list[tuple[str, str, Decimal]]:
        """(customer name, invoice number, total return amount) for EVERY
        return matching the same filters/visibility as `list_returns`, across
        all pages, in the same order. Reads persisted rows only — nothing is
        recalculated."""
        agent_sale_ids = self.picklists.agent_sale_ids(current_user.id) if current_user.is_picklist_agent else None
        returns: list[SalesReturn] = []
        page = 1
        while True:
            items, total = await self.returns.list_returns(
                PaginationParams(page=page, page_size=EXPORT_PAGE_SIZE), customer_id, sale_id, agent_sale_ids
            )
            returns.extend(items)
            if not items or len(returns) >= total:
                break
            page += 1
        if not returns:
            return []

        sale_ids = {r.sale_id for r in returns}
        lookup: dict[uuid.UUID, tuple[str, str]] = {}
        for chunk in _chunks(list(sale_ids), 500):
            result = await self.db.execute(
                select(Sale.id, Customer.name, Invoice.invoice_number)
                .join(Customer, Customer.id == Sale.customer_id)
                .outerjoin(Invoice, Invoice.sale_id == Sale.id)
                .where(Sale.id.in_(chunk))
            )
            for sid, customer_name, invoice_number in result.all():
                lookup[sid] = (customer_name, invoice_number or "")
        return [(*lookup.get(r.sale_id, ("", "")), r.total_return_amount) for r in returns]


EXPORT_PAGE_SIZE = 100  # same cap the list endpoint enforces


def _chunks(values: list, size: int):
    for i in range(0, len(values), size):
        yield values[i : i + size]
