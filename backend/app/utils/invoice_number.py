"""
Generates sequential, per-financial-year invoice numbers safely under
concurrency.

Format: SKE/{FY}/{seq:05d}  e.g. SKE/2526/00001  (FY = Apr 2025 - Mar 2026)

Uses a single atomic UPSERT against `invoice_number_sequences` (see
database/migrations/001_initial_schema.sql) instead of a read-then-write —
Postgres serializes concurrent UPDATEs to the same row, so two sales created
at the same instant can never receive the same sequence number. This must be
called inside the same DB transaction as the sale/invoice insert so a rolled
back sale doesn't leave a gap-free guarantee broken (gaps are fine; DUPLICATES
are not).
"""
from datetime import date

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


def financial_year_key(d: date) -> str:
    # Indian financial year: April 1 - March 31.
    if d.month >= 4:
        start_year, end_year = d.year, d.year + 1
    else:
        start_year, end_year = d.year - 1, d.year
    return f"{str(start_year)[2:]}{str(end_year)[2:]}"


async def next_invoice_number(db: AsyncSession, for_date: date) -> str:
    fy = financial_year_key(for_date)

    result = await db.execute(
        text(
            """
            INSERT INTO invoice_number_sequences (financial_year, last_sequence)
            VALUES (:fy, 1)
            ON CONFLICT (financial_year)
            DO UPDATE SET last_sequence = invoice_number_sequences.last_sequence + 1
            RETURNING last_sequence
            """
        ),
        {"fy": fy},
    )
    sequence = result.scalar_one()
    return f"SKE/{fy}/{sequence:05d}"
