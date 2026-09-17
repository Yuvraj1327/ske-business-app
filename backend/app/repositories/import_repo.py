import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.import_job import ImportJob, ImportJobRow
from app.utils.pagination import PaginationParams, paginate


class ImportRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_job(self, job_id: uuid.UUID) -> ImportJob | None:
        result = await self.db.execute(select(ImportJob).where(ImportJob.id == job_id))
        return result.scalar_one_or_none()

    async def create_job(self, job: ImportJob) -> ImportJob:
        self.db.add(job)
        await self.db.flush()
        await self.db.refresh(job)
        return job

    async def save_job(self, job: ImportJob) -> ImportJob:
        await self.db.flush()
        await self.db.refresh(job)
        return job

    async def list_jobs(self, pagination: PaginationParams):
        stmt = select(ImportJob).order_by(ImportJob.created_at.desc())
        return await paginate(self.db, stmt, pagination)

    async def add_rows(self, rows: list[ImportJobRow]) -> None:
        self.db.add_all(rows)
        await self.db.flush()

    async def list_job_rows(self, job_id: uuid.UUID, pagination: PaginationParams, status: str | None):
        stmt = select(ImportJobRow).where(ImportJobRow.import_job_id == job_id)
        if status:
            stmt = stmt.where(ImportJobRow.status == status)
        stmt = stmt.order_by(ImportJobRow.row_number)
        return await paginate(self.db, stmt, pagination)

    async def delete_job(self, job: ImportJob) -> None:
        """Deletes the job and (via ON DELETE CASCADE) its rows. Does NOT
        touch any business data created from this import (customers,
        sales, picklists, etc.) — see ImportService.delete_job for how a
        linked Picklist is detached first, since Picklist.import_job_id has
        no cascade of its own by design."""
        await self.db.delete(job)
        await self.db.flush()
