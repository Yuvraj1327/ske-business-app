import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import ENUM, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, new_uuid, utcnow

SettlementStatusEnum = ENUM(
    "draft", "in_progress", "completed", name="settlement_status_enum", create_type=False
)
SettlementDeliveryStatusEnum = ENUM(
    "pending", "delivered", "not_delivered", name="settlement_delivery_status_enum", create_type=False
)


class SettlementSheet(Base):
    __tablename__ = "settlement_sheets"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    sheet_no: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    sheet_date: Mapped[date] = mapped_column(Date, nullable=False)
    delivery_agent_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    salesman_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    status: Mapped[str] = mapped_column(SettlementStatusEnum, nullable=False, default="draft")
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # General / reconciliation fields — manually entered by Admin, independent
    # of whatever the Delivery Agent/Salesman later record per customer row.
    # See database/migrations/005_settlement_sheet_fields.sql and 006 (which
    # aligned these five on the "_amount" suffix already used by the other
    # three, to match the deployed schema).
    pick_sheet_no: Mapped[str | None] = mapped_column(String, nullable=True)
    pick_sheet_value: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    returns_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    damage_return_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    discount_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    cash_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    online_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    cheque_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    credit_bills_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    old_short_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)

    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    items: Mapped[list["SettlementSheetItem"]] = relationship(
        back_populates="sheet", cascade="all, delete-orphan", lazy="selectin"
    )


class SettlementSheetItem(Base):
    __tablename__ = "settlement_sheet_items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    settlement_sheet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("settlement_sheets.id", ondelete="CASCADE"), nullable=False
    )
    row_no: Mapped[int] = mapped_column(Integer, nullable=False)
    customer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=False)
    customer_code: Mapped[str | None] = mapped_column(String, nullable=True)
    customer_name: Mapped[str] = mapped_column(String, nullable=False)
    invoice_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)

    # Delivery half — Delivery Agent. Split across modes since one delivery
    # can be paid partly in cash, partly online, partly by cheque, with the
    # remainder left as credit/udhaar.
    delivery_status: Mapped[str] = mapped_column(SettlementDeliveryStatusEnum, nullable=False, default="pending")
    cash_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    online_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    cheque_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    agent_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Credit / Udhaar half — Salesman.
    credit_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    credit_collected: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    salesman_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    sheet: Mapped["SettlementSheet"] = relationship(back_populates="items")
