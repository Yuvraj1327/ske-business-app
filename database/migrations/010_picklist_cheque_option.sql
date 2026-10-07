-- ============================================================================
-- Sai Krishna Enterprises — Migration 010: Cheque option on Picklist items
-- ============================================================================
-- Adds a 4th collection option (Cheque) beside Cash / Online / Credit on a
-- picklist row, and stores the cheque amount entered for it. Purely
-- additive: no existing column, row or enum value is changed.
--
--   * 'cheque' joins picklist_item_status_enum.
--   * picklist_items.cheque_amount holds the amount collected by cheque
--     (0 for every other status). It may be less than amount_payable; the
--     remainder simply stays outstanding on the linked sale.
--
-- A cheque does NOT create a `payments` row here: cheque payments need a
-- cheque number / date / bank (cheque_details), which the picklist screen
-- doesn't collect, and a cheque only counts toward a sale's paid amount once
-- cleared. It is recorded through the existing Payments screen as before.
-- The picklist's cheque total is what the Settlement Sheet's "Cheque" field
-- starts from (matched via settlement_sheets.pick_sheet_no = picklist_no).
--
-- Safe to re-run.
-- ============================================================================

alter type picklist_item_status_enum add value if not exists 'cheque';

alter table picklist_items
  add column if not exists cheque_amount numeric(12,2) not null default 0 check (cheque_amount >= 0);

-- Speeds up resolving a settlement sheet's picklist by its Pick Sheet No.
create index if not exists idx_settlement_sheets_pick_sheet_no on settlement_sheets(pick_sheet_no);
