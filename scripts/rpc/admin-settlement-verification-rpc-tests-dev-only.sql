-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Admin supplier settlement verification RPC boundary tests.
-- Uses a transaction-scoped development fixture and rolls back all changes.

begin;

create temp table admin_settlement_verification_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on admin_settlement_verification_test_results to anon, authenticated;

create or replace function pg_temp.admin_settlement_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into admin_settlement_verification_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.admin_settlement_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.admin_settlement_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.admin_settlement_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.admin_settlement_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.admin_settlement_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_clerk text;
  v_customer_clerk text;
  v_reseller_clerk text;
  v_finance_profile_id uuid := gen_random_uuid();
  v_finance_clerk text := 'dev_admin_settlement_finance_operator';
  v_admin_profile_id uuid := gen_random_uuid();
  v_admin_clerk text := 'dev_admin_settlement_support_only';
  v_reseller_id uuid;
  v_variant_id uuid;
  v_reservation_id uuid;
  v_settlement_id uuid;
  v_commission_amount numeric;
  v_available_before numeric;
  v_pending_before numeric;
  v_available_after numeric;
  v_pending_after numeric;
  v_order_after record;
  v_settlement_after record;
  v_commission_after record;
  v_stock_before record;
  v_stock_after record;
  v_withdrawal_count_before bigint;
  v_withdrawal_count_after bigint;
  v_audit_verified_count bigint;
  v_audit_balance_count bigint;
  v_retry_available numeric;
  v_retry_audit_count bigint;
begin
  perform pg_temp.admin_settlement_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_finance_profile_id, v_finance_clerk, 'dev-admin-settlement-finance@example.invalid', 'Dev Finance Settlement Operator', 'customer', 'active'),
    (v_admin_profile_id, v_admin_clerk, 'dev-admin-settlement-support@example.invalid', 'Dev Support Admin Operator', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values
    (v_finance_profile_id, 'finance_staff', '{}'::jsonb, 'active'),
    (v_admin_profile_id, 'admin', '{}'::jsonb, 'active');

  select
    o.id,
    sp.clerk_user_id,
    cp.clerk_user_id,
    rp.clerk_user_id,
    o.reseller_id,
    sr.variant_id,
    sr.id,
    st.id,
    sum(cm.commission_amount)
  into
    v_order_id,
    v_supplier_clerk,
    v_customer_clerk,
    v_reseller_clerk,
    v_reseller_id,
    v_variant_id,
    v_reservation_id,
    v_settlement_id,
    v_commission_amount
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.suppliers s on s.id = oi.supplier_id
  join public.profiles sp on sp.id = s.owner_profile_id
  join public.customers c on c.id = o.customer_id
  join public.profiles cp on cp.id = c.profile_id
  join public.resellers r on r.id = o.reseller_id
  join public.profiles rp on rp.id = r.profile_id
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
  group by o.id, sp.clerk_user_id, cp.clerk_user_id, rp.clerk_user_id, o.reseller_id, sr.variant_id, sr.id, st.id
  order by o.updated_at desc, o.id::text desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.admin_settlement_record_result('development fixture available', false, 'No payment_reported development order with pending settlement exists');
    return;
  end if;

  select commission_available_amount, commission_pending_amount
  into v_available_before, v_pending_before
  from public.resellers
  where id = v_reseller_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_before
  from public.product_variants
  where id = v_variant_id;

  select count(*)
  into v_withdrawal_count_before
  from public.withdrawals
  where reseller_id = v_reseller_id;

  perform pg_temp.admin_settlement_set_context(v_supplier_clerk);
  perform pg_temp.admin_settlement_expect_blocked(
    'supplier cannot verify settlement',
    format($sql$select * from public.admin_verify_supplier_settlement(%L::uuid, 'DEV-SUPPLIER-BLOCKED', null, 'dev-supplier-blocked')$sql$, v_order_id)
  );

  perform pg_temp.admin_settlement_set_context(v_customer_clerk);
  perform pg_temp.admin_settlement_expect_blocked(
    'customer cannot verify settlement',
    format($sql$select * from public.admin_verify_supplier_settlement(%L::uuid, 'DEV-CUSTOMER-BLOCKED', null, 'dev-customer-blocked')$sql$, v_order_id)
  );

  perform pg_temp.admin_settlement_set_context(v_reseller_clerk);
  perform pg_temp.admin_settlement_expect_blocked(
    'reseller cannot verify settlement',
    format($sql$select * from public.admin_verify_supplier_settlement(%L::uuid, 'DEV-RESELLER-BLOCKED', null, 'dev-reseller-blocked')$sql$, v_order_id)
  );

  perform pg_temp.admin_settlement_set_context(v_admin_clerk);
  perform pg_temp.admin_settlement_expect_blocked(
    'general admin without finance role cannot verify settlement',
    format($sql$select * from public.admin_verify_supplier_settlement(%L::uuid, 'DEV-ADMIN-BLOCKED', null, 'dev-admin-blocked')$sql$, v_order_id)
  );

  perform pg_temp.admin_settlement_set_context(v_finance_clerk);
  perform public.admin_verify_supplier_settlement(
    v_order_id,
    'DEV-SETTLEMENT-REFERENCE',
    'Development-only private finance note',
    'admin-settlement-verify:dev-boundary'
  );
  perform pg_temp.admin_settlement_reset_context();

  select order_status, payment_collection_status, completed_at
  into v_order_after
  from public.orders
  where id = v_order_id;

  select settlement_status, paid_amount, outstanding_amount, verified_at, verified_by_profile_id, proof_reference, review_notes
  into v_settlement_after
  from public.settlements
  where id = v_settlement_id;

  select min(commission_status::text) as commission_status, count(*) as commission_count, sum(commission_amount) as commission_amount, min(available_at) as available_at
  into v_commission_after
  from public.commissions
  where order_id = v_order_id;

  select commission_available_amount, commission_pending_amount
  into v_available_after, v_pending_after
  from public.resellers
  where id = v_reseller_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after
  from public.product_variants
  where id = v_variant_id;

  select count(*)
  into v_withdrawal_count_after
  from public.withdrawals
  where reseller_id = v_reseller_id;

  select count(*)
  into v_audit_verified_count
  from public.audit_logs
  where target_entity_id = v_order_id
    and action in ('supplier_settlement_verified', 'order_completed');

  select count(*)
  into v_audit_balance_count
  from public.audit_logs
  where target_entity_id = v_reseller_id
    and action = 'reseller_available_balance_credited';

  perform pg_temp.admin_settlement_record_result('finance admin can verify settlement', v_order_after.order_status::text = 'completed' and v_order_after.payment_collection_status::text = 'settlement_verified');
  perform pg_temp.admin_settlement_record_result('settlement marked paid and verified', v_settlement_after.settlement_status::text = 'paid' and v_settlement_after.paid_amount = v_settlement_after.paid_amount + v_settlement_after.outstanding_amount and v_settlement_after.outstanding_amount = 0 and v_settlement_after.verified_at is not null and v_settlement_after.verified_by_profile_id = v_finance_profile_id);
  perform pg_temp.admin_settlement_record_result('commission becomes available', v_commission_after.commission_status = 'available' and v_commission_after.available_at is not null);
  perform pg_temp.admin_settlement_record_result('reseller balance credited exactly once', round(v_available_after - v_available_before, 2) = round(v_commission_amount, 2) and v_pending_after = greatest(v_pending_before - v_commission_amount, 0));
  perform pg_temp.admin_settlement_record_result('stock is not mutated by settlement verification', v_stock_before.total_stock_quantity = v_stock_after.total_stock_quantity and v_stock_before.reserved_stock_quantity = v_stock_after.reserved_stock_quantity and v_stock_before.sold_stock_quantity = v_stock_after.sold_stock_quantity);
  perform pg_temp.admin_settlement_record_result('no withdrawal is created', v_withdrawal_count_after = v_withdrawal_count_before);
  perform pg_temp.admin_settlement_record_result('audit events are written', v_audit_verified_count >= 2 and v_audit_balance_count = 1);

  perform pg_temp.admin_settlement_set_context(v_finance_clerk);
  perform public.admin_verify_supplier_settlement(
    v_order_id,
    'DEV-SETTLEMENT-REFERENCE',
    'Development-only private finance note',
    'admin-settlement-verify:dev-boundary'
  );
  perform pg_temp.admin_settlement_reset_context();

  select commission_available_amount
  into v_retry_available
  from public.resellers
  where id = v_reseller_id;

  select count(*)
  into v_retry_audit_count
  from public.audit_logs
  where target_entity_id = v_reseller_id
    and action = 'reseller_available_balance_credited';

  perform pg_temp.admin_settlement_record_result('same-key retry is idempotent', v_retry_available = v_available_after and v_retry_audit_count = v_audit_balance_count);

  perform pg_temp.admin_settlement_set_context(v_finance_clerk);
  perform pg_temp.admin_settlement_expect_blocked(
    'conflicting retry is blocked',
    format($sql$select * from public.admin_verify_supplier_settlement(%L::uuid, 'DIFFERENT-REFERENCE', 'Different note', 'admin-settlement-verify:dev-boundary')$sql$, v_order_id)
  );
  perform pg_temp.admin_settlement_reset_context();

  perform pg_temp.admin_settlement_set_context(v_finance_clerk);
  perform pg_temp.admin_settlement_record_result('admin safe reads expose pending or verified settlement safely', exists (select 1 from public.get_admin_supplier_settlement_safe(v_order_id)));
  perform pg_temp.admin_settlement_reset_context();
end;
$$;

select test_name, passed, details
from admin_settlement_verification_test_results
order by test_name;

do $$
begin
  if exists (select 1 from admin_settlement_verification_test_results where not passed) then
    raise exception 'Admin settlement verification RPC boundary tests failed';
  end if;
end;
$$;

rollback;
