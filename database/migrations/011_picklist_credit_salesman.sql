-- ============================================================================
-- Sai Krishna Enterprises — Migration 011: Salesman for Picklist Credit rows
-- ============================================================================
-- When a Delivery Agent marks a picklist row as Credit, they now choose which
-- Salesman will handle that Credit/Udhaar customer. The choice is stored on
-- the picklist row (`credit_salesman_id`) as the record of who was picked.
--
-- It also flows into the EXISTING Settlement / Salesman credit machinery,
-- which keys off customers.assigned_salesman_id (who may update a settlement
-- row's Credit/Udhaar half, which customers a salesman sees) and
-- sales.salesman_id (which invoices a salesman sees) — both are set by the
-- app when the row is confirmed, so no new table is involved.
--
-- Purely additive and nullable: existing rows (including already-confirmed
-- Credit rows) simply have no salesman recorded. Safe to re-run.
-- ============================================================================

alter table picklist_items
  add column if not exists credit_salesman_id uuid references users(id);

create index if not exists idx_picklist_items_credit_salesman on picklist_items(credit_salesman_id);
