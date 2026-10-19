"""Reset Business Data against a REAL (temporary SQLite file) database with
foreign keys ENFORCED, so a wrong deletion order raises like Postgres does."""
import importlib
import pkgutil
import uuid
from datetime import date

import pytest
import pytest_asyncio
from sqlalchemy import event, func, select
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.ext.compiler import compiles

import app.models as models_pkg
from app.db.base import Base
from app.models.customer import Customer
from app.models.role import Role
from app.models.settlement import SettlementSheet, SettlementSheetItem
from app.models.user import User
from app.services import admin_service
from app.services.admin_service import _RESET_TABLES_IN_ORDER, AdminService


@compiles(JSONB, "sqlite")
def _jsonb_as_json_on_sqlite(element, compiler, **kw):  # test-only: SQLite has no JSONB
    return "JSON"


@pytest_asyncio.fixture
async def factory(tmp_path):
    for mod in pkgutil.iter_modules(models_pkg.__path__):
        importlib.import_module(f"app.models.{mod.name}")
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'reset.db'}")

    @event.listens_for(engine.sync_engine, "connect")
    def _fk_on(dbapi_conn, _):
        dbapi_conn.execute("PRAGMA foreign_keys=ON")

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        # Tables that exist in the migrations but have no ORM model.
        for t in _RESET_TABLES_IN_ORDER:
            if t not in Base.metadata.tables:
                await conn.exec_driver_sql(f"CREATE TABLE {t} (id INTEGER PRIMARY KEY)")
    yield async_sessionmaker(engine, expire_on_commit=False, autoflush=False)
    await engine.dispose()


def test_every_fk_into_a_reset_table_is_handled():
    """Every table with an FK to a reset table must itself be reset (or be cascaded from one)."""
    for mod in pkgutil.iter_modules(models_pkg.__path__):
        importlib.import_module(f"app.models.{mod.name}")
    reset = set(_RESET_TABLES_IN_ORDER)
    position = {t: i for i, t in enumerate(_RESET_TABLES_IN_ORDER)}
    cascaded = set()
    for table in Base.metadata.tables.values():
        for fk in table.foreign_keys:
            if fk.ondelete and fk.ondelete.upper() == "CASCADE" and fk.column.table.name in reset:
                cascaded.add(table.name)
    for table in Base.metadata.tables.values():
        for fk in table.foreign_keys:
            parent = fk.column.table.name
            if parent in reset and table.name != parent:
                assert table.name in reset or table.name in cascaded, f"{table.name} -> {parent} not handled"
                if table.name in position:
                    assert position[table.name] < position[parent], f"{table.name} must be deleted before {parent}"


@pytest.mark.asyncio
async def test_reset_with_settlement_sheet_referencing_customer(factory, monkeypatch):
    monkeypatch.setattr(admin_service, "verify_password", lambda email, pw: True)
    async with factory() as db:
        role = Role(name="admin")
        db.add(role)
        await db.flush()
        user = User(auth_user_id=uuid.uuid4(), full_name="a", role_id=role.id)
        db.add(user)
        await db.flush()
        cust = Customer(name="c", created_by=user.id)
        db.add(cust)
        await db.flush()
        sheet = SettlementSheet(sheet_no="S-1", delivery_agent_id=user.id, sheet_date=date.today(), created_by=user.id)
        db.add(sheet)
        await db.flush()
        db.add(SettlementSheetItem(settlement_sheet_id=sheet.id, row_no=1, customer_id=cust.id, customer_name="c"))
        await db.commit()

    async with factory() as db:
        svc = AdminService(db)
        admin = type("U", (), {"is_admin": True, "email": "a@x.com"})()
        result = await svc.reset_business_data(admin, "pw")
        assert result.success

    async with factory() as db:
        for model in (Customer, SettlementSheet, SettlementSheetItem):
            assert (await db.execute(select(func.count()).select_from(model))).scalar() == 0
        assert (await db.execute(select(func.count()).select_from(User))).scalar() == 1
        assert (await db.execute(select(func.count()).select_from(Role))).scalar() == 1
