"""
Permission-checking logic, exercised directly against CurrentUser without a
database. `require_permission`'s inner dependency function only needs an
already-resolved CurrentUser (DB lookup happens earlier, in
get_current_user) — so we can call it directly here to prove the
allow/deny decision itself is correct, independent of DB/HTTP plumbing.
"""
import uuid

import pytest

from app.core.exceptions import PermissionDeniedError
from app.core.permissions import require_any_permission, require_permission
from app.core.security import CurrentUser


def _make_user(role_name: str, permissions: set[str]) -> CurrentUser:
    return CurrentUser(
        id=uuid.uuid4(),
        auth_user_id=uuid.uuid4(),
        full_name="Test User",
        role_name=role_name,
        is_active=True,
        permission_keys=permissions,
    )


@pytest.mark.asyncio
async def test_require_permission_allows_user_with_permission():
    user = _make_user("salesman", {"sales.create"})
    dependency = require_permission("sales.create")
    result = await dependency(current_user=user)
    assert result is user


@pytest.mark.asyncio
async def test_require_permission_denies_user_without_permission():
    user = _make_user("salesman", {"sales.create"})
    dependency = require_permission("users.manage")
    with pytest.raises(PermissionDeniedError):
        await dependency(current_user=user)


@pytest.mark.asyncio
async def test_require_any_permission_allows_if_any_match():
    user = _make_user("salesman", {"sales.view_assigned"})
    dependency = require_any_permission("sales.view_all", "sales.view_assigned")
    result = await dependency(current_user=user)
    assert result is user


@pytest.mark.asyncio
async def test_require_any_permission_denies_if_none_match():
    user = _make_user("salesman", {"dashboard.view"})
    dependency = require_any_permission("sales.view_all", "sales.view_assigned")
    with pytest.raises(PermissionDeniedError):
        await dependency(current_user=user)


def test_is_admin_reflects_role_name():
    admin = _make_user("admin", set())
    salesman = _make_user("salesman", set())
    assert admin.is_admin is True
    assert salesman.is_admin is False


def test_has_permission_checks_exact_key():
    user = _make_user("salesman", {"customers.view_assigned"})
    assert user.has_permission("customers.view_assigned") is True
    assert user.has_permission("customers.view_all") is False
