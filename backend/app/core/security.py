"""
Authentication core: verifies Supabase-issued JWTs and resolves the app's
internal `User` row (with role/permissions) for each request.

Flow:
  1. Flutter authenticates against Supabase Auth directly and receives a JWT.
  2. Flutter sends that JWT as `Authorization: Bearer <token>` to FastAPI.
  3. FastAPI verifies the JWT signature/expiry using SUPABASE_JWT_SECRET
     (HS256, the default for Supabase project JWTs).
  4. FastAPI looks up the internal `users` row by `auth_user_id` (the JWT's
     `sub` claim) to load role + permissions.

We NEVER trust a role/permission claim sent by the client — role always comes
from our own `users`/`roles` tables, resolved server-side on every request.

DIAGNOSTIC LOGGING: every 401 branch below logs its specific reason (via
loguru, at WARNING level) including the auth_user_id where available. This
does not change the response sent to the client — it exists so a real
"why did this login fail" question can be answered from server logs alone,
without weakening the actual security check.
"""
import uuid
from dataclasses import dataclass, field

from fastapi import Depends, Header
from jose import JWTError, jwt
from loguru import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.exceptions import UnauthorizedError
from app.db.session import get_db
from app.models.user import User

settings = get_settings()


@dataclass
class CurrentUser:
    """Lightweight, request-scoped representation of the authenticated user."""

    id: uuid.UUID
    auth_user_id: uuid.UUID
    full_name: str
    role_name: str
    is_active: bool
    email: str | None = None
    permission_keys: set[str] = field(default_factory=set)

    def has_permission(self, key: str) -> bool:
        return key in self.permission_keys

    @property
    def is_admin(self) -> bool:
        return self.role_name == "admin"


def _decode_supabase_jwt(token: str) -> dict:
    try:
        # Supabase project JWTs are signed HS256 with the project's JWT secret.
        # `audience` is typically "authenticated" for logged-in users.
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
            options={"verify_aud": True},
        )
        return payload
    except JWTError as exc:
        # Logging exc's class name (not the token itself) tells us WHICH
        # jose failure fired: ExpiredSignatureError (token genuinely
        # expired), JWTClaimsError (wrong audience — often means the
        # project uses a non-default JWT template), or a generic
        # JWTError (wrong SUPABASE_JWT_SECRET / wrong signing algorithm,
        # e.g. the project has asymmetric JWT signing keys enabled instead
        # of the legacy HS256 shared secret this code assumes).
        logger.warning(f"JWT verification failed: {type(exc).__name__}: {exc}")
        raise UnauthorizedError("Invalid or expired authentication token") from exc


async def get_current_user(
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> CurrentUser:
    if not authorization or not authorization.lower().startswith("bearer "):
        logger.warning("Auth failed: missing or malformed Authorization header")
        raise UnauthorizedError("Missing or malformed Authorization header")

    token = authorization.split(" ", 1)[1].strip()
    payload = _decode_supabase_jwt(token)

    auth_user_id_str = payload.get("sub")
    if not auth_user_id_str:
        logger.warning("Auth failed: JWT payload has no 'sub' claim")
        raise UnauthorizedError("Token missing subject claim")

    try:
        auth_user_id = uuid.UUID(auth_user_id_str)
    except ValueError as exc:
        logger.warning(f"Auth failed: 'sub' claim '{auth_user_id_str}' is not a valid UUID")
        raise UnauthorizedError("Malformed subject claim") from exc

    result = await db.execute(select(User).where(User.auth_user_id == auth_user_id))
    user = result.scalar_one_or_none()

    if user is None:
        # This is the case most likely to be hit by an account created
        # directly in Supabase Auth (or the SQL Editor) without a matching
        # INSERT into public.users — see database/migrations/001_initial_schema.sql
        # and the README's "create your first admin user" step for the
        # pattern this requires.
        logger.warning(
            f"Auth failed: no public.users row for auth_user_id={auth_user_id} "
            f"(Supabase Auth session is valid, but there's no matching app profile)"
        )
        raise UnauthorizedError("No application profile found for this account")

    if not user.is_active:
        logger.warning(f"Auth failed: user {user.id} (auth_user_id={auth_user_id}) is deactivated")
        raise UnauthorizedError("This account has been deactivated")

    permission_keys = {perm.key for perm in user.role.permissions}

    logger.info(f"Auth OK: user {user.id} ({user.role.name}), {len(permission_keys)} permissions")

    return CurrentUser(
        id=user.id,
        auth_user_id=user.auth_user_id,
        full_name=user.full_name,
        role_name=user.role.name,
        is_active=user.is_active,
        email=payload.get("email"),
        permission_keys=permission_keys,
    )
