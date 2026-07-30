-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Checkout Phase C Group 2 order creation and atomic stock reservation RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction and rolls everything back.
-- This script is created in Group C2 but must not be executed until explicit development approval.
-- Reservation expiry assertions target stock_reservations.expires_at, not orders.expires_at.

begin;

create temp table checkout_order_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on checkout_order_test_results to authenticated;

create temp table checkout_order_fixture_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on checkout_order_fixture_counts to authenticated;

create temp table checkout_order_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on checkout_order_fixture_ids to authenticated;

create or replace function pg_temp.checkout_order_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into checkout_order_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.checkout_order_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.checkout_order_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.checkout_order_expect_count(
  p_test_name text,
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
  perform pg_temp.checkout_order_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.checkout_order_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.checkout_order_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.checkout_order_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.checkout_order_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.checkout_order_expect_no_rows_changed(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_row_count bigint;
begin
  execute p_sql;
  get diagnostics v_row_count = row_count;

  perform pg_temp.checkout_order_record_result(
    p_test_name,
    v_row_count = 0,
    'row_count=' || coalesce(v_row_count::text, 'null')
  );
exception when others then
  perform pg_temp.checkout_order_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.checkout_order_expect_equal_uuid(
  p_test_name text,
  p_left uuid,
  p_right uuid
)
returns void
language plpgsql
as $$
begin
  perform pg_temp.checkout_order_record_result(
    p_test_name,
    p_left = p_right,
    'left=' || coalesce(p_left::text, 'null') || ', right=' || coalesce(p_right::text, 'null')
  );
end;
$$;

do $$
declare
  v_customer_a_profile_id uuid := gen_random_uuid();
  v_customer_b_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_customer_a_id uuid := gen_random_uuid();
  v_customer_b_id uuid := gen_random_uuid();
  v_admin_customer_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_inactive_supplier_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_active_product_id uuid := gen_random_uuid();
  v_pending_product_id uuid := gen_random_uuid();
  v_rejected_product_id uuid := gen_random_uuid();
  v_archived_product_id uuid := gen_random_uuid();
  v_inactive_supplier_product_id uuid := gen_random_uuid();
  v_inactive_variant_product_id uuid := gen_random_uuid();
  v_low_stock_product_id uuid := gen_random_uuid();
  v_active_variant_id uuid := gen_random_uuid();
  v_pending_product_variant_id uuid := gen_random_uuid();
  v_rejected_product_variant_id uuid := gen_random_uuid();
  v_archived_product_variant_id uuid := gen_random_uuid();
  v_inactive_supplier_variant_id uuid := gen_random_uuid();
  v_inactive_variant_id uuid := gen_random_uuid();
  v_low_stock_variant_id uuid := gen_random_uuid();
  v_active_listing_id uuid := gen_random_uuid();
  v_pending_listing_id uuid := gen_random_uuid();
  v_rejected_product_listing_id uuid := gen_random_uuid();
  v_archived_listing_id uuid := gen_random_uuid();
  v_inactive_supplier_listing_id uuid := gen_random_uuid();
  v_inactive_variant_listing_id uuid := gen_random_uuid();
  v_low_stock_listing_id uuid := gen_random_uuid();
  v_customer_a_address_id uuid := gen_random_uuid();
  v_customer_b_address_id uuid := gen_random_uuid();
  v_positive_draft_id uuid;
  v_draft_status_draft_id uuid;
  v_abandoned_draft_id uuid;
  v_customer_b_draft_id uuid;
  v_pending_listing_draft_id uuid := gen_random_uuid();
  v_rejected_product_draft_id uuid := gen_random_uuid();
  v_archived_listing_draft_id uuid := gen_random_uuid();
  v_inactive_supplier_draft_id uuid := gen_random_uuid();
  v_inactive_variant_draft_id uuid := gen_random_uuid();
  v_insufficient_stock_draft_id uuid := gen_random_uuid();
  v_order_id uuid;
  v_duplicate_order_id uuid;
  v_initial_reserved integer;
begin
  perform pg_temp.checkout_order_reset_context();

  insert into checkout_order_fixture_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('inventory_movements', (select count(*) from public.inventory_movements)),
    ('delivery_quotes', (select count(*) from public.delivery_quotes)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals));

  insert into public.profiles(id, clerk_user_id, email, full_name, phone, whatsapp, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_checkout_order_customer_a', 'dev-checkout-order-customer-a@example.test', 'Dev Checkout Order Customer A', '0201000101', '0201000102', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_checkout_order_customer_b', 'dev-checkout-order-customer-b@example.test', 'Dev Checkout Order Customer B', '0201000201', null, 'customer', 'active'),
    (v_reseller_profile_id, 'dev_checkout_order_reseller', 'dev-checkout-order-reseller@example.test', 'Dev Checkout Order Reseller', '0201000301', null, 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_checkout_order_supplier', 'dev-checkout-order-supplier@example.test', 'Dev Checkout Order Supplier', '0201000401', null, 'supplier_owner', 'active'),
    (v_admin_profile_id, 'dev_checkout_order_admin', 'dev-checkout-order-admin@example.test', 'Dev Checkout Order Admin', '0201000501', null, 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active'),
    (v_admin_customer_id, v_admin_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_checkout_order_reseller', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-checkout-order-shop', 'Dev Checkout Order Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_id, v_supplier_profile_id, 'Dev Checkout Supplier', 'active', 'approved', 'Dev Checkout Supplier'),
    (v_inactive_supplier_id, v_supplier_profile_id, 'Dev Inactive Checkout Supplier', 'pending', 'pending_review', 'Dev Inactive Checkout Supplier');

  insert into public.products(
    id,
    supplier_id,
    category,
    name,
    slug,
    description,
    brand,
    product_status,
    approval_status,
    base_price_amount,
    platform_margin_amount,
    max_reseller_margin_amount,
    currency_code,
    created_by_profile_id
  )
  values
    (v_active_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Order Product', 'dev-checkout-order-product', 'Approved checkout order product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_pending_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Order Pending Product', 'dev-checkout-order-pending-product', 'Pending product', 'Dev Safe Brand', 'pending_approval', 'pending_review', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_rejected_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Order Rejected Product', 'dev-checkout-order-rejected-product', 'Rejected product', 'Dev Safe Brand', 'rejected', 'rejected', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_archived_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Order Archived Product', 'dev-checkout-order-archived-product', 'Archived product', 'Dev Safe Brand', 'archived', 'archived', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_inactive_supplier_product_id, v_inactive_supplier_id, 'QA Test', 'Dev Checkout Inactive Supplier Product', 'dev-checkout-inactive-supplier-product', 'Inactive supplier product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_inactive_variant_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Inactive Variant Product', 'dev-checkout-inactive-variant-product', 'Inactive variant product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_low_stock_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Low Stock Product', 'dev-checkout-low-stock-product', 'Low stock product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', v_supplier_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_active_variant_id, v_active_product_id, 'DEV-ORDER-ACTIVE', 'Default', 5, 0, 0, 'active'),
    (v_pending_product_variant_id, v_pending_product_id, 'DEV-ORDER-PENDING', 'Default', 5, 0, 0, 'active'),
    (v_rejected_product_variant_id, v_rejected_product_id, 'DEV-ORDER-REJECTED', 'Default', 5, 0, 0, 'active'),
    (v_archived_product_variant_id, v_archived_product_id, 'DEV-ORDER-ARCHIVED', 'Default', 5, 0, 0, 'active'),
    (v_inactive_supplier_variant_id, v_inactive_supplier_product_id, 'DEV-ORDER-INACTIVE-SUPPLIER', 'Default', 5, 0, 0, 'active'),
    (v_inactive_variant_id, v_inactive_variant_product_id, 'DEV-ORDER-INACTIVE-VARIANT', 'Default', 5, 0, 0, 'archived'),
    (v_low_stock_variant_id, v_low_stock_product_id, 'DEV-ORDER-LOW-STOCK', 'Default', 1, 0, 0, 'active');

  insert into public.reseller_products(
    id,
    reseller_id,
    shop_id,
    product_id,
    variant_id,
    listing_status,
    reseller_margin_amount,
    customer_product_price_amount,
    share_slug
  )
  values
    (v_active_listing_id, v_reseller_id, v_shop_id, v_active_product_id, v_active_variant_id, 'active', 30, 150, 'dev-checkout-order-active-listing'),
    (v_pending_listing_id, v_reseller_id, v_shop_id, v_pending_product_id, v_pending_product_variant_id, 'needs_review', 30, 150, 'dev-checkout-order-pending-listing'),
    (v_rejected_product_listing_id, v_reseller_id, v_shop_id, v_rejected_product_id, v_rejected_product_variant_id, 'active', 30, 150, 'dev-checkout-order-rejected-product'),
    (v_archived_listing_id, v_reseller_id, v_shop_id, v_archived_product_id, v_archived_product_variant_id, 'archived', 30, 150, 'dev-checkout-order-archived-listing'),
    (v_inactive_supplier_listing_id, v_reseller_id, v_shop_id, v_inactive_supplier_product_id, v_inactive_supplier_variant_id, 'active', 30, 150, 'dev-checkout-order-inactive-supplier'),
    (v_inactive_variant_listing_id, v_reseller_id, v_shop_id, v_inactive_variant_product_id, v_inactive_variant_id, 'active', 30, 150, 'dev-checkout-order-inactive-variant'),
    (v_low_stock_listing_id, v_reseller_id, v_shop_id, v_low_stock_product_id, v_low_stock_variant_id, 'active', 30, 150, 'dev-checkout-order-low-stock');

  insert into public.customer_delivery_addresses(
    id,
    customer_id,
    label,
    recipient_name,
    phone,
    region,
    city,
    area,
    street_address,
    landmark,
    is_default
  )
  values
    (v_customer_a_address_id, v_customer_a_id, 'Home', 'Dev Checkout Order Customer A', '0201000101', 'Greater Accra', 'Accra', 'East Legon', 'Fake dev checkout order street', 'Fake dev landmark', true),
    (v_customer_b_address_id, v_customer_b_id, 'Home', 'Dev Checkout Order Customer B', '0201000201', 'Ashanti', 'Kumasi', 'Adum', 'Fake dev customer B street', null, true);

  perform pg_temp.checkout_order_set_context('dev_checkout_order_customer_a');

  select draft_id
  into v_positive_draft_id
  from public.create_checkout_draft_from_listing(v_active_listing_id, 2);

  perform public.update_checkout_draft_contact_address(v_positive_draft_id, v_customer_a_address_id, '0201000109');

  select draft_id
  into v_draft_status_draft_id
  from public.create_checkout_draft_from_listing(v_active_listing_id, 1);

  select draft_id
  into v_abandoned_draft_id
  from public.create_checkout_draft_from_listing(v_active_listing_id, 1);

  perform public.abandon_checkout_draft(v_abandoned_draft_id);

  perform pg_temp.checkout_order_reset_context();
  perform pg_temp.checkout_order_set_context('dev_checkout_order_customer_b');

  select draft_id
  into v_customer_b_draft_id
  from public.create_checkout_draft_from_listing(v_active_listing_id, 1);

  perform public.update_checkout_draft_contact_address(v_customer_b_draft_id, v_customer_b_address_id, null);

  perform pg_temp.checkout_order_reset_context();

  insert into public.checkout_drafts(
    id, customer_id, customer_profile_id, reseller_product_id, reseller_id, shop_id, supplier_id, product_id, variant_id,
    quantity, draft_status, product_name_snapshot, product_slug_snapshot, product_description_snapshot, product_category_snapshot,
    product_brand_snapshot, final_customer_price_snapshot_amount, line_total_snapshot_amount, currency_code,
    customer_contact_snapshot, delivery_address_id, delivery_address_snapshot, public_listing_snapshot
  )
  values
    (v_pending_listing_draft_id, v_customer_a_id, v_customer_a_profile_id, v_pending_listing_id, v_reseller_id, v_shop_id, v_supplier_id, v_pending_product_id, v_pending_product_variant_id, 1, 'review_pending', 'Pending listing product', 'pending-listing-product', 'Pending listing draft', 'QA Test', 'Dev Safe Brand', 150, 150, 'GHS', '{}'::jsonb, v_customer_a_address_id, '{"label":"Home"}'::jsonb, '{}'::jsonb),
    (v_rejected_product_draft_id, v_customer_a_id, v_customer_a_profile_id, v_rejected_product_listing_id, v_reseller_id, v_shop_id, v_supplier_id, v_rejected_product_id, v_rejected_product_variant_id, 1, 'review_pending', 'Rejected product', 'rejected-product', 'Rejected product draft', 'QA Test', 'Dev Safe Brand', 150, 150, 'GHS', '{}'::jsonb, v_customer_a_address_id, '{"label":"Home"}'::jsonb, '{}'::jsonb),
    (v_archived_listing_draft_id, v_customer_a_id, v_customer_a_profile_id, v_archived_listing_id, v_reseller_id, v_shop_id, v_supplier_id, v_archived_product_id, v_archived_product_variant_id, 1, 'review_pending', 'Archived listing', 'archived-listing', 'Archived listing draft', 'QA Test', 'Dev Safe Brand', 150, 150, 'GHS', '{}'::jsonb, v_customer_a_address_id, '{"label":"Home"}'::jsonb, '{}'::jsonb),
    (v_inactive_supplier_draft_id, v_customer_a_id, v_customer_a_profile_id, v_inactive_supplier_listing_id, v_reseller_id, v_shop_id, v_inactive_supplier_id, v_inactive_supplier_product_id, v_inactive_supplier_variant_id, 1, 'review_pending', 'Inactive supplier', 'inactive-supplier', 'Inactive supplier draft', 'QA Test', 'Dev Safe Brand', 150, 150, 'GHS', '{}'::jsonb, v_customer_a_address_id, '{"label":"Home"}'::jsonb, '{}'::jsonb),
    (v_inactive_variant_draft_id, v_customer_a_id, v_customer_a_profile_id, v_inactive_variant_listing_id, v_reseller_id, v_shop_id, v_supplier_id, v_inactive_variant_product_id, v_inactive_variant_id, 1, 'review_pending', 'Inactive variant', 'inactive-variant', 'Inactive variant draft', 'QA Test', 'Dev Safe Brand', 150, 150, 'GHS', '{}'::jsonb, v_customer_a_address_id, '{"label":"Home"}'::jsonb, '{}'::jsonb),
    (v_insufficient_stock_draft_id, v_customer_a_id, v_customer_a_profile_id, v_low_stock_listing_id, v_reseller_id, v_shop_id, v_supplier_id, v_low_stock_product_id, v_low_stock_variant_id, 2, 'review_pending', 'Low stock', 'low-stock', 'Low stock draft', 'QA Test', 'Dev Safe Brand', 150, 300, 'GHS', '{}'::jsonb, v_customer_a_address_id, '{"label":"Home"}'::jsonb, '{}'::jsonb);

  insert into checkout_order_fixture_ids(fixture_key, fixture_id)
  values
    ('customer_a_draft', v_positive_draft_id),
    ('customer_b_draft', v_customer_b_draft_id),
    ('draft_status_draft', v_draft_status_draft_id),
    ('abandoned_draft', v_abandoned_draft_id),
    ('pending_listing_draft', v_pending_listing_draft_id),
    ('rejected_product_draft', v_rejected_product_draft_id),
    ('archived_listing_draft', v_archived_listing_draft_id),
    ('inactive_supplier_draft', v_inactive_supplier_draft_id),
    ('inactive_variant_draft', v_inactive_variant_draft_id),
    ('insufficient_stock_draft', v_insufficient_stock_draft_id),
    ('active_variant', v_active_variant_id),
    ('low_stock_variant', v_low_stock_variant_id);

  select reserved_stock_quantity
  into v_initial_reserved
  from public.product_variants
  where id = v_active_variant_id;

  perform pg_temp.checkout_order_set_context('dev_checkout_order_customer_a');

  select order_id
  into v_order_id
  from public.create_order_from_checkout_draft(v_positive_draft_id, 'dev-checkout-order-idem-a');

  insert into checkout_order_fixture_ids(fixture_key, fixture_id)
  values ('positive_order', v_order_id);

  perform pg_temp.checkout_order_expect_count(
    'customer can create one order from own review_pending draft',
    $sql$select count(*) from public.checkout_order_safe_row((select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order')) where checkout_draft_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_a_draft') and order_status = 'placed_pending_confirmation'$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'order price is server-calculated',
    $sql$select count(*) from public.checkout_order_safe_row((select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order')) where final_customer_price_amount = 150 and line_total_amount = 300 and total_payable_amount = 300$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'one order item is created',
    $sql$select count(*) from public.order_items where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and quantity = 2 and customer_product_price_snapshot_amount = 150 and line_total_amount = 300$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'one reservation is created',
    $sql$select count(*) from public.stock_reservations where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and reservation_status = 'reserved' and quantity = 2 and expires_at > now()$sql$,
    1
  );

  perform pg_temp.checkout_order_reset_context();

  perform pg_temp.checkout_order_expect_count(
    'reserved stock increments once',
    format('select count(*) from public.product_variants where id = %L::uuid and reserved_stock_quantity = %s', v_active_variant_id, v_initial_reserved + 2),
    1
  );

  perform pg_temp.checkout_order_set_context('dev_checkout_order_customer_a');

  select order_id
  into v_duplicate_order_id
  from public.create_order_from_checkout_draft(v_positive_draft_id, 'dev-checkout-order-idem-a');

  perform pg_temp.checkout_order_expect_equal_uuid(
    'duplicate confirmation returns the same order',
    v_order_id,
    v_duplicate_order_id
  );

  perform pg_temp.checkout_order_expect_count(
    'one checkout draft cannot create two orders',
    $sql$select count(*) from public.orders where checkout_draft_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_a_draft')$sql$,
    1
  );

  perform pg_temp.checkout_order_reset_context();

  perform pg_temp.checkout_order_expect_count(
    'duplicate confirmation does not increment reserved stock twice',
    format('select count(*) from public.product_variants where id = %L::uuid and reserved_stock_quantity = %s', v_active_variant_id, v_initial_reserved + 2),
    1
  );

  perform pg_temp.checkout_order_set_context('dev_checkout_order_customer_a');

  perform pg_temp.checkout_order_expect_count(
    'converted draft stores resulting order reference',
    $sql$select count(*) from public.checkout_drafts where id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_a_draft') and draft_status = 'converted' and converted_order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and converted_at is not null$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'commercial snapshots are server-calculated',
    $sql$select count(*) from public.order_items where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and supplier_base_price_snapshot_amount = 100 and platform_margin_snapshot_amount = 20 and reseller_margin_snapshot_amount = 30 and reseller_cost_snapshot_amount = 120 and settlement_due_amount = 100 and commission_amount = 60$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'payment is not collected',
    $sql$select count(*) from public.orders where id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and payment_method = 'pay_on_delivery' and payment_collection_status = 'not_collected'$sql$,
    1
  );

  perform pg_temp.checkout_order_reset_context();

  update public.reseller_products
  set customer_product_price_amount = 999,
      reseller_margin_amount = 879
  where id = v_active_listing_id;

  update public.products
  set base_price_amount = 888,
      platform_margin_amount = 77
  where id = v_active_product_id;

  perform pg_temp.checkout_order_set_context('dev_checkout_order_customer_a');

  perform pg_temp.checkout_order_expect_count(
    'order price remains immutable after listing price changes',
    $sql$select count(*) from public.order_items where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and customer_product_price_snapshot_amount = 150 and line_total_amount = 300$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'order-item snapshot remains immutable after product changes',
    $sql$select count(*) from public.order_items where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and supplier_base_price_snapshot_amount = 100 and platform_margin_snapshot_amount = 20 and reseller_margin_snapshot_amount = 30$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_blocked(
    'customer A cannot confirm customer B draft',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_b_draft'), 'blocked-cross-customer')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'draft status draft is blocked',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'draft_status_draft'), 'blocked-draft')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'abandoned draft is blocked',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'abandoned_draft'), 'blocked-abandoned')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'pending listing is blocked',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'pending_listing_draft'), 'blocked-pending-listing')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'rejected product is blocked',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'rejected_product_draft'), 'blocked-rejected-product')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'archived listing is blocked',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'archived_listing_draft'), 'blocked-archived-listing')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'inactive supplier is blocked',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'inactive_supplier_draft'), 'blocked-inactive-supplier')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'invalid or inactive variant is blocked',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'inactive_variant_draft'), 'blocked-inactive-variant')$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'insufficient stock blocks the whole transaction',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'insufficient_stock_draft'), 'blocked-insufficient-stock')$sql$
  );

  perform pg_temp.checkout_order_expect_count(
    'failed confirmation leaves no order, item, reservation, or stock increment',
    $sql$select count(*) from public.orders o where o.checkout_draft_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'insufficient_stock_draft')$sql$,
    0
  );

  perform pg_temp.checkout_order_reset_context();

  perform pg_temp.checkout_order_expect_count(
    'insufficient stock failure does not increment reserved stock',
    $sql$select count(*) from public.product_variants where id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'low_stock_variant') and reserved_stock_quantity = 0$sql$,
    1
  );

  perform pg_temp.checkout_order_set_context('dev_checkout_order_customer_a');

  perform pg_temp.checkout_order_expect_blocked(
    'browser cannot supply price',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_b_draft'), 'extra-price', 1::numeric)$sql$
  );

  perform pg_temp.checkout_order_expect_blocked(
    'browser cannot supply supplier reseller product or variant ids',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_b_draft'), 'extra-ids', gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$sql$
  );

  perform pg_temp.checkout_order_expect_no_rows_changed(
    'customer cannot alter commercial snapshots',
    $sql$update public.order_items set commission_amount = 999 where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order')$sql$
  );

  perform pg_temp.checkout_order_reset_context();
  perform pg_temp.checkout_order_set_context('dev_checkout_order_reseller');

  perform pg_temp.checkout_order_expect_blocked(
    'reseller cannot create customer order',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_b_draft'), 'blocked-reseller')$sql$
  );

  perform pg_temp.checkout_order_reset_context();
  perform pg_temp.checkout_order_set_context('dev_checkout_order_supplier');

  perform pg_temp.checkout_order_expect_blocked(
    'supplier_owner cannot create customer order',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_b_draft'), 'blocked-supplier')$sql$
  );

  perform pg_temp.checkout_order_reset_context();
  perform pg_temp.checkout_order_set_context('dev_checkout_order_admin');

  perform pg_temp.checkout_order_expect_blocked(
    'admin_staff cannot bypass customer ownership checks',
    $sql$select count(*) from public.create_order_from_checkout_draft((select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_b_draft'), 'blocked-admin')$sql$
  );

  perform pg_temp.checkout_order_reset_context();

  perform pg_temp.checkout_order_expect_count(
    'order created audit log is written',
    $sql$select count(*) from public.audit_logs where action = 'order_created' and target_entity_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order')$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'order item created audit log is written',
    $sql$select count(*) from public.audit_logs where action = 'order_item_created' and target_entity_id in (select id from public.order_items where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order'))$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'stock reserved audit log is written',
    $sql$select count(*) from public.audit_logs where action = 'stock_reserved' and target_entity_id in (select id from public.stock_reservations where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order'))$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'checkout draft converted audit log is written',
    $sql$select count(*) from public.audit_logs where action = 'checkout_draft_converted' and target_entity_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'customer_a_draft')$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'inventory movement is created for reservation',
    $sql$select count(*) from public.inventory_movements where order_id = (select fixture_id from checkout_order_fixture_ids where fixture_key = 'positive_order') and movement_type = 'reservation_created'$sql$,
    1
  );

  perform pg_temp.checkout_order_expect_count(
    'no delivery quote is created',
    $sql$select count(*) from public.delivery_quotes$sql$,
    (select row_count from checkout_order_fixture_counts where table_name = 'delivery_quotes')
  );

  perform pg_temp.checkout_order_expect_count(
    'no commission is released',
    $sql$select count(*) from public.commissions$sql$,
    (select row_count from checkout_order_fixture_counts where table_name = 'commissions')
  );

  perform pg_temp.checkout_order_expect_count(
    'no settlement is marked paid',
    $sql$select count(*) from public.settlements$sql$,
    (select row_count from checkout_order_fixture_counts where table_name = 'settlements')
  );

  perform pg_temp.checkout_order_expect_count(
    'no withdrawal is created',
    $sql$select count(*) from public.withdrawals$sql$,
    (select row_count from checkout_order_fixture_counts where table_name = 'withdrawals')
  );
end;
$$;

reset role;

select test_name, passed, details
from checkout_order_test_results
order by test_name;

do $$
declare
  v_failure_count integer;
  v_failure_details text;
begin
  select count(*)
  into v_failure_count
  from checkout_order_test_results
  where passed is false;

  if v_failure_count > 0 then
    select string_agg(test_name || ': ' || coalesce(details, ''), E'\n' order by test_name)
    into v_failure_details
    from checkout_order_test_results
    where passed is false;

    raise exception 'Checkout order/stock RPC tests failed: % failure(s): %', v_failure_count, v_failure_details;
  end if;

  raise notice 'Checkout order/stock RPC tests passed.';
end;
$$;

rollback;

-- Rollback is intentional. This script must not leave fixture data behind.
-- True concurrent oversell testing for Group C3 should use two separate database sessions:
-- 1. Create two customers and two review_pending drafts for the same active listing/variant.
-- 2. Set variant total stock to 1 and reserved/sold stock to 0.
-- 3. Call create_order_from_checkout_draft from both sessions at the same time.
-- 4. Verify exactly one success, exactly one INSUFFICIENT_STOCK failure, exactly one order,
--    exactly one stock reservation, reserved stock = 1, and no negative availability.
