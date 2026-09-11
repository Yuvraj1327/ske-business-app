"""
Auth endpoints.

Note: actual login/signup is performed by the Flutter app talking directly to
Supabase Auth (email/password or OTP) — FastAPI does not issue its own
tokens. This router only exposes endpoints that need server-side identity
resolution, starting with `/auth/me`, which Flutter calls right after login
to fetch the user's role/permissions and confirm the token is valid against
our backend.
"""
from fastapi import APIRouter, Depends

from app.core.security import CurrentUser, get_current_user
from app.schemas.auth import CurrentUserResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/me", response_model=CurrentUserResponse)
async def get_me(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUserResponse:
    return CurrentUserResponse(
        id=current_user.id,
        full_name=current_user.full_name,
        role_name=current_user.role_name,
        is_active=current_user.is_active,
        permissions=sorted(current_user.permission_keys),
    )
