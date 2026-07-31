-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Admin supplier settlement verification idempotency/concurrency guard.
-- Uses a transaction-scoped development fixture and rolls back all changes.

begin;

create temp table admin_settlement_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on admin_settlement_concurrency_results to anon, authenticated;

create or replace function pg_temp.admin_settlement_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into admin_settlement_concurrency_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.admin_settlement_concurrency_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.admin_settlement_concurrency_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

do $$
declare
  v_order_id uuid;
  v_reseller_id uuid;
  v_settlement_id uuid;
  v_variant_id uuid;
  v_finance_profile_id uuid := gen_random_uuid();
  v_finance_clerk text := 'dev_admin_settlement_concurrency_finance';
  v_commission_amount numeric;
  v_available_before numeric;
  v_available_after_first numeric;
  v_available_after_retry numeric;
  v_audit_after_first bigint;
  v_audit_after_retry bigint;
  v_verified_at_first timestamptz;
  v_verified_at_retry timestamptz;
  v_stock_before record;
  v_stock_after_retry record;
begin
  perform pg_temp.admin_settlement_concurrency_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values (v_finance_profile_id, v_finance_clerk, 'dev-admin-settlement-concurrency@example.invalid', 'Dev Settlement Concurrency Finance', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values (v_finance_profile_id, 'finance_staff', '{}'::jsonb, 'active');

  select
    o.id,
    o.reseller_id,
    st.id,
    sr.variant_id,
    sum(cm.commission_amount)
  into
    v_order_id,
    v_reseller_id,
    v_settlement_id,
    v_variant_id,
    v_commission_amount
  from public.orders o
  join public.stock_reservations sr on sr.order_id = o.id
  join public.settlements st on st.order_id = o.id and st.deleted_at is null
  join public.commissions cm on cm.order_id = o.id and cm.settlement_id = st.id
  where o.deleted_at is null
    and o.order_status::text = 'payment_reported'
    and o.payment_collection_status::text = 'supplier_reported'
    and sr.reservation_status = 'committed'
    and st.settlement_status = 'due'
    and cm.commission_status = 'awaiting_supplier_settlement'
    and cm.withdrawal_id is null
  group by o.id, o.reseller_id, st.id, sr.variant_id
  order by o.updated_at desc, o.id::text desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.admin_settlement_concurrency_record('development fixture available', false, 'No payment_reported development order with pending settlement exists');
    return;
  end if;

  select commission_available_amount
  into v_available_before
  from public.resellers
  where id = v_reseller_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_before
  from public.product_variants
  where id = v_variant_id;

  perform pg_temp.admin_settlement_concurrency_set_context(v_finance_clerk);
  perform public.admin_verify_supplier_settlement(v_order_id, 'DEV-CONCURRENCY-REFERENCE', null, 'admin-settlement-verify:dev-concurrency');
  perform pg_temp.admin_settlement_concurrency_reset_context();

  select commission_available_amount
  into v_available_after_first
  from public.resellers
  where id = v_reseller_id;

  select verified_at
  into v_verified_at_first
  from public.settlements
  where id = v_settlement_id;

  select count(*)
  into v_audit_after_first
  from public.audit_logs
  where target_entity_id = v_reseller_id
    and action = 'reseller_available_balance_credited';

  perform pg_temp.admin_settlement_concurrency_set_context(v_finance_clerk);
  perform public.admin_verify_supplier_settlement(v_order_id, 'DEV-CONCURRENCY-REFERENCE', null, 'admin-settlement-verify:dev-concurrency');
  perform pg_temp.admin_settlement_concurrency_reset_context();

  select commission_available_amount
  into v_available_after_retry
  from public.resellers
  where id = v_reseller_id;

  select verified_at
  into v_verified_at_retry
  from public.settlements
  where id = v_settlement_id;

  select count(*)
  into v_audit_after_retry
  from public.audit_logs
  where target_entity_id = v_reseller_id
    and action = 'reseller_available_balance_credited';

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after_retry
  from public.product_variants
  where id = v_variant_id;

  perform pg_temp.admin_settlement_concurrency_record('development fixture available', true);
  perform pg_temp.admin_settlement_concurrency_record('first verification credits commission once', round(v_available_after_first - v_available_before, 2) = round(v_commission_amount, 2));
  perform pg_temp.admin_settlement_concurrency_record('same-key retry does not credit again', v_available_after_retry = v_available_after_first);
  perform pg_temp.admin_settlement_concurrency_record('same-key retry preserves verified timestamp', v_verified_at_retry = v_verified_at_first);
  perform pg_temp.admin_settlement_concurrency_record('same-key retry does not duplicate balance audit', v_audit_after_retry = v_audit_after_first);
  perform pg_temp.admin_settlement_concurrency_record('same-key retry does not mutate stock', v_stock_before.total_stock_quantity = v_stock_after_retry.total_stock_quantity and v_stock_before.reserved_stock_quantity = v_stock_after_retry.reserved_stock_quantity and v_stock_before.sold_stock_quantity = v_stock_after_retry.sold_stock_quantity);
end;
$$;

select test_name, passed, details
from admin_settlement_concurrency_results
order by test_name;

do $$
begin
  if exists (select 1 from admin_settlement_concurrency_results where not passed) then
    raise exception 'Admin settlement verification concurrency tests failed';
  end if;
end;
$$;

rollback;
