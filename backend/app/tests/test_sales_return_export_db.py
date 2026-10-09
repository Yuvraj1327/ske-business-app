"""Sales Return .xlsx export against a REAL (temporary SQLite file) database,
through the actual route, service and repository (same approach as
test_picklist_settlement_sync_db.py)."""
import importlib
import io
import pkgutil
import uuid
from datetime import date
from decimal import Decimal

import httpx
import pytest
import pytest_asyncio
from openpyxl import load_workbook
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.ext.compiler import compiles

import app.models as models_pkg
from app.core.permissions import get_current_user
from app.core.security import CurrentUser
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.customer import Customer
from app.models.invoice import Invoice
from app.models.role import Role
from app.models.sale import Sale
from app.models.sales_return import SalesReturn
from app.models.user import User

N_RETURNS = 105  # more than one 100-row page


@compiles(JSONB, "sqlite")
def _jsonb_as_json_on_sqlite(element, compiler, **kw):  # test-only: SQLite has no JSONB
    return "JSON"


@pytest_asyncio.fixture
async def factory(tmp_path):
    for mod in pkgutil.iter_modules(models_pkg.__path__):
        importlib.import_module(f"app.models.{mod.name}")
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'ret.db'}")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, expire_on_commit=False, autoflush=False)
    await engine.dispose()


async def _seed(factory) -> list[tuple[str, str, Decimal]]:
    """Returns the expected export rows, newest first (the list order)."""
    expected = []
    async with factory() as db:
        role = Role(name="admin")
        db.add(role)
        await db.flush()
        user = User(auth_user_id=uuid.uuid4(), full_name="a", role_id=role.id)
        db.add(user)
        await db.flush()
        for i in range(N_RETURNS):
            name = "=HYPERLINK(\"http://x\")" if i == 0 else f"Customer {i}"
            customer = Customer(name=name)
            db.add(customer)
            await db.flush()
            sale = Sale(customer_id=customer.id, sale_date=date(2026, 1, 1), total_amount=Decimal("1000"))
            db.add(sale)
            await db.flush()
            invoice_no = f"INV-{i:04d}"
            # One sale without an invoice must still export (blank invoice number).
            if i != 3:
                db.add(Invoice(sale_id=sale.id, invoice_number=invoice_no, invoice_date=date(2026, 1, 1)))
            amount = Decimal(f"{i}.50")
            db.add(
                SalesReturn(
                    sale_id=sale.id, customer_id=customer.id, return_date=date(2026, 2, 1) if i % 2 else date(2026, 1, 15),
                    total_return_amount=amount, status="completed", created_by=user.id,
                )
            )
            expected.append((name, "" if i == 3 else invoice_no, amount, date(2026, 2, 1) if i % 2 else date(2026, 1, 15)))
        await db.commit()
    # list order is return_date desc, created_at desc
    return expected


def _client(factory, permissions):
    async def _db():
        async with factory() as db:
            yield db

    async def _user():
        return CurrentUser(
            id=uuid.uuid4(), auth_user_id=uuid.uuid4(), full_name="t", role_name="admin", is_active=True,
            permission_keys=set(permissions),
        )

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = _user
    return httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://t")


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


def _rows(content: bytes):
    ws = load_workbook(io.BytesIO(content)).active
    return [tuple(c.value for c in r) for r in ws.iter_rows()]


@pytest.mark.asyncio
async def test_export_contains_every_return_with_correct_mapping(factory):
    expected = await _seed(factory)
    async with _client(factory, {"returns.create"}) as c:
        resp = await c.get("/api/v1/returns/export")
        listing = [
            r
            for p in (1, 2)
            for r in (await c.get("/api/v1/returns", params={"page": p, "page_size": 100})).json()["items"]
        ]
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    assert f"sales_returns_{date.today().isoformat()}.xlsx" in resp.headers["content-disposition"]

    rows = _rows(resp.content)
    assert rows[0] == ("Customer Name", "Invoice Number", "Total Amount")
    body = rows[1:]
    assert len(body) == N_RETURNS  # past the 100-row page size

    # Same set as the paginated list API: customer name + amount per return.
    assert sorted((n, Decimal(str(a))) for n, _, a in body) == sorted(
        (r["customer_name"], Decimal(r["total_return_amount"])) for r in listing
    )
    # Correct invoice per customer/amount, blank (not shifted/dropped) when there is none.
    want = {(n, inv, a) for n, inv, a, _ in expected}
    assert {(n, inv or "", Decimal(str(a))) for n, inv, a in body} == want
    # Amounts are numbers, and a formula-looking name stays literal text.
    ws = load_workbook(io.BytesIO(resp.content)).active
    assert isinstance(ws["C2"].value, (int, float))
    assert any(r[0] == '=HYPERLINK("http://x")' for r in body)
    assert ws.max_column == 3


@pytest.mark.asyncio
async def test_export_empty_is_header_only(factory):
    async with factory() as db:  # schema only, no data
        pass
    async with _client(factory, {"returns.create"}) as c:
        resp = await c.get("/api/v1/returns/export")
    assert resp.status_code == 200
    assert _rows(resp.content) == [("Customer Name", "Invoice Number", "Total Amount")]


@pytest.mark.asyncio
async def test_export_requires_the_same_permission_as_the_list(factory):
    async with _client(factory, {"sales.view"}) as c:
        assert (await c.get("/api/v1/returns/export")).status_code == 403
        assert (await c.get("/api/v1/returns")).status_code == 403
