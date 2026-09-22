-- ============================================================================
-- Sai Krishna Enterprises — Migration 005: Settlement Sheet general fields
-- ============================================================================
-- Extends the Settlement Sheet workflow (see 004_add_settlement_sheets.sql)
-- with the paper-sheet reconciliation fields Admin fills in when creating a
-- sheet — Pick Sheet No./Value, Returns Goods, Damage Return, Discount,
-- Cash, Online/Bank/UPI, Cheque, Credit Bills, Old Short. These are
-- MANUALLY entered target/expected totals, independent of whatever the
-- Delivery Agent/Salesman later record per customer row — Admin compares
-- the two during final review before marking the sheet Completed.
--
-- `pick_sheet_no` is deliberately separate from `sheet_no` (the settlement
-- sheet's own auto-generated internal id, e.g. SET-20260922-001): it
-- references the physical picking document, entered by Admin, not
-- auto-generated.
--
-- On the row side, a single `payment_mode` + `amount_collected` can't
-- represent a delivery paid across multiple modes, and had no "cheque"
-- option. Replaced with three separate collected-amount columns
-- (cash/online/cheque); `credit_amount`/`credit_collected` are unchanged —
-- `credit_amount` simply becomes settable by the Delivery Agent when
-- recording the delivery, instead of fixed by Admin at row creation.
-- ============================================================================

alter table settlement_sheets
  add column pick_sheet_no text,
  add column pick_sheet_value numeric(12,2) not null default 0 check (pick_sheet_value >= 0),
  add column returns_goods numeric(12,2) not null default 0 check (returns_goods >= 0),
  add column damage_return numeric(12,2) not null default 0 check (damage_return >= 0),
  add column discount numeric(12,2) not null default 0 check (discount >= 0),
  add column cash_amount numeric(12,2) not null default 0 check (cash_amount >= 0),
  add column online_amount numeric(12,2) not null default 0 check (online_amount >= 0),
  add column cheque_amount numeric(12,2) not null default 0 check (cheque_amount >= 0),
  add column credit_bills numeric(12,2) not null default 0 check (credit_bills >= 0),
  add column old_short numeric(12,2) not null default 0 check (old_short >= 0);

alter table settlement_sheet_items
  add column cash_amount numeric(12,2) not null default 0 check (cash_amount >= 0),
  add column online_amount numeric(12,2) not null default 0 check (online_amount >= 0),
  add column cheque_amount numeric(12,2) not null default 0 check (cheque_amount >= 0);

alter table settlement_sheet_items
  drop column payment_mode,
  drop column amount_collected;

drop type settlement_payment_mode_enum;
