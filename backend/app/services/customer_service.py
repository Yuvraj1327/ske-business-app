import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.payment import Payment
from app.models.sale import Sale
from app.models.sales_return import SalesReturn
from app.repositories.customer_repo import CustomerRepository
from app.schemas.common import money_str
from app.schemas.customer import (
    CustomerCreateRequest,
    CustomerLedgerResponse,
    CustomerListResponse,
    CustomerOutstandingResponse,
    CustomerResponse,
    CustomerUpdateRequest,
    LedgerEntry,
)
from app.utils.pagination import PaginationParams


class CustomerService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.customers = CustomerRepository(db)

    def _scope_salesman_id(self, current_user: CurrentUser) -> uuid.UUID | None:
        """
        Row-level scoping: a user with only `customers.view_assigned` (not
        `customers.view_all`) may only see customers assigned to them. Admins
        and anyone with `customers.view_all` see everyone. This is enforced
        here in the service layer, not just hidden in the UI.
        """
        if current_user.is_admin or current_user.has_permission("customers.view_all"):
            return None  # no restriction
        if current_user.has_permission("customers.view_assigned"):
            return current_user.id
        raise PermissionDeniedError("You do not have permission to view customers.")

    async def list_customers(
        self,
        current_user: CurrentUser,
        pagination: PaginationParams,
        search: str | None,
        is_active: bool | None,
    ):
        scoped_salesman_id = self._scope_salesman_id(current_user)
        items, total = await self.customers.list_customers(pagination, search, scoped_salesman_id, is_active)
        return [CustomerResponse.from_model(c) for c in items], total

    async def get_customer(self, customer_id: uuid.UUID, current_user: CurrentUser) -> CustomerResponse:
        customer = await self._get_scoped(customer_id, current_user)
        return CustomerResponse.from_model(customer)

    async def lookup_by_external_code(self, external_code: str, current_user: CurrentUser) -> CustomerResponse:
        """Settlement Sheet's "Customer Code search + autofill". Raises
        NotFoundError (404) when no customer has this code, which the
        Flutter side treats as the trigger to offer "create a new
        customer" — same lookup-or-create shape as
        picklist_service.find_or_create_customer, just surfaced as an API
        the Admin drives interactively instead of an unattended import."""
        # Uses the same visibility scoping as get_customer — a Salesman-only
        # user (no settlements involvement) still can't fish for customers
        # outside their assignment via this endpoint.
        self._scope_salesman_id(current_user)
        customer = await self.customers.get_by_external_code(external_code)
        if customer is None:
            raise NotFoundError(f"No customer found with code '{external_code}'.")
        return CustomerResponse.from_model(customer)

    async def _get_scoped(self, customer_id: uuid.UUID, current_user: CurrentUser) -> Customer:
        customer = await self.customers.get_by_id(customer_id)
        if customer is None:
            raise NotFoundError("Customer not found")
        scoped_salesman_id = self._scope_salesman_id(current_user)
        if scoped_salesman_id is not None and customer.assigned_salesman_id != scoped_salesman_id:
            raise NotFoundError("Customer not found")
        return customer

    async def _ensure_external_code_available(
        self, external_code: str | None, exclude_customer_id: uuid.UUID | None = None
    ) -> None:
        if not external_code:
            return
        existing = await self.customers.get_by_external_code(external_code)
        if existing is not None and existing.id != exclude_customer_id:
            raise ConflictError(f"Customer code '{external_code}' is already used by another customer.")

    async def create_customer(self, payload: CustomerCreateRequest, current_user: CurrentUser) -> CustomerResponse:
        await self._ensure_external_code_available(payload.external_code)

        customer = Customer(
            name=payload.name,
            phone=payload.phone,
            email=payload.email,
            address=payload.address,
            gst_number=payload.gst_number,
            external_code=payload.external_code,
            assigned_salesman_id=payload.assigned_salesman_id,
            created_by=current_user.id,
            is_active=True,
        )
        customer = await self.customers.create(customer)
        await self.db.commit()
        return CustomerResponse.from_model(customer)

    async def update_customer(
        self, customer_id: uuid.UUID, payload: CustomerUpdateRequest, current_user: CurrentUser
    ) -> CustomerResponse:
        customer = await self._get_scoped(customer_id, current_user)

        if payload.name is not None:
            customer.name = payload.name.strip()
        if payload.phone is not None:
            customer.phone = payload.phone
        if payload.email is not None:
            customer.email = payload.email
        if payload.address is not None:
            customer.address = payload.address
        if payload.gst_number is not None:
            customer.gst_number = payload.gst_number
        if payload.external_code is not None:
            await self._ensure_external_code_available(payload.external_code, exclude_customer_id=customer.id)
            customer.external_code = payload.external_code
        if payload.assigned_salesman_id is not None:
            customer.assigned_salesman_id = payload.assigned_salesman_id
        if payload.is_active is not None:
            customer.is_active = payload.is_active

        customer = await self.customers.save(customer)
        await self.db.commit()
        return CustomerResponse.from_model(customer)

    async def get_outstanding(self, customer_id: uuid.UUID, current_user: CurrentUser) -> CustomerOutstandingResponse:
        await self._get_scoped(customer_id, current_user)

        sales_result = await self.db.execute(
            select(Sale.total_amount, Sale.paid_amount).where(Sale.customer_id == customer_id, Sale.status == "active")
        )
        rows = sales_result.all()
        total_sales = sum((r[0] for r in rows), Decimal("0"))
        total_paid_via_sales = sum((r[1] for r in rows), Decimal("0"))

        returns_result = await self.db.execute(
            select(SalesReturn.total_return_amount).where(
                SalesReturn.customer_id == customer_id, SalesReturn.status == "completed"
            )
        )
        total_returned = sum((r[0] for r in returns_result.all()), Decimal("0"))

        # Unallocated (on-account) cleared payments not tied to any sale —
        # see business rule #3 in the architecture doc: these reduce the
        # customer's aggregate outstanding but not any specific invoice.
        unallocated_result = await self.db.execute(
            select(Payment.amount).where(
                Payment.customer_id == customer_id, Payment.sale_id.is_(None), Payment.status == "cleared"
            )
        )
        total_unallocated_payments = sum((r[0] for r in unallocated_result.all()), Decimal("0"))

        outstanding = total_sales - total_paid_via_sales - total_returned - total_unallocated_payments
        if outstanding < 0:
            outstanding = Decimal("0")

        return CustomerOutstandingResponse(
            customer_id=customer_id,
            total_sales=money_str(total_sales),
            total_paid=money_str(total_paid_via_sales + total_unallocated_payments),
            total_returned=money_str(total_returned),
            outstanding=money_str(outstanding),
        )

    async def get_ledger(self, customer_id: uuid.UUID, current_user: CurrentUser) -> CustomerLedgerResponse:
        await self._get_scoped(customer_id, current_user)

        entries: list[LedgerEntry] = []

        sales_result = await self.db.execute(
            select(Sale).where(Sale.customer_id == customer_id, Sale.status == "active").order_by(Sale.sale_date)
        )
        for sale in sales_result.scalars().all():
            entries.append(
                LedgerEntry(
                    entry_date=sale.created_at,
                    entry_type="sale",
                    reference_id=sale.id,
                    reference_label=f"Sale on {sale.sale_date.isoformat()}",
                    debit=money_str(sale.total_amount),
                    credit=money_str(Decimal("0")),
                )
            )

        payments_result = await self.db.execute(
            select(Payment)
            .where(Payment.customer_id == customer_id, Payment.status == "cleared")
            .order_by(Payment.payment_date)
        )
        for payment in payments_result.scalars().all():
            entries.append(
                LedgerEntry(
                    entry_date=payment.created_at,
                    entry_type="payment",
                    reference_id=payment.id,
                    reference_label=f"{payment.payment_method.replace('_', ' ').title()} payment",
                    debit=money_str(Decimal("0")),
                    credit=money_str(payment.amount),
                )
            )

        returns_result = await self.db.execute(
            select(SalesReturn)
            .where(SalesReturn.customer_id == customer_id, SalesReturn.status == "completed")
            .order_by(SalesReturn.return_date)
        )
        for ret in returns_result.scalars().all():
            entries.append(
                LedgerEntry(
                    entry_date=ret.created_at,
                    entry_type="return",
                    reference_id=ret.id,
                    reference_label=f"Return on {ret.return_date.isoformat()}",
                    debit=money_str(Decimal("0")),
                    credit=money_str(ret.total_return_amount),
                )
            )

        entries.sort(key=lambda e: e.entry_date)

        outstanding_response = await self.get_outstanding(customer_id, current_user)

        return CustomerLedgerResponse(
            customer_id=customer_id, entries=entries, outstanding=outstanding_response.outstanding
        )
