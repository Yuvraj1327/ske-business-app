import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, Query, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_permission
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.import_job import ImportJobListResponse, ImportJobResponse, ImportJobRowListResponse
from app.services.import_service import ImportService, process_import_job
from app.utils.pagination import PaginationParams, pagination_params

router = APIRouter(prefix="/imports", tags=["imports"])


@router.post("/upload", response_model=ImportJobResponse, status_code=202)
async def upload_import_file(
    background_tasks: BackgroundTasks,
    entity_type: str = Form(...),
    file: UploadFile = File(...),
    delivery_agent_id: uuid.UUID | None = Form(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("imports.manage")),
) -> ImportJobResponse:
    """
    Returns immediately (202) with a job in 'queued' status — actual parsing
    happens in a background task after the response is sent, so a large
    file never blocks this request. Poll GET /imports/{job_id} for progress.

    `delivery_agent_id` is required (validated in the service layer) when
    entity_type='picklists' — the Delivery Agent this picklist's deliveries
    get assigned to. Ignored for other entity types.
    """
    file_bytes = await file.read()
    service = ImportService(db)
    job = await service.start_import(
        entity_type, file.filename or "upload.xlsx", file_bytes, current_user.id, delivery_agent_id
    )

    background_tasks.add_task(process_import_job, job.id, file_bytes, delivery_agent_id)

    return job


@router.get("", response_model=ImportJobListResponse)
async def list_import_jobs(
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("imports.manage")),
) -> ImportJobListResponse:
    service = ImportService(db)
    items, total = await service.list_jobs(pagination)
    return ImportJobListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.get("/{job_id}", response_model=ImportJobResponse)
async def get_import_job(
    job_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("imports.manage")),
) -> ImportJobResponse:
    service = ImportService(db)
    return await service.get_job(job_id)


@router.get("/{job_id}/rows", response_model=ImportJobRowListResponse)
async def list_import_job_rows(
    job_id: uuid.UUID,
    status: str | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("imports.manage")),
) -> ImportJobRowListResponse:
    service = ImportService(db)
    items, total = await service.list_job_rows(job_id, pagination, status)
    return ImportJobRowListResponse(
        items=items,
        total=total,
        page=pagination.page,
        page_size=pagination.page_size,
        total_pages=max(1, -(-total // pagination.page_size)),
    )


@router.delete("/{job_id}", status_code=204)
async def delete_import_job(
    job_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: CurrentUser = Depends(require_permission("imports.manage")),
) -> None:
    """Deletes an import history entry only — never the business data it
    created (see ImportService.delete_job)."""
    service = ImportService(db)
    await service.delete_job(job_id)
