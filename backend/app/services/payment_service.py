import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.payment import ChequeDetail, Payment
from app.models.sale import Sale
from app.models.transaction import Transaction
from app.repositories.payment_repo import PaymentRepository
from app.schemas.common import money_str
from app.schemas.payment import ChequeDetailResponse, PaymentCreateRequest, PaymentResponse
from app.services.sale_service import recompute_sale_paid_amount
from app.utils.pagination import PaginationParams

# Cash/UPI/bank-transfer payments post straight to the unified transactions
# ledger (they've already "cleared" by definition — money moved when
# recorded). Cheques only post to the ledger once cleared (see
# update_cheque_status), which is why "cheque" has no entry here.
_METHOD_TO_TRANSACTION_TYPE = {"cash": "cash", "upi": "upi", "bank_transfer": "bank"}


class PaymentService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.payments = PaymentRepository(db)

    async def create_payment(self, payload: PaymentCreateRequest, current_user: CurrentUser) -> PaymentResponse:
        customer_result = await self.db.execute(select(Customer).where(Customer.id == payload.customer_id))
        customer = customer_result.scalar_one_or_none()
        if customer is None:
            raise ValidationError("Customer does not exist.", field="customer_id")

        sale: Sale | None = None
        if payload.sale_id is not None:
            sale_result = await self.db.execute(select(Sale).where(Sale.id == payload.sale_id))
            sale = sale_result.scalar_one_or_none()
            if sale is None:
                raise ValidationError("Sale does not exist.", field="sale_id")
            if sale.customer_id != customer.id:
                raise ValidationError("Sale does not belong to this customer.", field="sale_id")
            if sale.status != "active":
                raise BusinessRuleError("Cannot record a payment against a cancelled sale.")

        payment_date = payload.payment_date or date.today()
        # Cheques start pending until manually cleared/bounced; every other
        # method is treated as settled the moment it's recorded (see business
        # rule #5 in the architecture doc).
        initial_status = "pending" if payload.payment_method == "cheque" else "cleared"

        payment = Payment(
            customer_id=customer.id,
            sale_id=sale.id if sale else None,
            amount=payload.amount,
            payment_method=payload.payment_method,
            payment_date=payment_date,
            status=initial_status,
            received_by=current_user.id,
            notes=payload.notes,
        )

        try:
            payment = await self.payments.create(payment)
            await self.db.flush()  # assigns payment.id

            if payload.payment_method == "cheque":
                cheque = ChequeDetail(
                    payment_id=payment.id,
                    cheque_number=payload.cheque_number,
                    cheque_date=payload.cheque_date,
                    bank_name=payload.bank_name,
                )
                self.db.add(cheque)
                await self.db.flush()
            else:
                transaction = Transaction(
                    transaction_type=_METHOD_TO_TRANSACTION_TYPE[payload.payment_method],
                    direction="in",
                    amount=payment.amount,
                    transaction_date=payment_date,
                    related_payment_id=payment.id,
                    created_by=current_user.id,
                )
                self.db.add(transaction)
                await self.db.flush()

            if sale is not None and payment.status == "cleared":
                await recompute_sale_paid_amount(self.db, sale.id)

            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        return await self._build_response(payment, customer)

    async def update_cheque_status(self, payment_id: uuid.UUID, new_status: str, current_user: CurrentUser) -> PaymentResponse:
        if new_status not in {"cleared", "cancelled"}:
            raise ValidationError("status must be 'cleared' or 'cancelled'.", field="status")

        payment = await self.payments.get_by_id(payment_id)
        if payment is None:
            raise NotFoundError("Payment not found")
        if payment.payment_method != "cheque":
            raise BusinessRuleError("Only cheque payments have a clearable status.")
        if payment.status != "pending":
            raise BusinessRuleError(f"This cheque is already {payment.status} and cannot be changed.")

        cheque_result = await self.db.execute(select(ChequeDetail).where(ChequeDetail.payment_id == payment_id))
        cheque = cheque_result.scalar_one()

        try:
            payment.status = new_status

            if new_status == "cleared":
                cheque.cleared_date = date.today()
                transaction = Transaction(
                    transaction_type="bank",
                    direction="in",
                    amount=payment.amount,
                    transaction_date=cheque.cleared_date,
                    related_payment_id=payment.id,
                    reference_note=f"Cheque #{cheque.cheque_number} cleared",
                    created_by=current_user.id,
                )
                self.db.add(transaction)
                await self.db.flush()

                if payment.sale_id is not None:
                    await recompute_sale_paid_amount(self.db, payment.sale_id)
            # If bounced/cancelled: no financial effect at all — the payment
            # never counted toward paid_amount while pending, so there's
            # nothing to reverse (business rule #5).

            await self.db.flush()
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        customer_result = await self.db.execute(select(Customer).where(Customer.id == payment.customer_id))
        customer = customer_result.scalar_one()
        return await self._build_response(payment, customer)

    async def list_payments(
        self,
        pagination: PaginationParams,
        customer_id: uuid.UUID | None,
        sale_id: uuid.UUID | None,
        payment_method: str | None,
        status: str | None,
    ):
        items, total = await self.payments.list_payments(pagination, customer_id, sale_id, payment_method, status)

        customer_ids = {p.customer_id for p in items}
        customers_by_id: dict[uuid.UUID, Customer] = {}
        if customer_ids:
            result = await self.db.execute(select(Customer).where(Customer.id.in_(customer_ids)))
            customers_by_id = {c.id: c for c in result.scalars().all()}

        responses = [await self._build_response(p, customers_by_id.get(p.customer_id)) for p in items]
        return responses, total

    async def _build_response(self, payment: Payment, customer: Customer | None) -> PaymentResponse:
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
