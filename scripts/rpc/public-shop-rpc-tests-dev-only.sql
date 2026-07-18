-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Public reseller shop read-only RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction and rolls everything back.

begin;

create temp table public_shop_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on public_shop_test_results to anon, authenticated;

create temp table public_shop_fixture_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on public_shop_fixture_counts to anon, authenticated;

create temp table public_shop_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on public_shop_fixture_ids to anon, authenticated;

create or replace function pg_temp.public_shop_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into public_shop_test_results (test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.public_shop_set_anon_context()
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

create or replace function pg_temp.public_shop_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.public_shop_expect_count(
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
  perform pg_temp.public_shop_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.public_shop_record_result(p_test_name, false, sqlerrm);
end;
$$;

create or replace function pg_temp.public_shop_expect_json_key_absent(
  p_test_name text,
  p_row jsonb,
  p_forbidden_key text
)
returns void
language plpgsql
as $$
begin
  perform pg_temp.public_shop_record_result(
    p_test_name,
    not (p_row ? p_forbidden_key),
    'forbidden_key=' || p_forbidden_key || ', exposed=' || case when p_row ? p_forbidden_key then 'true' else 'false' end
  );
exception when others then
  perform pg_temp.public_shop_record_result(p_test_name, false, sqlerrm);
end;
$$;

create or replace function pg_temp.public_shop_expect_json_key_present(
  p_test_name text,
  p_row jsonb,
  p_required_key text
)
returns void
language plpgsql
as $$
begin
  perform pg_temp.public_shop_record_result(
    p_test_name,
    p_row ? p_required_key,
    'required_key=' || p_required_key || ', present=' || case when p_row ? p_required_key then 'true' else 'false' end
  );
exception when others then
  perform pg_temp.public_shop_record_result(p_test_name, false, sqlerrm);
end;
$$;

do $$
declare
  v_reseller_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_active_product_id uuid := gen_random_uuid();
  v_pending_product_id uuid := gen_random_uuid();
  v_rejected_product_id uuid := gen_random_uuid();
  v_archived_product_id uuid := gen_random_uuid();
  v_hidden_listing_product_id uuid := gen_random_uuid();
  v_deleted_listing_product_id uuid := gen_random_uuid();
  v_active_listing_id uuid := gen_random_uuid();
  v_shop_slug text := 'dev-public-shop-boundary-' || lower(left(replace(gen_random_uuid()::text, '-', ''), 10));
  v_active_product_slug text := 'dev-public-shop-approved-product';
  v_active_share_slug text := 'dev-public-shop-approved-share';
  v_active_row jsonb;
  v_product_row jsonb;
  v_forbidden_key text;
  v_required_key text;
begin
  perform pg_temp.public_shop_reset_context();

  insert into public_shop_fixture_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('delivery_quotes', (select count(*) from public.delivery_quotes)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals));

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_reseller_profile_id, 'dev_public_shop_reseller_' || lower(left(replace(gen_random_uuid()::text, '-', ''), 10)), 'dev-public-shop-reseller@example.test', 'Dev Public Shop Reseller', 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_public_shop_supplier_' || lower(left(replace(gen_random_uuid()::text, '-', ''), 10)), 'dev-public-shop-supplier@example.test', 'Dev Public Shop Supplier', 'supplier_owner', 'active');

  insert into public.resellers(
    id,
    profile_id,
    reseller_type,
    approval_status,
    risk_level,
    payout_status,
    commission_available_amount,
    commission_pending_amount,
    payout_details_masked
  )
  values (
    v_reseller_id,
    v_reseller_profile_id,
    'dev_only_public_shop_reseller',
    'approved',
    'high',
    'active',
    123.45,
    67.89,
    jsonb_build_object('provider', 'DEV_ONLY_DO_NOT_EXPOSE', 'account', '0000')
  );

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, bio, shop_status, visibility)
  values (
    v_shop_id,
    v_reseller_id,
    v_shop_slug,
    'Dev Public Shop Boundary',
    'Development-only public shop boundary fixture',
    'active',
    'public'
  );

  insert into public.suppliers(
    id,
    owner_profile_id,
    business_name,
    business_type,
    primary_category,
    location_region,
    location_city,
    supplier_status,
    verification_status,
    risk_level,
    trust_level,
    settlement_status,
    public_display_name
  )
  values (
    v_supplier_id,
    v_supplier_profile_id,
    'Dev Public Supplier Private Business',
    'dev_private_type',
    'QA Test',
    'Dev Private Region',
    'Dev Private City',
    'active',
    'approved',
    'high',
    'dev_private_trust',
    'overdue',
    'Dev Public Supplier'
  );

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
    rejection_reason,
    created_by_profile_id
  )
  values
    (v_active_product_id, v_supplier_id, 'QA Test', 'Dev Approved Public Product', v_active_product_slug, 'Development-only approved public product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', null, v_supplier_profile_id),
    (v_pending_product_id, v_supplier_id, 'QA Test', 'Dev Pending Public Product', 'dev-public-shop-pending-product', 'Development-only pending product', 'Dev Safe Brand', 'pending_approval', 'pending_review', 100, 20, 60, 'GHS', null, v_supplier_profile_id),
    (v_rejected_product_id, v_supplier_id, 'QA Test', 'Dev Rejected Public Product', 'dev-public-shop-rejected-product', 'Development-only rejected product', 'Dev Safe Brand', 'rejected', 'rejected', 100, 20, 60, 'GHS', 'dev-only rejection', v_supplier_profile_id),
    (v_archived_product_id, v_supplier_id, 'QA Test', 'Dev Archived Public Product', 'dev-public-shop-archived-product', 'Development-only archived product', 'Dev Safe Brand', 'archived', 'archived', 100, 20, 60, 'GHS', null, v_supplier_profile_id),
    (v_hidden_listing_product_id, v_supplier_id, 'QA Test', 'Dev Hidden Listing Product', 'dev-public-shop-hidden-listing-product', 'Development-only hidden listing product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', null, v_supplier_profile_id),
    (v_deleted_listing_product_id, v_supplier_id, 'QA Test', 'Dev Deleted Listing Product', 'dev-public-shop-deleted-listing-product', 'Development-only deleted listing product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', null, v_supplier_profile_id);

  insert into public.product_variants(product_id, total_stock_quantity, reserved_stock_quantity, variant_status)
  values
    (v_active_product_id, 9, 2, 'active'),
    (v_pending_product_id, 9, 0, 'active'),
    (v_rejected_product_id, 9, 0, 'active'),
    (v_archived_product_id, 9, 0, 'active'),
    (v_hidden_listing_product_id, 9, 0, 'active'),
    (v_deleted_listing_product_id, 9, 0, 'active');

  insert into public.product_images(product_id, storage_path, alt_text, sort_order, image_status, is_primary, created_by_profile_id)
  values
    (v_active_product_id, 'dev-only/public-shop/approved-primary.webp', 'Dev approved public product image', 1, 'active', true, v_supplier_profile_id),
    (v_active_product_id, 'dev-only/public-shop/approved-hidden.webp', 'Dev hidden product image', 2, 'hidden', false, v_supplier_profile_id);

  insert into public.reseller_products(
    id,
    reseller_id,
    shop_id,
    product_id,
    listing_status,
    reseller_margin_amount,
    customer_product_price_amount,
    share_slug,
    deleted_at
  )
  values
    (v_active_listing_id, v_reseller_id, v_shop_id, v_active_product_id, 'active', 30, 150, v_active_share_slug, null),
    (gen_random_uuid(), v_reseller_id, v_shop_id, v_pending_product_id, 'active', 30, 150, 'dev-public-shop-pending-share', null),
    (gen_random_uuid(), v_reseller_id, v_shop_id, v_rejected_product_id, 'active', 30, 150, 'dev-public-shop-rejected-share', null),
    (gen_random_uuid(), v_reseller_id, v_shop_id, v_archived_product_id, 'active', 30, 150, 'dev-public-shop-archived-product-share', null),
    (gen_random_uuid(), v_reseller_id, v_shop_id, v_hidden_listing_product_id, 'hidden', 30, 150, 'dev-public-shop-hidden-listing-share', null),
    (gen_random_uuid(), v_reseller_id, v_shop_id, v_deleted_listing_product_id, 'archived', 30, 150, 'dev-public-shop-archived-listing-share', now());

  insert into public_shop_fixture_ids(fixture_key, fixture_id)
  values
    ('shop', v_shop_id),
    ('active_listing', v_active_listing_id),
    ('active_product', v_active_product_id);

  perform pg_temp.public_shop_set_anon_context();

  select to_jsonb(public_shop)
  into v_active_row
  from public.get_public_reseller_shop(v_shop_slug) public_shop
  where public_shop.listing_id = v_active_listing_id;

  perform pg_temp.public_shop_record_result(
    'anonymous public can read active approved reseller shop listing',
    v_active_row is not null,
    'shop_slug=' || v_shop_slug || ', listing_id=' || v_active_listing_id::text
  );

  perform pg_temp.public_shop_expect_count(
    'active approved reseller listing appears exactly once',
    format('select count(*) from public.get_public_reseller_shop(%L) where listing_id = %L::uuid', v_shop_slug, v_active_listing_id),
    1
  );

  perform pg_temp.public_shop_expect_count(
    'pending product listing is hidden',
    format('select count(*) from public.get_public_reseller_shop(%L) where product_slug = %L', v_shop_slug, 'dev-public-shop-pending-product'),
    0
  );

  perform pg_temp.public_shop_expect_count(
    'rejected product listing is hidden',
    format('select count(*) from public.get_public_reseller_shop(%L) where product_slug = %L', v_shop_slug, 'dev-public-shop-rejected-product'),
    0
  );

  perform pg_temp.public_shop_expect_count(
    'archived product listing is hidden',
    format('select count(*) from public.get_public_reseller_shop(%L) where product_slug = %L', v_shop_slug, 'dev-public-shop-archived-product'),
    0
  );

  perform pg_temp.public_shop_expect_count(
    'hidden reseller listing is hidden',
    format('select count(*) from public.get_public_reseller_shop(%L) where share_slug = %L', v_shop_slug, 'dev-public-shop-hidden-listing-share'),
    0
  );

  perform pg_temp.public_shop_expect_count(
    'archived deleted reseller listing is hidden',
    format('select count(*) from public.get_public_reseller_shop(%L) where share_slug = %L', v_shop_slug, 'dev-public-shop-archived-listing-share'),
    0
  );

  select to_jsonb(public_shop_product)
  into v_product_row
  from public.get_public_reseller_shop_product(v_shop_slug, v_active_share_slug) public_shop_product;

  perform pg_temp.public_shop_record_result(
    'anonymous public can read active approved product detail by share slug',
    v_product_row is not null and v_product_row->>'listing_id' = v_active_listing_id::text,
    'expected_listing_id=' || v_active_listing_id::text || ', observed=' || coalesce(v_product_row->>'listing_id', 'null')
  );

  perform pg_temp.public_shop_expect_count(
    'product detail can be read by product slug',
    format('select count(*) from public.get_public_reseller_shop_product(%L, %L) where listing_id = %L::uuid', v_shop_slug, v_active_product_slug, v_active_listing_id),
    1
  );

  perform pg_temp.public_shop_expect_count(
    'invalid shop slug returns empty safe result',
    'select count(*) from public.get_public_reseller_shop(''dev-public-shop-missing-shop'')',
    0
  );

  perform pg_temp.public_shop_expect_count(
    'invalid product slug returns empty safe result',
    format('select count(*) from public.get_public_reseller_shop_product(%L, %L)', v_shop_slug, 'dev-public-shop-missing-product'),
    0
  );

  foreach v_required_key in array array[
    'shop_slug',
    'shop_display_name',
    'shop_bio',
    'listing_id',
    'product_slug',
    'share_slug',
    'name',
    'description',
    'category',
    'brand',
    'customer_product_price_amount',
    'currency_code',
    'stock_availability_label',
    'image_count',
    'primary_image_alt'
  ] loop
    perform pg_temp.public_shop_expect_json_key_present(
      'customer-safe field exposed: ' || v_required_key,
      v_active_row,
      v_required_key
    );
  end loop;

  foreach v_forbidden_key in array array[
    'supplier_id',
    'supplier_display_name',
    'supplier_contact',
    'supplier_phone',
    'supplier_email',
    'supplier_payout',
    'payout_details_masked',
    'business_name',
    'business_type',
    'location_region',
    'location_city',
    'risk_level',
    'trust_level',
    'settlement_status',
    'supplier_team_members',
    'permissions',
    'base_price_amount',
    'platform_margin_amount',
    'reseller_cost_amount',
    'max_reseller_margin_amount',
    'max_customer_price_amount',
    'reseller_margin_amount',
    'commission_available_amount',
    'commission_pending_amount',
    'restricted_reason',
    'rejection_reason',
    'admin_notes',
    'internal_notes',
    'settlement_id',
    'commission_id',
    'withdrawal_id'
  ] loop
    perform pg_temp.public_shop_expect_json_key_absent(
      'sensitive field not exposed: ' || v_forbidden_key,
      v_active_row,
      v_forbidden_key
    );
  end loop;

  perform pg_temp.public_shop_record_result(
    'final customer price is exposed safely',
    (v_active_row->>'customer_product_price_amount')::numeric = 150,
    'expected=150, observed=' || coalesce(v_active_row->>'customer_product_price_amount', 'null')
  );

  perform pg_temp.public_shop_record_result(
    'currency is exposed safely',
    v_active_row->>'currency_code' = 'GHS',
    'expected=GHS, observed=' || coalesce(v_active_row->>'currency_code', 'null')
  );

  perform pg_temp.public_shop_record_result(
    'stock availability label is exposed safely',
    v_active_row->>'stock_availability_label' = '7 available',
    'expected=7 available, observed=' || coalesce(v_active_row->>'stock_availability_label', 'null')
  );

  perform pg_temp.public_shop_record_result(
    'active public image metadata is exposed safely',
    (v_active_row->>'image_count')::integer = 1
      and v_active_row->>'primary_image_alt' = 'Dev approved public product image',
    'expected image_count=1 and primary alt; observed image_count=' || coalesce(v_active_row->>'image_count', 'null') || ', alt=' || coalesce(v_active_row->>'primary_image_alt', 'null')
  );

  perform pg_temp.public_shop_expect_count(
    'no order rows created by public shop reads',
    'select count(*) from public.orders',
    (select row_count from public_shop_fixture_counts where table_name = 'orders')
  );

  perform pg_temp.public_shop_expect_count(
    'no order item rows created by public shop reads',
    'select count(*) from public.order_items',
    (select row_count from public_shop_fixture_counts where table_name = 'order_items')
  );

  perform pg_temp.public_shop_expect_count(
    'no stock reservation rows created by public shop reads',
    'select count(*) from public.stock_reservations',
    (select row_count from public_shop_fixture_counts where table_name = 'stock_reservations')
  );

  perform pg_temp.public_shop_expect_count(
    'no delivery quote rows created by public shop reads',
    'select count(*) from public.delivery_quotes',
    (select row_count from public_shop_fixture_counts where table_name = 'delivery_quotes')
  );

  perform pg_temp.public_shop_expect_count(
    'no settlement rows created by public shop reads',
    'select count(*) from public.settlements',
    (select row_count from public_shop_fixture_counts where table_name = 'settlements')
  );

  perform pg_temp.public_shop_expect_count(
    'no commission rows created by public shop reads',
    'select count(*) from public.commissions',
    (select row_count from public_shop_fixture_counts where table_name = 'commissions')
  );

  perform pg_temp.public_shop_expect_count(
    'no withdrawal rows created by public shop reads',
    'select count(*) from public.withdrawals',
    (select row_count from public_shop_fixture_counts where table_name = 'withdrawals')
  );

  perform pg_temp.public_shop_record_result(
    'no payment table is connected by public shop reads',
    to_regclass('public.payments') is null,
    'public.payments regclass=' || coalesce(to_regclass('public.payments')::text, 'null')
  );
end;
$$;

do $$
declare
  v_failure_count integer;
  v_failure_details text;
begin
  select count(*)
  into v_failure_count
  from public_shop_test_results
  where passed is false;

  if v_failure_count > 0 then
    select string_agg(test_name || ': ' || coalesce(details, ''), E'\n')
    into v_failure_details
    from public_shop_test_results
    where passed is false;

    raise exception 'Public shop RPC tests failed: % failure(s): %', v_failure_count, v_failure_details;
  end if;

  raise notice 'Public shop RPC tests passed.';
end;
$$;

rollback;
