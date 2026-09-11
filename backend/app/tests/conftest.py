"""
Shared pytest fixtures.

IMPORTANT — what these tests can and cannot cover without a real database:
Full CRUD/transactional integration tests (e.g. "create a sale end-to-end
and confirm the row exists in Postgres") require a real Postgres instance —
either a local Supabase dev stack (`supabase start`) or a disposable test
Postgres container — because they exercise actual SQL, constraints, and
transactions that can't be faithfully simulated with mocks.

What CAN be verified without a database, and what this test suite actually
covers, is every pure calculation and validation rule: money math, invoice
numbering, payment-status derivation, proportional refund math, and Pydantic
schema validation. These are exactly the places a silent bug would be most
costly (wrong totals, wrong invoice numbers), so they're covered here with
real, executable, passing tests — not just asserted in prose.

To add DB-backed integration tests later: point DATABASE_URL at a disposable
test database, run the migration, and use SQLAlchemy's session directly in a
fixture that wraps each test in a transaction it rolls back at the end.
"""
import os

# Provide minimal required env vars so `app.config.get_settings()` (imported
# transitively by nearly everything) doesn't fail during test collection.
os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "test-anon-key")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-service-key")
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-jwt-secret")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://postgres:password@localhost:5432/postgres")
os.environ.setdefault("SECRET_KEY", "test-secret-key")

# Async tests use @pytest.mark.asyncio (pytest-asyncio, strict mode — the
# default), not the anyio plugin, matching what's in requirements.txt.
