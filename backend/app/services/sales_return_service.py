import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.product import Product
from app.models.sale import Sale, SaleItem
from app.models.sales_return import SalesReturn, SalesReturnItem
from app.repositories.sales_return_repo import SalesReturnRepository
from app.schemas.common import money_str
from app.schemas.sales_return import SalesReturnCreateRequest, SalesReturnItemResponse, SalesReturnResponse
from app.services.sale_service import compute_payment_status
from app.utils.pagination import PaginationParams


class SalesReturnService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.returns = SalesReturnRepository(db)

    async def create_return(self, payload: SalesReturnCreateRequest, current_user: CurrentUser) -> SalesReturnResponse:
        sale_result = await self.db.execute(select(Sale).where(Sale.id == payload.sale_id))
        sale = sale_result.scalar_one_or_none()
        if sale is None:
            raise ValidationError("Sale does not exist.", field="sale_id")
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

            # Per-unit rate derived from the line's actual net total (so a
            # line discount is reflected proportionally in the refund),
            # documented assumption: no separate/partial-discount rule.
            per_unit_rate = sale_item.line_total / sale_item.quantity if sale_item.quantity else Decimal("0")
            item_amount = (item.quantity * per_unit_rate).quantize(Decimal("0.01"))

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

            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        return await self._build_response(sales_return, sale)

    async def _build_response(self, sales_return: SalesReturn, sale: Sale) -> SalesReturnResponse:
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

    async def get_return(self, return_id: uuid.UUID) -> SalesReturnResponse:
        sales_return = await self.returns.get_by_id(return_id)
        if sales_return is None:
            raise NotFoundError("Return not found")
        sale_result = await self.db.execute(select(Sale).where(Sale.id == sales_return.sale_id))
        sale = sale_result.scalar_one()
        return await self._build_response(sales_return, sale)

    async def list_returns(self, pagination: PaginationParams, customer_id: uuid.UUID | None, sale_id: uuid.UUID | None):
        items, total = await self.returns.list_returns(pagination, customer_id, sale_id)
        responses = []
        for sales_return in items:
            sale_result = await self.db.execute(select(Sale).where(Sale.id == sales_return.sale_id))
            sale = sale_result.scalar_one()
            responses.append(await self._build_response(sales_return, sale))
        return responses, total
