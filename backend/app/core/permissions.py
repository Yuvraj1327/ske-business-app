"""
Route-level permission enforcement.

Usage on any route:

    @router.post("/customers", dependencies=[Depends(require_permission("customers.create"))])
    async def create_customer(...): ...

This answers "can this user call this endpoint at all". Row-level scoping
(e.g. "a salesman only sees their assigned customers") is a separate concern
handled in the service/repository layer via CurrentUser, not here.
"""
from fastapi import Depends

from app.core.exceptions import PermissionDeniedError
from app.core.security import CurrentUser, get_current_user


def require_permission(permission_key: str):
    async def _dependency(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if not current_user.has_permission(permission_key):
            raise PermissionDeniedError(
                f"You do not have permission to perform this action ('{permission_key}' required)."
            )
        return current_user

    return _dependency


def require_any_permission(*permission_keys: str):
    async def _dependency(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if not any(current_user.has_permission(key) for key in permission_keys):
            raise PermissionDeniedError(
                f"You do not have permission to perform this action (one of {permission_keys} required)."
            )
        return current_user

    return _dependency


def require_admin():
    async def _dependency(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if not current_user.is_admin:
            raise PermissionDeniedError("This action requires admin access.")
        return current_user

    return _dependency
