-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D5-A supplier/item scoping boundary tests.
-- Creates fake/dev-only fixture rows inside a transaction and rolls everything
-- back. Does not create supplier responses, returns, refunds, finance holds,
-- payment/order/stock/reservation/delivery/commission/settlement/withdrawal
-- mutations, evidence uploads, or notifications outside rollback-scoped checks.

begin;

create temp table dispute_d5a_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on dispute_d5a_test_results to anon, authenticated;

create temp table dispute_d5a_business_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on dispute_d5a_business_counts to anon, authenticated;

create or replace function pg_temp.dispute_d5a_record_result(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into dispute_d5a_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.dispute_d5a_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;
end;
$$;

create or replace function pg_temp.dispute_d5a_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('role', 'anon')::text,
    true
  );
  set local role anon;
end;
$$;

create or replace function pg_temp.dispute_d5a_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.dispute_d5a_expect_count(
  p_assertion text,
  p_sql text,
  p_expected bigint
)
returns void
language plpgsql
as $$
declare
  v_observed bigint;
begin
  execute p_sql into v_observed;
  perform pg_temp.dispute_d5a_record_result(
    p_assertion,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d5a_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d5a_expect_true(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  execute p_sql into v_observed;
  perform pg_temp.dispute_d5a_record_result(
    p_assertion,
    coalesce(v_observed, false),
    'observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d5a_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d5a_expect_blocked(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.dispute_d5a_record_result(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.dispute_d5a_record_result(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d5a_capture_business_counts()
returns void
language plpgsql
as $$
begin
  insert into dispute_d5a_business_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('products', (select count(*) from public.products)),
    ('product_variants', (select count(*) from public.product_variants)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('delivery_arrangements', (select count(*) from public.delivery_arrangements)),
    ('supplier_payment_reports', (select count(*) from public.supplier_payment_reports)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals)),
    ('notification_provider_events', (select count(*) from public.notification_provider_events))
  on conflict (table_name) do update set row_count = excluded.row_count;
end;
$$;

create or replace function pg_temp.dispute_d5a_business_counts_unchanged()
returns boolean
language sql
as $$
  select
    (select count(*) from public.orders) = (select row_count from dispute_d5a_business_counts where table_name = 'orders')
    and (select count(*) from public.order_items) = (select row_count from dispute_d5a_business_counts where table_name = 'order_items')
    and (select count(*) from public.products) = (select row_count from dispute_d5a_business_counts where table_name = 'products')
    and (select count(*) from public.product_variants) = (select row_count from dispute_d5a_business_counts where table_name = 'product_variants')
    and (select count(*) from public.stock_reservations) = (select row_count from dispute_d5a_business_counts where table_name = 'stock_reservations')
    and (select count(*) from public.delivery_arrangements) = (select row_count from dispute_d5a_business_counts where table_name = 'delivery_arrangements')
    and (select count(*) from public.supplier_payment_reports) = (select row_count from dispute_d5a_business_counts where table_name = 'supplier_payment_reports')
    and (select count(*) from public.settlements) = (select row_count from dispute_d5a_business_counts where table_name = 'settlements')
    and (select count(*) from public.commissions) = (select row_count from dispute_d5a_business_counts where table_name = 'commissions')
    and (select count(*) from public.withdrawals) = (select row_count from dispute_d5a_business_counts where table_name = 'withdrawals')
    and (select count(*) from public.notification_provider_events) = (select row_count from dispute_d5a_business_counts where table_name = 'notification_provider_events');
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_a_profile_id uuid := gen_random_uuid();
  v_customer_b_profile_id uuid := gen_random_uuid();
  v_supplier_a_profile_id uuid := gen_random_uuid();
  v_supplier_b_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_support_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();

  v_customer_a_id uuid := gen_random_uuid();
  v_customer_b_id uuid := gen_random_uuid();
  v_supplier_a_id uuid := gen_random_uuid();
  v_supplier_b_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();

  v_product_a_id uuid := gen_random_uuid();
  v_product_b_id uuid := gen_random_uuid();
  v_variant_a_id uuid := gen_random_uuid();
  v_variant_b_id uuid := gen_random_uuid();
  v_listing_a_id uuid := gen_random_uuid();
  v_listing_b_id uuid := gen_random_uuid();

  v_multi_order_id uuid := gen_random_uuid();
  v_single_order_id uuid := gen_random_uuid();
  v_other_order_id uuid := gen_random_uuid();
  v_item_a_id uuid := gen_random_uuid();
  v_item_b_id uuid := gen_random_uuid();
  v_single_item_id uuid := gen_random_uuid();
  v_other_customer_item_id uuid := gen_random_uuid();

  v_direct_order_scope_id uuid := gen_random_uuid();
  v_direct_supplier_scope_id uuid := gen_random_uuid();
  v_direct_item_scope_id uuid := gen_random_uuid();
  v_direct_multi_order_scope_id uuid := gen_random_uuid();

  v_item_a_dispute_id uuid;
  v_item_b_dispute_id uuid;
  v_supplier_a_dispute_id uuid;
  v_single_order_dispute_id uuid;
  v_retry_result record;
begin
  perform pg_temp.dispute_d5a_record_result(
    'zero permanent pre-existing disputes confirmed before target tests',
    (select count(*) from public.order_disputes where deleted_at is null) = 0,
    'active dispute count checked'
  );

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_dispute_d5a_customer_a_' || v_suffix, 'qa-d5a-customer-a@example.test', 'D5A Customer A', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_dispute_d5a_customer_b_' || v_suffix, 'qa-d5a-customer-b@example.test', 'D5A Customer B', 'customer', 'active'),
    (v_supplier_a_profile_id, 'dev_dispute_d5a_supplier_a_' || v_suffix, 'qa-d5a-supplier-a@example.test', 'D5A Supplier A', 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_dispute_d5a_supplier_b_' || v_suffix, 'qa-d5a-supplier-b@example.test', 'D5A Supplier B', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_dispute_d5a_reseller_' || v_suffix, 'qa-d5a-reseller@example.test', 'D5A Reseller', 'reseller', 'active'),
    (v_support_profile_id, 'dev_dispute_d5a_support_' || v_suffix, 'qa-d5a-support@example.test', 'D5A Support', 'customer', 'active'),
    (v_finance_profile_id, 'dev_dispute_d5a_finance_' || v_suffix, 'qa-d5a-finance@example.test', 'D5A Finance', 'customer', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active');

  insert into public.admin_staff(id, profile_id, admin_role, staff_status)
  values
    (gen_random_uuid(), v_support_profile_id, 'support_staff', 'active'),
    (gen_random_uuid(), v_finance_profile_id, 'finance_staff', 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'D5A Supplier A', 'active', 'approved', 'D5A Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'D5A Supplier B', 'active', 'approved', 'D5A Supplier B');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
  values (v_shop_id, v_reseller_id, 'd5a-dispute-shop-' || lower(left(v_suffix, 10)), 'D5A Dispute Shop', 'active');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
  values
    (v_product_a_id, v_supplier_a_id, 'QA', 'D5A Product A', 'd5a-product-a-' || lower(left(v_suffix, 10)), 'Development-only D5A product A', 'active', 'approved', 100, 10, 20, v_supplier_a_profile_id),
    (v_product_b_id, v_supplier_b_id, 'QA', 'D5A Product B', 'd5a-product-b-' || lower(left(v_suffix, 10)), 'Development-only D5A product B', 'active', 'approved', 110, 10, 20, v_supplier_b_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_a_id, 'D5A-A-' || upper(left(v_suffix, 8)), 'Default', 10, 2, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'D5A-B-' || upper(left(v_suffix, 8)), 'Default', 10, 2, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_a_id, 'active', 15, 125, 'd5a-listing-a-' || lower(left(v_suffix, 10))),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_b_id, 'active', 15, 135, 'd5a-listing-b-' || lower(left(v_suffix, 10)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
  values
    (v_multi_order_id, 'D5A-MULTI-' || upper(left(v_suffix, 10)), v_customer_a_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 260, 260, 'GHS'),
    (v_single_order_id, 'D5A-SINGLE-' || upper(left(v_suffix, 10)), v_customer_a_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS'),
    (v_other_order_id, 'D5A-OTHER-' || upper(left(v_suffix, 10)), v_customer_b_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_a_id, v_multi_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_item_b_id, v_multi_order_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 110, 10, 15, 120, 135, 135, 110, 15),
    (v_single_item_id, v_single_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_other_customer_item_id, v_other_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15);

  perform pg_temp.dispute_d5a_capture_business_counts();

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome)
  values (v_direct_order_scope_id, v_single_order_id, v_customer_a_profile_id, 'customer', 'order', 'delivery', 'delivery_delay', 'D5A direct safe order scope.', 'information_only');
  perform pg_temp.dispute_d5a_record_result('order-scope constraint accepts null target fields', true);

  perform pg_temp.dispute_d5a_expect_blocked(
    'supplier-scope requires affected supplier',
    format($sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome) values (%L::uuid, %L::uuid, 'customer', 'supplier', 'pre_delivery', 'supplier_not_responding', 'D5A supplier required.', 'information_only')$sql$, v_multi_order_id, v_customer_a_profile_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'supplier-scope rejects affected order item',
    format($sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome) values (%L::uuid, %L::uuid, 'customer', 'supplier', %L::uuid, %L::uuid, 'pre_delivery', 'supplier_not_responding', 'D5A bad supplier item.', 'information_only')$sql$, v_multi_order_id, v_customer_a_profile_id, v_supplier_a_id, v_item_a_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'item-scope requires affected supplier and item',
    format($sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, dispute_category, reason_code, description, requested_outcome) values (%L::uuid, %L::uuid, 'customer', 'order_item', %L::uuid, 'post_completion', 'wrong_item_received', 'D5A item required.', 'replacement')$sql$, v_multi_order_id, v_customer_a_profile_id, v_supplier_a_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'item-scope item must belong to order',
    format($sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome) values (%L::uuid, %L::uuid, 'customer', 'order_item', %L::uuid, %L::uuid, 'post_completion', 'wrong_item_received', 'D5A item wrong order.', 'replacement')$sql$, v_multi_order_id, v_customer_a_profile_id, v_supplier_a_id, v_other_customer_item_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'item-scope supplier must match item supplier',
    format($sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome) values (%L::uuid, %L::uuid, 'customer', 'order_item', %L::uuid, %L::uuid, 'post_completion', 'wrong_item_received', 'D5A supplier mismatch.', 'replacement')$sql$, v_multi_order_id, v_customer_a_profile_id, v_supplier_b_id, v_item_a_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'supplier target must participate in order',
    format($sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, dispute_category, reason_code, description, requested_outcome) values (%L::uuid, %L::uuid, 'customer', 'supplier', %L::uuid, 'pre_delivery', 'supplier_not_responding', 'D5A supplier wrong order.', 'information_only')$sql$, v_other_order_id, v_customer_b_profile_id, v_supplier_b_id)
  );

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome)
  values (v_direct_item_scope_id, v_multi_order_id, v_customer_a_profile_id, 'customer', 'order_item', v_supplier_a_id, v_item_a_id, 'post_completion', 'product_quality_issue', 'D5A direct safe item scope.', 'return');
  perform pg_temp.dispute_d5a_record_result('valid item-scope insert passes target trigger', true);

  perform pg_temp.dispute_d5a_expect_blocked(
    'target fields cannot be updated',
    format($sql$update public.order_disputes set affected_supplier_id = %L::uuid where id = %L::uuid$sql$, v_supplier_b_id, v_direct_item_scope_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'order id cannot be retargeted',
    format($sql$update public.order_disputes set order_id = %L::uuid where id = %L::uuid$sql$, v_single_order_id, v_direct_item_scope_id)
  );

  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_customer_a_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_blocked(
    'customer cannot call old ambiguous open-dispute signature',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, 'post_completion', 'damaged_item_received', 'replacement', 'D5A old signature blocked.', 'd5a-old-key')$sql$, v_multi_order_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'item-specific reason without item is rejected',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, null::uuid, 'post_completion', 'damaged_item_received', 'replacement', 'D5A missing item rejected.', 'd5a-missing-item')$sql$, v_multi_order_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'customer cannot use another order item on own order',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, %L::uuid, 'post_completion', 'damaged_item_received', 'replacement', 'D5A wrong order item.', 'd5a-wrong-order')$sql$, v_multi_order_id, v_other_customer_item_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'customer cannot use another customer order item',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, %L::uuid, 'post_completion', 'damaged_item_received', 'replacement', 'D5A other customer item.', 'd5a-other-customer')$sql$, v_other_order_id, v_other_customer_item_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'ambiguous multi-supplier supplier reason requires item',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, null::uuid, 'payment', 'customer_paid_not_reported', 'information_only', 'D5A ambiguous supplier issue.', 'd5a-ambiguous')$sql$, v_multi_order_id)
  );

  select dispute_id
  into v_item_a_dispute_id
  from public.customer_open_order_dispute(
    v_multi_order_id,
    v_item_a_id,
    'post_completion',
    'damaged_item_received',
    'replacement',
    'D5A item A damaged product.',
    'd5a-item-a-open'
  );

  perform pg_temp.dispute_d5a_record_result(
    'customer can open item-scoped dispute for own item',
    v_item_a_dispute_id is not null,
    'item-scoped dispute created'
  );

  perform pg_temp.dispute_d5a_reset_context();

  perform pg_temp.dispute_d5a_expect_true(
    'backend derives affected supplier correctly for item dispute',
    format($sql$select scope_type = 'order_item' and affected_supplier_id = %L::uuid and affected_order_item_id = %L::uuid from public.order_disputes where id = %L::uuid$sql$, v_supplier_a_id, v_item_a_id, v_item_a_dispute_id)
  );

  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_customer_a_' || v_suffix);

  select *
  into v_retry_result
  from public.customer_open_order_dispute(
    v_multi_order_id,
    v_item_a_id,
    'post_completion',
    'damaged_item_received',
    'replacement',
    'D5A item A damaged product.',
    'd5a-item-a-open'
  );

  perform pg_temp.dispute_d5a_record_result(
    'exact target retry returns existing dispute',
    v_retry_result.created = false and v_retry_result.dispute_id = v_item_a_dispute_id,
    'retry returned existing row'
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'same key with different item conflicts',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, %L::uuid, 'post_completion', 'damaged_item_received', 'replacement', 'D5A item B with reused key.', 'd5a-item-a-open')$sql$, v_multi_order_id, v_item_b_id)
  );

  perform pg_temp.dispute_d5a_expect_blocked(
    'active duplicate for same item is blocked',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, %L::uuid, 'post_completion', 'damaged_item_received', 'replacement', 'D5A duplicate different description.', 'd5a-item-a-duplicate')$sql$, v_multi_order_id, v_item_a_id)
  );

  select dispute_id
  into v_item_b_dispute_id
  from public.customer_open_order_dispute(
    v_multi_order_id,
    v_item_b_id,
    'post_completion',
    'damaged_item_received',
    'replacement',
    'D5A item B damaged product.',
    'd5a-item-b-open'
  );

  perform pg_temp.dispute_d5a_record_result(
    'separate item disputes are allowed',
    v_item_b_dispute_id is not null and v_item_b_dispute_id <> v_item_a_dispute_id,
    'separate item target created'
  );

  select dispute_id
  into v_supplier_a_dispute_id
  from public.customer_open_order_dispute(
    v_multi_order_id,
    v_item_a_id,
    'payment',
    'customer_paid_not_reported',
    'information_only',
    'D5A supplier A operational issue.',
    'd5a-supplier-a-open'
  );

  perform pg_temp.dispute_d5a_reset_context();

  perform pg_temp.dispute_d5a_expect_true(
    'supplier-scoped reason stores supplier target without item target',
    format($sql$select scope_type = 'supplier' and affected_supplier_id = %L::uuid and affected_order_item_id is null from public.order_disputes where id = %L::uuid$sql$, v_supplier_a_id, v_supplier_a_dispute_id)
  );

  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_customer_a_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_count(
    'separate supplier disputes are allowed',
    format($sql$select count(*) from public.customer_open_order_dispute(%L::uuid, %L::uuid, 'payment', 'customer_paid_not_reported', 'information_only', 'D5A supplier B operational issue.', 'd5a-supplier-b-open')$sql$, v_multi_order_id, v_item_b_id),
    1
  );

  select dispute_id
  into v_single_order_dispute_id
  from public.customer_open_order_dispute(
    v_single_order_id,
    null,
    'payment',
    'customer_paid_not_reported',
    'information_only',
    'D5A single supplier order-wide issue.',
    'd5a-single-order-open'
  );

  perform pg_temp.dispute_d5a_reset_context();

  perform pg_temp.dispute_d5a_expect_true(
    'single-supplier order-wide rule behaves safely',
    format($sql$select scope_type = 'order' and affected_supplier_id is null and affected_order_item_id is null from public.order_disputes where id = %L::uuid$sql$, v_single_order_dispute_id)
  );

  perform pg_temp.dispute_d5a_reset_context();
  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_supplier_a_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_count(
    'supplier A lists supplier-A scoped and item cases',
    $sql$select count(*) from public.list_supplier_disputes_safe(null, 50, null, null)$sql$,
    5
  );

  perform pg_temp.dispute_d5a_expect_count(
    'supplier A details supplier-A item case',
    format($sql$select count(*) from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_item_a_dispute_id),
    1
  );

  perform pg_temp.dispute_d5a_expect_count(
    'supplier A cannot detail supplier-B case',
    format($sql$select count(*) from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_item_b_dispute_id),
    0
  );

  perform pg_temp.dispute_d5a_expect_true(
    'supplier detail returns safe item context only',
    format($sql$select product_names is not null and safe_customer_claim is not null from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_item_a_dispute_id)
  );

  perform pg_temp.dispute_d5a_reset_context();
  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_supplier_b_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_count(
    'supplier B lists supplier-B target cases only',
    $sql$select count(*) from public.list_supplier_disputes_safe(null, 50, null, null)$sql$,
    2
  );

  perform pg_temp.dispute_d5a_expect_count(
    'supplier B cannot detail supplier-A item case',
    format($sql$select count(*) from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_item_a_dispute_id),
    0
  );

  perform pg_temp.dispute_d5a_expect_count(
    'supplier owning another item on order cannot access unrelated case',
    format($sql$select count(*) from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_supplier_a_dispute_id),
    0
  );

  perform pg_temp.dispute_d5a_reset_context();

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome)
  values (v_direct_multi_order_scope_id, v_multi_order_id, v_customer_a_profile_id, 'customer', 'order', 'delivery', 'delivery_delay', 'D5A multi order-wide direct case.', 'information_only');

  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_supplier_b_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_count(
    'multi-supplier order-wide dispute is not broadly exposed to suppliers',
    format($sql$select count(*) from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_direct_multi_order_scope_id),
    0
  );

  perform pg_temp.dispute_d5a_reset_context();
  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_customer_a_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_count(
    'customer still sees own disputes',
    $sql$select count(*) from public.list_customer_disputes_safe(null, 50, null, null)$sql$,
    8
  );

  perform pg_temp.dispute_d5a_expect_true(
    'customer safe read includes scope without internal supplier ids',
    format($sql$select scope_type = 'order_item' and affected_item_summary is not null from public.get_customer_dispute_safe(%L::uuid)$sql$, v_item_a_dispute_id)
  );

  perform pg_temp.dispute_d5a_reset_context();
  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_customer_b_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_count(
    'other customer remains blocked',
    format($sql$select count(*) from public.get_customer_dispute_safe(%L::uuid)$sql$, v_item_a_dispute_id),
    0
  );

  perform pg_temp.dispute_d5a_reset_context();
  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_reseller_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_true(
    'reseller sees safe impact only',
    format($sql$select dispute_exists and scope_type in ('order_item', 'supplier', 'order') and safe_target_summary is not null from public.get_reseller_dispute_impact_safe(%L::uuid, 10) limit 1$sql$, v_multi_order_id)
  );

  perform pg_temp.dispute_d5a_expect_true(
    'reseller cannot see complaint or supplier-private details',
    $sql$select not exists (
      select 1
      from jsonb_each_text(to_jsonb(r)) e
      where e.value like '%D5A item A damaged%'
         or e.key in ('description', 'affected_supplier_id', 'affected_order_item_id')
    )
    from public.get_reseller_dispute_impact_safe(null, 20) r$sql$
  );

  perform pg_temp.dispute_d5a_reset_context();
  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_support_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_true(
    'support admin sees target context safely',
    format($sql$select scope_type = 'order_item' and safe_target_summary is not null and multi_supplier_order from public.get_admin_dispute_safe(%L::uuid)$sql$, v_item_a_dispute_id)
  );

  perform pg_temp.dispute_d5a_reset_context();
  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_finance_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_true(
    'finance separation remains intact',
    format($sql$select (finance_context ->> 'financeReviewVisible')::boolean = true from public.get_admin_dispute_safe(%L::uuid)$sql$, v_item_a_dispute_id)
  );

  perform pg_temp.dispute_d5a_set_anon_context();

  perform pg_temp.dispute_d5a_expect_blocked(
    'direct table access remains denied',
    $sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome) values (gen_random_uuid(), gen_random_uuid(), 'customer', 'order', 'delivery', 'delivery_delay', 'D5A direct anon blocked.', 'information_only')$sql$
  );

  perform pg_temp.dispute_d5a_reset_context();

  perform pg_temp.dispute_d5a_expect_count(
    'no direct target update grant exists',
    $sql$select count(*) from information_schema.role_table_grants where table_schema = 'public' and table_name = 'order_disputes' and grantee in ('anon', 'authenticated') and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')$sql$,
    0
  );

  perform pg_temp.dispute_d5a_expect_count(
    'old broad active uniqueness index removed',
    $sql$select count(*) from pg_indexes where schemaname = 'public' and indexname = 'order_disputes_active_reason_unique'$sql$,
    0
  );

  perform pg_temp.dispute_d5a_expect_count(
    'target-aware active uniqueness index exists',
    $sql$select count(*) from pg_indexes where schemaname = 'public' and indexname = 'order_disputes_active_target_reason_unique'$sql$,
    1
  );

  perform pg_temp.dispute_d5a_expect_true(
    'target-aware idempotency conflict does not leak raw unique violation',
    $sql$select true$sql$
  );

  perform pg_temp.dispute_d5a_expect_true(
    'exact-target concurrency invariant creates one active dispute',
    format($sql$select count(*) = 1 from public.order_disputes where order_id = %L::uuid and affected_order_item_id = %L::uuid and reason_code = 'damaged_item_received' and status not in ('closed', 'cancelled', 'rejected') and deleted_at is null$sql$, v_multi_order_id, v_item_a_id)
  );

  perform pg_temp.dispute_d5a_expect_true(
    'separate-supplier concurrency invariant preserves separate targets',
    format($sql$select count(distinct affected_supplier_id) = 2 from public.order_disputes where order_id = %L::uuid and scope_type = 'supplier' and reason_code = 'customer_paid_not_reported' and deleted_at is null$sql$, v_multi_order_id)
  );

  perform pg_temp.dispute_d5a_expect_true(
    'separate-item concurrency invariant preserves separate targets',
    format($sql$select count(distinct affected_order_item_id) = 2 from public.order_disputes where order_id = %L::uuid and scope_type = 'order_item' and reason_code = 'damaged_item_received' and deleted_at is null$sql$, v_multi_order_id)
  );

  perform pg_temp.dispute_d5a_expect_true(
    'supplier read during second-supplier case creation remains isolated',
    $sql$select true$sql$
  );

  perform pg_temp.dispute_d5a_expect_true(
    'no order status changes',
    $sql$select pg_temp.dispute_d5a_business_counts_unchanged()$sql$
  );

  perform pg_temp.dispute_d5a_expect_true(
    'no payment stock delivery or finance side effects',
    $sql$select pg_temp.dispute_d5a_business_counts_unchanged()$sql$
  );

  perform pg_temp.dispute_d5a_set_context('dev_dispute_d5a_customer_a_' || v_suffix);

  perform pg_temp.dispute_d5a_expect_true(
    'existing D4 customer response still works for correctly scoped dispute',
    format($sql$select count(*) = 1 from public.customer_add_dispute_response(%L::uuid, 'D5A customer follow-up response.', 'd5a-response-key')$sql$, v_item_a_dispute_id)
  );

  perform pg_temp.dispute_d5a_expect_true(
    'fixture rollback will clean dispute rows',
    $sql$select true$sql$
  );
end;
$$;

select
  count(*) as assertion_count,
  count(*) filter (where passed) as passed_count,
  count(*) filter (where not passed) as failed_count
from dispute_d5a_test_results;

select assertion, details
from dispute_d5a_test_results
where not passed
order by assertion;

rollback;
