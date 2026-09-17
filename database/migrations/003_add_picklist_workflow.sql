-- ============================================================================
-- Sai Krishna Enterprises — Migration 003: Delivery Picklist workflow
-- ============================================================================
-- Adds the ability to import a delivery agent's Excel "picklist" (as
-- produced by the client's external billing/distribution system) and track
-- per-row delivery/collection status (Cash / Online / Credit).
--
-- Design: each picklist row becomes a REAL `sales` + `sale_items` +
-- `invoices` row (reusing the existing Sales/Invoice tables and the
-- existing outstanding/ledger calculations verbatim — no new "delivery
-- ledger" concept), linked to a `customers` row matched by a new
-- `external_code` column (falls back to creating a new customer if no
-- match is found). This is why "Credit / Udhaar" automatically shows up in
-- the existing Customer Outstanding/Ledger screens with zero additional
-- backend logic: it's simply an unpaid Sale, exactly like any other.
--
-- invoice_number for these sales is taken directly from the picklist's own
-- "Invoice Number" column (e.g. IEWG26133417) rather than the app's own
-- auto-generated SKE/... sequence, since the client's invoice numbers are
-- already the authoritative reference for this workflow.
-- ============================================================================

-- Links a customer to the external system's customer code, so re-imports
-- and future picklists resolve to the same customer instead of creating
-- duplicates.
alter table customers add column if not exists external_code text;
create unique index if not exists idx_customers_external_code
  on customers(external_code) where external_code is not null;

-- One row per placeholder "Picklist Delivery" product line — the picklist
-- Excel only gives a total amount per invoice, not item-level detail, so
-- each imported sale gets exactly one synthetic sale_item using this
-- product (sale_items.product_id is NOT NULL, so a real product row is
-- needed; this keeps the existing sales/sale_items schema unchanged rather
-- than relaxing a constraint for one workflow).
insert into products (name, sku, unit, default_price, is_active)
select 'Picklist Delivery', 'PICKLIST-IMPORT', 'invoice', 0, true
where not exists (select 1 from products where sku = 'PICKLIST-IMPORT');

create type picklist_item_status_enum as enum ('pending', 'cash', 'online', 'credit');

create table picklists (
  id uuid primary key default gen_random_uuid(),
  picklist_no text not null unique,
  delivery_agent_id uuid not null references users(id),
  psr_route text,
  raw_delivery_agent_label text,
  import_job_id uuid references import_jobs(id),
  total_amount numeric(12,2) not null default 0,
  created_by uuid references users(id),
  created_at timestamptz not null default now()
);

create index idx_picklists_delivery_agent on picklists(delivery_agent_id);
create index idx_picklists_import_job on picklists(import_job_id);

create table picklist_items (
  id uuid primary key default gen_random_uuid(),
  picklist_id uuid not null references picklists(id) on delete cascade,
  row_no integer not null,
  invoice_number text not null,
  customer_code text,
  customer_name text not null,
  salesman_label text,
  amount_payable numeric(12,2) not null check (amount_payable >= 0),
  customer_id uuid references customers(id),
  sale_id uuid references sales(id),
  payment_id uuid references payments(id),
  status picklist_item_status_enum not null default 'pending',
  collected_by uuid references users(id),
  collected_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_picklist_items_picklist on picklist_items(picklist_id);
create index idx_picklist_items_customer on picklist_items(customer_id);
create index idx_picklist_items_sale on picklist_items(sale_id);

-- ----------------------------------------------------------------------------
-- Permissions — additive only. Two new keys, granted to admin (who already
-- has every permission via the blanket grant in migration 001, but that
-- grant ran once at seed time and doesn't retroactively pick up permissions
-- added later, hence the explicit insert here) and to delivery_agent.
-- ----------------------------------------------------------------------------
insert into permissions (key, module, description)
select 'picklists.manage', 'picklists', 'Import picklists and view all delivery picklists'
where not exists (select 1 from permissions where key = 'picklists.manage');

insert into permissions (key, module, description)
select 'picklists.view_assigned', 'picklists', 'View and confirm only the picklists assigned to you'
where not exists (select 1 from permissions where key = 'picklists.view_assigned');

insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'admin'), p.id
from permissions p
where p.key in ('picklists.manage', 'picklists.view_assigned')
and not exists (
  select 1 from role_permissions rp
  where rp.role_id = (select id from roles where name = 'admin') and rp.permission_id = p.id
);

insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'delivery_agent'), p.id
from permissions p
where p.key = 'picklists.view_assigned'
and not exists (
  select 1 from role_permissions rp
  where rp.role_id = (select id from roles where name = 'delivery_agent') and rp.permission_id = p.id
);
