import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, PermissionDeniedError, ValidationError
from app.core.security import CurrentUser
from app.models.customer import Customer
from app.models.sale import Sale
from app.models.task import Task
from app.models.user import User
from app.repositories.customer_repo import CustomerRepository
from app.repositories.salesman_repo import SalesmanRepository, TaskRepository
from app.schemas.common import money_str
from app.schemas.customer import CustomerResponse
from app.schemas.salesman import (
    AssignCustomerRequest,
    SalesmanPerformanceResponse,
    SalesmanResponse,
    TaskCreateRequest,
    TaskResponse,
)
from app.utils.pagination import PaginationParams


class SalesmanService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.salesmen = SalesmanRepository(db)
        self.customers = CustomerRepository(db)

    async def list_salesmen(self) -> list[SalesmanResponse]:
        salesmen = await self.salesmen.list_salesmen(is_active=True)
        return [SalesmanResponse.model_validate(s) for s in salesmen]

    async def get_salesman_customers(self, salesman_id: uuid.UUID, pagination: PaginationParams):
        salesman = await self.salesmen.get_salesman(salesman_id)
        if salesman is None:
            raise NotFoundError("Salesman not found")
        items, total = await self.customers.list_customers(pagination, None, salesman_id, None)
        return [CustomerResponse.from_model(c) for c in items], total

    async def assign_customer(self, salesman_id: uuid.UUID, payload: AssignCustomerRequest) -> CustomerResponse:
        salesman = await self.salesmen.get_salesman(salesman_id)
        if salesman is None:
            raise NotFoundError("Salesman not found")

        customer = await self.customers.get_by_id(payload.customer_id)
        if customer is None:
            raise ValidationError("Customer does not exist.", field="customer_id")

        customer.assigned_salesman_id = salesman_id
        customer = await self.customers.save(customer)
        await self.db.commit()
        return CustomerResponse.from_model(customer)

    async def get_performance(self, salesman_id: uuid.UUID) -> SalesmanPerformanceResponse:
        salesman = await self.salesmen.get_salesman(salesman_id)
        if salesman is None:
            raise NotFoundError("Salesman not found")

        customers_count_result = await self.db.execute(
            select(func.count()).select_from(Customer).where(Customer.assigned_salesman_id == salesman_id, Customer.is_active.is_(True))
        )
        customers_count = customers_count_result.scalar_one()

        sales_result = await self.db.execute(
            select(func.count(Sale.id), func.coalesce(func.sum(Sale.total_amount), 0))
            .where(Sale.salesman_id == salesman_id, Sale.status == "active")
        )
        sales_count, sales_total = sales_result.one()

        outstanding_result = await self.db.execute(
            select(func.coalesce(func.sum(Sale.total_amount - Sale.paid_amount), 0))
            .join(Customer, Customer.id == Sale.customer_id)
            .where(Customer.assigned_salesman_id == salesman_id, Sale.status == "active")
        )
        outstanding_total = outstanding_result.scalar_one()

        return SalesmanPerformanceResponse(
            salesman_id=salesman_id,
            salesman_name=salesman.full_name,
            customers_count=customers_count,
            sales_count=sales_count,
            sales_total=money_str(sales_total),
            outstanding_total=money_str(outstanding_total),
        )


class TaskService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.tasks = TaskRepository(db)
        self.salesmen = SalesmanRepository(db)

    async def create_task(self, payload: TaskCreateRequest, current_user: CurrentUser) -> TaskResponse:
        assignee_result = await self.db.execute(select(User).where(User.id == payload.assigned_to))
        assignee = assignee_result.scalar_one_or_none()
        if assignee is None:
            raise ValidationError("Assignee does not exist.", field="assigned_to")

        task = Task(
            assigned_to=payload.assigned_to,
            assigned_by=current_user.id,
            title=payload.title,
            description=payload.description,
            due_date=payload.due_date,
            status="pending",
        )
        task = await self.tasks.create(task)
        await self.db.commit()
        return await self._build_response(task)

    async def _build_response(self, task: Task) -> TaskResponse:
        assignee_result = await self.db.execute(select(User).where(User.id == task.assigned_to))
        assignee = assignee_result.scalar_one()
        assigner_result = await self.db.execute(select(User).where(User.id == task.assigned_by))
        assigner = assigner_result.scalar_one()

        return TaskResponse(
            id=task.id,
            assigned_to=task.assigned_to,
            assigned_to_name=assignee.full_name,
            assigned_by=task.assigned_by,
            assigned_by_name=assigner.full_name,
            title=task.title,
            description=task.description,
            due_date=task.due_date,
            status=task.status,
            created_at=task.created_at,
        )

    async def list_tasks(
        self,
        current_user: CurrentUser,
        pagination: PaginationParams,
        assigned_to: uuid.UUID | None,
        status: str | None,
    ):
        # Anyone can list their OWN tasks (assigned_to defaults to self).
        # Listing someone else's tasks requires salesmen.manage.
        if assigned_to is None:
            assigned_to = current_user.id
        elif assigned_to != current_user.id and not current_user.has_permission("salesmen.manage") and not current_user.is_admin:
            raise PermissionDeniedError("You do not have permission to view another user's tasks.")

        items, total = await self.tasks.list_tasks(pagination, assigned_to, status)
        responses = [await self._build_response(t) for t in items]
        return responses, total

    async def update_task_status(self, task_id: uuid.UUID, status: str, current_user: CurrentUser) -> TaskResponse:
        task = await self.tasks.get_by_id(task_id)
        if task is None:
            raise NotFoundError("Task not found")

        is_owner = task.assigned_to == current_user.id
        if not is_owner and not current_user.has_permission("salesmen.manage") and not current_user.is_admin:
            raise PermissionDeniedError("You do not have permission to update this task.")

        task.status = status
        task = await self.tasks.save(task)
        await self.db.commit()
        return await self._build_response(task)
