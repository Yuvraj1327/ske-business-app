from datetime import date

from pydantic import BaseModel


class DashboardSummaryResponse(BaseModel):
    range_key: str
    range_start: date
    range_end: date

    total_customers: int

    sales_count: int
    sales_total: str          # money as string — see app/schemas/common.py
    payments_received: str
    outstanding_total: str    # point-in-time snapshot, not scoped to the date range
    expenses_total: str
