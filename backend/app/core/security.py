"""
Authentication core: verifies Supabase-issued JWTs and resolves the app's
internal `User` row (with role/permissions) for each request.

Flow:
  1. Flutter authenticates against Supabase Auth directly and receives a JWT.
  2. Flutter sends that JWT as `Authorization: Bearer <token>` to FastAPI.
  3. FastAPI verifies the JWT signature/expiry against the project's signing
     key (see below).
  4. FastAPI looks up the internal `users` row by `auth_user_id` (the JWT's
     `sub` claim) to load role + permissions.

Signing algorithms
------------------
Supabase projects issue tokens in one of two ways, and a project can be
migrated from the first to the second at any time:

  * Legacy: symmetric HS256, signed with the project's shared JWT secret
    (SUPABASE_JWT_SECRET).
  * Current: asymmetric ES256/RS256, signed with a rotating private key whose
    public half is published at `{SUPABASE_URL}/auth/v1/.well-known/jwks.json`
    and selected by the token header's `kid`.

We support both. The token header decides which path is taken, so no config
change is needed when a project rotates to asymmetric keys. JWKS responses are
cached in-process and re-fetched when an unknown `kid` appears (key rotation).

We NEVER trust a role/permission claim sent by the client — role always comes
from our own `users`/`roles` tables, resolved server-side on every request.
"""
import threading
import time
import uuid
from dataclasses import dataclass, field

import httpx
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

# Claims every Supabase user token carries.
_EXPECTED_AUDIENCE = "authenticated"
_EXPECTED_ISSUER = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1"
_JWKS_URL = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json"

# Refetch at most this often when a `kid` misses, so a bogus token cannot make
# us hammer the JWKS endpoint.
_JWKS_MIN_REFRESH_SECONDS = 60


class _JwksCache:
    """Thread-safe in-process cache of the project's public signing keys."""

    def __init__(self) -> None:
        self._keys: dict[str, dict] = {}
        self._fetched_at: float = 0.0
        self._lock = threading.Lock()

    def _fetch(self) -> None:
        response = httpx.get(_JWKS_URL, timeout=10.0)
        response.raise_for_status()
        keys = response.json().get("keys", [])
        self._keys = {key["kid"]: key for key in keys if "kid" in key}
        self._fetched_at = time.monotonic()
        logger.debug(f"Loaded {len(self._keys)} Supabase JWKS signing key(s)")

    def get(self, kid: str) -> dict | None:
        with self._lock:
            key = self._keys.get(kid)
            if key is not None:
                return key

            # Unknown kid: either first use, or the project rotated its keys.
            stale = time.monotonic() - self._fetched_at > _JWKS_MIN_REFRESH_SECONDS
            if self._keys and not stale:
                return None
            try:
                self._fetch()
            except Exception as exc:  # network/JWKS outage
                logger.error(f"Failed to fetch Supabase JWKS from {_JWKS_URL}: {exc}")
                return None
            return self._keys.get(kid)


_jwks_cache = _JwksCache()


@dataclass
class CurrentUser:
    """Lightweight, request-scoped representation of the authenticated user."""

    id: uuid.UUID
    auth_user_id: uuid.UUID
    full_name: str
    role_name: str
    is_active: bool
    permission_keys: set[str] = field(default_factory=set)

    def has_permission(self, key: str) -> bool:
        return key in self.permission_keys

    @property
    def is_admin(self) -> bool:
        return self.role_name == "admin"


def _decode_supabase_jwt(token: str) -> dict:
    """Verify a Supabase access token's signature, expiry, audience and issuer."""
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise UnauthorizedError("Malformed authentication token") from exc

    alg = header.get("alg", "HS256")

    if alg == "HS256":
        # Legacy symmetric signing with the project's shared JWT secret.
        key: object = settings.SUPABASE_JWT_SECRET
    else:
        # Asymmetric signing (ES256/RS256) — resolve the public key by `kid`.
        kid = header.get("kid")
        if not kid:
            raise UnauthorizedError("Authentication token missing key id")
        jwk = _jwks_cache.get(kid)
        if jwk is None:
            raise UnauthorizedError("Unknown authentication token signing key")
        key = jwk

    try:
        return jwt.decode(
            token,
            key,
            algorithms=[alg],
            audience=_EXPECTED_AUDIENCE,
            issuer=_EXPECTED_ISSUER,
            options={"verify_aud": True, "verify_iss": True},
        )
    except JWTError as exc:
        raise UnauthorizedError("Invalid or expired authentication token") from exc


async def get_current_user(
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> CurrentUser:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise UnauthorizedError("Missing or malformed Authorization header")

    token = authorization.split(" ", 1)[1].strip()
    payload = _decode_supabase_jwt(token)

    auth_user_id_str = payload.get("sub")
    if not auth_user_id_str:
        raise UnauthorizedError("Token missing subject claim")

    try:
        auth_user_id = uuid.UUID(auth_user_id_str)
    except ValueError as exc:
        raise UnauthorizedError("Malformed subject claim") from exc

    result = await db.execute(select(User).where(User.auth_user_id == auth_user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise UnauthorizedError("No application profile found for this account")
    if not user.is_active:
        raise UnauthorizedError("This account has been deactivated")

    permission_keys = {perm.key for perm in user.role.permissions}

    return CurrentUser(
        id=user.id,
        auth_user_id=user.auth_user_id,
        full_name=user.full_name,
        role_name=user.role.name,
        is_active=user.is_active,
        permission_keys=permission_keys,
    )
