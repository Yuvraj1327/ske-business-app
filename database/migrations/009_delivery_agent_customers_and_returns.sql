-- ============================================================================
-- Sai Krishna Enterprises — Migration 009: Delivery Agent can create customers and returns
-- ============================================================================
-- A Delivery Agent adding a customer row to a Settlement Sheet who searches
-- a Customer Code and finds nothing must be able to create that customer
-- (POST /customers requires `customers.create`), otherwise the dialog fails
-- with a permission error. Likewise the Picklist screen's return actions
-- reuse Sales Return (POST /returns requires `returns.create`). Grants those
-- two existing permissions to the delivery_agent role only — Admin and
-- Salesman are untouched (the app restricts an agent's returns to sales on
-- their own picklists). Safe to re-run.
-- ============================================================================

insert into role_permissions (role_id, permission_id)
select (select id from roles where name = 'delivery_agent'), p.id
from permissions p
where p.key in ('customers.create', 'returns.create')
and exists (select 1 from roles where name = 'delivery_agent')
and not exists (
  select 1 from role_permissions rp
  where rp.role_id = (select id from roles where name = 'delivery_agent') and rp.permission_id = p.id
);
