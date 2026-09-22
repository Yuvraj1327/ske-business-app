-- ============================================================================
-- Sai Krishna Enterprises — Migration 005: Settlement Sheet summary fields
-- ============================================================================
-- Adds the route-level totals from the client's paper "Cash / Credit
-- Settlement Sheet" that have no digital equivalent yet. These live on
-- settlement_sheets (one set of numbers per sheet, not per customer row):
--
--   pick_sheet_no / pick_sheet_value — structural, Admin-only, set at
--     creation alongside sheet_date/delivery_agent/salesman.
--   returns_amount / damage_return_amount / discount_amount / cash_amount /
--     online_amount / cheque_amount — the assigned Delivery Agent's (or
--     Admin's) route-level totals, editable while 'in_progress'.
--   credit_bills_amount — the assigned Salesman's (or Admin's) Credit/Udhaar
--     total, editable while 'in_progress'.
--   old_short_amount — Admin-only carry-forward figure from a prior
--     unresolved sheet, editable up until the sheet is 'completed'.
--
-- day_short and total_balance are NOT stored — they're pure arithmetic over
-- the above (see SettlementService._build_response) and are always derived,
-- same spirit as the existing computed `summary.*` fields.
-- ============================================================================

alter table settlement_sheets
  add column pick_sheet_no text,
  add column pick_sheet_value numeric(12,2) not null default 0 check (pick_sheet_value >= 0),
  add column returns_amount numeric(12,2) not null default 0 check (returns_amount >= 0),
  add column damage_return_amount numeric(12,2) not null default 0 check (damage_return_amount >= 0),
  add column discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  add column cash_amount numeric(12,2) not null default 0 check (cash_amount >= 0),
  add column online_amount numeric(12,2) not null default 0 check (online_amount >= 0),
  add column cheque_amount numeric(12,2) not null default 0 check (cheque_amount >= 0),
  add column credit_bills_amount numeric(12,2) not null default 0 check (credit_bills_amount >= 0),
  add column old_short_amount numeric(12,2) not null default 0 check (old_short_amount >= 0);
