"""Sales Return -> Sale -> Customer outstanding/ledger -> Picklist -> Settlement,
against a real (temporary SQLite) database with the real services. Each check
re-reads from a fresh session, i.e. what a refreshed / reopened screen shows."""
import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.core.exceptions import BusinessRuleError
from app.models.customer import Customer
from app.models.picklist import Picklist, PicklistItem
from app.models.product import Product
from app.models.sale import Sale, SaleItem
from app.schemas.sales_return import SalesReturnCreateRequest, SalesReturnItemCreateRequest
from app.schemas.settlement import SettlementSheetCreateRequest
from app.services.customer_service import CustomerService
from app.services.picklist_service import PicklistService
from app.services.sales_return_service import SalesReturnService
from app.services.settlement_service import SettlementService
from app.tests.test_picklist_settlement_sync_db import (  # noqa: F401  (session_factory is a fixture)
    PICKLIST_NO, _confirm, _item_ids, _reopen, _seed, _sheet_fields, _user, session_factory,
)

D = Decimal


async def _return(f, user, sale_id, lines, reason=None):
    async with f() as db:
        return await SalesReturnService(db).create_return(
            SalesReturnCreateRequest(
                sale_id=sale_id,
                items=[SalesReturnItemCreateRequest(sale_item_id=i, quantity=q) for i, q in lines],
                reason=reason,
            ),
            user,
        )


async def _make_sale(f, qty, line_total, subtotal, discount):
    async with f() as db:
        cust = Customer(name="Direct Customer")
        prod = Product(name="Widget", default_price=D("100"))
        db.add_all([cust, prod])
        await db.flush()
        sale = Sale(
            customer_id=cust.id, sale_date=date(2026, 10, 9), subtotal=subtotal, discount_amount=discount,
            total_amount=subtotal - discount, paid_amount=D("0"), payment_status="unpaid", status="active",
        )
        sale.items = [SaleItem(product_id=prod.id, quantity=qty, unit_price=line_total / qty, line_discount=D("0"), line_total=line_total)]
        db.add(sale)
        await db.commit()
        return cust.id, sale.id, sale.items[0].id


async def _sale(f, sale_id):
    async with f() as db:
        return (await db.execute(select(Sale).where(Sale.id == sale_id))).scalar_one()


@pytest.mark.asyncio
async def test_header_discount_full_return_refunds_exactly_what_was_charged(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin")
    # 3 x 100 = 300, header discount 30 -> customer charged 270.
    _, sale_id, item_id = await _make_sale(f, D("3"), D("300"), D("300"), D("30"))
    r1 = await _return(f, admin, sale_id, [(item_id, D("1"))])
    assert D(r1.total_return_amount) == D("90.00")  # 1/3 of 270, not 100
    s = await _sale(f, sale_id)
    assert s.total_amount == D("180.00") and s.payment_status == "unpaid"
    r2 = await _return(f, admin, sale_id, [(item_id, D("2"))])  # the rest
    assert D(r2.total_return_amount) == D("180.00")
    s = await _sale(f, sale_id)
    assert s.total_amount == D("0.00")  # exactly zero, nothing refunded beyond the 270 charged
    with pytest.raises(BusinessRuleError):
        await _return(f, admin, sale_id, [(item_id, D("1"))])
    assert (await _sale(f, sale_id)).total_amount == D("0.00")


@pytest.mark.asyncio
async def test_rounding_parts_sum_exactly_to_line_total(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin")
    _, sale_id, item_id = await _make_sale(f, D("3"), D("100"), D("100"), D("0"))
    amounts = []
    for _ in range(3):
        r = await _return(f, admin, sale_id, [(item_id, D("1"))])
        amounts.append(D(r.total_return_amount))
    assert amounts == [D("33.33"), D("33.33"), D("33.34")]
    assert sum(amounts) == D("100.00")
    assert (await _sale(f, sale_id)).total_amount == D("0.00")


@pytest.mark.asyncio
async def test_customer_outstanding_and_ledger_do_not_double_deduct(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin")
    cust_id, sale_id, item_id = await _make_sale(f, D("10"), D("1000"), D("1000"), D("0"))
    await _return(f, admin, sale_id, [(item_id, D("3"))])  # 300 back
    async with f() as db:
        out = await CustomerService(db).get_outstanding(cust_id, admin)
        ledger = await CustomerService(db).get_ledger(cust_id, admin)
    assert D(out.outstanding) == D("700.00")      # 1000 - 300, deducted once
    assert D(out.total_sales) == D("1000.00") and D(out.total_returned) == D("300.00")
    debit = sum(D(e.debit) for e in ledger.entries)
    credit = sum(D(e.credit) for e in ledger.entries)
    assert (debit, credit) == (D("1000.00"), D("300.00"))
    assert debit - credit == D(ledger.outstanding) == D("700.00")


@pytest.mark.asyncio
async def test_picklist_and_settlement_follow_return_once(session_factory):
    f = session_factory
    ids = await _seed(f)
    admin = _user(ids["admin"], "admin", "settlements.manage", "picklists.manage", "returns.create")
    agent = _user(ids["delivery_agent"], "delivery_agent", "picklists.view_assigned", "returns.create")
    async with f() as db:
        created = await SettlementService(db).create_sheet(
            SettlementSheetCreateRequest(
                sheet_date=date(2026, 10, 9), delivery_agent_id=ids["delivery_agent"],
                salesman_ids=[ids["salesman"]], pick_sheet_no=PICKLIST_NO,
            ),
            admin,
        )
    sheet_id = created.id
    items = await _item_ids(f)
    async with f() as db:
        row = (await db.execute(select(PicklistItem).where(PicklistItem.id == items[0]))).scalar_one()
        row2 = (await db.execute(select(PicklistItem).where(PicklistItem.id == items[1]))).scalar_one()
        sale1, sale2 = row.sale_id, row2.sale_id
        sale_item1 = (await db.execute(select(SaleItem).where(SaleItem.sale_id == sale1))).scalar_one().id
        sale_item2 = (await db.execute(select(SaleItem).where(SaleItem.sale_id == sale2))).scalar_one().id

    # Full return of invoice 1 (1000), then a damaged return of invoice 2 (2000).
    await _return(f, agent, sale1, [(sale_item1, D("1"))], reason="Full return")
    got = await _sheet_fields(f, sheet_id)
    assert (got["returns"], got["damage"], got["pick_sheet_value"]) == (D("1000"), D("0"), D("4500"))
    await _return(f, agent, sale2, [(sale_item2, D("1"))], reason="Damaged")
    got = await _sheet_fields(f, sheet_id)
    assert (got["returns"], got["damage"], got["pick_sheet_value"]) == (D("1000"), D("2000"), D("4500"))

    # The returned rows can no longer be collected at their original amount;
    # the picklist's imported total is unchanged.
    async with f() as db:
        amounts = [i.amount_payable for i in (await db.execute(select(PicklistItem).order_by(PicklistItem.row_no))).scalars()]
        assert (await db.execute(select(Picklist.total_amount))).scalar_one() == D("4500")
    assert amounts == [D("0"), D("0"), D("500"), D("700"), D("300")]

    # Collecting the rest and re-confirming never changes returns (no duplicate deduction).
    await _confirm(f, items[2], "cash", agent)
    await _confirm(f, items[3], "online", agent)
    got = await _sheet_fields(f, sheet_id)
    assert (got["returns"], got["damage"], got["cash"], got["online"]) == (D("1000"), D("2000"), D("500"), D("700"))
    reopened = await _reopen(f, sheet_id, admin)
    assert reopened["pick_sheet_value"] == D("4500")
    # A rejected repeat return changes nothing.
    with pytest.raises(BusinessRuleError):
        await _return(f, agent, sale1, [(sale_item1, D("1"))], reason="Full return")
    assert await _sheet_fields(f, sheet_id) == got
