from fastapi import APIRouter
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Depends

from app.db.session import get_db

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check() -> dict:
    """Basic liveness check — does not touch the database."""
    return {"status": "ok"}


@router.get("/health/db")
async def health_check_db(db: AsyncSession = Depends(get_db)) -> dict:
    """Readiness check — confirms the API can reach Postgres."""
    await db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}
