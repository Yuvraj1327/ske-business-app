# Sai Krishna Enterprises — Business Management Application

A complete business management system: Flutter (mobile + web admin) on top
of a FastAPI backend, backed by Supabase (PostgreSQL, Auth, Storage).

```
Flutter App  →  REST API  →  FastAPI Backend  →  Supabase PostgreSQL
                                                 (+ Storage, Auth)
```

**Status: all 15 planned build steps are implemented.** Authentication &
roles, dashboard, customers, products, sales & invoices, payments (incl.
cheques), cash/UPI/bank transactions, sales returns, expenses, salesman
management, reports, Excel import, an automated test suite, and this
deployment guide.

---

## 1. Prerequisites

- Python 3.11+
- Flutter 3.22+ (Dart 3.3+)
- A free [Supabase](https://supabase.com) project
- (Optional, for production-scale Excel imports) Redis + a task queue — see
  §8 "Known limitations and recommended production hardening"

---

## 2. Supabase Setup

1. Create a new project at [supabase.com](https://supabase.com).
2. In **Project Settings → API**, note down:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` key → `SUPABASE_ANON_KEY`
   - `service_role` key → `SUPABASE_SERVICE_ROLE_KEY` (**backend only, never in Flutter**)
   - `JWT Secret` → `SUPABASE_JWT_SECRET`
3. In **Project Settings → Database**, copy the connection string (URI) → `DATABASE_URL`
   (use the `asyncpg`-compatible form: `postgresql+asyncpg://...`).
4. Open the **SQL Editor** and run the migration:
   ```
   database/migrations/001_initial_schema.sql
   ```
   This creates all tables, indexes, RLS policies, and seeds the `admin` /
   `salesman` roles with default permissions plus a few expense categories.
5. Create your first admin user:
   - In **Authentication → Users**, add a user (email + password). Copy their
     generated `auth_user_id` (the UUID shown in the Supabase Auth users table).
   - In the SQL Editor, link them to the `admin` role:
     ```sql
     insert into users (auth_user_id, full_name, role_id, is_active)
     values (
       '<paste-the-auth-user-id-here>',
       'Admin User',
       (select id from roles where name = 'admin'),
       true
     );
     ```
   - Every subsequent user (more admins or salesmen) can be created directly
     from the app's **Users** screen — no more manual SQL needed.

---

## 3. Backend Setup (FastAPI)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# Edit .env with your Supabase values from step 2 above
```

Run the API:

```bash
uvicorn app.main:app --reload --port 8000
```

Verify it's running:

```bash
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/health/db
```

Interactive API docs: http://localhost:8000/docs

### Backend environment variables

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Public anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | Service-role key — **server only** |
| `SUPABASE_JWT_SECRET` | Used to verify JWTs issued by Supabase Auth |
| `DATABASE_URL` | Direct Postgres connection string (asyncpg form) |
| `SECRET_KEY` | Random string for any internal signing needs |
| `CORS_ORIGINS` | Comma-separated list of allowed origins |

---

## 4. Flutter Setup

```bash
cd flutter_app
flutter pub get

cp .env.example .env
# Edit .env: set SUPABASE_URL, SUPABASE_ANON_KEY (same as backend's),
# and API_BASE_URL to point at your running FastAPI instance.
```

**Choosing `API_BASE_URL`:**
- Android emulator → `http://10.0.2.2:8000/api/v1`
- iOS simulator → `http://localhost:8000/api/v1`
- Physical device → `http://<your-computer's-LAN-IP>:8000/api/v1`
- Flutter Web (admin panel) → `http://localhost:8000/api/v1` (ensure `CORS_ORIGINS` includes the web app's origin)

Run on Android: `flutter run`
Run as web (admin panel): `flutter run -d chrome`

Log in with the admin user you created in Supabase. You should land on the
dashboard with the full navigation: Dashboard, Customers, Products, Sales,
Payments, Cash/UPI/Bank, Sales Returns, Expenses, Salesmen, Reports, Excel
Import, Users, Roles & Permissions.

---

## 5. Running the Test Suite

```bash
cd backend
source .venv/bin/activate
pip install -r requirements.txt   # pytest + pytest-asyncio are included
pytest -v
```

**What's covered (33 passing tests, all executable without a database):**
- Decimal-safe money math (no float rounding errors)
- Invoice financial-year numbering boundaries (Apr 1 rollover)
- Payment-status derivation, shared identically by payments and returns
- Proportional refund math when a return is made against a discounted line
- Pydantic request validation (cheque-required-fields, sale line items, task status)
- Permission allow/deny logic (`require_permission`, `require_any_permission`)
- Excel import row parsing/validation against real in-memory `.xlsx` workbooks

**What's NOT covered here, and why:** full CRUD/transactional integration
tests (e.g. "create a sale end-to-end and confirm the row in Postgres")
need a real database — either a local Supabase dev stack (`supabase start`)
or a disposable test Postgres container — because they exercise actual SQL
constraints and transaction behavior that can't be faithfully mocked. To add
these: point a test `DATABASE_URL` at a disposable database, run the
migration against it, and wrap each test in a session/transaction that rolls
back at the end. This is the natural next investment before a production
launch — see §8.

Flutter tests were not added in this pass; the highest-value additions
would be widget tests for the Create Sale and Record Payment forms (the
two most complex client-side flows) and a repository-mocked provider test
for the permission-filtered navigation.

---

## 6. Project Structure

```
ske-app/
├── database/
│   └── migrations/
│       └── 001_initial_schema.sql   # full schema, RLS, seed data
├── backend/
│   ├── app/
│   │   ├── main.py                  # FastAPI entrypoint
│   │   ├── config.py                # env-based settings
│   │   ├── core/                    # security, permissions, exceptions
│   │   ├── db/                      # SQLAlchemy engine/session/base
│   │   ├── models/                  # ORM models (every table)
│   │   ├── schemas/                 # Pydantic request/response models
│   │   ├── repositories/            # DB query layer, one per domain
│   │   ├── services/                # business logic, one per domain
│   │   ├── api/v1/                  # route modules, one per domain
│   │   └── tests/                   # pytest suite (see §5)
│   ├── requirements.txt
│   ├── pytest.ini
│   └── .env.example
└── flutter_app/
    ├── lib/
    │   ├── app/                     # app shell, router, theme
    │   ├── core/                    # network, auth, permissions, widgets, utils
    │   └── features/
    │       ├── auth/          ├── payments/       ├── expenses/
    │       ├── dashboard/     ├── transactions/    ├── salesmen/
    │       ├── customers/     ├── returns/          ├── reports/
    │       ├── products/      ├── users/            ├── imports/
    │       ├── sales/         └── roles/
    ├── pubspec.yaml
    └── .env.example
```

## 7. Architecture Notes

- **Flutter never talks to Supabase for business data** — only for
  authentication (sign-in/out) and to hold the session. All customer, sales,
  payment, etc. data flows through FastAPI, which is the sole place business
  rules, calculations, and permission checks are enforced.
- **Row Level Security is defense-in-depth, not the primary gate.** FastAPI
  connects with the service-role key (bypasses RLS) and is the trusted
  authorization boundary.
- **Roles and permissions are fully data-driven** — adding a new role or
  permission never requires a code change, only a data change plus wiring
  `require_permission("...")` on new routes as they're built.
- **Every money calculation happens server-side in Decimal**, never trusting
  a client-sent total, and is serialized to JSON as a string (not a float)
  so Flutter never has to worry about floating-point precision when parsing.
- **"No automatic reversal" is a consistent rule** across sale cancellation,
  bounced cheques, voided expenses, and sales returns: none of these
  automatically undo a payment or transaction that already happened. Staff
  record any actual money-back movement as a separate, explicit action. This
  was a deliberate simplification everywhere the original requirements
  didn't specify a reversal rule, rather than inventing accounting behavior.

## 8. Known Limitations and Recommended Production Hardening

Being upfront about what would need attention before a real production
launch, beyond what's already built:

1. **No live database testing performed.** Every backend verification in
   this build was static: Python compilation, SQLAlchemy ORM mapper
   resolution (`configure_mappers()`), and pure-function unit tests (§5).
   The full request→service→repository→Postgres path has not been exercised
   against a real Supabase instance. **Test the complete flows yourself**
   (login → create customer → create sale → record payment → check
   dashboard/reports) before relying on this in production.
2. **Excel Storage is simplified.** Uploaded files are parsed directly from
   the request and not persisted to a Supabase Storage bucket — see the
   docstring in `app/services/import_service.py` for exactly what to change
   to add real Storage persistence.
3. **Import processing uses FastAPI `BackgroundTasks`, not a real job
   queue.** Fine for realistic small-business file sizes; for very large
   files or multi-worker/multi-server deployments, swap in Celery/RQ + Redis
   — the processing function itself (`process_import_job`) doesn't need to
   change, only how it's invoked.
4. **RLS policies exist only for `users`, `customers`, `sales`, `payments`,
   `expenses`** (from the Step 1 migration). Tables added since (`sale_items`,
   `invoices`, `cheque_details`, `transactions`, `sales_returns`, `tasks`,
   `import_jobs`, etc.) don't yet have explicit policies. This is safe today
   because FastAPI's service-role connection bypasses RLS entirely and is
   the actual enforcement point — but if you ever expose the Supabase anon
   key to a context that queries these tables directly, add policies first.
5. **No rate limiting is wired to specific sensitive endpoints** — `slowapi`
   is installed and available in `app/main.py`, but individual routes (like
   `/auth/me` or `/imports/upload`) don't yet have per-route limits applied.
6. **Multi-salesman-per-customer isn't implemented.** The database keeps a
   `salesman_customer_assignments` junction table for it, but the app uses
   the simpler single `customers.assigned_salesman_id` column — this was an
   explicit, documented decision (see the architecture doc's original open
   assumptions) rather than an oversight.
7. **No integration/E2E test coverage** (see §5) and **no Flutter test
   coverage** yet.

## 9. Deployment Architecture

```
Flutter Android APK/AAB → Play Store (or direct APK distribution for internal use)
Flutter Web (Admin)     → static hosting (e.g., Netlify/Vercel/Firebase Hosting)

FastAPI                 → containerized (Docker), deployed to a small VM or
                           container platform (Railway, Render, Fly.io, or a
                           basic VM + gunicorn/uvicorn workers) behind HTTPS

Supabase                 → managed Postgres + Storage + Auth (hosted by Supabase)

Environment separation   → separate Supabase projects (or schemas) + separate
                            FastAPI env configs for staging vs production
```

### Minimal Dockerfile for the backend

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Flutter Android build

```bash
cd flutter_app
flutter build apk --release --dart-define-from-file=.env
# or for Play Store:
flutter build appbundle --release --dart-define-from-file=.env
```

### Flutter Web (admin panel) build

```bash
cd flutter_app
flutter build web --release
# deploy the build/web/ directory to your static host
```

Remember to set production values for `CORS_ORIGINS` (backend) and
`API_BASE_URL` / `SUPABASE_URL` / `SUPABASE_ANON_KEY` (Flutter `.env`) before
building for production — none of the example values in `.env.example` are
usable as-is.
