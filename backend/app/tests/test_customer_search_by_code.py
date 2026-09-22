"""Customer Code suffix search (Settlement Sheet's relaxed "last 6 digits"
lookup) — the permission check and length validation both run before any
DB access, so they're safe to exercise directly against CustomerService
without a database, same approach as test_settlement_business_rules.py."""
import uuid

import pytest

from app.core.exceptions import PermissionDeniedError, ValidationError
from app.core.security import CurrentUser
from app.services.customer_service import CustomerService


def _make_user(role_name: str, permissions: set[str]) -> CurrentUser:
    return CurrentUser(
        id=uuid.uuid4(),
        auth_user_id=uuid.uuid4(),
        full_name="Test User",
        role_name=role_name,
        is_active=True,
        permission_keys=permissions,
    )


@pytest.fixture
def service() -> CustomerService:
    return CustomerService(db=None)


@pytest.mark.asyncio
async def test_search_by_code_rejects_user_without_customer_permissions(service):
    user = _make_user("salesman", set())
    with pytest.raises(PermissionDeniedError):
        await service.search_by_code("103533", user)


@pytest.mark.asyncio
async def test_search_by_code_requires_at_least_three_characters(service):
    user = _make_user("admin", {"customers.view_all"})
    with pytest.raises(ValidationError):
        await service.search_by_code("12", user)


@pytest.mark.asyncio
async def test_search_by_code_strips_whitespace_before_length_check(service):
    user = _make_user("admin", {"customers.view_all"})
    with pytest.raises(ValidationError):
        await service.search_by_code("  1  ", user)
