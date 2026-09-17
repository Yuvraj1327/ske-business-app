"""
Admin-only data-reset utility (Settings → Reset Data).

Deletion order below was derived by tracing every foreign key across all
three migrations (001/002/003) — not guessed. The rule: a table with a
non-cascading FK to another table-being-deleted must be cleared BEFORE that
other table. Tables with `ON DELETE CASCADE` already declared (sale_items,
cheque_details, sales_return_items, import_job_rows, picklist_items) don't
need an explicit statement — deleting their parent removes them
automatically at the database level.

Preserved, never touched: users (including the admin account), roles,
permissions, role_permissions, products, expense_categories, tasks,
audit_logs — i.e. accounts, RBAC configuration, and catalog/config data.
"""
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_verification import verify_password
from app.core.exceptions import UnauthorizedError, ValidationError
from app.core.security import CurrentUser
from app.schemas.admin import ResetDataResponse

# Order matters — see module docstring. Each DELETE also implicitly cascades
# to any table with an ON DELETE CASCADE foreign key to it.
_RESET_TABLES_IN_ORDER = [
    "picklists",  # cascades -> picklist_items
    "sales_returns",  # cascades -> sales_return_items
    "transactions",
    "payments",  # cascades -> cheque_details
    "invoices",
    "sales",  # cascades -> sale_items
    "import_jobs",  # cascades -> import_job_rows
    "expenses",
    "salesman_customer_assignments",
    "customers",
    "invoice_number_sequences",
]


class AdminService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def reset_business_data(self, current_user: CurrentUser, password: str) -> ResetDataResponse:
        if not current_user.is_admin:
            # Redundant with the route's require_admin() dependency, but
            # this method is security-critical enough to double-check
            # rather than rely solely on the route wiring.
            raise UnauthorizedError("Only an administrator can reset business data.")

        if not current_user.email:
            raise ValidationError("Your session is missing an email claim; please log out and back in, then retry.")

        # Verify the CURRENT password before touching anything. No DELETE
        # statement runs until this returns True — a failed verification
        # exits here with nothing in the database touched.
        if not verify_password(current_user.email, password):
            raise UnauthorizedError("Incorrect password. Data was not reset.")

        try:
            for table in _RESET_TABLES_IN_ORDER:
                await self.db.execute(text(f"DELETE FROM {table}"))
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        return ResetDataResponse(
            success=True,
            message="Business data has been reset. Customers, sales, invoices, payments, expenses, "
            "transactions, imports, and picklists were cleared. Users, roles, permissions, and "
            "products were preserved.",
        )
