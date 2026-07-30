-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Checkout Phase C C5 customer-safe order read RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction and rolls everything back.

begin;

create temp table customer_order_safe_read_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on customer_order_safe_read_test_results to anon, authenticated;

create temp table customer_order_safe_read_fixture_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on customer_order_safe_read_fixture_counts to anon, authenticated;

create or replace function pg_temp.customer_order_safe_read_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into customer_order_safe_read_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.customer_order_safe_read_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.customer_order_safe_read_set_anon_context()
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

create or replace function pg_temp.customer_order_safe_read_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.customer_order_safe_read_expect_count(
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
  perform pg_temp.customer_order_safe_read_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.customer_order_safe_read_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.customer_order_safe_read_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.customer_order_safe_read_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.customer_order_safe_read_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
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
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_variant_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_address_id uuid := gen_random_uuid();
  v_draft_id uuid := gen_random_uuid();
  v_order_id uuid := gen_random_uuid();
  v_order_item_id uuid := gen_random_uuid();
  v_reservation_id uuid := gen_random_uuid();
  v_order_row jsonb;
  v_forbidden_key text;
  v_required_key text;
  v_expected_columns text[] := array[
    'order_id',
    'order_number',
    'created_at',
    'updated_at',
    'order_status_label',
    'customer_confirmation_label',
    'payment_method_label',
    'payment_collection_label',
    'delivery_status_label',
    'delivery_quote_label',
    'product_name',
    'product_slug',
    'product_image_snapshot',
    'quantity',
    'final_customer_price_amount',
    'line_total_amount',
    'total_payable_amount',
    'currency_code',
    'customer_contact_snapshot',
    'delivery_address_snapshot',
    'reseller_shop_name',
    'reseller_shop_slug',
    'reservation_status_label',
    'reservation_expires_at'
  ];
  v_forbidden_columns text[] := array[
    'customer_id',
    'reseller_id',
    'supplier_id',
    'shop_id',
    'reseller_product_id',
    'product_id',
    'variant_id',
    'supplier_base_price_snapshot_amount',
    'platform_margin_snapshot_amount',
    'reseller_margin_snapshot_amount',
    'reseller_cost_snapshot_amount',
    'settlement_due_amount',
    'commission_amount',
    'risk_level',
    'admin_notes',
    'payment_provider_reference'
  ];
  v_missing_columns text[];
  v_leaked_columns text[];
begin
  perform pg_temp.customer_order_safe_read_reset_context();

  insert into customer_order_safe_read_fixture_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('checkout_drafts', (select count(*) from public.checkout_drafts)),
    ('delivery_quotes', (select count(*) from public.delivery_quotes)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals));

  insert into public.profiles(id, clerk_user_id, email, full_name, phone, whatsapp, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_customer_order_read_customer_a', 'dev-customer-order-read-a@example.test', 'Dev Customer Order Read A', '0202000101', null, 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_customer_order_read_customer_b', 'dev-customer-order-read-b@example.test', 'Dev Customer Order Read B', '0202000201', null, 'customer', 'active'),
    (v_reseller_profile_id, 'dev_customer_order_read_reseller', 'dev-customer-order-read-reseller@example.test', 'Dev Customer Order Read Reseller', '0202000301', null, 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_customer_order_read_supplier', 'dev-customer-order-read-supplier@example.test', 'Dev Customer Order Read Supplier', '0202000401', null, 'supplier_owner', 'active'),
    (v_admin_profile_id, 'dev_customer_order_read_admin', 'dev-customer-order-read-admin@example.test', 'Dev Customer Order Read Admin', '0202000501', null, 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active'),
    (v_admin_customer_id, v_admin_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_customer_order_read_reseller', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-customer-order-read-shop', 'Dev Customer Order Read Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Customer Order Read Supplier', 'active', 'approved', 'Dev Customer Order Read Supplier');

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
  values (
    v_product_id,
    v_supplier_id,
    'QA Test',
    'Dev Customer Order Read Product',
    'dev-customer-order-read-product',
    'Development-only customer order read product',
    'Dev Safe Brand',
    'active',
    'approved',
    100,
    20,
    60,
    'GHS',
    v_supplier_profile_id
  );

  insert into public.product_variants(id, product_id, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values (v_variant_id, v_product_id, 3, 1, 0, 'active');

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
  values (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 30, 150, 'dev-customer-order-read-share');

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
  values (
    v_address_id,
    v_customer_a_id,
    'Dev order read address',
    'Dev Customer A',
    '0202000101',
    'Greater Accra',
    'Accra',
    'Dev Area',
    'Development-only street',
    'Development-only landmark',
    true
  );

  insert into public.checkout_drafts(
    id,
    customer_id,
    customer_profile_id,
    reseller_product_id,
    reseller_id,
    shop_id,
    supplier_id,
    product_id,
    variant_id,
    quantity,
    draft_status,
    product_name_snapshot,
    product_slug_snapshot,
    product_description_snapshot,
    product_category_snapshot,
    product_brand_snapshot,
    product_image_snapshot,
    final_customer_price_snapshot_amount,
    line_total_snapshot_amount,
    currency_code,
    customer_contact_snapshot,
    delivery_address_id,
    delivery_address_snapshot,
    public_listing_snapshot
  )
  values (
    v_draft_id,
    v_customer_a_id,
    v_customer_a_profile_id,
    v_listing_id,
    v_reseller_id,
    v_shop_id,
    v_supplier_id,
    v_product_id,
    v_variant_id,
    1,
    'converted',
    'Dev Customer Order Read Product',
    'dev-customer-order-read-product',
    'Development-only customer order read product',
    'QA Test',
    'Dev Safe Brand',
    jsonb_build_object('image_count', 1, 'primary_alt', 'Dev customer order read product image'),
    150,
    150,
    'GHS',
    jsonb_build_object('phone', '0202000101', 'email', 'dev-customer-order-read-a@example.test'),
    v_address_id,
    jsonb_build_object(
      'label', 'Dev order read address',
      'recipient_name', 'Dev Customer A',
      'phone', '0202000101',
      'region', 'Greater Accra',
      'city', 'Accra',
      'area', 'Dev Area',
      'street_address', 'Development-only street',
      'landmark', 'Development-only landmark'
    ),
    jsonb_build_object('listing_id', v_listing_id, 'shop_slug', 'dev-customer-order-read-shop')
  );

  insert into public.orders(
    id,
    order_number,
    checkout_draft_id,
    customer_id,
    reseller_id,
    shop_id,
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
  values (
    v_order_id,
    'RSR-DEV-ORDER-READ',
    v_draft_id,
    v_customer_a_id,
    v_reseller_id,
    v_shop_id,
    'placed_pending_confirmation',
    'pay_on_delivery',
    'not_collected',
    'estimate_selected',
    'pending',
    'pending',
    150,
    150,
    'GHS',
    jsonb_build_object(
      'label', 'Dev order read address',
      'recipient_name', 'Dev Customer A',
      'phone', '0202000101',
      'city', 'Accra',
      'area', 'Dev Area'
    ),
    jsonb_build_object('phone', '0202000101', 'email', 'dev-customer-order-read-a@example.test')
  );

  update public.checkout_drafts
  set converted_order_id = v_order_id,
      converted_at = now()
  where id = v_draft_id;

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
  values (
    v_order_item_id,
    v_order_id,
    v_supplier_id,
    v_product_id,
    v_variant_id,
    v_listing_id,
    1,
    100,
    20,
    30,
    120,
    150,
    150,
    50,
    30
  );

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
  values (
    v_reservation_id,
    'RSV-DEV-ORDER-READ',
    v_customer_a_id,
    v_reseller_id,
    v_listing_id,
    v_product_id,
    v_variant_id,
    v_order_id,
    1,
    'reserved',
    now() + interval '1 hour'
  );

  perform pg_temp.customer_order_safe_read_record_result(
    'read RPC signature present',
    exists (
      select 1
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'get_customer_order_safe'
        and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'p_order_id uuid'
        and p.proretset is true
    ),
    'public.get_customer_order_safe(p_order_id uuid) must exist and return a set'
  );

  select array_agg(column_name order by column_name)
  into v_missing_columns
  from unnest(v_expected_columns) as expected(column_name)
  where not exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join lateral pg_catalog.generate_subscripts(p.proargnames, 1) as arg(arg_index)
    where n.nspname = 'public'
      and p.proname = 'get_customer_order_safe'
      and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'p_order_id uuid'
      and p.proargmodes[arg.arg_index] in ('o', 'b', 't')
      and p.proargnames[arg.arg_index] = expected.column_name
  );

  perform pg_temp.customer_order_safe_read_record_result(
    'expected safe columns present',
    v_missing_columns is null,
    coalesce(array_to_string(v_missing_columns, ', '), 'all expected safe columns present')
  );

  select array_agg(column_name order by column_name)
  into v_leaked_columns
  from unnest(v_forbidden_columns) as forbidden(column_name)
  where exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join lateral pg_catalog.generate_subscripts(p.proargnames, 1) as arg(arg_index)
    where n.nspname = 'public'
      and p.proname = 'get_customer_order_safe'
      and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'p_order_id uuid'
      and p.proargmodes[arg.arg_index] in ('o', 'b', 't')
      and p.proargnames[arg.arg_index] = forbidden.column_name
  );

  perform pg_temp.customer_order_safe_read_record_result(
    'internal columns absent',
    v_leaked_columns is null,
    coalesce(array_to_string(v_leaked_columns, ', '), 'no forbidden columns exposed')
  );

  perform pg_temp.customer_order_safe_read_record_result(
    'source avoids current_customer_id side effect',
    not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'get_customer_order_safe'
        and pg_get_functiondef(p.oid) ilike '%current_customer_id%'
    ),
    'read RPC must not call current_customer_id because that helper can create customer rows'
  );

  perform pg_temp.customer_order_safe_read_reset_context();
  perform pg_temp.customer_order_safe_read_set_context('dev_customer_order_read_customer_a');

  select to_jsonb(row_data)
  into v_order_row
  from public.get_customer_order_safe(v_order_id) as row_data;

  perform pg_temp.customer_order_safe_read_record_result('customer can read own order', v_order_row is not null, 'own order row returned');
  perform pg_temp.customer_order_safe_read_record_result('product snapshot present', v_order_row ->> 'product_name' = 'Dev Customer Order Read Product', coalesce(v_order_row ->> 'product_name', 'missing'));
  perform pg_temp.customer_order_safe_read_record_result('final customer price present', (v_order_row ->> 'final_customer_price_amount')::numeric = 150, coalesce(v_order_row ->> 'final_customer_price_amount', 'missing'));
  perform pg_temp.customer_order_safe_read_record_result('currency present', v_order_row ->> 'currency_code' = 'GHS', coalesce(v_order_row ->> 'currency_code', 'missing'));
  perform pg_temp.customer_order_safe_read_record_result('pay on delivery present', v_order_row ->> 'payment_method_label' = 'Pay on Delivery', coalesce(v_order_row ->> 'payment_method_label', 'missing'));
  perform pg_temp.customer_order_safe_read_record_result('payment not collected present', v_order_row ->> 'payment_collection_label' = 'Payment not collected', coalesce(v_order_row ->> 'payment_collection_label', 'missing'));
  perform pg_temp.customer_order_safe_read_record_result('address snapshot safe', v_order_row -> 'delivery_address_snapshot' ? 'area', coalesce((v_order_row -> 'delivery_address_snapshot')::text, 'missing'));
  perform pg_temp.customer_order_safe_read_record_result('reservation label safe', v_order_row ->> 'reservation_status_label' = 'Stock reserved for this order', coalesce(v_order_row ->> 'reservation_status_label', 'missing'));

  foreach v_forbidden_key in array array[
    'supplier_base_price_snapshot_amount',
    'platform_margin_snapshot_amount',
    'reseller_margin_snapshot_amount',
    'reseller_cost_snapshot_amount',
    'settlement_due_amount',
    'commission_amount',
    'supplier_id',
    'reseller_id',
    'product_id',
    'variant_id',
    'risk_level',
    'admin_notes'
  ]
  loop
    perform pg_temp.customer_order_safe_read_record_result(
      'forbidden field absent: ' || v_forbidden_key,
      not (coalesce(v_order_row, '{}'::jsonb) ? v_forbidden_key),
      'forbidden_key=' || v_forbidden_key
    );
  end loop;

  perform pg_temp.customer_order_safe_read_set_context('dev_customer_order_read_customer_b');
  perform pg_temp.customer_order_safe_read_expect_count(
    'customer cannot read another customer order',
    format($sql$select count(*) from public.get_customer_order_safe(%L::uuid)$sql$, v_order_id),
    0
  );

  perform pg_temp.customer_order_safe_read_set_context('dev_customer_order_read_reseller');
  perform pg_temp.customer_order_safe_read_expect_count(
    'reseller blocked',
    format($sql$select count(*) from public.get_customer_order_safe(%L::uuid)$sql$, v_order_id),
    0
  );

  perform pg_temp.customer_order_safe_read_set_context('dev_customer_order_read_supplier');
  perform pg_temp.customer_order_safe_read_expect_count(
    'supplier_owner blocked',
    format($sql$select count(*) from public.get_customer_order_safe(%L::uuid)$sql$, v_order_id),
    0
  );

  perform pg_temp.customer_order_safe_read_set_context('dev_customer_order_read_admin');
  perform pg_temp.customer_order_safe_read_expect_count(
    'admin_staff blocked from customer boundary',
    format($sql$select count(*) from public.get_customer_order_safe(%L::uuid)$sql$, v_order_id),
    0
  );

  perform pg_temp.customer_order_safe_read_set_context('dev_customer_order_read_customer_a');
  perform pg_temp.customer_order_safe_read_expect_count(
    'missing order does not leak existence',
    format($sql$select count(*) from public.get_customer_order_safe(%L::uuid)$sql$, gen_random_uuid()),
    0
  );

  perform pg_temp.customer_order_safe_read_reset_context();
  perform pg_temp.customer_order_safe_read_set_anon_context();
  perform pg_temp.customer_order_safe_read_expect_blocked(
    'anonymous blocked',
    format($sql$select count(*) from public.get_customer_order_safe(%L::uuid)$sql$, v_order_id)
  );

  perform pg_temp.customer_order_safe_read_reset_context();

  perform pg_temp.customer_order_safe_read_record_result(
    'no order side effect from reads',
    (select count(*) from public.orders) = (select row_count + 1 from customer_order_safe_read_fixture_counts where table_name = 'orders'),
    'read calls should not create orders'
  );
  perform pg_temp.customer_order_safe_read_record_result(
    'no order item side effect from reads',
    (select count(*) from public.order_items) = (select row_count + 1 from customer_order_safe_read_fixture_counts where table_name = 'order_items'),
    'read calls should not create order items'
  );
  perform pg_temp.customer_order_safe_read_record_result(
    'no stock reservation side effect from reads',
    (select count(*) from public.stock_reservations) = (select row_count + 1 from customer_order_safe_read_fixture_counts where table_name = 'stock_reservations'),
    'read calls should not create stock reservations'
  );
  perform pg_temp.customer_order_safe_read_record_result(
    'no delivery quote side effect from reads',
    (select count(*) from public.delivery_quotes) = (select row_count from customer_order_safe_read_fixture_counts where table_name = 'delivery_quotes'),
    'read calls should not create delivery quotes'
  );
  perform pg_temp.customer_order_safe_read_record_result(
    'no settlement side effect from reads',
    (select count(*) from public.settlements) = (select row_count from customer_order_safe_read_fixture_counts where table_name = 'settlements'),
    'read calls should not create settlements'
  );
  perform pg_temp.customer_order_safe_read_record_result(
    'no commission side effect from reads',
    (select count(*) from public.commissions) = (select row_count from customer_order_safe_read_fixture_counts where table_name = 'commissions'),
    'read calls should not create commissions'
  );
  perform pg_temp.customer_order_safe_read_record_result(
    'no withdrawal side effect from reads',
    (select count(*) from public.withdrawals) = (select row_count from customer_order_safe_read_fixture_counts where table_name = 'withdrawals'),
    'read calls should not create withdrawals'
  );
end;
$$;

select test_name, passed, details
from customer_order_safe_read_test_results
order by test_name;

do $$
declare
  v_failed text;
begin
  select string_agg(test_name || ': ' || coalesce(details, ''), '; ' order by test_name)
  into v_failed
  from customer_order_safe_read_test_results
  where not passed;

  if v_failed is not null then
    raise exception 'CUSTOMER_ORDER_SAFE_READ_RPC_TEST_FAILED: %', v_failed;
  end if;
end;
$$;

rollback;
