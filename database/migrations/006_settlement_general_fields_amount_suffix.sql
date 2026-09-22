-- ============================================================================
-- Sai Krishna Enterprises — Migration 006: Align Settlement Sheet general
-- field names with the "_amount" suffix convention
-- ============================================================================
-- Migration 005 added five reconciliation fields (returns_goods,
-- damage_return, discount, credit_bills, old_short) without the "_amount"
-- suffix used by the other three money fields it added in the same table
-- (cash_amount, online_amount, cheque_amount). The backend model now
-- expects the consistent "_amount"-suffixed names throughout
-- (returns_amount, damage_return_amount, discount_amount,
-- credit_bills_amount, old_short_amount) — this migration converges any
-- environment onto those names WITHOUT dropping the settlement_sheets
-- table or losing any existing rows:
--
--   - If the old (005) name exists and the new name doesn't: rename it
--     (preserves whatever values are already stored).
--   - If neither exists yet (e.g. 005 never ran against this database):
--     add the column fresh with the same default/constraint 005 used.
--   - If the new name already exists (already converged, e.g. this ran
--     before): do nothing.
--
-- Safe to run repeatedly and regardless of which of the above states a
-- given database is in.
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheets' and column_name = 'returns_amount'
  ) then
    if exists (
      select 1 from information_schema.columns
      where table_name = 'settlement_sheets' and column_name = 'returns_goods'
    ) then
      alter table settlement_sheets rename column returns_goods to returns_amount;
    else
      alter table settlement_sheets
        add column returns_amount numeric(12,2) not null default 0 check (returns_amount >= 0);
    end if;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheets' and column_name = 'damage_return_amount'
  ) then
    if exists (
      select 1 from information_schema.columns
      where table_name = 'settlement_sheets' and column_name = 'damage_return'
    ) then
      alter table settlement_sheets rename column damage_return to damage_return_amount;
    else
      alter table settlement_sheets
        add column damage_return_amount numeric(12,2) not null default 0 check (damage_return_amount >= 0);
    end if;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheets' and column_name = 'discount_amount'
  ) then
    if exists (
      select 1 from information_schema.columns
      where table_name = 'settlement_sheets' and column_name = 'discount'
    ) then
      alter table settlement_sheets rename column discount to discount_amount;
    else
      alter table settlement_sheets
        add column discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0);
    end if;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheets' and column_name = 'credit_bills_amount'
  ) then
    if exists (
      select 1 from information_schema.columns
      where table_name = 'settlement_sheets' and column_name = 'credit_bills'
    ) then
      alter table settlement_sheets rename column credit_bills to credit_bills_amount;
    else
      alter table settlement_sheets
        add column credit_bills_amount numeric(12,2) not null default 0 check (credit_bills_amount >= 0);
    end if;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheets' and column_name = 'old_short_amount'
  ) then
    if exists (
      select 1 from information_schema.columns
      where table_name = 'settlement_sheets' and column_name = 'old_short'
    ) then
      alter table settlement_sheets rename column old_short to old_short_amount;
    else
      alter table settlement_sheets
        add column old_short_amount numeric(12,2) not null default 0 check (old_short_amount >= 0);
    end if;
  end if;
end $$;
