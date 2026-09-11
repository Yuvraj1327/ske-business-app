"""
Wrapper around Supabase's Admin API (service-role only) for operations
Supabase Auth itself doesn't expose to normal clients — specifically,
creating a user on an admin's behalf (the salesman never self-registers;
an admin creates their account and hands them credentials).

This is the ONLY place the service-role key is used for auth operations.
It must never be reachable from Flutter.
"""
import uuid

from supabase import create_client, Client

from app.config import get_settings
from app.core.exceptions import ConflictError, ValidationError

settings = get_settings()

_admin_client: Client | None = None


def get_admin_client() -> Client:
    global _admin_client
    if _admin_client is None:
        _admin_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    return _admin_client


def create_auth_user(email: str, password: str, full_name: str) -> uuid.UUID:
    """
    Creates a Supabase Auth user via the Admin API and returns its auth
    user id. Email is pre-confirmed since this is an admin-provisioned
    account, not a public self-signup flow.
    """
    client = get_admin_client()
    try:
        result = client.auth.admin.create_user(
            {
                "email": email,
                "password": password,
                "email_confirm": True,
                "user_metadata": {"full_name": full_name},
            }
        )
    except Exception as exc:  # supabase-py raises generic exceptions with .message
        message = getattr(exc, "message", str(exc))
        if "already registered" in message.lower() or "already exists" in message.lower():
            raise ConflictError(f"A user with email '{email}' already exists.") from exc
        raise ValidationError(f"Could not create authentication account: {message}") from exc

    if result.user is None:
        raise ValidationError("Could not create authentication account.")

    return uuid.UUID(result.user.id)


def delete_auth_user(auth_user_id: uuid.UUID) -> None:
    """Best-effort cleanup — used when a DB write fails after the auth user
    was already created, to avoid orphaned Supabase Auth accounts."""
    client = get_admin_client()
    try:
        client.auth.admin.delete_user(str(auth_user_id))
    except Exception:
        # Deliberately swallow — this is a best-effort cleanup path and
        # shouldn't mask the original error that triggered it.
        pass


def update_auth_user_password(auth_user_id: uuid.UUID, new_password: str) -> None:
    client = get_admin_client()
    try:
        client.auth.admin.update_user_by_id(str(auth_user_id), {"password": new_password})
    except Exception as exc:
        message = getattr(exc, "message", str(exc))
        raise ValidationError(f"Could not update password: {message}") from exc
