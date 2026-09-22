-- ============================================================================
-- Sai Krishna Enterprises — Migration 008: Multiple Salesmen per Settlement
-- Sheet, and support for adding customer rows after creation
-- ============================================================================
-- Admin can now assign MULTIPLE Salesmen to one Settlement Sheet (not just
-- one), and the Delivery Agent can add new customer rows to a sheet after
-- it's created (previously rows were create-once, by Admin, at sheet
-- creation only).
--
-- Multi-salesman is modeled as a join table rather than reshaping
-- settlement_sheets.salesman_id, and existing sheets' salesman assignment
-- is backfilled into it — no existing settlement data is lost.
--
-- Per the safety lesson learned twice already in this project's migration
-- history (004/005/006/007): this migration is additive/constraint-relaxing
-- only. It does NOT drop settlement_sheets.salesman_id — the backend model
-- simply stops mapping it going forward, exactly like
-- settlement_sheet_items.payment_mode/amount_collected before it. The
-- column's NOT NULL constraint is relaxed (not dropped) because new code
-- stops writing it, which would otherwise fail every insert.
-- ============================================================================

create table if not exists settlement_sheet_salesmen (
  settlement_sheet_id uuid not null references settlement_sheets(id) on delete cascade,
  user_id uuid not null references users(id),
  primary key (settlement_sheet_id, user_id)
);

create index if not exists idx_settlement_sheet_salesmen_user on settlement_sheet_salesmen(user_id);

insert into settlement_sheet_salesmen (settlement_sheet_id, user_id)
select id, salesman_id from settlement_sheets
where salesman_id is not null
on conflict do nothing;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'settlement_sheets' and column_name = 'salesman_id' and is_nullable = 'NO'
  ) then
    alter table settlement_sheets alter column salesman_id drop not null;
  end if;
end $$;
