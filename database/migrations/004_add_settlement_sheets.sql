-- ============================================================================
-- Sai Krishna Enterprises — Migration 004: Settlement Sheet workflow
-- ============================================================================
-- A Settlement Sheet is a MANUALLY entered record of one Delivery Agent's
-- collection route for a given date (one agent + one salesman, multiple
-- customers), worked through three stages:
--
--   draft -> in_progress -> completed
--
--   - draft:       Admin builds the sheet (picks agent, salesman, adds
--                   customer rows). Structural changes (add/remove a row,
--                   change the agent/salesman) are only allowed here.
--   - in_progress: the assigned Delivery Agent records delivery status +
--                   amount collected + payment mode per row; the assigned
--                   Salesman records Credit/Udhaar collected per row.
--                   Structural changes are locked; only these per-row
--                   fields can move.
--   - completed:   Admin has reviewed and confirmed. The sheet is now
--                   read-only.
--
-- This is DELIBERATELY separate from the existing `picklists` workflow
-- (see 003_add_picklist_workflow.sql): picklists are Excel-imported and
-- each row auto-creates a real Sale/Invoice (so Credit there becomes a
-- real outstanding sale). A Settlement Sheet is manually entered, has its
-- own Draft/In Progress/Completed lifecycle, and is its own standalone
-- record of a day's collection route — it does not touch sales/invoices.
-- Both features can coexist; a future iteration could link them, but that
-- was not asked for here.
--
-- Reuses `customers.external_code` (added in migration 003) as the
-- "Customer Code" field for search + autofill, instead of adding a new
-- column — that field already exists for exactly this purpose and already
-- has a unique partial index.
-- ============================================================================

create type settlement_status_enum as enum ('draft', 'in_progress', 'completed');
create type settlement_delivery_status_enum as enum ('pending', 'delivered', 'not_delivered');
create type settlement_payment_mode_enum as enum ('cash', 'online', 'credit', 'none');

create table settlement_sheets (
  id uuid primary key default gen_random_uuid(),
  sheet_no text not null unique,
  sheet_date date not null,
  delivery_agent_id uuid not null references users(id),
  salesman_id uuid not null references users(id),
  status settlement_status_enum not null default 'draft',
  notes text,
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_settlement_sheets_agent on settlement_sheets(delivery_agent_id);
create index idx_settlement_sheets_salesman on settlement_sheets(salesman_id);
create index idx_settlement_sheets_status on settlement_sheets(status);
create index idx_settlement_sheets_date on settlement_sheets(sheet_date);

create table settlement_sheet_items (
  id uuid primary key default gen_random_uuid(),
  settlement_sheet_id uuid not null references settlement_sheets(id) on delete cascade,
  row_no integer not null,
  customer_id uuid not null references customers(id),
  -- Denormalized copies of the customer's code/name at the time the row was
  -- added, so a sheet still reads correctly even if the customer record is
  -- edited later — same pattern as picklist_items.customer_name.
  customer_code text,
  customer_name text not null,
  invoice_amount numeric(12,2) not null default 0 check (invoice_amount >= 0),

  -- Delivery half — set by Admin (structural default) and updated by the
  -- assigned Delivery Agent while the sheet is 'in_progress'.
  delivery_status settlement_delivery_status_enum not null default 'pending',
  amount_collected numeric(12,2) not null default 0 check (amount_collected >= 0),
  payment_mode settlement_payment_mode_enum not null default 'none',
  agent_notes text,

  -- Credit / Udhaar half — updated by the assigned Salesman while the
  -- sheet is 'in_progress'. credit_collected is a running total capped at
  -- credit_amount (enforced in application code, mirrored here as a
  -- check constraint for defense in depth).
  credit_amount numeric(12,2) not null default 0 check (credit_amount >= 0),
  credit_collected numeric(12,2) not null default 0 check (credit_collected >= 0),
  salesman_notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ck_settlement_sheet_items_credit_within_amount check (credit_collected <= credit_amount)
);

create index idx_settlement_sheet_items_sheet on settlement_sheet_items(settlement_sheet_id);
create index idx_settlement_sheet_items_customer on settlement_sheet_items(customer_id);

-- ----------------------------------------------------------------------------
-- Permissions — additive only, same pattern as migration 002/003.
--   settlements.manage        — Admin: create sheets, move status, full access
--   settlements.view_assigned — Delivery Agent / Salesman: see and update only
--                                the sheets where they are the assigned agent
--                                or salesman (row-level scoping enforced in
--                                SettlementService, not here)
-- ----------------------------------------------------------------------------
insert into permissions (key, module, description)
select 'settlements.manage', 'settlements', 'Create settlement sheets and manage their status (Admin)'
where not exists (select 1 from permissions where key = 'settlements.manage');

insert into permissions (key, module, description)
select 'settlements.view_assigned', 'settlements', 'View and update only settlement sheets assigned to you (as delivery agent or salesman)'
where not exists (select 1 from permissions where key = 'settlements.view_assigned');

insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'admin'), p.id
from permissions p
where p.key in ('settlements.manage', 'settlements.view_assigned')
and not exists (
  select 1 from role_permissions rp
  where rp.role_id = (select id from roles where name = 'admin') and rp.permission_id = p.id
);

insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'delivery_agent'), p.id
from permissions p
where p.key = 'settlements.view_assigned'
and not exists (
  select 1 from role_permissions rp
  where rp.role_id = (select id from roles where name = 'delivery_agent') and rp.permission_id = p.id
);

insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'salesman'), p.id
from permissions p
where p.key = 'settlements.view_assigned'
and not exists (
  select 1 from role_permissions rp
  where rp.role_id = (select id from roles where name = 'salesman') and rp.permission_id = p.id
);
