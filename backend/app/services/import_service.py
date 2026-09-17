"""
Excel import processing.

Design notes (documented simplifications for this MVP):

- Processing runs via FastAPI's BackgroundTasks rather than a dedicated
  queue (Celery/RQ + Redis). This still satisfies "don't block the API" for
  realistic small-business import sizes (hundreds to low thousands of rows).
  For very large files or multi-worker deployments, swap the BackgroundTask
  call for a real queue — the processing function itself doesn't change,
  only how it gets invoked.
- Three entity types are supported: `customers`, `products` (simple flat
  column imports), and `picklists` (the delivery-agent workflow — a
  structurally different Excel with metadata header rows before the data
  table; see `_process_picklist_import` and app/services/picklist_service.py
  for what a picklist row actually creates). Importing other financial
  records isn't supported — that needs its own validation rules that
  weren't specified, so it's not invented here.
- Uploaded files ARE persisted (see app/core/storage.py) to the configured
  Supabase Storage bucket, with a graceful local-placeholder fallback if
  Storage isn't reachable/configured, so an import never hard-fails purely
  because of the optional file-preservation step.
"""
import io
import uuid
from datetime import datetime

from openpyxl import load_workbook
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.core.storage import upload_import_file
from app.db.session import AsyncSessionLocal
from app.models.customer import Customer
from app.models.import_job import ImportJob, ImportJobRow
from app.models.picklist import Picklist, PicklistItem
from app.models.product import Product
from app.models.user import User
from app.repositories.import_repo import ImportRepository
from app.schemas.import_job import ImportJobResponse
from app.services.picklist_service import create_sale_for_picklist_row, find_or_create_customer
from app.utils.pagination import PaginationParams

SUPPORTED_ENTITY_TYPES = {"customers", "products", "picklists"}

_COLUMN_SPECS = {
    "customers": {"required": ["name"], "optional": ["phone", "email", "address", "gst_number"]},
    "products": {"required": ["name", "default_price"], "optional": ["sku", "unit"]},
}


class ImportService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.imports = ImportRepository(db)

    async def start_import(
        self,
        entity_type: str,
        file_name: str,
        file_bytes: bytes,
        uploaded_by: uuid.UUID,
        delivery_agent_id: uuid.UUID | None = None,
    ) -> ImportJobResponse:
        if entity_type not in SUPPORTED_ENTITY_TYPES:
            raise ValidationError(f"entity_type must be one of {sorted(SUPPORTED_ENTITY_TYPES)}", field="entity_type")
        if not file_name.lower().endswith((".xlsx", ".xlsm")):
            raise ValidationError("Only .xlsx files are supported.", field="file")
        if not file_bytes:
            raise ValidationError("Uploaded file is empty.", field="file")

        if entity_type == "picklists":
            if delivery_agent_id is None:
                raise ValidationError(
                    "A Delivery Agent must be selected before uploading a picklist.", field="delivery_agent_id"
                )
            agent_result = await self.db.execute(select(User).where(User.id == delivery_agent_id))
            if agent_result.scalar_one_or_none() is None:
                raise ValidationError("Selected delivery agent does not exist.", field="delivery_agent_id")

        file_url = upload_import_file(file_name, file_bytes)

        job = ImportJob(
            file_name=file_name,
            file_url=file_url,
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


async def process_import_job(job_id: uuid.UUID, file_bytes: bytes, delivery_agent_id: uuid.UUID | None = None) -> None:
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
            if job.entity_type == "picklists":
                total_rows, success_rows, failed_rows, job_rows = await _process_picklist_import(
                    db, job, file_bytes, delivery_agent_id
                )
            else:
                total_rows, success_rows, failed_rows, job_rows = await _process_flat_import(db, job, file_bytes)

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


async def _process_flat_import(db: AsyncSession, job: ImportJob, file_bytes: bytes):
    """The original customers/products import path — a flat sheet with a
    single header row followed by data rows. Unchanged from before
    picklists were added."""
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

    return total_rows, success_rows, failed_rows, job_rows


_PICKLIST_HEADER_LABELS = {"no.", "invoice number", "customer code", "customer name", "amount payable"}


async def _process_picklist_import(db: AsyncSession, job: ImportJob, file_bytes: bytes, delivery_agent_id: uuid.UUID | None):
    """
    Parses the client's delivery-picklist Excel format: a few metadata rows
    (Picklist No / Delivery agent / PSR Route) followed by a data table with
    its own header row (No., Invoice Number, Customer Code, Customer Name,
    sales man, Amount Payable), then a trailing "Total" row.

    Each data row creates a Customer (matched-or-created), a Sale + one
    synthetic SaleItem + Invoice (see picklist_service.create_sale_for_picklist_row),
    and a PicklistItem tracking its delivery/collection status — all wrapped
    under one Picklist header row for this import.
    """
    if delivery_agent_id is None:
        raise ValueError("No delivery agent was specified for this picklist import.")

    workbook = load_workbook(io.BytesIO(file_bytes), read_only=True, data_only=True)
    sheet = workbook.active
    all_rows = list(sheet.iter_rows(values_only=True))

    metadata: dict[str, str] = {}
    header_row_index: int | None = None
    header_cols: dict[str, int] = {}

    for idx, row in enumerate(all_rows):
        if row is None:
            continue
        first_cell = str(row[0]).strip().lower() if row[0] is not None else ""

        if first_cell in {"picklist no", "delivery agent", "psr route"}:
            value = next((str(c).strip() for c in row[1:] if c is not None and str(c).strip()), "")
            metadata[first_cell] = value
            continue

        normalized_cells = {str(c).strip().lower() for c in row if c is not None}
        if _PICKLIST_HEADER_LABELS.issubset(normalized_cells):
            header_row_index = idx
            header_cols = {str(c).strip().lower(): i for i, c in enumerate(row) if c is not None}
            break

    if header_row_index is None:
        raise ValueError(
            "Could not find the picklist's column header row "
            "(expected columns: No., Invoice Number, Customer Code, Customer Name, Amount Payable)."
        )
    if "picklist no" not in metadata:
        raise ValueError("Missing 'Picklist No' in the file header.")

    picklist_no = metadata["picklist no"]

    existing_result = await db.execute(select(Picklist).where(Picklist.picklist_no == picklist_no))
    if existing_result.scalar_one_or_none() is not None:
        raise ValueError(f"Picklist '{picklist_no}' has already been imported.")

    picklist = Picklist(
        picklist_no=picklist_no,
        delivery_agent_id=delivery_agent_id,
        psr_route=metadata.get("psr route"),
        raw_delivery_agent_label=metadata.get("delivery agent"),
        import_job_id=job.id,
        total_amount=0,
        created_by=job.uploaded_by,
    )
    db.add(picklist)
    await db.flush()

    total_rows = 0
    success_rows = 0
    failed_rows = 0
    job_rows: list[ImportJobRow] = []
    running_total = 0

    for row_number, row in enumerate(all_rows[header_row_index + 1 :], start=header_row_index + 2):
        if row is None or all(cell is None for cell in row):
            continue

        no_value = row[header_cols["no."]] if header_cols["no."] < len(row) else None
        if no_value is None or str(no_value).strip().lower() == "total":
            continue  # trailing Total row — not a data row

        total_rows += 1
        raw_data = {label: (row[i] if i < len(row) else None) for label, i in header_cols.items()}

        try:
            invoice_number = str(raw_data.get("invoice number") or "").strip()
            customer_name = str(raw_data.get("customer name") or "").strip()
            customer_code = str(raw_data.get("customer code") or "").strip() or None
            salesman_label = str(raw_data.get("sales man") or raw_data.get("salesman") or "").strip() or None
            amount_raw = raw_data.get("amount payable")

            if not invoice_number:
                raise ValueError("'Invoice Number' is required")
            if not customer_name:
                raise ValueError("'Customer Name' is required")
            try:
                amount = float(amount_raw)
            except (TypeError, ValueError):
                raise ValueError("'Amount Payable' must be a number")
            if amount < 0:
                raise ValueError("'Amount Payable' cannot be negative")

            customer = await find_or_create_customer(db, customer_code, customer_name, job.uploaded_by)
            sale = await create_sale_for_picklist_row(
                db, customer, invoice_number, amount, job.started_at.date() if job.started_at else datetime.utcnow().date(), job.uploaded_by
            )

            item = PicklistItem(
                picklist_id=picklist.id,
                row_no=int(no_value) if str(no_value).strip().lstrip("-").isdigit() else row_number,
                invoice_number=invoice_number,
                customer_code=customer_code,
                customer_name=customer_name,
                salesman_label=salesman_label,
                amount_payable=amount,
                customer_id=customer.id,
                sale_id=sale.id,
                status="pending",
            )
            db.add(item)
            await db.flush()

            running_total += amount
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

    picklist.total_amount = running_total
    await db.flush()

    return total_rows, success_rows, failed_rows, job_rows


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
