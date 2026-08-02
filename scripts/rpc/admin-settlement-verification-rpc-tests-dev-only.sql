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
  v_suffix text := replace(gen_random_uuid()::text, '-', '');
  v_customer_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_item_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_commission_id uuid := gen_random_uuid();
begin
  perform pg_temp.admin_settlement_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_finance_profile_id, v_finance_clerk, 'dev-admin-settlement-finance@example.invalid', 'Dev Finance Settlement Operator', 'customer', 'active'),
    (v_admin_profile_id, v_admin_clerk, 'dev-admin-settlement-support@example.invalid', 'Dev Support Admin Operator', 'customer', 'active'),
    (v_customer_profile_id, 'dev_admin_settlement_customer_' || v_suffix, 'dev-admin-settlement-customer@example.invalid', 'Dev Settlement Customer', 'customer', 'active'),
    (v_supplier_profile_id, 'dev_admin_settlement_supplier_' || v_suffix, 'dev-admin-settlement-supplier@example.invalid', 'Dev Settlement Supplier', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_admin_settlement_reseller_' || v_suffix, 'dev-admin-settlement-reseller@example.invalid', 'Dev Settlement Reseller', 'reseller', 'active');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values
    (v_finance_profile_id, 'finance_staff', '{}'::jsonb, 'active'),
    (v_admin_profile_id, 'admin', '{}'::jsonb, 'active');

  v_order_id := gen_random_uuid();
  v_reseller_id := gen_random_uuid();
  v_variant_id := gen_random_uuid();
  v_reservation_id := gen_random_uuid();
  v_settlement_id := gen_random_uuid();
  v_commission_amount := 30.00;
  v_supplier_clerk := 'dev_admin_settlement_supplier_' || v_suffix;
  v_customer_clerk := 'dev_admin_settlement_customer_' || v_suffix;
  v_reseller_clerk := 'dev_admin_settlement_reseller_' || v_suffix;

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile_id, 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Settlement Supplier', 'active', 'approved');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
  values (v_reseller_id, v_reseller_profile_id, 'individual', 'approved', 'active', 0, 30.00, 0, 0);

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-settlement-' || lower(substr(v_suffix, 1, 10)), 'Dev Settlement Shop', 'active', 'public');

  insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values (v_product_id, v_supplier_id, 'Dev Settlement', 'Dev Settlement Product', 'dev-settlement-product-' || lower(substr(v_suffix, 1, 8)), 'active', 'approved', 100, 20, 40, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values (v_variant_id, v_product_id, 'DEV-SETTLEMENT-' || upper(substr(v_suffix, 1, 8)), 'Dev Settlement Variant', 20, 1, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 30, 150, 'dev-settlement-listing-' || lower(substr(v_suffix, 1, 8)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code)
  values (v_order_id, 'DEV-SETTLE-' || upper(substr(v_suffix, 1, 8)), v_customer_id, v_reseller_id, v_shop_id, 'payment_reported', 'supplier_reported', 'delivered', 150, 0, 150, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values (v_item_id, v_order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 20, 30, 120, 150, 150, 50, 30);

  insert into public.stock_reservations(id, reservation_reference, customer_id, reseller_id, reseller_product_id, product_id, variant_id, order_id, quantity, reservation_status, expires_at, committed_at)
  values (v_reservation_id, 'DEV-SETTLEMENT-RES-' || upper(substr(v_suffix, 1, 8)), v_customer_id, v_reseller_id, v_listing_id, v_product_id, v_variant_id, v_order_id, 1, 'committed', now() + interval '1 day', now());

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount)
  values (v_settlement_id, v_supplier_id, v_order_id, 'due', 50, 0, 50);

  insert into public.supplier_payment_reports(order_id, supplier_id, reported_by_profile_id, reported_amount, currency_code, idempotency_key)
  values (v_order_id, v_supplier_id, v_supplier_profile_id, 150, 'GHS', 'dev-settlement-payment-report-' || v_suffix);

  insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount)
  values (v_commission_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'awaiting_supplier_settlement', v_commission_amount);

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
