import uuid
from datetime import date

from pydantic import BaseModel

from app.schemas.expense import ExpenseResponse
from app.schemas.payment import PaymentResponse
from app.schemas.sale import SaleListItemResponse


class SalesReportResponse(BaseModel):
    range_start: date
    range_end: date
    total_sales_count: int
    total_sales_amount: str
    total_discount: str
    items: list[SaleListItemResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class CustomerReportRow(BaseModel):
    customer_id: uuid.UUID
    customer_name: str
    sales_count: int
    sales_total: str
    outstanding: str


class CustomerReportResponse(BaseModel):
    items: list[CustomerReportRow]
    total: int
    page: int
    page_size: int
    total_pages: int


class PaymentMethodBreakdown(BaseModel):
    payment_method: str
    count: int
    total: str


class PaymentReportResponse(BaseModel):
    range_start: date
    range_end: date
    breakdown_by_method: list[PaymentMethodBreakdown]
    items: list[PaymentResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class OutstandingReportRow(BaseModel):
    customer_id: uuid.UUID
    customer_name: str
    phone: str | None
    outstanding: str


class OutstandingReportResponse(BaseModel):
    items: list[OutstandingReportRow]
    total: int
    page: int
    page_size: int
    total_pages: int
    grand_total_outstanding: str


class ExpenseCategoryBreakdown(BaseModel):
    category_name: str
    count: int
    total: str


class ExpenseReportResponse(BaseModel):
    range_start: date
    range_end: date
    breakdown_by_category: list[ExpenseCategoryBreakdown]
    items: list[ExpenseResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class SalesmanReportRow(BaseModel):
    salesman_id: uuid.UUID
    salesman_name: str
    customers_count: int
    sales_count: int
    sales_total: str
    outstanding_total: str


class SalesmanReportResponse(BaseModel):
    range_start: date
    range_end: date
    items: list[SalesmanReportRow]


class TransactionReportBreakdown(BaseModel):
    transaction_type: str
    direction: str
    count: int
    total: str


class TransactionReportResponse(BaseModel):
    range_start: date
    range_end: date
    breakdown: list[TransactionReportBreakdown]
    total_in: str
    total_out: str
    net: str
