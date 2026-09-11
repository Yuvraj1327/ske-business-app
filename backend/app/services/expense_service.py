import uuid
from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BusinessRuleError, NotFoundError, ValidationError
from app.core.security import CurrentUser
from app.models.expense import Expense, ExpenseCategory
from app.models.transaction import Transaction
from app.repositories.expense_repo import ExpenseCategoryRepository, ExpenseRepository
from app.schemas.common import money_str
from app.schemas.expense import (
    ExpenseCategoryCreateRequest,
    ExpenseCategoryResponse,
    ExpenseCreateRequest,
    ExpenseResponse,
    ExpenseUpdateRequest,
)
from app.utils.pagination import PaginationParams

_VALID_TRANSACTION_TYPES = {"cash", "upi", "bank"}


class ExpenseCategoryService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.categories = ExpenseCategoryRepository(db)

    async def list_categories(self) -> list[ExpenseCategoryResponse]:
        categories = await self.categories.list_categories(is_active=True)
        return [ExpenseCategoryResponse.model_validate(c) for c in categories]

    async def create_category(self, payload: ExpenseCategoryCreateRequest) -> ExpenseCategoryResponse:
        category = ExpenseCategory(name=payload.name, is_active=True)
        try:
            category = await self.categories.create(category)
            await self.db.commit()
        except Exception as exc:
            await self.db.rollback()
            if "unique" in str(exc).lower() or "duplicate" in str(exc).lower():
                raise ValidationError("A category with this name already exists.", field="name") from exc
            raise
        return ExpenseCategoryResponse.model_validate(category)


class ExpenseService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.expenses = ExpenseRepository(db)
        self.categories = ExpenseCategoryRepository(db)

    async def create_expense(self, payload: ExpenseCreateRequest, current_user: CurrentUser) -> ExpenseResponse:
        category = await self.categories.get_by_id(payload.category_id)
        if category is None:
            raise ValidationError("The selected expense category does not exist.", field="category_id")

        if payload.payment_method is not None and payload.payment_method not in _VALID_TRANSACTION_TYPES:
            raise ValidationError("payment_method must be one of: cash, upi, bank", field="payment_method")

        expense_date = payload.expense_date or date.today()

        expense = Expense(
            category_id=category.id,
            amount=payload.amount,
            expense_date=expense_date,
            description=payload.description,
            status="active",
            created_by=current_user.id,
        )

        try:
            expense = await self.expenses.create(expense)
            await self.db.flush()  # assigns expense.id

            if payload.payment_method is not None:
                transaction = Transaction(
                    transaction_type=payload.payment_method,
                    direction="out",
                    amount=expense.amount,
                    transaction_date=expense_date,
                    related_expense_id=expense.id,
                    created_by=current_user.id,
                )
                self.db.add(transaction)
                await self.db.flush()

            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

        return ExpenseResponse.from_model(expense)

    async def update_expense(self, expense_id: uuid.UUID, payload: ExpenseUpdateRequest) -> ExpenseResponse:
        expense = await self.expenses.get_by_id(expense_id)
        if expense is None:
            raise NotFoundError("Expense not found")
        if expense.status == "voided":
            raise BusinessRuleError("Cannot edit a voided expense.")

        if payload.category_id is not None:
            category = await self.categories.get_by_id(payload.category_id)
            if category is None:
                raise ValidationError("The selected expense category does not exist.", field="category_id")
            expense.category_id = payload.category_id
        if payload.amount is not None:
            expense.amount = payload.amount
        if payload.expense_date is not None:
            expense.expense_date = payload.expense_date
        if payload.description is not None:
            expense.description = payload.description

        expense = await self.expenses.save(expense)
        await self.db.commit()
        return ExpenseResponse.from_model(expense)

    async def void_expense(self, expense_id: uuid.UUID) -> ExpenseResponse:
        expense = await self.expenses.get_by_id(expense_id)
        if expense is None:
            raise NotFoundError("Expense not found")
        if expense.status == "voided":
            raise BusinessRuleError("This expense is already voided.")

        # Voiding an expense does not reverse any linked transaction — that
        # mirrors the same "no automatic reversal" principle used for sale
        # cancellations and bounced cheques (see architecture doc). Staff
        # record any actual money-back movement as a separate transaction.
        expense.status = "voided"
        expense = await self.expenses.save(expense)
        await self.db.commit()
        return ExpenseResponse.from_model(expense)

    async def list_expenses(
        self,
        pagination: PaginationParams,
        category_id: uuid.UUID | None,
        status: str | None,
        date_from: date | None,
        date_to: date | None,
    ):
        items, total, total_amount = await self.expenses.list_expenses(pagination, category_id, status, date_from, date_to)
        return [ExpenseResponse.from_model(e) for e in items], total, money_str(total_amount)
