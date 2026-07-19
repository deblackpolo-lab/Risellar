-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Checkout Phase B Group 1 checkout draft RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction and rolls everything back.

begin;

create temp table checkout_draft_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on checkout_draft_test_results to authenticated;

create temp table checkout_draft_fixture_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on checkout_draft_fixture_counts to authenticated;

create temp table checkout_draft_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on checkout_draft_fixture_ids to authenticated;

create or replace function pg_temp.checkout_draft_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into checkout_draft_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.checkout_draft_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.checkout_draft_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.checkout_draft_expect_count(
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
  perform pg_temp.checkout_draft_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.checkout_draft_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.checkout_draft_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.checkout_draft_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.checkout_draft_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_customer_a_profile_id uuid := gen_random_uuid();
  v_customer_b_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_customer_a_id uuid := gen_random_uuid();
  v_customer_b_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_active_product_id uuid := gen_random_uuid();
  v_pending_product_id uuid := gen_random_uuid();
  v_rejected_product_id uuid := gen_random_uuid();
  v_archived_product_id uuid := gen_random_uuid();
  v_active_listing_id uuid := gen_random_uuid();
  v_pending_listing_id uuid := gen_random_uuid();
  v_rejected_listing_id uuid := gen_random_uuid();
  v_archived_listing_id uuid := gen_random_uuid();
  v_customer_a_address_id uuid := gen_random_uuid();
  v_customer_b_address_id uuid := gen_random_uuid();
  v_draft_id uuid;
begin
  perform pg_temp.checkout_draft_reset_context();

  insert into checkout_draft_fixture_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('delivery_quotes', (select count(*) from public.delivery_quotes)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals));

  insert into public.profiles(id, clerk_user_id, email, full_name, phone, whatsapp, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_checkout_draft_customer_a', 'dev-checkout-draft-customer-a@example.test', 'Dev Checkout Customer A', '0200000101', '0200000102', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_checkout_draft_customer_b', 'dev-checkout-draft-customer-b@example.test', 'Dev Checkout Customer B', '0200000201', null, 'customer', 'active'),
    (v_reseller_profile_id, 'dev_checkout_draft_reseller', 'dev-checkout-draft-reseller@example.test', 'Dev Checkout Reseller', '0200000301', null, 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_checkout_draft_supplier', 'dev-checkout-draft-supplier@example.test', 'Dev Checkout Supplier', '0200000401', null, 'supplier_owner', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_checkout_draft_reseller', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-checkout-draft-shop', 'Dev Checkout Draft Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Checkout Supplier', 'active', 'approved', 'Dev Checkout Supplier');

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
    (v_active_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Approved Product', 'dev-checkout-approved-product', 'Approved checkout draft product', 'Dev Safe Brand', 'active', 'approved', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_pending_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Pending Product', 'dev-checkout-pending-product', 'Pending checkout draft product', 'Dev Safe Brand', 'pending_approval', 'pending_review', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_rejected_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Rejected Product', 'dev-checkout-rejected-product', 'Rejected checkout draft product', 'Dev Safe Brand', 'rejected', 'rejected', 100, 20, 60, 'GHS', v_supplier_profile_id),
    (v_archived_product_id, v_supplier_id, 'QA Test', 'Dev Checkout Archived Product', 'dev-checkout-archived-product', 'Archived checkout draft product', 'Dev Safe Brand', 'archived', 'archived', 100, 20, 60, 'GHS', v_supplier_profile_id);

  insert into public.product_variants(product_id, total_stock_quantity, reserved_stock_quantity, variant_status)
  values
    (v_active_product_id, 5, 0, 'active'),
    (v_pending_product_id, 5, 0, 'active'),
    (v_rejected_product_id, 5, 0, 'active'),
    (v_archived_product_id, 5, 0, 'active');

  insert into public.product_images(product_id, storage_path, alt_text, sort_order, image_status, is_primary, created_by_profile_id)
  values (v_active_product_id, 'dev-only/checkout-draft/primary.webp', 'Dev checkout draft image', 1, 'active', true, v_supplier_profile_id);

  insert into public.reseller_products(
    id,
    reseller_id,
    shop_id,
    product_id,
    listing_status,
    reseller_margin_amount,
    customer_product_price_amount,
    share_slug
  )
  values
    (v_active_listing_id, v_reseller_id, v_shop_id, v_active_product_id, 'active', 30, 150, 'dev-checkout-active-listing'),
    (v_pending_listing_id, v_reseller_id, v_shop_id, v_pending_product_id, 'needs_review', 30, 150, 'dev-checkout-pending-listing'),
    (v_rejected_listing_id, v_reseller_id, v_shop_id, v_rejected_product_id, 'active', 30, 150, 'dev-checkout-rejected-product-listing'),
    (v_archived_listing_id, v_reseller_id, v_shop_id, v_archived_product_id, 'archived', 30, 150, 'dev-checkout-archived-listing');

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
    (v_customer_a_address_id, v_customer_a_id, 'Home', 'Dev Checkout Customer A', '0200000101', 'Greater Accra', 'Accra', 'East Legon', 'Fake dev checkout street', 'Fake dev landmark', true),
    (v_customer_b_address_id, v_customer_b_id, 'Home', 'Dev Checkout Customer B', '0200000201', 'Ashanti', 'Kumasi', 'Adum', 'Fake dev customer B street', null, true);

  insert into checkout_draft_fixture_ids(fixture_key, fixture_id)
  values
    ('customer_a', v_customer_a_id),
    ('customer_b', v_customer_b_id),
    ('customer_a_address', v_customer_a_address_id),
    ('customer_b_address', v_customer_b_address_id),
    ('active_listing', v_active_listing_id),
    ('pending_listing', v_pending_listing_id),
    ('rejected_listing', v_rejected_listing_id),
    ('archived_listing', v_archived_listing_id);

  perform pg_temp.checkout_draft_set_context('dev_checkout_draft_customer_a');

  select draft_id
  into v_draft_id
  from public.create_checkout_draft_from_listing(v_active_listing_id, 2);

  insert into checkout_draft_fixture_ids(fixture_key, fixture_id)
  values ('customer_a_draft', v_draft_id);

  perform pg_temp.checkout_draft_expect_count(
    'customer can create checkout draft from active approved listing',
    $sql$select count(*) from public.get_checkout_draft((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft')) where draft_status = 'draft'$sql$,
    1
  );

  perform pg_temp.checkout_draft_expect_count(
    'draft snapshot price is server-calculated from listing',
    $sql$select count(*) from public.get_checkout_draft((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft')) where final_customer_price_amount = 150 and line_total_amount = 300$sql$,
    1
  );

  perform pg_temp.checkout_draft_reset_context();

  update public.reseller_products
  set customer_product_price_amount = 999
  where id = v_active_listing_id;

  perform pg_temp.checkout_draft_set_context('dev_checkout_draft_customer_a');

  perform pg_temp.checkout_draft_expect_count(
    'existing draft snapshot is immutable after listing price changes',
    $sql$select count(*) from public.get_checkout_draft((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft')) where final_customer_price_amount = 150 and line_total_amount = 300$sql$,
    1
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'invalid quantity is blocked',
    format('select count(*) from public.create_checkout_draft_from_listing(%L::uuid, 0)', v_active_listing_id)
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'pending reseller listing cannot create draft',
    format('select count(*) from public.create_checkout_draft_from_listing(%L::uuid, 1)', v_pending_listing_id)
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'rejected product listing cannot create draft',
    format('select count(*) from public.create_checkout_draft_from_listing(%L::uuid, 1)', v_rejected_listing_id)
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'archived listing cannot create draft',
    format('select count(*) from public.create_checkout_draft_from_listing(%L::uuid, 1)', v_archived_listing_id)
  );

  perform pg_temp.checkout_draft_expect_count(
    'customer can attach own address to own draft',
    $sql$select count(*) from public.update_checkout_draft_contact_address((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft'), (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_address'), '0200000109') where draft_status = 'review_pending' and delivery_address_id = (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_address')$sql$,
    1
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'customer cannot attach another customer address',
    $sql$select count(*) from public.update_checkout_draft_contact_address((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft'), (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_b_address'), '0200000109')$sql$
  );

  perform pg_temp.checkout_draft_reset_context();
  perform pg_temp.checkout_draft_set_context('dev_checkout_draft_customer_b');

  perform pg_temp.checkout_draft_expect_count(
    'customer B cannot read customer A draft',
    $sql$select count(*) from public.get_checkout_draft((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft'))$sql$,
    0
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'customer B cannot update customer A draft',
    $sql$select count(*) from public.update_checkout_draft_contact_address((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft'), (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_b_address'), null)$sql$
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'customer B cannot abandon customer A draft',
    $sql$select count(*) from public.abandon_checkout_draft((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft'))$sql$
  );

  perform pg_temp.checkout_draft_reset_context();
  perform pg_temp.checkout_draft_set_context('dev_checkout_draft_reseller');

  perform pg_temp.checkout_draft_expect_blocked(
    'reseller cannot create customer checkout draft',
    format('select count(*) from public.create_checkout_draft_from_listing(%L::uuid, 1)', v_active_listing_id)
  );

  perform pg_temp.checkout_draft_reset_context();
  perform pg_temp.checkout_draft_set_context('dev_checkout_draft_supplier');

  perform pg_temp.checkout_draft_expect_blocked(
    'supplier cannot create customer checkout draft',
    format('select count(*) from public.create_checkout_draft_from_listing(%L::uuid, 1)', v_active_listing_id)
  );

  perform pg_temp.checkout_draft_reset_context();
  perform pg_temp.checkout_draft_set_context('dev_checkout_draft_customer_a');

  perform pg_temp.checkout_draft_expect_count(
    'customer can abandon own draft',
    $sql$select count(*) from public.abandon_checkout_draft((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft')) where draft_status = 'abandoned' and abandoned_at is not null$sql$,
    1
  );

  perform pg_temp.checkout_draft_expect_blocked(
    'abandoned draft cannot be updated',
    $sql$select count(*) from public.update_checkout_draft_contact_address((select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft'), (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_address'), null)$sql$
  );

  perform pg_temp.checkout_draft_reset_context();

  perform pg_temp.checkout_draft_expect_count(
    'checkout draft create writes audit row',
    $sql$select count(*) from public.audit_logs where action = 'create_checkout_draft' and target_entity_id = (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft')$sql$,
    1
  );

  perform pg_temp.checkout_draft_expect_count(
    'checkout draft address update writes audit row',
    $sql$select count(*) from public.audit_logs where action = 'update_checkout_draft_contact_address' and target_entity_id = (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft')$sql$,
    1
  );

  perform pg_temp.checkout_draft_expect_count(
    'checkout draft abandon writes audit row',
    $sql$select count(*) from public.audit_logs where action = 'abandon_checkout_draft' and target_entity_id = (select fixture_id from checkout_draft_fixture_ids where fixture_key = 'customer_a_draft')$sql$,
    1
  );

  perform pg_temp.checkout_draft_expect_count(
    'no order rows are created by checkout drafts',
    $sql$select count(*) from public.orders$sql$,
    (select row_count from checkout_draft_fixture_counts where table_name = 'orders')
  );

  perform pg_temp.checkout_draft_expect_count(
    'no order item rows are created by checkout drafts',
    $sql$select count(*) from public.order_items$sql$,
    (select row_count from checkout_draft_fixture_counts where table_name = 'order_items')
  );

  perform pg_temp.checkout_draft_expect_count(
    'no stock reservation rows are created by checkout drafts',
    $sql$select count(*) from public.stock_reservations$sql$,
    (select row_count from checkout_draft_fixture_counts where table_name = 'stock_reservations')
  );

  perform pg_temp.checkout_draft_expect_count(
    'no delivery quote rows are created by checkout drafts',
    $sql$select count(*) from public.delivery_quotes$sql$,
    (select row_count from checkout_draft_fixture_counts where table_name = 'delivery_quotes')
  );

  perform pg_temp.checkout_draft_expect_count(
    'no settlement rows are created by checkout drafts',
    $sql$select count(*) from public.settlements$sql$,
    (select row_count from checkout_draft_fixture_counts where table_name = 'settlements')
  );

  perform pg_temp.checkout_draft_expect_count(
    'no commission rows are created by checkout drafts',
    $sql$select count(*) from public.commissions$sql$,
    (select row_count from checkout_draft_fixture_counts where table_name = 'commissions')
  );

  perform pg_temp.checkout_draft_expect_count(
    'no withdrawal rows are created by checkout drafts',
    $sql$select count(*) from public.withdrawals$sql$,
    (select row_count from checkout_draft_fixture_counts where table_name = 'withdrawals')
  );
end;
$$;

reset role;

select test_name, passed, details
from checkout_draft_test_results
order by test_name;

do $$
declare
  v_failure_count integer;
  v_failure_details text;
begin
  select count(*)
  into v_failure_count
  from checkout_draft_test_results
  where passed is false;

  if v_failure_count > 0 then
    select string_agg(test_name || ': ' || coalesce(details, ''), E'\n' order by test_name)
    into v_failure_details
    from checkout_draft_test_results
    where passed is false;

    raise exception 'Checkout draft RPC tests failed: % failure(s): %', v_failure_count, v_failure_details;
  end if;

  raise notice 'Checkout draft RPC tests passed.';
end;
$$;

rollback;

-- Rollback is intentional. This script must not leave fixture data behind.
