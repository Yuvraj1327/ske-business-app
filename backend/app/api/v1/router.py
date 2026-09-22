from fastapi import APIRouter

from app.api.v1 import (
    admin,
    auth,
    customers,
    dashboard,
    expenses,
    health,
    imports,
    invoices,
    payments,
    picklists,
    products,
    reports,
    returns,
    roles,
    sales,
    salesmen,
    settlements,
    transactions,
    users,
)

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(roles.router)
api_router.include_router(dashboard.router)
api_router.include_router(customers.router)
api_router.include_router(products.router)
api_router.include_router(sales.router)
api_router.include_router(invoices.router)
api_router.include_router(payments.router)
api_router.include_router(transactions.router)
api_router.include_router(returns.router)
api_router.include_router(expenses.router)
api_router.include_router(salesmen.router)
api_router.include_router(reports.router)
api_router.include_router(imports.router)
api_router.include_router(picklists.router)
api_router.include_router(settlements.router)
api_router.include_router(admin.router)
