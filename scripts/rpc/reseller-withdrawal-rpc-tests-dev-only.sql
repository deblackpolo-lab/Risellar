-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Verifies reseller withdrawal request and finance-admin manual payout RPC boundaries.
-- This script uses fake/dev-only fixture rows and rolls back all fixture data.

begin;

create temp table reseller_withdrawal_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on reseller_withdrawal_test_results to authenticated;

create or replace function pg_temp.reseller_withdrawal_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into reseller_withdrawal_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.reseller_withdrawal_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.reseller_withdrawal_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.reseller_withdrawal_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.reseller_withdrawal_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.reseller_withdrawal_record_result(p_test_name, true, sqlerrm);
end;
$$;

do $$
declare
  v_reseller_profile_id uuid := gen_random_uuid();
  v_other_reseller_profile_id uuid := gen_random_uuid();
  v_customer_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_general_admin_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_other_reseller_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_variant_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_order_id uuid := gen_random_uuid();
  v_item_id uuid := gen_random_uuid();
  v_settlement_id uuid := gen_random_uuid();
  v_commission_a_id uuid := gen_random_uuid();
  v_commission_b_id uuid := gen_random_uuid();
  v_payout_account_id uuid;
  v_withdrawal_id uuid;
  v_request_reference text;
  v_available_before numeric := 125.00;
  v_pending_before numeric := 20.00;
  v_pending_withdrawal_before numeric := 0.00;
  v_withdrawn_before numeric := 0.00;
  v_available_after numeric;
  v_pending_withdrawal_after numeric;
  v_withdrawn_after numeric;
  v_status text;
  v_paid_at timestamptz;
  v_audit_request_count bigint;
  v_audit_paid_count bigint;
  v_orders_before bigint := 0;
  v_orders_after bigint := 0;
  v_stock_before bigint := 0;
  v_stock_after bigint := 0;
  v_settlements_before bigint := 0;
  v_settlements_after bigint := 0;
begin
  perform pg_temp.reseller_withdrawal_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_reseller_profile_id, 'dev_withdrawal_reseller', 'dev-withdrawal-reseller@example.invalid', 'Dev Withdrawal Reseller', 'reseller', 'active'),
    (v_other_reseller_profile_id, 'dev_withdrawal_other_reseller', 'dev-withdrawal-other@example.invalid', 'Dev Other Reseller', 'reseller', 'active'),
    (v_customer_profile_id, 'dev_withdrawal_customer', 'dev-withdrawal-customer@example.invalid', 'Dev Withdrawal Customer', 'customer', 'active'),
    (v_supplier_profile_id, 'dev_withdrawal_supplier', 'dev-withdrawal-supplier@example.invalid', 'Dev Withdrawal Supplier', 'supplier_owner', 'active'),
    (v_finance_profile_id, 'dev_withdrawal_finance', 'dev-withdrawal-finance@example.invalid', 'Dev Withdrawal Finance', 'customer', 'active'),
    (v_general_admin_profile_id, 'dev_withdrawal_general_admin', 'dev-withdrawal-admin@example.invalid', 'Dev Withdrawal General Admin', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values
    (v_finance_profile_id, 'finance_staff', '{}'::jsonb, 'active'),
    (v_general_admin_profile_id, 'admin', '{}'::jsonb, 'active');

  insert into public.resellers(
    id,
    profile_id,
    reseller_type,
    approval_status,
    payout_status,
    commission_available_amount,
    commission_pending_amount,
    commission_pending_withdrawal_amount,
    commission_withdrawn_amount,
    payout_details_masked
  )
  values
    (v_reseller_id, v_reseller_profile_id, 'individual', 'approved', 'active', v_available_before, v_pending_before, v_pending_withdrawal_before, v_withdrawn_before, '{}'::jsonb),
    (v_other_reseller_id, v_other_reseller_profile_id, 'individual', 'approved', 'active', 5.00, 0, 0, 0, '{}'::jsonb);

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile_id, 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Withdrawal Supplier', 'active', 'approved');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-withdrawal-shop', 'Dev Withdrawal Shop', 'active', 'public');

  insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values (v_product_id, v_supplier_id, 'Dev Withdrawal', 'Dev Withdrawal Product', 'dev-withdrawal-product', 'active', 'approved', 100, 20, 40, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values (v_variant_id, v_product_id, 'DEV-WITHDRAWAL', 'Dev Withdrawal Variant', 30, 0, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 30, 150, 'dev-withdrawal-listing');

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code, completed_at)
  values (v_order_id, 'DEV-WITHDRAWAL', v_customer_id, v_reseller_id, v_shop_id, 'completed', 'settlement_verified', 'delivered', 150, 0, 150, 'GHS', now());

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values (v_item_id, v_order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 20, 30, 120, 150, 150, 50, 50);

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount, verified_at)
  values (v_settlement_id, v_supplier_id, v_order_id, 'paid', 50, 50, 0, now());

  insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount, available_at)
  values
    (v_commission_a_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'available', 30.00, now() - interval '2 days'),
    (v_commission_b_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'available', 20.00, now() - interval '1 day');

  select count(*) into v_orders_before from public.orders;
  select count(*) into v_stock_before from public.stock_reservations;
  select count(*) into v_settlements_before from public.settlements;

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_reseller');

  select payout_account_id
  into v_payout_account_id
  from public.reseller_upsert_payout_account('Dev Withdrawal Account', 'mtn_momo', '+233000000000', 'dev-withdrawal-payout-account-key');

  perform pg_temp.reseller_withdrawal_record_result('reseller can save payout account', v_payout_account_id is not null);

  select withdrawal_id, request_reference
  into v_withdrawal_id, v_request_reference
  from public.reseller_request_withdrawal(50.00, v_payout_account_id, 'dev-withdrawal-request-key');

  select commission_available_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount
  into v_available_after, v_pending_withdrawal_after, v_withdrawn_after
  from public.resellers
  where id = v_reseller_id;

  perform pg_temp.reseller_withdrawal_record_result('reseller can request withdrawal', v_withdrawal_id is not null);
  perform pg_temp.reseller_withdrawal_record_result('available balance reserved once', v_available_after = v_available_before - 50.00);
  perform pg_temp.reseller_withdrawal_record_result('pending withdrawal increases once', v_pending_withdrawal_after = v_pending_withdrawal_before + 50.00);
  perform pg_temp.reseller_withdrawal_record_result('withdrawn unchanged after request', v_withdrawn_after = v_withdrawn_before);

  perform pg_temp.reseller_withdrawal_reset_context();

  select count(*) into v_audit_request_count
  from public.audit_logs
  where target_entity_id = v_withdrawal_id
    and action = 'reseller_withdrawal_requested_allocation_reserved';

  perform pg_temp.reseller_withdrawal_record_result('request audit event created once', v_audit_request_count = 1);

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_reseller');

  perform pg_temp.reseller_withdrawal_expect_blocked(
    'duplicate pending withdrawal blocked',
    format($sql$select count(*) from public.reseller_request_withdrawal(10.00, %L::uuid, 'dev-withdrawal-second-key')$sql$, v_payout_account_id)
  );

  perform pg_temp.reseller_withdrawal_expect_blocked(
    'same idempotency key conflicting retry blocked',
    format($sql$select count(*) from public.reseller_request_withdrawal(60.00, %L::uuid, 'dev-withdrawal-request-key')$sql$, v_payout_account_id)
  );

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_other_reseller');
  perform pg_temp.reseller_withdrawal_expect_blocked(
    'payout account ownership enforced',
    format($sql$select count(*) from public.reseller_request_withdrawal(10.00, %L::uuid, 'dev-withdrawal-other-key')$sql$, v_payout_account_id)
  );

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_customer');
  perform pg_temp.reseller_withdrawal_expect_blocked(
    'customer cannot request reseller withdrawal',
    format($sql$select count(*) from public.reseller_request_withdrawal(10.00, %L::uuid, 'dev-withdrawal-customer-key')$sql$, v_payout_account_id)
  );

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_supplier');
  perform pg_temp.reseller_withdrawal_expect_blocked(
    'supplier cannot request reseller withdrawal',
    format($sql$select count(*) from public.reseller_request_withdrawal(10.00, %L::uuid, 'dev-withdrawal-supplier-key')$sql$, v_payout_account_id)
  );

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_general_admin');
  perform pg_temp.reseller_withdrawal_expect_blocked(
    'general admin cannot mark withdrawal paid',
    format($sql$select count(*) from public.admin_mark_reseller_withdrawal_paid(%L::uuid, 'DEV-PAYOUT-GENERAL', null, 'dev-withdrawal-payout-general-key')$sql$, v_withdrawal_id)
  );

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_reseller');
  perform pg_temp.reseller_withdrawal_expect_blocked(
    'reseller cannot mark own withdrawal paid',
    format($sql$select count(*) from public.admin_mark_reseller_withdrawal_paid(%L::uuid, 'DEV-PAYOUT-OWNER', null, 'dev-withdrawal-payout-owner-key')$sql$, v_withdrawal_id)
  );

  perform pg_temp.reseller_withdrawal_set_context('dev_withdrawal_finance');
  select withdrawal_status, paid_at, pending_withdrawal_amount, withdrawn_amount
  into v_status, v_paid_at, v_pending_withdrawal_after, v_withdrawn_after
  from public.admin_mark_reseller_withdrawal_paid(v_withdrawal_id, 'DEV-PAYOUT-REF-001', 'development-only note', 'dev-withdrawal-payout-key');

  perform pg_temp.reseller_withdrawal_record_result('finance staff can mark paid', v_status = 'paid' and v_paid_at is not null);
  perform pg_temp.reseller_withdrawal_record_result('pending withdrawal decreases after paid', v_pending_withdrawal_after = 0);
  perform pg_temp.reseller_withdrawal_record_result('withdrawn increases after paid', v_withdrawn_after = 50.00);

  perform pg_temp.reseller_withdrawal_reset_context();

  select commission_available_amount
  into v_available_after
  from public.resellers
  where id = v_reseller_id;

  perform pg_temp.reseller_withdrawal_record_result('available unchanged after paid', v_available_after = v_available_before - 50.00);

  select count(*) into v_audit_paid_count
  from public.audit_logs
  where target_entity_id = v_withdrawal_id
    and action = 'reseller_withdrawal_paid';

  perform pg_temp.reseller_withdrawal_record_result('paid audit event created once', v_audit_paid_count = 1);

  select count(*) into v_orders_after from public.orders;
  select count(*) into v_stock_after from public.stock_reservations;
  select count(*) into v_settlements_after from public.settlements;

  perform pg_temp.reseller_withdrawal_record_result('no order rows created or changed by withdrawal test', v_orders_after = v_orders_before);
  perform pg_temp.reseller_withdrawal_record_result('no stock reservation rows created by withdrawal test', v_stock_after = v_stock_before);
  perform pg_temp.reseller_withdrawal_record_result('no settlement rows created by withdrawal test', v_settlements_after = v_settlements_before);
end;
$$;

select *
from reseller_withdrawal_test_results
order by test_name;

do $$
begin
  if exists (select 1 from reseller_withdrawal_test_results where not passed) then
    raise exception 'Reseller withdrawal RPC boundary tests failed';
  end if;
end;
$$;

rollback;
