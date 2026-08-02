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
  v_reservation_id uuid := gen_random_uuid();
  v_commission_id uuid := gen_random_uuid();
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
  values
    (v_finance_profile_id, v_finance_clerk, 'dev-admin-settlement-concurrency@example.invalid', 'Dev Settlement Concurrency Finance', 'customer', 'active'),
    (v_customer_profile_id, 'dev_admin_settlement_concurrency_customer_' || v_suffix, 'dev-admin-settlement-concurrency-customer@example.invalid', 'Dev Settlement Concurrency Customer', 'customer', 'active'),
    (v_supplier_profile_id, 'dev_admin_settlement_concurrency_supplier_' || v_suffix, 'dev-admin-settlement-concurrency-supplier@example.invalid', 'Dev Settlement Concurrency Supplier', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_admin_settlement_concurrency_reseller_' || v_suffix, 'dev-admin-settlement-concurrency-reseller@example.invalid', 'Dev Settlement Concurrency Reseller', 'reseller', 'active');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values (v_finance_profile_id, 'finance_staff', '{}'::jsonb, 'active');

  v_order_id := gen_random_uuid();
  v_reseller_id := gen_random_uuid();
  v_settlement_id := gen_random_uuid();
  v_variant_id := gen_random_uuid();
  v_commission_amount := 30.00;

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile_id, 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Settlement Concurrency Supplier', 'active', 'approved');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
  values (v_reseller_id, v_reseller_profile_id, 'individual', 'approved', 'active', 0, 30.00, 0, 0);

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-settlement-concurrency-' || lower(substr(v_suffix, 1, 10)), 'Dev Settlement Concurrency Shop', 'active', 'public');

  insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values (v_product_id, v_supplier_id, 'Dev Settlement', 'Dev Settlement Concurrency Product', 'dev-settlement-concurrency-product-' || lower(substr(v_suffix, 1, 8)), 'active', 'approved', 100, 20, 40, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values (v_variant_id, v_product_id, 'DEV-SETTLEMENT-CONC-' || upper(substr(v_suffix, 1, 8)), 'Dev Settlement Concurrency Variant', 20, 1, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 30, 150, 'dev-settlement-concurrency-listing-' || lower(substr(v_suffix, 1, 8)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code)
  values (v_order_id, 'DEV-SETTLE-C-' || upper(substr(v_suffix, 1, 8)), v_customer_id, v_reseller_id, v_shop_id, 'payment_reported', 'supplier_reported', 'delivered', 150, 0, 150, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values (v_item_id, v_order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 20, 30, 120, 150, 150, 50, 30);

  insert into public.stock_reservations(id, reservation_reference, customer_id, reseller_id, reseller_product_id, product_id, variant_id, order_id, quantity, reservation_status, expires_at, committed_at)
  values (v_reservation_id, 'DEV-SETTLEMENT-CONC-RES-' || upper(substr(v_suffix, 1, 8)), v_customer_id, v_reseller_id, v_listing_id, v_product_id, v_variant_id, v_order_id, 1, 'committed', now() + interval '1 day', now());

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount)
  values (v_settlement_id, v_supplier_id, v_order_id, 'due', 50, 0, 50);

  insert into public.supplier_payment_reports(order_id, supplier_id, reported_by_profile_id, reported_amount, currency_code, idempotency_key)
  values (v_order_id, v_supplier_id, v_supplier_profile_id, 150, 'GHS', 'dev-settlement-concurrency-payment-report-' || v_suffix);

  insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount)
  values (v_commission_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'awaiting_supplier_settlement', v_commission_amount);

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
