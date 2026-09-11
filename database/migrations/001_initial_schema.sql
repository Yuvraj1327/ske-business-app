-- ============================================================================
-- Sai Krishna Enterprises — Business Management Application
-- Migration 001: Initial Schema
-- Target: Supabase PostgreSQL
-- ============================================================================
-- Run this in the Supabase SQL Editor, or via `supabase db push` /
-- `psql "$DATABASE_URL" -f database/migrations/001_initial_schema.sql`
-- ============================================================================

create extension if not exists "pgcrypto"; -- for gen_random_uuid()

-- ----------------------------------------------------------------------------
-- Generic updated_at trigger
-- ----------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- ----------------------------------------------------------------------------
-- ROLES & PERMISSIONS (RBAC core)
-- ----------------------------------------------------------------------------
create table roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,           -- e.g. 'customers.create'
  module text not null,               -- e.g. 'customers' (used to group in admin UI)
  description text,
  created_at timestamptz not null default now()
);

create table role_permissions (
  role_id uuid not null references roles(id) on delete cascade,
  permission_id uuid not null references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create trigger trg_roles_updated_at before update on roles
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- USERS (app-domain profile, mirrors Supabase auth.users)
-- ----------------------------------------------------------------------------
create table users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique,  -- FK conceptually -> auth.users.id (Supabase managed)
  full_name text not null,
  phone text,
  role_id uuid not null references roles(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_users_role_id on users(role_id);
create index idx_users_auth_user_id on users(auth_user_id);
create index idx_users_is_active on users(is_active);

create trigger trg_users_updated_at before update on users
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- CUSTOMERS
-- ----------------------------------------------------------------------------
create table customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  address text,
  gst_number text,
  assigned_salesman_id uuid references users(id),
  is_active boolean not null default true,
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_customers_phone on customers(phone);
create index idx_customers_assigned_salesman on customers(assigned_salesman_id);
create index idx_customers_name_trgm on customers using gin (name gin_trgm_ops);

create extension if not exists pg_trgm;

create trigger trg_customers_updated_at before update on customers
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- PRODUCTS
-- ----------------------------------------------------------------------------
create table products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sku text unique,
  unit text not null default 'pcs',
  default_price numeric(12,2) not null check (default_price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_products_is_active on products(is_active);
create index idx_products_name_trgm on products using gin (name gin_trgm_ops);

create trigger trg_products_updated_at before update on products
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- SALES & SALE ITEMS
-- ----------------------------------------------------------------------------
create type payment_status_enum as enum ('unpaid', 'partial', 'paid');
create type sale_status_enum as enum ('active', 'cancelled');

create table sales (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  salesman_id uuid references users(id),
  sale_date date not null default current_date,
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  payment_status payment_status_enum not null default 'unpaid',
  status sale_status_enum not null default 'active',
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_sales_customer_id on sales(customer_id);
create index idx_sales_salesman_id on sales(salesman_id);
create index idx_sales_sale_date on sales(sale_date);
create index idx_sales_status on sales(status);

create trigger trg_sales_updated_at before update on sales
  for each row execute function set_updated_at();

create table sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id) on delete cascade,
  product_id uuid not null references products(id),
  quantity numeric(10,2) not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_discount numeric(12,2) not null default 0 check (line_discount >= 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);

create index idx_sale_items_sale_id on sale_items(sale_id);
create index idx_sale_items_product_id on sale_items(product_id);

-- ----------------------------------------------------------------------------
-- INVOICES
-- ----------------------------------------------------------------------------
create type invoice_status_enum as enum ('generated', 'void');

create table invoices (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null unique references sales(id),
  invoice_number text not null unique,
  invoice_date date not null default current_date,
  pdf_url text,
  status invoice_status_enum not null default 'generated',
  created_at timestamptz not null default now()
);

create index idx_invoices_invoice_number on invoices(invoice_number);

-- Sequence-tracking table for per-financial-year invoice numbering
create table invoice_number_sequences (
  financial_year text primary key,   -- e.g. '2526'
  last_sequence integer not null default 0
);

-- ----------------------------------------------------------------------------
-- PAYMENTS & CHEQUE DETAILS
-- ----------------------------------------------------------------------------
create type payment_method_enum as enum ('cash', 'upi', 'bank_transfer', 'cheque');
create type payment_state_enum as enum ('pending', 'cleared', 'cancelled');

create table payments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  sale_id uuid references sales(id),
  amount numeric(12,2) not null check (amount > 0),
  payment_method payment_method_enum not null,
  payment_date date not null default current_date,
  status payment_state_enum not null default 'cleared',
  received_by uuid references users(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_payments_customer_id on payments(customer_id);
create index idx_payments_sale_id on payments(sale_id);
create index idx_payments_method on payments(payment_method);
create index idx_payments_status on payments(status);
create index idx_payments_payment_date on payments(payment_date);

create trigger trg_payments_updated_at before update on payments
  for each row execute function set_updated_at();

create table cheque_details (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null unique references payments(id) on delete cascade,
  cheque_number text not null,
  cheque_date date not null,
  bank_name text not null,
  cleared_date date
);

-- ----------------------------------------------------------------------------
-- SALES RETURNS
-- ----------------------------------------------------------------------------
create type return_status_enum as enum ('completed', 'cancelled');

create table sales_returns (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id),
  customer_id uuid not null references customers(id),
  return_date date not null default current_date,
  total_return_amount numeric(12,2) not null check (total_return_amount >= 0),
  reason text,
  status return_status_enum not null default 'completed',
  created_by uuid references users(id),
  created_at timestamptz not null default now()
);

create index idx_sales_returns_sale_id on sales_returns(sale_id);
create index idx_sales_returns_customer_id on sales_returns(customer_id);

create table sales_return_items (
  id uuid primary key default gen_random_uuid(),
  sales_return_id uuid not null references sales_returns(id) on delete cascade,
  sale_item_id uuid not null references sale_items(id),
  quantity numeric(10,2) not null check (quantity > 0),
  amount numeric(12,2) not null check (amount >= 0)
);

create index idx_sales_return_items_return_id on sales_return_items(sales_return_id);

-- ----------------------------------------------------------------------------
-- UNIFIED TRANSACTIONS (Cash / UPI / Bank)
-- ----------------------------------------------------------------------------
create type transaction_type_enum as enum ('cash', 'upi', 'bank');
create type transaction_direction_enum as enum ('in', 'out');

create table transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_type transaction_type_enum not null,
  direction transaction_direction_enum not null,
  amount numeric(12,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  related_payment_id uuid references payments(id),
  related_expense_id uuid,  -- FK added after expenses table is created below
  reference_note text,
  created_by uuid references users(id),
  created_at timestamptz not null default now()
);

create index idx_transactions_type on transactions(transaction_type);
create index idx_transactions_date on transactions(transaction_date);
create index idx_transactions_direction on transactions(direction);

-- ----------------------------------------------------------------------------
-- EXPENSES
-- ----------------------------------------------------------------------------
create table expense_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table expenses (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references expense_categories(id),
  amount numeric(12,2) not null check (amount > 0),
  expense_date date not null default current_date,
  description text,
  status text not null default 'active', -- 'active' | 'voided'
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_expenses_category_id on expenses(category_id);
create index idx_expenses_date on expenses(expense_date);

create trigger trg_expenses_updated_at before update on expenses
  for each row execute function set_updated_at();

alter table transactions
  add constraint fk_transactions_expense
  foreign key (related_expense_id) references expenses(id);

-- ----------------------------------------------------------------------------
-- SALESMAN <-> CUSTOMER ASSIGNMENTS & TASKS
-- ----------------------------------------------------------------------------
create table salesman_customer_assignments (
  id uuid primary key default gen_random_uuid(),
  salesman_id uuid not null references users(id),
  customer_id uuid not null references customers(id),
  created_at timestamptz not null default now(),
  unique (salesman_id, customer_id)
);

create type task_status_enum as enum ('pending', 'in_progress', 'completed', 'cancelled');

create table tasks (
  id uuid primary key default gen_random_uuid(),
  assigned_to uuid not null references users(id),
  assigned_by uuid not null references users(id),
  title text not null,
  description text,
  due_date date,
  status task_status_enum not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_tasks_assigned_to on tasks(assigned_to);
create index idx_tasks_status on tasks(status);

create trigger trg_tasks_updated_at before update on tasks
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- EXCEL IMPORTS
-- ----------------------------------------------------------------------------
create type import_status_enum as enum ('queued', 'processing', 'completed', 'failed');
create type import_row_status_enum as enum ('success', 'failed');

create table import_jobs (
  id uuid primary key default gen_random_uuid(),
  file_name text not null,
  file_url text not null,
  entity_type text not null,
  status import_status_enum not null default 'queued',
  total_rows integer,
  success_rows integer not null default 0,
  failed_rows integer not null default 0,
  uploaded_by uuid references users(id),
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_import_jobs_status on import_jobs(status);
create index idx_import_jobs_uploaded_by on import_jobs(uploaded_by);

create table import_job_rows (
  id uuid primary key default gen_random_uuid(),
  import_job_id uuid not null references import_jobs(id) on delete cascade,
  row_number integer not null,
  status import_row_status_enum not null,
  error_message text,
  raw_data jsonb,
  created_at timestamptz not null default now()
);

create index idx_import_job_rows_job_id on import_job_rows(import_job_id);
create index idx_import_job_rows_status on import_job_rows(status);

-- ----------------------------------------------------------------------------
-- AUDIT LOGS
-- ----------------------------------------------------------------------------
create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index idx_audit_logs_entity on audit_logs(entity_type, entity_id);
create index idx_audit_logs_user_id on audit_logs(user_id);

-- ============================================================================
-- ROW LEVEL SECURITY (defense-in-depth; primary enforcement is in FastAPI)
-- ============================================================================
-- FastAPI connects using the service role key which bypasses RLS by design.
-- These policies protect against direct client access to Supabase (e.g. if
-- the anon/public key were ever used to query tables directly).

alter table users enable row level security;
alter table customers enable row level security;
alter table sales enable row level security;
alter table payments enable row level security;
alter table expenses enable row level security;

-- Users can read their own profile row
create policy users_select_own on users
  for select
  using (auth_user_id = auth.uid());

-- Deny all direct writes from the client role; all writes happen via FastAPI
-- using the service role key, which bypasses RLS entirely.
create policy customers_no_direct_write on customers
  for all
  using (false)
  with check (false);

create policy sales_no_direct_write on sales
  for all
  using (false)
  with check (false);

create policy payments_no_direct_write on payments
  for all
  using (false)
  with check (false);

create policy expenses_no_direct_write on expenses
  for all
  using (false)
  with check (false);

-- ============================================================================
-- SEED DATA: default roles & permissions
-- ============================================================================
insert into roles (name, description) values
  ('admin', 'Full system access'),
  ('salesman', 'Sales staff with scoped access to assigned customers');

insert into permissions (key, module, description) values
  ('users.manage', 'users', 'Create, edit, activate/deactivate users'),
  ('roles.manage', 'roles', 'Manage roles and permission assignments'),
  ('customers.view_all', 'customers', 'View all customers'),
  ('customers.view_assigned', 'customers', 'View only assigned customers'),
  ('customers.create', 'customers', 'Create customers'),
  ('customers.edit', 'customers', 'Edit customers'),
  ('products.manage', 'products', 'Create/edit products'),
  ('sales.create', 'sales', 'Create sales'),
  ('sales.view_all', 'sales', 'View all sales'),
  ('sales.view_assigned', 'sales', 'View only own/assigned sales'),
  ('sales.cancel', 'sales', 'Cancel a sale'),
  ('invoices.view', 'invoices', 'View invoices'),
  ('payments.create', 'payments', 'Record payments'),
  ('payments.manage_cheque_status', 'payments', 'Clear/bounce cheques'),
  ('returns.create', 'returns', 'Create sales returns'),
  ('transactions.manage', 'transactions', 'Manage cash/UPI/bank transactions'),
  ('expenses.manage', 'expenses', 'Create/edit expenses'),
  ('salesmen.manage', 'salesmen', 'Manage salesman assignments and tasks'),
  ('reports.view', 'reports', 'View reports'),
  ('imports.manage', 'imports', 'Run and view Excel imports'),
  ('dashboard.view', 'dashboard', 'View dashboard');

-- Admin gets everything
insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'admin'), id from permissions;

-- Salesman gets a scoped subset
insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'salesman'), id
from permissions
where key in (
  'customers.view_assigned',
  'customers.create',
  'customers.edit',
  'sales.create',
  'sales.view_assigned',
  'invoices.view',
  'payments.create',
  'returns.create',
  'dashboard.view'
);

-- Default expense categories (extensible — admin can add more via API)
insert into expense_categories (name) values
  ('Rent'), ('Utilities'), ('Salaries'), ('Transport'), ('Miscellaneous');
