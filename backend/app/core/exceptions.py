"""
Typed exception hierarchy used throughout services.

Services should raise these instead of returning None/False on failure, and
instead of raising raw HTTPException — that keeps business logic decoupled
from FastAPI/HTTP concerns. app/core/exception_handlers.py maps each of these
to a consistent JSON error response.
"""


class AppError(Exception):
    """Base class for all application-raised errors."""

    code: str = "APP_ERROR"
    status_code: int = 500

    def __init__(self, message: str, field: str | None = None):
        self.message = message
        self.field = field
        super().__init__(message)


class NotFoundError(AppError):
    code = "NOT_FOUND"
    status_code = 404


class ValidationError(AppError):
    code = "VALIDATION_ERROR"
    status_code = 422


class PermissionDeniedError(AppError):
    code = "PERMISSION_DENIED"
    status_code = 403


class UnauthorizedError(AppError):
    code = "UNAUTHORIZED"
    status_code = 401


class ConflictError(AppError):
    code = "CONFLICT"
    status_code = 409


class BusinessRuleError(AppError):
    """Raised when an operation violates a domain business rule
    (e.g. returning more items than were sold)."""

    code = "BUSINESS_RULE_VIOLATION"
    status_code = 400
