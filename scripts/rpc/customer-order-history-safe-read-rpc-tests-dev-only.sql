-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Customer Order History Phase 1 customer-safe list/summary RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction and rolls everything back.

begin;

create temp table customer_order_history_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on customer_order_history_test_results to anon, authenticated;

create temp table customer_order_history_fixture_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on customer_order_history_fixture_counts to anon, authenticated;

create or replace function pg_temp.customer_order_history_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into customer_order_history_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.customer_order_history_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.customer_order_history_set_anon_context()
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

create or replace function pg_temp.customer_order_history_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.customer_order_history_expect_count(
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
  perform pg_temp.customer_order_history_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.customer_order_history_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.customer_order_history_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.customer_order_history_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.customer_order_history_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
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
  v_active_order_id uuid := gen_random_uuid();
  v_completed_order_id uuid := gen_random_uuid();
  v_rejected_order_id uuid := gen_random_uuid();
  v_other_customer_order_id uuid := gen_random_uuid();
  v_order_row jsonb;
  v_summary_row jsonb;
  v_forbidden_key text;
  v_expected_columns text[] := array[
    'order_id',
    'order_number',
    'created_at',
    'updated_at',
    'order_status_label',
    'order_status_group',
    'completed_at',
    'rejected_at',
    'product_name',
    'product_slug',
    'product_image_snapshot',
    'quantity',
    'final_customer_price_amount',
    'line_total_amount',
    'total_payable_amount',
    'currency_code',
    'payment_method_label',
    'payment_collection_label',
    'delivery_status_label',
    'reseller_shop_name',
    'reseller_shop_slug',
    'detail_href'
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
    'payment_provider_reference',
    'reservation_status'
  ];
  v_missing_columns text[];
  v_leaked_columns text[];
begin
  perform pg_temp.customer_order_history_reset_context();

  insert into customer_order_history_fixture_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('delivery_quotes', (select count(*) from public.delivery_quotes)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals));

  insert into public.profiles(id, clerk_user_id, email, full_name, phone, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_customer_order_history_customer_a', 'dev-customer-order-history-a@example.test', 'Dev Customer Order History A', '0203000101', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_customer_order_history_customer_b', 'dev-customer-order-history-b@example.test', 'Dev Customer Order History B', '0203000201', 'customer', 'active'),
    (v_reseller_profile_id, 'dev_customer_order_history_reseller', 'dev-customer-order-history-reseller@example.test', 'Dev Customer Order History Reseller', '0203000301', 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_customer_order_history_supplier', 'dev-customer-order-history-supplier@example.test', 'Dev Customer Order History Supplier', '0203000401', 'supplier_owner', 'active'),
    (v_admin_profile_id, 'dev_customer_order_history_admin', 'dev-customer-order-history-admin@example.test', 'Dev Customer Order History Admin', '0203000501', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active'),
    (v_admin_customer_id, v_admin_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_customer_order_history_reseller', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-customer-order-history-shop', 'Dev Customer Order History Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Customer Order History Supplier', 'active', 'approved', 'Dev Customer Order History Supplier');

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
    'Dev Customer Order History Product',
    'dev-customer-order-history-product',
    'Development-only customer order history product',
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
  values (v_variant_id, v_product_id, 10, 2, 1, 'active');

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
  values (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 30, 150, 'dev-customer-order-history-share');

  insert into public.orders(
    id,
    order_number,
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
    customer_contact_snapshot,
    created_at,
    updated_at,
    completed_at,
    supplier_rejected_at,
    supplier_rejection_reason_note
  )
  values
    (
      v_active_order_id,
      'RSR-DEV-HISTORY-ACTIVE',
      v_customer_a_id,
      v_reseller_id,
      v_shop_id,
      'supplier_confirmed',
      'pay_on_delivery',
      'not_collected',
      'estimate_selected',
      'pending',
      'pending',
      150,
      150,
      'GHS',
      jsonb_build_object('city', 'Accra', 'area', 'Dev Area'),
      jsonb_build_object('phone', '0203000101'),
      now() - interval '1 day',
      now() - interval '1 day',
      null,
      null,
      null
    ),
    (
      v_completed_order_id,
      'RSR-DEV-HISTORY-COMPLETE',
      v_customer_a_id,
      v_reseller_id,
      v_shop_id,
      'completed',
      'pay_on_delivery',
      'settlement_verified',
      'delivered',
      'confirmed',
      'approved',
      150,
      150,
      'GHS',
      jsonb_build_object('city', 'Accra', 'area', 'Dev Area'),
      jsonb_build_object('phone', '0203000101'),
      now() - interval '2 days',
      now() - interval '2 days',
      now() - interval '1 day',
      null,
      null
    ),
    (
      v_rejected_order_id,
      'RSR-DEV-HISTORY-REJECTED',
      v_customer_a_id,
      v_reseller_id,
      v_shop_id,
      'supplier_rejected',
      'pay_on_delivery',
      'not_collected',
      'cancelled',
      'pending',
      'pending',
      150,
      150,
      'GHS',
      jsonb_build_object('city', 'Accra', 'area', 'Dev Area'),
      jsonb_build_object('phone', '0203000101'),
      now() - interval '3 days',
      now() - interval '3 days',
      null,
      now() - interval '3 days',
      'private supplier rejection note must not appear'
    ),
    (
      v_other_customer_order_id,
      'RSR-DEV-HISTORY-OTHER',
      v_customer_b_id,
      v_reseller_id,
      v_shop_id,
      'supplier_confirmed',
      'pay_on_delivery',
      'not_collected',
      'estimate_selected',
      'pending',
      'pending',
      150,
      150,
      'GHS',
      jsonb_build_object('city', 'Accra', 'area', 'Other Area'),
      jsonb_build_object('phone', '0203000201'),
      now() - interval '4 days',
      now() - interval '4 days',
      null,
      null,
      null
    );

  insert into public.order_items(
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
  select order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 20, 30, 120, 150, 150, 50, 30
  from (
    values
      (v_active_order_id),
      (v_completed_order_id),
      (v_rejected_order_id),
      (v_other_customer_order_id)
  ) as fixture(order_id);

  insert into public.stock_reservations(
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
    ('RSV-DEV-HISTORY-ACTIVE', v_customer_a_id, v_reseller_id, v_listing_id, v_product_id, v_variant_id, v_active_order_id, 1, 'reserved', now() + interval '1 hour'),
    ('RSV-DEV-HISTORY-COMPLETE', v_customer_a_id, v_reseller_id, v_listing_id, v_product_id, v_variant_id, v_completed_order_id, 1, 'committed', now() - interval '1 hour'),
    ('RSV-DEV-HISTORY-REJECTED', v_customer_a_id, v_reseller_id, v_listing_id, v_product_id, v_variant_id, v_rejected_order_id, 1, 'released', now() - interval '1 hour');

  perform pg_temp.customer_order_history_record_result(
    'list RPC signature present',
    exists (
      select 1
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'list_customer_orders_safe'
        and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'p_group text, p_search text, p_date_from date, p_date_to date, p_limit integer, p_cursor_created_at timestamp with time zone, p_cursor_order_id uuid'
        and p.proretset is true
    ),
    'public.list_customer_orders_safe signature must exist'
  );

  perform pg_temp.customer_order_history_record_result(
    'summary RPC signature present',
    exists (
      select 1
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'get_customer_order_summary_safe'
        and pg_catalog.pg_get_function_identity_arguments(p.oid) = ''
        and p.proretset is true
    ),
    'public.get_customer_order_summary_safe signature must exist'
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
      and p.proname = 'list_customer_orders_safe'
      and p.proargmodes[arg.arg_index] in ('o', 'b', 't')
      and p.proargnames[arg.arg_index] = expected.column_name
  );

  perform pg_temp.customer_order_history_record_result(
    'expected safe list columns present',
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
      and p.proname = 'list_customer_orders_safe'
      and p.proargmodes[arg.arg_index] in ('o', 'b', 't')
      and p.proargnames[arg.arg_index] = forbidden.column_name
  );

  perform pg_temp.customer_order_history_record_result(
    'internal columns absent from list',
    v_leaked_columns is null,
    coalesce(array_to_string(v_leaked_columns, ', '), 'no forbidden columns exposed')
  );

  perform pg_temp.customer_order_history_record_result(
    'list source avoids current_customer_id side effect',
    not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'list_customer_orders_safe'
        and pg_get_functiondef(p.oid) ilike '%current_customer_id%'
    ),
    'read RPC must resolve an existing customer without calling current_customer_id'
  );

  perform pg_temp.customer_order_history_set_context('dev_customer_order_history_customer_a');

  perform pg_temp.customer_order_history_expect_count(
    'customer can list own orders',
    $sql$select count(*) from public.list_customer_orders_safe('all', null, null, null, 20, null, null)$sql$,
    3
  );

  perform pg_temp.customer_order_history_expect_count(
    'active filter shows active only',
    $sql$select count(*) from public.list_customer_orders_safe('active', null, null, null, 20, null, null)$sql$,
    1
  );

  perform pg_temp.customer_order_history_expect_count(
    'completed filter shows completed only',
    $sql$select count(*) from public.list_customer_orders_safe('completed', null, null, null, 20, null, null)$sql$,
    1
  );

  perform pg_temp.customer_order_history_expect_count(
    'rejected filter shows rejected only',
    $sql$select count(*) from public.list_customer_orders_safe('rejected', null, null, null, 20, null, null)$sql$,
    1
  );

  perform pg_temp.customer_order_history_expect_count(
    'search finds product/order/shop safely',
    $sql$select count(*) from public.list_customer_orders_safe('all', 'HISTORY-ACTIVE', null, null, 20, null, null)$sql$,
    1
  );

  perform pg_temp.customer_order_history_expect_count(
    'date filter excludes older orders',
    format($sql$select count(*) from public.list_customer_orders_safe('all', null, %L::date, null, 20, null, null)$sql$, current_date - 1),
    1
  );

  select to_jsonb(row_data)
  into v_order_row
  from public.list_customer_orders_safe('active', null, null, null, 20, null, null) as row_data
  limit 1;

  perform pg_temp.customer_order_history_record_result('list row returned', v_order_row is not null, 'active order row returned');
  perform pg_temp.customer_order_history_record_result('safe customer price present', (v_order_row ->> 'total_payable_amount')::numeric = 150, coalesce(v_order_row ->> 'total_payable_amount', 'missing'));
  perform pg_temp.customer_order_history_record_result(
    'safe detail href present',
    (v_order_row ->> 'detail_href') like '/customer/orders/%',
    case when (v_order_row ->> 'detail_href') like '/customer/orders/%' then 'detail link present' else 'missing detail link' end
  );
  perform pg_temp.customer_order_history_record_result('pay on delivery label present', v_order_row ->> 'payment_method_label' = 'Pay on Delivery', coalesce(v_order_row ->> 'payment_method_label', 'missing'));

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
    'customer_id',
    'risk_level',
    'admin_notes',
    'supplier_rejection_reason_note',
    'reservation_status'
  ]
  loop
    perform pg_temp.customer_order_history_record_result(
      'forbidden list field absent: ' || v_forbidden_key,
      not (coalesce(v_order_row, '{}'::jsonb) ? v_forbidden_key),
      'forbidden_key=' || v_forbidden_key
    );
  end loop;

  select to_jsonb(row_data)
  into v_summary_row
  from public.get_customer_order_summary_safe() as row_data
  limit 1;

  perform pg_temp.customer_order_history_record_result('summary total count safe', (v_summary_row ->> 'total_order_count')::bigint = 3, 'summary total checked');
  perform pg_temp.customer_order_history_record_result('summary active count safe', (v_summary_row ->> 'active_order_count')::bigint = 1, 'summary active checked');
  perform pg_temp.customer_order_history_record_result('summary completed count safe', (v_summary_row ->> 'completed_order_count')::bigint = 1, 'summary completed checked');
  perform pg_temp.customer_order_history_record_result('summary rejected count safe', (v_summary_row ->> 'rejected_order_count')::bigint = 1, 'summary rejected checked');

  perform pg_temp.customer_order_history_set_context('dev_customer_order_history_customer_b');
  perform pg_temp.customer_order_history_expect_count(
    'customer cannot list another customer order',
    $sql$select count(*) from public.list_customer_orders_safe('all', null, null, null, 20, null, null)$sql$,
    1
  );

  perform pg_temp.customer_order_history_set_context('dev_customer_order_history_reseller');
  perform pg_temp.customer_order_history_expect_count(
    'reseller blocked from customer history',
    $sql$select count(*) from public.list_customer_orders_safe('all', null, null, null, 20, null, null)$sql$,
    0
  );

  perform pg_temp.customer_order_history_set_context('dev_customer_order_history_supplier');
  perform pg_temp.customer_order_history_expect_count(
    'supplier_owner blocked from customer history',
    $sql$select count(*) from public.list_customer_orders_safe('all', null, null, null, 20, null, null)$sql$,
    0
  );

  perform pg_temp.customer_order_history_set_context('dev_customer_order_history_admin');
  perform pg_temp.customer_order_history_expect_count(
    'admin_staff blocked from customer history boundary',
    $sql$select count(*) from public.list_customer_orders_safe('all', null, null, null, 20, null, null)$sql$,
    0
  );

  perform pg_temp.customer_order_history_set_context('dev_customer_order_history_customer_a');
  perform pg_temp.customer_order_history_expect_blocked(
    'invalid group blocked',
    $sql$select count(*) from public.list_customer_orders_safe('admin', null, null, null, 20, null, null)$sql$
  );

  perform pg_temp.customer_order_history_reset_context();
  perform pg_temp.customer_order_history_set_anon_context();
  perform pg_temp.customer_order_history_expect_blocked(
    'anonymous blocked from list',
    $sql$select count(*) from public.list_customer_orders_safe('all', null, null, null, 20, null, null)$sql$
  );
  perform pg_temp.customer_order_history_expect_blocked(
    'anonymous blocked from summary',
    $sql$select count(*) from public.get_customer_order_summary_safe()$sql$
  );

  perform pg_temp.customer_order_history_reset_context();

  perform pg_temp.customer_order_history_record_result(
    'no order side effect from reads',
    (select count(*) from public.orders) = (select row_count + 4 from customer_order_history_fixture_counts where table_name = 'orders'),
    'read calls should not create orders'
  );
  perform pg_temp.customer_order_history_record_result(
    'no order item side effect from reads',
    (select count(*) from public.order_items) = (select row_count + 4 from customer_order_history_fixture_counts where table_name = 'order_items'),
    'read calls should not create order items'
  );
  perform pg_temp.customer_order_history_record_result(
    'no stock reservation side effect from reads',
    (select count(*) from public.stock_reservations) = (select row_count + 3 from customer_order_history_fixture_counts where table_name = 'stock_reservations'),
    'read calls should not create stock reservations'
  );
  perform pg_temp.customer_order_history_record_result(
    'no delivery quote side effect from reads',
    (select count(*) from public.delivery_quotes) = (select row_count from customer_order_history_fixture_counts where table_name = 'delivery_quotes'),
    'read calls should not create delivery quotes'
  );
  perform pg_temp.customer_order_history_record_result(
    'no settlement side effect from reads',
    (select count(*) from public.settlements) = (select row_count from customer_order_history_fixture_counts where table_name = 'settlements'),
    'read calls should not create settlements'
  );
  perform pg_temp.customer_order_history_record_result(
    'no commission side effect from reads',
    (select count(*) from public.commissions) = (select row_count from customer_order_history_fixture_counts where table_name = 'commissions'),
    'read calls should not create commissions'
  );
  perform pg_temp.customer_order_history_record_result(
    'no withdrawal side effect from reads',
    (select count(*) from public.withdrawals) = (select row_count from customer_order_history_fixture_counts where table_name = 'withdrawals'),
    'read calls should not create withdrawals'
  );
end;
$$;

select test_name, passed, details
from customer_order_history_test_results
order by test_name;

do $$
declare
  v_failed text;
begin
  select string_agg(test_name || ': ' || coalesce(details, ''), '; ' order by test_name)
  into v_failed
  from customer_order_history_test_results
  where not passed;

  if v_failed is not null then
    raise exception 'CUSTOMER_ORDER_HISTORY_RPC_TEST_FAILED: %', v_failed;
  end if;
end;
$$;

rollback;
