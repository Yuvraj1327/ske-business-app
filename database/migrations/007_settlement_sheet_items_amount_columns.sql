-- ============================================================================
-- Sai Krishna Enterprises — Migration 007: Add missing settlement_sheet_items
-- amount columns (cash_amount/online_amount/cheque_amount)
-- ============================================================================
-- Migration 005 defined cash_amount/online_amount/cheque_amount on
-- settlement_sheet_items (replacing payment_mode/amount_collected), but
-- production never actually received that ALTER — the backend now queries
-- these three columns and fails with UndefinedColumnError.
--
-- This migration ONLY adds the three columns if missing. It deliberately
-- does NOT repeat migration 005's `drop column payment_mode`,
-- `drop column amount_collected`, or `drop type
-- settlement_payment_mode_enum` — those are destructive and, since we don't
-- know from here whether they already ran on production, re-issuing them
-- risks erroring (if already dropped) or discarding still-relied-upon data
-- (if not). The backend model no longer maps payment_mode/amount_collected,
-- so leaving them in place (if they still exist) is harmless — an unmapped
-- column is simply ignored by the ORM. Dropping them, if still desired,
-- should be a separate, deliberate follow-up migration once it's confirmed
-- safe to do so.
--
-- Does not touch settlement_sheets, does not drop or recreate any table,
-- does not remove any existing row.
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheet_items' and column_name = 'cash_amount'
  ) then
    alter table settlement_sheet_items
      add column cash_amount numeric(12,2) not null default 0 check (cash_amount >= 0);
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheet_items' and column_name = 'online_amount'
  ) then
    alter table settlement_sheet_items
      add column online_amount numeric(12,2) not null default 0 check (online_amount >= 0);
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheet_items' and column_name = 'cheque_amount'
  ) then
    alter table settlement_sheet_items
      add column cheque_amount numeric(12,2) not null default 0 check (cheque_amount >= 0);
  end if;
end $$;
