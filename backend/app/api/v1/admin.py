from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import require_admin
from app.core.security import CurrentUser
from app.db.session import get_db
from app.schemas.admin import ResetDataRequest, ResetDataResponse
from app.services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/reset-data", response_model=ResetDataResponse)
async def reset_data(
    payload: ResetDataRequest,
    db: AsyncSession = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin()),
) -> ResetDataResponse:
    """
    Settings -> Reset Data. Requires the admin's current password
    (verified against Supabase Auth — see core/auth_verification.py) before
    any deletion happens. See app/services/admin_service.py for exactly
    what is and isn't cleared, and why the deletion order is safe.
    """
    service = AdminService(db)
    return await service.reset_business_data(current_user, payload.password)
