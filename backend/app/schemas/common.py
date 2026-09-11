"""
Shared schema helpers.

Money amounts are always serialized as strings (e.g. "1234.56") rather than
JSON numbers, so Flutter never has to worry about floating-point rounding
when parsing them — it parses the string with Decimal-safe intent and only
converts to double at the very last step, for display formatting only.
"""
from decimal import ROUND_HALF_UP, Decimal


def money_str(value: Decimal | int | float | None) -> str:
    if value is None:
        value = Decimal("0")
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return str(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
