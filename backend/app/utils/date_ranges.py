"""
Resolves a dashboard/report date-range query into concrete start/end dates.
Centralized so "today", "this week", "this month" mean the same thing
everywhere in the API (dashboard, reports, etc.) instead of each endpoint
defining its own notion of a week/month boundary.
"""
from datetime import date, timedelta

from app.core.exceptions import ValidationError

VALID_RANGE_KEYS = {"today", "week", "month", "custom"}


def resolve_range(range_key: str, custom_from: date | None, custom_to: date | None) -> tuple[date, date]:
    if range_key not in VALID_RANGE_KEYS:
        raise ValidationError(
            f"Invalid range '{range_key}'. Use one of: today, week, month, custom.", field="range"
        )

    today = date.today()

    if range_key == "today":
        return today, today

    if range_key == "week":
        # Week starts Monday.
        start = today - timedelta(days=today.weekday())
        return start, today

    if range_key == "month":
        start = today.replace(day=1)
        return start, today

    # custom
    if custom_from is None or custom_to is None:
        raise ValidationError("'from' and 'to' are required when range=custom.", field="from")
    if custom_from > custom_to:
        raise ValidationError("'from' date must not be after 'to' date.", field="from")
    return custom_from, custom_to
