import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import ENUM, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, new_uuid, utcnow

PaymentMethodEnum = ENUM(
    "cash", "upi", "bank_transfer", "cheque", name="payment_method_enum", create_type=False
)
PaymentStateEnum = ENUM("pending", "cleared", "cancelled", name="payment_state_enum", create_type=False)


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    customer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=False)
    sale_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("sales.id"), nullable=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    payment_method: Mapped[str] = mapped_column(PaymentMethodEnum, nullable=False)
    payment_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(PaymentStateEnum, nullable=False, default="cleared")
    received_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    notes: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    cheque_detail: Mapped["ChequeDetail | None"] = relationship(
        back_populates="payment", uselist=False, cascade="all, delete-orphan", lazy="selectin"
    )


class ChequeDetail(Base):
    __tablename__ = "cheque_details"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    payment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("payments.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    cheque_number: Mapped[str] = mapped_column(String, nullable=False)
    cheque_date: Mapped[date] = mapped_column(Date, nullable=False)
    bank_name: Mapped[str] = mapped_column(String, nullable=False)
    cleared_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    payment: Mapped["Payment"] = relationship(back_populates="cheque_detail")
