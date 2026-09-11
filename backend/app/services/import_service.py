"""
Excel import processing.

Design notes (documented simplifications for this MVP):

- Uploaded files are parsed directly from the request body and are NOT
  persisted to Supabase Storage — `file_url` is stored as a local
  placeholder ("uploaded:<filename>") rather than a real Storage URL. Wiring
  in real Storage persistence later only means replacing the placeholder
  with an actual `supabase.storage.upload(...)` call before parsing; nothing
  else in this module needs to change.
- Processing runs via FastAPI's BackgroundTasks rather than a dedicated
  queue (Celery/RQ + Redis). This still satisfies "don't block the API" for
  realistic small-business import sizes (hundreds to low thousands of rows).
  For very large files or multi-worker deployments, swap the BackgroundTask
  call for a real queue — the processing function itself doesn't change,
  only how it gets invoked.
- Only `customers` and `products` are supported entity types — importing
  sales/payments/financial records is explicitly out of scope (importing
  transactional financial data safely needs its own validation rules that
  weren't specified, so it's not invented here).
"""
import io
import uuid
from datetime import datetime

from openpyxl import load_workbook
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.db.session import AsyncSessionLocal
from app.models.customer import Customer
from app.models.import_job import ImportJob, ImportJobRow
from app.models.product import Product
from app.repositories.import_repo import ImportRepository
from app.schemas.import_job import ImportJobResponse
from app.utils.pagination import PaginationParams

SUPPORTED_ENTITY_TYPES = {"customers", "products"}

_COLUMN_SPECS = {
    "customers": {"required": ["name"], "optional": ["phone", "email", "address", "gst_number"]},
    "products": {"required": ["name", "default_price"], "optional": ["sku", "unit"]},
}


class ImportService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.imports = ImportRepository(db)

    async def start_import(
        self, entity_type: str, file_name: str, file_bytes: bytes, uploaded_by: uuid.UUID
    ) -> ImportJobResponse:
        if entity_type not in SUPPORTED_ENTITY_TYPES:
            raise ValidationError(f"entity_type must be one of {sorted(SUPPORTED_ENTITY_TYPES)}", field="entity_type")
        if not file_name.lower().endswith((".xlsx", ".xlsm")):
            raise ValidationError("Only .xlsx files are supported.", field="file")
        if not file_bytes:
            raise ValidationError("Uploaded file is empty.", field="file")

        job = ImportJob(
            file_name=file_name,
            file_url=f"uploaded:{file_name}",  # see module docstring
            entity_type=entity_type,
            status="queued",
            uploaded_by=uploaded_by,
        )
        job = await self.imports.create_job(job)
        await self.db.commit()

        return ImportJobResponse.model_validate(job)

    async def get_job(self, job_id: uuid.UUID) -> ImportJobResponse:
        job = await self.imports.get_job(job_id)
        if job is None:
            raise ValidationError("Import job not found.")
        return ImportJobResponse.model_validate(job)

    async def list_jobs(self, pagination: PaginationParams):
        items, total = await self.imports.list_jobs(pagination)
        return [ImportJobResponse.model_validate(j) for j in items], total

    async def list_job_rows(self, job_id: uuid.UUID, pagination: PaginationParams, status: str | None):
        return await self.imports.list_job_rows(job_id, pagination, status)


async def process_import_job(job_id: uuid.UUID, file_bytes: bytes) -> None:
    """
    Runs as a FastAPI BackgroundTask AFTER the upload response has already
    been sent — this is what keeps the API responsive regardless of file
    size (see module docstring). Uses its own DB session since the
    request-scoped session is closed by the time this runs.
    """
    async with AsyncSessionLocal() as db:
        repo = ImportRepository(db)
        job = await repo.get_job(job_id)
        if job is None:
            return

        job.status = "processing"
        job.started_at = datetime.utcnow()
        await repo.save_job(job)
        await db.commit()

        try:
            workbook = load_workbook(io.BytesIO(file_bytes), read_only=True, data_only=True)
            sheet = workbook.active

            rows_iter = sheet.iter_rows(values_only=True)
            try:
                header_row = next(rows_iter)
            except StopIteration:
                raise ValueError("The file has no rows.")

            headers = [str(h).strip().lower() if h is not None else "" for h in header_row]
            spec = _COLUMN_SPECS[job.entity_type]
            missing_required = [col for col in spec["required"] if col not in headers]
            if missing_required:
                raise ValueError(f"Missing required column(s): {', '.join(missing_required)}")

            col_index = {name: idx for idx, name in enumerate(headers)}

            existing_keys: set[str] = set()
            if job.entity_type == "customers":
                result = await db.execute(select(Customer.phone).where(Customer.phone.is_not(None)))
                existing_keys = {p for (p,) in result.all() if p}
            elif job.entity_type == "products":
                result = await db.execute(select(Product.sku).where(Product.sku.is_not(None)))
                existing_keys = {s for (s,) in result.all() if s}

            total_rows = 0
            success_rows = 0
            failed_rows = 0
            job_rows: list[ImportJobRow] = []
            new_entities: list = []

            for row_number, row in enumerate(rows_iter, start=2):  # row 1 was the header
                if row is None or all(cell is None for cell in row):
                    continue  # skip fully blank rows silently, not counted
                total_rows += 1

                raw_data = {headers[i]: row[i] for i in range(len(headers)) if i < len(row)}

                try:
                    if job.entity_type == "customers":
                        entity, dedupe_key = _build_customer(raw_data, col_index, row)
                    else:
                        entity, dedupe_key = _build_product(raw_data, col_index, row)

                    if dedupe_key and dedupe_key in existing_keys:
                        raise ValueError(f"Duplicate value '{dedupe_key}' already exists — row skipped.")

                    if dedupe_key:
                        existing_keys.add(dedupe_key)
                    new_entities.append(entity)
                    success_rows += 1
                    job_rows.append(
                        ImportJobRow(import_job_id=job.id, row_number=row_number, status="success", raw_data=_json_safe(raw_data))
                    )
                except Exception as row_exc:
                    failed_rows += 1
                    job_rows.append(
                        ImportJobRow(
                            import_job_id=job.id,
                            row_number=row_number,
                            status="failed",
                            error_message=str(row_exc),
                            raw_data=_json_safe(raw_data),
                        )
                    )

            if new_entities:
                db.add_all(new_entities)
            if job_rows:
                await repo.add_rows(job_rows)

            job.total_rows = total_rows
            job.success_rows = success_rows
            job.failed_rows = failed_rows
            job.status = "completed"
            job.completed_at = datetime.utcnow()
            await repo.save_job(job)
            await db.commit()

        except Exception as exc:
            await db.rollback()
            # Re-fetch since the failed transaction above may have expired
            # the in-memory object's session association.
            job = await repo.get_job(job_id)
            if job is not None:
                job.status = "failed"
                job.error_message = f"Could not process file: {exc}"
                job.completed_at = datetime.utcnow()
                await repo.save_job(job)
                await db.commit()


def _build_customer(raw_data: dict, col_index: dict, row: tuple):
    name = raw_data.get("name")
    if not name or not str(name).strip():
        raise ValueError("'name' is required")
    phone = raw_data.get("phone")
    phone = str(phone).strip() if phone else None
    customer = Customer(
        name=str(name).strip(),
        phone=phone,
        email=str(raw_data["email"]).strip() if raw_data.get("email") else None,
        address=str(raw_data["address"]).strip() if raw_data.get("address") else None,
        gst_number=str(raw_data["gst_number"]).strip() if raw_data.get("gst_number") else None,
        is_active=True,
    )
    return customer, phone


def _build_product(raw_data: dict, col_index: dict, row: tuple):
    name = raw_data.get("name")
    if not name or not str(name).strip():
        raise ValueError("'name' is required")
    price = raw_data.get("default_price")
    try:
        price = float(price)
    except (TypeError, ValueError):
        raise ValueError("'default_price' must be a number")
    if price <= 0:
        raise ValueError("'default_price' must be greater than 0")

    sku = raw_data.get("sku")
    sku = str(sku).strip() if sku else None
    product = Product(
        name=str(name).strip(),
        sku=sku,
        unit=str(raw_data["unit"]).strip() if raw_data.get("unit") else "pcs",
        default_price=price,
        is_active=True,
    )
    return product, sku


def _json_safe(raw_data: dict) -> dict:
    """Excel cells can contain datetime/Decimal objects that aren't natively
    JSON-serializable — stringify anything that isn't a plain primitive
    before storing in the JSONB raw_data column."""
    safe = {}
    for key, value in raw_data.items():
        if value is None or isinstance(value, (str, int, float, bool)):
            safe[key] = value
        else:
            safe[key] = str(value)
    return safe
