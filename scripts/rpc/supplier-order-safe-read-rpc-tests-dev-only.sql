-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Order Handling S2 supplier-safe order read RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction and rolls everything back.

begin;

create temp table supplier_order_safe_read_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_safe_read_test_results to anon, authenticated;

create temp table supplier_order_safe_read_fixture_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on supplier_order_safe_read_fixture_counts to anon, authenticated;

create or replace function pg_temp.supplier_order_safe_read_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_safe_read_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_safe_read_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.supplier_order_safe_read_set_anon_context()
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

create or replace function pg_temp.supplier_order_safe_read_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_safe_read_expect_count(
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
  perform pg_temp.supplier_order_safe_read_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.supplier_order_safe_read_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.supplier_order_safe_read_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_safe_read_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_safe_read_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_customer_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_supplier_a_profile_id uuid := gen_random_uuid();
  v_supplier_b_profile_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_supplier_a_id uuid := gen_random_uuid();
  v_supplier_b_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_a_id uuid := gen_random_uuid();
  v_product_b_id uuid := gen_random_uuid();
  v_variant_a_id uuid := gen_random_uuid();
  v_variant_b_id uuid := gen_random_uuid();
  v_listing_a_id uuid := gen_random_uuid();
  v_listing_b_id uuid := gen_random_uuid();
  v_draft_a_id uuid := gen_random_uuid();
  v_draft_b_id uuid := gen_random_uuid();
  v_order_a_id uuid := gen_random_uuid();
  v_order_b_id uuid := gen_random_uuid();
  v_order_item_a_id uuid := gen_random_uuid();
  v_order_item_b_id uuid := gen_random_uuid();
  v_reservation_a_id uuid := gen_random_uuid();
  v_reservation_b_id uuid := gen_random_uuid();
  v_list_row jsonb;
  v_detail_row jsonb;
  v_forbidden_key text;
  v_required_key text;
  v_required_list_keys text[] := array[
    'order_id',
    'order_number',
    'created_at',
    'updated_at',
    'order_status',
    'order_status_label',
    'is_supplier_actionable',
    'product_name',
    'product_slug',
    'product_image_snapshot',
    'quantity',
    'supplier_amount_expected',
    'currency_code',
    'payment_method_label',
    'payment_status_label',
    'reservation_status_label',
    'reservation_expires_at',
    'recipient_name',
    'location_summary',
    'reseller_shop_name'
  ];
  v_required_detail_keys text[] := array[
    'order_id',
    'order_number',
    'created_at',
    'updated_at',
    'order_status',
    'order_status_label',
    'is_supplier_actionable',
    'product_name',
    'product_slug',
    'product_image_snapshot',
    'variant_sku',
    'variant_name',
    'quantity',
    'supplier_amount_expected',
    'customer_total_amount',
    'currency_code',
    'payment_method_label',
    'payment_status_label',
    'delivery_status_label',
    'reservation_status_label',
    'reservation_expires_at',
    'reservation_quantity',
    'recipient_name',
    'recipient_phone',
    'recipient_whatsapp',
    'delivery_address_snapshot',
    'reseller_shop_name',
    'reseller_shop_slug'
  ];
  v_forbidden_keys text[] := array[
    'customer_id',
    'customer_email',
    'clerk_user_id',
    'customer_metadata',
    'reseller_id',
    'reseller_private_phone',
    'reseller_private_contact',
    'supplier_id',
    'product_id',
    'variant_id',
    'reseller_product_id',
    'supplier_base_price_snapshot_amount',
    'platform_margin_snapshot_amount',
    'reseller_margin_snapshot_amount',
    'reseller_cost_snapshot_amount',
    'commission_amount',
    'settlement_due_amount',
    'settlement_status',
    'risk_level',
    'admin_notes',
    'total_stock_quantity',
    'reserved_stock_quantity',
    'sold_stock_quantity',
    'payment_provider_reference',
    'delivery_provider_reference'
  ];
  v_orders_before bigint;
  v_order_items_before bigint;
  v_reservations_before bigint;
  v_movements_before bigint;
begin
  perform pg_temp.supplier_order_safe_read_reset_context();

  insert into supplier_order_safe_read_fixture_counts(table_name, row_count)
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
    (v_customer_profile_id, 'dev_supplier_order_read_customer', 'dev-supplier-order-read-customer@example.test', 'Dev Customer', '0203000101', null, 'customer', 'active'),
    (v_reseller_profile_id, 'dev_supplier_order_read_reseller', 'dev-supplier-order-read-reseller@example.test', 'Dev Reseller', '0203000201', null, 'reseller', 'active'),
    (v_supplier_a_profile_id, 'dev_supplier_order_read_supplier_a', 'dev-supplier-order-read-a@example.test', 'Dev Supplier A', '0203000301', null, 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_supplier_order_read_supplier_b', 'dev-supplier-order-read-b@example.test', 'Dev Supplier B', '0203000401', null, 'supplier_owner', 'active'),
    (v_admin_profile_id, 'dev_supplier_order_read_admin', 'dev-supplier-order-read-admin@example.test', 'Dev Admin', '0203000501', null, 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_supplier_order_read_reseller', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-supplier-order-read-shop', 'Dev Supplier Order Read Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'Dev Supplier Order Read A', 'active', 'approved', 'Dev Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'Dev Supplier Order Read B', 'active', 'approved', 'Dev Supplier B');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values
    (v_product_a_id, v_supplier_a_id, 'QA Test', 'Dev Supplier Order Read Product A', 'dev-supplier-order-read-product-a', 'Development-only supplier order read product A', 'active', 'approved', 100, 10, 20, 'GHS'),
    (v_product_b_id, v_supplier_b_id, 'QA Test', 'Dev Supplier Order Read Product B', 'dev-supplier-order-read-product-b', 'Development-only supplier order read product B', 'active', 'approved', 100, 10, 20, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_a_id, 'DEV-SUP-ORDER-A', 'Default A', 10, 1, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'DEV-SUP-ORDER-B', 'Default B', 10, 1, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_a_id, 'active', 15, 125, 'dev-supplier-order-read-a'),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_b_id, 'active', 15, 125, 'dev-supplier-order-read-b');

  insert into public.checkout_drafts(
    id,
    customer_id,
    reseller_id,
    shop_id,
    reseller_product_id,
    product_id,
    variant_id,
    supplier_id,
    quantity,
    final_customer_price_amount,
    line_total_amount,
    currency_code,
    draft_status,
    product_name_snapshot,
    product_slug_snapshot,
    product_image_snapshot,
    customer_contact_snapshot,
    delivery_address_snapshot
  )
  values
    (
      v_draft_a_id,
      v_customer_id,
      v_reseller_id,
      v_shop_id,
      v_listing_a_id,
      v_product_a_id,
      v_variant_a_id,
      v_supplier_a_id,
      1,
      125,
      125,
      'GHS',
      'converted',
      'Dev Supplier Order Read Product A',
      'dev-supplier-order-read-product-a',
      jsonb_build_object('primary_alt', 'Dev product A'),
      jsonb_build_object('email', 'should-not-leak@example.test', 'full_name', 'Dev Recipient', 'phone', '0203999000', 'whatsapp', '0203999001'),
      jsonb_build_object('recipient_name', 'Dev Recipient', 'phone', '0203999000', 'region', 'Greater Accra', 'city', 'Accra', 'area', 'East Legon', 'street_address', 'Dev Street 1', 'landmark', 'Dev Landmark')
    ),
    (
      v_draft_b_id,
      v_customer_id,
      v_reseller_id,
      v_shop_id,
      v_listing_b_id,
      v_product_b_id,
      v_variant_b_id,
      v_supplier_b_id,
      1,
      125,
      125,
      'GHS',
      'converted',
      'Dev Supplier Order Read Product B',
      'dev-supplier-order-read-product-b',
      jsonb_build_object('primary_alt', 'Dev product B'),
      jsonb_build_object('email', 'should-not-leak@example.test', 'full_name', 'Dev Recipient', 'phone', '0203999000', 'whatsapp', '0203999001'),
      jsonb_build_object('recipient_name', 'Dev Recipient', 'phone', '0203999000', 'region', 'Greater Accra', 'city', 'Accra', 'area', 'East Legon', 'street_address', 'Dev Street 1', 'landmark', 'Dev Landmark')
    );

  insert into public.orders(
    id,
    order_number,
    customer_id,
    reseller_id,
    shop_id,
    checkout_draft_id,
    order_status,
    payment_method,
    payment_collection_status,
    delivery_status,
    customer_confirmation_status,
    delivery_quote_status,
    subtotal_product_amount,
    total_payable_amount,
    currency_code,
    delivery_address_snapshot,
    customer_contact_snapshot
  )
  values
    (
      v_order_a_id,
      'RSR-DEV-SUP-READ-A',
      v_customer_id,
      v_reseller_id,
      v_shop_id,
      v_draft_a_id,
      'placed_pending_confirmation',
      'pay_on_delivery',
      'not_collected',
      'estimate_selected',
      'pending',
      'pending',
      125,
      125,
      'GHS',
      jsonb_build_object('recipient_name', 'Dev Recipient', 'phone', '0203999000', 'region', 'Greater Accra', 'city', 'Accra', 'area', 'East Legon', 'street_address', 'Dev Street 1', 'landmark', 'Dev Landmark'),
      jsonb_build_object('email', 'should-not-leak@example.test', 'full_name', 'Dev Recipient', 'phone', '0203999000', 'whatsapp', '0203999001')
    ),
    (
      v_order_b_id,
      'RSR-DEV-SUP-READ-B',
      v_customer_id,
      v_reseller_id,
      v_shop_id,
      v_draft_b_id,
      'placed_pending_confirmation',
      'pay_on_delivery',
      'not_collected',
      'estimate_selected',
      'pending',
      'pending',
      125,
      125,
      'GHS',
      jsonb_build_object('recipient_name', 'Dev Recipient', 'phone', '0203999000', 'region', 'Greater Accra', 'city', 'Accra', 'area', 'East Legon', 'street_address', 'Dev Street 1', 'landmark', 'Dev Landmark'),
      jsonb_build_object('email', 'should-not-leak@example.test', 'full_name', 'Dev Recipient', 'phone', '0203999000', 'whatsapp', '0203999001')
    );

  insert into public.order_items(
    id,
    order_id,
    supplier_id,
    product_id,
    variant_id,
    reseller_product_id,
    quantity,
    supplier_base_price_snapshot_amount,
    platform_margin_snapshot_amount,
    reseller_margin_snapshot_amount,
    reseller_cost_snapshot_amount,
    customer_product_price_snapshot_amount,
    line_total_amount,
    settlement_due_amount,
    commission_amount
  )
  values
    (v_order_item_a_id, v_order_a_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_item_b_id, v_order_b_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 100, 10, 15, 110, 125, 125, 25, 15);

  insert into public.stock_reservations(
    id,
    reservation_reference,
    customer_id,
    reseller_id,
    reseller_product_id,
    product_id,
    variant_id,
    order_id,
    quantity,
    reservation_status,
    expires_at
  )
  values
    (v_reservation_a_id, 'RSV-DEV-SUP-READ-A', v_customer_id, v_reseller_id, v_listing_a_id, v_product_a_id, v_variant_a_id, v_order_a_id, 1, 'reserved', now() + interval '1 hour'),
    (v_reservation_b_id, 'RSV-DEV-SUP-READ-B', v_customer_id, v_reseller_id, v_listing_b_id, v_product_b_id, v_variant_b_id, v_order_b_id, 1, 'reserved', now() + interval '1 hour');

  select count(*) into v_orders_before from public.orders;
  select count(*) into v_order_items_before from public.order_items;
  select count(*) into v_reservations_before from public.stock_reservations;
  select count(*) into v_movements_before from public.inventory_movements;

  perform pg_temp.supplier_order_safe_read_set_context('dev_supplier_order_read_supplier_a');

  select to_jsonb(x)
  into v_list_row
  from public.list_supplier_orders_safe(null, 50, null, null) x
  limit 1;

  select to_jsonb(x)
  into v_detail_row
  from public.get_supplier_order_safe(v_order_a_id) x
  limit 1;

  perform pg_temp.supplier_order_safe_read_record_result('supplier_owner can list own orders', v_list_row is not null);
  perform pg_temp.supplier_order_safe_read_record_result('supplier_owner can read own order detail', v_detail_row is not null);

  perform pg_temp.supplier_order_safe_read_expect_count(
    'supplier cannot list another supplier order',
    format($sql$select count(*) from public.list_supplier_orders_safe(null, 50, null, null) where order_id = %L::uuid$sql$, v_order_b_id),
    0
  );

  perform pg_temp.supplier_order_safe_read_expect_count(
    'supplier cannot read another supplier detail',
    format($sql$select count(*) from public.get_supplier_order_safe(%L::uuid)$sql$, v_order_b_id),
    0
  );

  foreach v_required_key in array v_required_list_keys loop
    perform pg_temp.supplier_order_safe_read_record_result(
      'list includes ' || v_required_key,
      v_list_row ? v_required_key,
      coalesce(v_list_row::text, 'null')
    );
  end loop;

  foreach v_required_key in array v_required_detail_keys loop
    perform pg_temp.supplier_order_safe_read_record_result(
      'detail includes ' || v_required_key,
      v_detail_row ? v_required_key,
      coalesce(v_detail_row::text, 'null')
    );
  end loop;

  foreach v_forbidden_key in array v_forbidden_keys loop
    perform pg_temp.supplier_order_safe_read_record_result(
      'list omits ' || v_forbidden_key,
      not (v_list_row ? v_forbidden_key),
      coalesce(v_list_row::text, 'null')
    );

    perform pg_temp.supplier_order_safe_read_record_result(
      'detail omits ' || v_forbidden_key,
      not (v_detail_row ? v_forbidden_key),
      coalesce(v_detail_row::text, 'null')
    );
  end loop;

  perform pg_temp.supplier_order_safe_read_record_result(
    'status mapping is safe',
    v_list_row ->> 'order_status_label' = 'New order - confirm or reject'
      and v_detail_row ->> 'order_status_label' = 'New order - confirm or reject'
  );

  perform pg_temp.supplier_order_safe_read_record_result(
    'product snapshot present',
    v_list_row ->> 'product_name' = 'Dev Supplier Order Read Product A'
      and v_detail_row ->> 'product_name' = 'Dev Supplier Order Read Product A'
  );

  perform pg_temp.supplier_order_safe_read_record_result('quantity present', (v_detail_row ->> 'quantity')::integer = 1);
  perform pg_temp.supplier_order_safe_read_record_result('supplier amount expected present', (v_detail_row ->> 'supplier_amount_expected')::numeric = 100);
  perform pg_temp.supplier_order_safe_read_record_result('currency present', v_detail_row ->> 'currency_code' = 'GHS');
  perform pg_temp.supplier_order_safe_read_record_result('pay on delivery present', v_detail_row ->> 'payment_method_label' = 'Pay on Delivery');
  perform pg_temp.supplier_order_safe_read_record_result('payment not collected present', v_detail_row ->> 'payment_status_label' = 'Payment not collected');
  perform pg_temp.supplier_order_safe_read_record_result('reservation label safe', v_detail_row ->> 'reservation_status_label' = 'Stock reserved');

  perform pg_temp.supplier_order_safe_read_record_result(
    'list has fulfilment preview only',
    v_list_row ? 'recipient_name'
      and v_list_row ? 'location_summary'
      and not (v_list_row ? 'recipient_phone')
      and not (v_list_row ? 'delivery_address_snapshot')
  );

  perform pg_temp.supplier_order_safe_read_record_result(
    'detail has fulfilment contact and address',
    v_detail_row ? 'recipient_name'
      and v_detail_row ? 'recipient_phone'
      and v_detail_row ? 'delivery_address_snapshot'
  );

  perform pg_temp.supplier_order_safe_read_record_result(
    'customer email absent from snapshots',
    position('should-not-leak@example.test' in coalesce(v_list_row::text, '') || coalesce(v_detail_row::text, '')) = 0
  );

  perform pg_temp.supplier_order_safe_read_expect_count(
    'pagination limit enforced',
    $sql$select count(*) from public.list_supplier_orders_safe(null, 1, null, null)$sql$,
    1
  );

  perform pg_temp.supplier_order_safe_read_expect_blocked(
    'invalid status filter blocked',
    $sql$select count(*) from public.list_supplier_orders_safe('supplier_confirmed', 50, null, null)$sql$
  );

  perform pg_temp.supplier_order_safe_read_reset_context();
  perform pg_temp.supplier_order_safe_read_set_context('dev_supplier_order_read_customer');
  perform pg_temp.supplier_order_safe_read_expect_blocked('customer blocked from supplier list', $sql$select count(*) from public.list_supplier_orders_safe(null, 50, null, null)$sql$);
  perform pg_temp.supplier_order_safe_read_expect_blocked('customer blocked from supplier detail', format($sql$select count(*) from public.get_supplier_order_safe(%L::uuid)$sql$, v_order_a_id));

  perform pg_temp.supplier_order_safe_read_reset_context();
  perform pg_temp.supplier_order_safe_read_set_context('dev_supplier_order_read_reseller');
  perform pg_temp.supplier_order_safe_read_expect_blocked('reseller blocked from supplier list', $sql$select count(*) from public.list_supplier_orders_safe(null, 50, null, null)$sql$);
  perform pg_temp.supplier_order_safe_read_expect_blocked('reseller blocked from supplier detail', format($sql$select count(*) from public.get_supplier_order_safe(%L::uuid)$sql$, v_order_a_id));

  perform pg_temp.supplier_order_safe_read_reset_context();
  perform pg_temp.supplier_order_safe_read_set_context('dev_supplier_order_read_admin');
  perform pg_temp.supplier_order_safe_read_expect_blocked('admin_staff blocked from supplier list', $sql$select count(*) from public.list_supplier_orders_safe(null, 50, null, null)$sql$);
  perform pg_temp.supplier_order_safe_read_expect_blocked('admin_staff blocked from supplier detail', format($sql$select count(*) from public.get_supplier_order_safe(%L::uuid)$sql$, v_order_a_id));

  perform pg_temp.supplier_order_safe_read_reset_context();
  perform pg_temp.supplier_order_safe_read_set_anon_context();
  perform pg_temp.supplier_order_safe_read_expect_blocked('anonymous blocked from supplier list', $sql$select count(*) from public.list_supplier_orders_safe(null, 50, null, null)$sql$);
  perform pg_temp.supplier_order_safe_read_expect_blocked('anonymous blocked from supplier detail', format($sql$select count(*) from public.get_supplier_order_safe(%L::uuid)$sql$, v_order_a_id));

  perform pg_temp.supplier_order_safe_read_reset_context();
  perform pg_temp.supplier_order_safe_read_set_context('dev_supplier_order_read_supplier_a');
  perform pg_temp.supplier_order_safe_read_expect_count(
    'missing order does not leak existence',
    format($sql$select count(*) from public.get_supplier_order_safe(%L::uuid)$sql$, gen_random_uuid()),
    0
  );

  perform pg_temp.supplier_order_safe_read_reset_context();

  perform pg_temp.supplier_order_safe_read_record_result(
    'read flow creates no order',
    (select count(*) from public.orders) = v_orders_before
  );
  perform pg_temp.supplier_order_safe_read_record_result(
    'read flow creates no order item',
    (select count(*) from public.order_items) = v_order_items_before
  );
  perform pg_temp.supplier_order_safe_read_record_result(
    'read flow creates no reservation',
    (select count(*) from public.stock_reservations) = v_reservations_before
  );
  perform pg_temp.supplier_order_safe_read_record_result(
    'read flow changes no stock',
    (select reserved_stock_quantity from public.product_variants where id = v_variant_a_id) = 1
  );
  perform pg_temp.supplier_order_safe_read_record_result(
    'read flow changes no order status',
    (select order_status from public.orders where id = v_order_a_id) = 'placed_pending_confirmation'
  );
  perform pg_temp.supplier_order_safe_read_record_result(
    'read flow creates no inventory movement',
    (select count(*) from public.inventory_movements) = v_movements_before
  );
  perform pg_temp.supplier_order_safe_read_record_result(
    'no payment delivery preparation finance side effects',
    (select count(*) from public.delivery_quotes) = (select row_count from supplier_order_safe_read_fixture_counts where table_name = 'delivery_quotes')
      and (select count(*) from public.settlements) = (select row_count from supplier_order_safe_read_fixture_counts where table_name = 'settlements')
      and (select count(*) from public.commissions) = (select row_count from supplier_order_safe_read_fixture_counts where table_name = 'commissions')
      and (select count(*) from public.withdrawals) = (select row_count from supplier_order_safe_read_fixture_counts where table_name = 'withdrawals')
  );
end;
$$;

select *
from supplier_order_safe_read_test_results
order by test_name;

do $$
declare
  v_failed_count integer;
  v_failure_details text;
begin
  select count(*)
  into v_failed_count
  from supplier_order_safe_read_test_results
  where not passed;

  if v_failed_count > 0 then
    select string_agg(test_name || ' - ' || coalesce(details, ''), '; ' order by test_name)
    into v_failure_details
    from supplier_order_safe_read_test_results
    where not passed;

    raise exception 'Supplier order safe read RPC boundary tests failed: % failure(s): %', v_failed_count, v_failure_details;
  end if;
end;
$$;

rollback;
