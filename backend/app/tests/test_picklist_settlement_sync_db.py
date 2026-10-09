"""Picklist -> Settlement sync against a REAL (temporary SQLite file) database.

Runs the actual import parser, SettlementService.create_sheet / update_sheet /
get_sheet and PicklistService.confirm_item against persisted rows — no stubs.
Each step re-reads from a fresh session so what is asserted is what was
committed, i.e. what a refreshed / reopened Settlement would show. SQLite only
stands in for Postgres here (same SQLAlchemy models and queries)."""
import importlib
import io
import pkgutil
import uuid
from datetime import date
from decimal import Decimal
from types import SimpleNamespace

import pytest
import pytest_asyncio
from openpyxl import Workbook
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import app.models as models_pkg
from app.core.security import CurrentUser
from app.db.base import Base
from app.models.import_job import ImportJob
from app.models.picklist import Picklist, PicklistItem
from app.models.role import Role
from app.models.settlement import SettlementSheet
from app.models.user import User
from app.schemas.settlement import SettlementSheetCreateRequest, SettlementSheetUpdateRequest
from app.services.import_service import _process_picklist_import
from app.services.picklist_service import PicklistService
from app.services.settlement_service import SettlementService

D = Decimal


@compiles(JSONB, "sqlite")
def _jsonb_as_json_on_sqlite(element, compiler, **kw):  # test-only: SQLite has no JSONB
    return "JSON"


PICKLIST_NO = "PL-DB-1"
AMOUNTS = ["1000.00", "2000.00", "500.00", "700.00", "300.00"]  # imported invoice amounts, total 4500


@pytest_asyncio.fixture
async def session_factory(tmp_path):
    for mod in pkgutil.iter_modules(models_pkg.__path__):
        importlib.import_module(f"app.models.{mod.name}")
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'sync.db'}")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, expire_on_commit=False, autoflush=False)
    await engine.dispose()


def _xlsx() -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.append(["Picklist No", PICKLIST_NO])
    ws.append(["Delivery Agent", "Agent One"])
    ws.append(["PSR Route", "R1"])
    ws.append(["No.", "Invoice Number", "Customer Code", "Customer Name", "sales man", "Amount Payable"])
    for i, amount in enumerate(AMOUNTS, start=1):
        ws.append([i, f"INV-{i}", f"C{i}", f"Customer {i}", "S", float(amount)])
    ws.append(["Total", None, None, None, None, sum(float(a) for a in AMOUNTS)])
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


async def _seed(factory):
    """Users + a real picklist imported through the actual import code."""
    async with factory() as db:
        roles = {name: Role(name=name) for name in ("admin", "delivery_agent", "salesman")}
        db.add_all(roles.values())
        await db.flush()
        users = {
            name: User(auth_user_id=uuid.uuid4(), full_name=name, role_id=roles[name].id)
            for name in ("admin", "delivery_agent", "salesman")
        }
        db.add_all(users.values())
        await db.flush()
        job = ImportJob(
            file_name="pl.xlsx", file_url="x", entity_type="picklists", uploaded_by=users["admin"].id,
        )
        db.add(job)
        await db.flush()
        _, success, failed, rows = await _process_picklist_import(db, job, _xlsx(), users["delivery_agent"].id)
        db.add_all(rows)
        await db.commit()
        assert (success, failed) == (5, 0)
        return {name: u.id for name, u in users.items()}


def _user(user_id, role, *perms):
    return CurrentUser(
        id=user_id, auth_user_id=uuid.uuid4(), full_name=role, role_name=role, is_active=True,
        permission_keys=set(perms),
    )


async def _item_ids(factory):
    async with factory() as db:
        rows = (await db.execute(select(PicklistItem).order_by(PicklistItem.row_no))).scalars().all()
        return [r.id for r in rows]


async def _confirm(factory, item_id, status, user, **kw):
    async with factory() as db:
        await PicklistService(db).confirm_item(item_id, status, user, **kw)


async def _sheet_fields(factory, sheet_id):
    """Straight from the database, via a brand-new session."""
    async with factory() as db:
        s = (await db.execute(select(SettlementSheet).where(SettlementSheet.id == sheet_id))).scalar_one()
        return {
            "pick_sheet_value": s.pick_sheet_value, "cash": s.cash_amount, "online": s.online_amount,
            "credit": s.credit_bills_amount, "cheque": s.cheque_amount, "returns": s.returns_amount,
            "damage": s.damage_return_amount, "discount": s.discount_amount, "old_short": s.old_short_amount,
        }


async def _reopen(factory, sheet_id, admin):
    """What GET /settlements/{id} returns."""
    async with factory() as db:
        resp = await SettlementService(db).get_sheet(sheet_id, admin)
        return {
            "pick_sheet_value": D(resp.pick_sheet_value), "cash": D(resp.cash_amount), "online": D(resp.online_amount),
            "credit": D(resp.credit_bills_amount), "cheque": D(resp.cheque_amount),
        }


@pytest.mark.asyncio
async def test_full_flow_totals_follow_picklist_and_survive_reopen(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin", "settlements.manage", "picklists.manage")
    agent = _user(ids["delivery_agent"], "delivery_agent", "picklists.view_assigned")

    # Imported picklist total is persisted by the real import.
    async with f() as db:
        assert (await db.execute(select(Picklist.total_amount))).scalar_one() == D("4500")

    # Admin creates the Settlement choosing only the Pick Sheet No. (nothing else typed).
    async with f() as db:
        created = await SettlementService(db).create_sheet(
            SettlementSheetCreateRequest(
                sheet_date=date(2026, 10, 9), delivery_agent_id=ids["delivery_agent"],
                salesman_ids=[ids["salesman"]], pick_sheet_no=PICKLIST_NO,
                returns_amount="11", damage_return_amount="22", discount_amount="33", old_short_amount="44",
            ),
            admin,
        )
    sheet_id = created.id
    assert D(created.pick_sheet_value) == D("4500")  # Pick Sheet Value from the import

    items = await _item_ids(f)
    # Delivery agent updates payments: cash 1000, online 2000, credit 500, cheque 300 of 700.
    await _confirm(f, items[0], "cash", agent)
    await _confirm(f, items[1], "online", agent)
    await _confirm(f, items[2], "credit", agent, salesman_id=ids["salesman"])
    await _confirm(f, items[3], "cheque", agent, cheque_amount=D("300"))

    got = await _sheet_fields(f, sheet_id)
    assert (got["pick_sheet_value"], got["cash"], got["online"], got["credit"], got["cheque"]) == (
        D("4500"), D("1000"), D("2000"), D("500"), D("300"),
    )
    # Existing reconciliation fields untouched.
    assert (got["returns"], got["damage"], got["discount"], got["old_short"]) == (D("11"), D("22"), D("33"), D("44"))
    reopened = await _reopen(f, sheet_id, admin)
    assert reopened == {
        "pick_sheet_value": D("4500"), "cash": D("1000"), "online": D("2000"), "credit": D("500"), "cheque": D("300"),
    }

    # Last pending row -> cash: totals move, nothing is double counted.
    await _confirm(f, items[4], "cash", agent)
    got = await _sheet_fields(f, sheet_id)
    assert (got["cash"], got["online"], got["credit"], got["cheque"]) == (D("1300"), D("2000"), D("500"), D("300"))

    # Admin edits the Settlement by hand: persists, and the picklist payment records are untouched.
    async with f() as db:
        await SettlementService(db).update_sheet(
            sheet_id, SettlementSheetUpdateRequest(cash_amount="1234", returns_amount="55"), admin
        )
    got = await _sheet_fields(f, sheet_id)
    assert (got["cash"], got["returns"]) == (D("1234"), D("55"))
    async with f() as db:
        statuses = [(i.status, i.amount_payable, i.cheque_amount) for i in
                    (await db.execute(select(PicklistItem).order_by(PicklistItem.row_no))).scalars()]
    assert statuses == [
        ("cash", D("1000"), D("0")), ("online", D("2000"), D("0")), ("credit", D("500"), D("0")),
        ("cheque", D("700"), D("300")), ("cash", D("300"), D("0")),
    ]


@pytest.mark.asyncio
async def test_sheet_created_after_payments_starts_from_saved_totals(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin", "settlements.manage", "picklists.manage")
    agent = _user(ids["delivery_agent"], "delivery_agent", "picklists.view_assigned")
    items = await _item_ids(f)
    await _confirm(f, items[0], "cash", agent)
    await _confirm(f, items[1], "online", agent)

    async with f() as db:
        created = await SettlementService(db).create_sheet(
            SettlementSheetCreateRequest(
                sheet_date=date(2026, 10, 9), delivery_agent_id=ids["delivery_agent"],
                salesman_ids=[ids["salesman"]], pick_sheet_no=PICKLIST_NO,
            ),
            admin,
        )
    assert await _reopen(f, created.id, admin) == {
        "pick_sheet_value": D("4500"), "cash": D("1000"), "online": D("2000"), "credit": D("0"), "cheque": D("0"),
    }


@pytest.mark.asyncio
async def test_existing_sheet_with_zero_pick_sheet_value_is_backfilled_but_typed_value_kept(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin", "settlements.manage", "picklists.manage")
    agent = _user(ids["delivery_agent"], "delivery_agent", "picklists.view_assigned")
    items = await _item_ids(f)

    async def new_sheet(value):
        async with f() as db:
            r = await SettlementService(db).create_sheet(
                SettlementSheetCreateRequest(
                    sheet_date=date(2026, 10, 9), delivery_agent_id=ids["delivery_agent"],
                    salesman_ids=[ids["salesman"]], pick_sheet_no=PICKLIST_NO, pick_sheet_value=value,
                ),
                admin,
            )
            return r.id

    zero_id, typed_id = await new_sheet("0"), await new_sheet("123")  # explicit values are kept at creation
    await _confirm(f, items[0], "cash", agent)
    assert (await _sheet_fields(f, zero_id))["pick_sheet_value"] == D("4500")
    assert (await _sheet_fields(f, typed_id))["pick_sheet_value"] == D("123")
    assert (await _sheet_fields(f, typed_id))["cash"] == D("1000")


@pytest.mark.asyncio
async def test_completed_sheet_is_not_modified(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin", "settlements.manage", "picklists.manage")
    agent = _user(ids["delivery_agent"], "delivery_agent", "picklists.view_assigned")
    items = await _item_ids(f)
    async with f() as db:
        created = await SettlementService(db).create_sheet(
            SettlementSheetCreateRequest(
                sheet_date=date(2026, 10, 9), delivery_agent_id=ids["delivery_agent"],
                salesman_ids=[ids["salesman"]], pick_sheet_no=PICKLIST_NO,
            ),
            admin,
        )
    async with f() as db:  # no rows -> can be completed straight away
        sheet = (await db.execute(select(SettlementSheet))).scalar_one()
        sheet.status = "completed"
        await db.commit()
    await _confirm(f, items[0], "cash", agent)
    assert (await _sheet_fields(f, created.id))["cash"] == D("0")
