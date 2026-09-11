"""
Provision an app-domain profile for an existing Supabase Auth user.

Supabase Auth owns credentials (the `auth.users` row), but this app owns the
profile that carries role and permissions (the public `users` row). Migration
001 seeds roles and permissions but deliberately cannot seed `users`, because
the auth user must exist first. Without this step every login authenticates
successfully against Supabase and then fails at `/auth/me` with
"No application profile found for this account".

This script bridges the two: it looks the auth user up by email via the Admin
API and inserts (or updates) the matching `users` row. It is idempotent.

Usage:
    python -m scripts.provision_user --email admin@skegmail.com \
        --role admin --full-name "Admin"

Run from the `backend/` directory, with .env populated.
"""
import argparse
import asyncio
import sys
import uuid

import httpx
from sqlalchemy import select

from app.config import get_settings
from app.db.session import AsyncSessionLocal, engine
from app.models.role import Role
from app.models.user import User

settings = get_settings()


async def _find_auth_user_id(email: str) -> uuid.UUID:
    """Look up a Supabase Auth user by email using the service-role Admin API."""
    url = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/admin/users"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(url, headers=headers, params={"page": 1, "per_page": 1000})
        response.raise_for_status()
        payload = response.json()

    users = payload.get("users", payload if isinstance(payload, list) else [])
    for user in users:
        if (user.get("email") or "").lower() == email.lower():
            return uuid.UUID(user["id"])

    raise SystemExit(
        f"No Supabase Auth user found with email {email!r}. "
        f"Create the account in Supabase Auth first, then re-run this script."
    )


async def provision(email: str, role_name: str, full_name: str, phone: str | None) -> None:
    auth_user_id = await _find_auth_user_id(email)
    print(f"Supabase auth user: {auth_user_id}")

    async with AsyncSessionLocal() as session:
        role = (
            await session.execute(select(Role).where(Role.name == role_name))
        ).scalar_one_or_none()
        if role is None:
            available = [r.name for r in (await session.execute(select(Role))).scalars()]
            raise SystemExit(f"Role {role_name!r} not found. Available roles: {available}")

        user = (
            await session.execute(select(User).where(User.auth_user_id == auth_user_id))
        ).scalar_one_or_none()

        if user is None:
            user = User(
                auth_user_id=auth_user_id,
                full_name=full_name,
                phone=phone,
                role_id=role.id,
                is_active=True,
            )
            session.add(user)
            action = "Created"
        else:
            user.full_name = full_name
            if phone is not None:
                user.phone = phone
            user.role_id = role.id
            user.is_active = True
            action = "Updated"

        await session.commit()
        await session.refresh(user)

    print(f"{action} profile {user.id} for {email} with role '{role_name}'")
    await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", required=True, help="Email of the existing Supabase Auth user")
    parser.add_argument("--role", default="admin", help="Role name (default: admin)")
    parser.add_argument("--full-name", required=True, help="Display name for the profile")
    parser.add_argument("--phone", default=None, help="Optional phone number")
    args = parser.parse_args()

    asyncio.run(provision(args.email, args.role, args.full_name, args.phone))


if __name__ == "__main__":
    sys.exit(main())
