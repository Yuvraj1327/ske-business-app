"""Generic pagination helpers shared across all list endpoints."""
import math
from dataclasses import dataclass
from typing import Generic, Sequence, TypeVar

from fastapi import Query
from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

T = TypeVar("T")


@dataclass
class PaginationParams:
    page: int = 1
    page_size: int = 20

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


def pagination_params(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> PaginationParams:
    return PaginationParams(page=page, page_size=page_size)


@dataclass
class Page(Generic[T]):
    items: Sequence[T]
    total: int
    page: int
    page_size: int

    @property
    def total_pages(self) -> int:
        return max(1, math.ceil(self.total / self.page_size)) if self.page_size else 1


async def paginate(db: AsyncSession, stmt: Select, pagination: PaginationParams) -> tuple[Sequence, int]:
    """Runs a COUNT query and a LIMIT/OFFSET query for the given base statement."""
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total = (await db.execute(count_stmt)).scalar_one()

    result = await db.execute(stmt.offset(pagination.offset).limit(pagination.page_size))
    items = result.scalars().all()

    return items, total
