from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.dashboard_repo import DashboardRepository
from app.schemas.common import money_str
from app.schemas.dashboard import DashboardSummaryResponse
from app.utils.date_ranges import resolve_range


class DashboardService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = DashboardRepository(db)

    async def get_summary(
        self, range_key: str, custom_from: date | None, custom_to: date | None
    ) -> DashboardSummaryResponse:
        start, end = resolve_range(range_key, custom_from, custom_to)

        total_customers = await self.repo.count_customers()
        sales_count, sales_total = await self.repo.sales_summary(start, end)
        payments_received = await self.repo.payments_received(start, end)
        outstanding_total = await self.repo.outstanding_total()
        expenses_total = await self.repo.expenses_total(start, end)

        return DashboardSummaryResponse(
            range_key=range_key,
            range_start=start,
            range_end=end,
            total_customers=total_customers,
            sales_count=sales_count,
            sales_total=money_str(sales_total),
            payments_received=money_str(payments_received),
            outstanding_total=money_str(outstanding_total),
            expenses_total=money_str(expenses_total),
        )
