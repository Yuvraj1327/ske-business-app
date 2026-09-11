-- ============================================================================
-- Sai Krishna Enterprises — Migration 002: Delivery Agent role
-- ============================================================================
-- Purely additive: adds one new role with a minimal, delivery-focused
-- permission set. Does not alter any existing table, role, or permission.
-- Safe to re-run (every insert is guarded with an existence check).
--
-- Delivery Agent gets exactly four permissions, all of which already exist
-- and are already used by the salesman role's scoping logic:
--   - dashboard.view            (see their delivery-focused dashboard)
--   - customers.view_assigned   (see customers assigned to them for delivery)
--   - sales.view_assigned       (see sales/orders assigned to them)
--   - invoices.view             (view invoice/delivery details for a sale)
-- No new permission keys, tables, or columns were needed — the existing
-- row-level scoping in CustomerService/SaleService already filters by
-- `assigned_salesman_id` / `sales.salesman_id` matching the current user's
-- id whenever they hold the "_assigned" permission variant, regardless of
-- role name. Admin assigns a delivery agent's customers/sales the same way
-- salesmen are assigned today (POST /salesmen/{id}/assign-customer works
-- for any user id, not just role='salesman').
-- ============================================================================

insert into roles (name, description)
select 'delivery_agent', 'Delivery staff with access limited to their assigned customers and deliveries'
where not exists (select 1 from roles where name = 'delivery_agent');

insert into role_permissions (role_id, permission_id)
select
  (select id from roles where name = 'delivery_agent'),
  p.id
from permissions p
where p.key in (
  'dashboard.view',
  'customers.view_assigned',
  'sales.view_assigned',
  'invoices.view'
)
and not exists (
  select 1 from role_permissions rp
  where rp.role_id = (select id from roles where name = 'delivery_agent')
    and rp.permission_id = p.id
);
