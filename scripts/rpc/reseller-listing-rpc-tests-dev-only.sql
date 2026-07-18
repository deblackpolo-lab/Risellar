-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Verifies reseller add-to-shop/listing RPC boundaries after the migration is applied to the development project.
-- This script uses fake/dev-only fixture rows and rolls back all fixture data.

begin;

create temp table reseller_listing_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on reseller_listing_test_results to authenticated;

create temp table reseller_listing_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on reseller_listing_fixture_ids to authenticated;

create or replace function pg_temp.reseller_listing_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into reseller_listing_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.reseller_listing_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.reseller_listing_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.reseller_listing_expect_count(
  p_test_name text,
  p_sql text,
  p_expected integer
)
returns void
language plpgsql
as $$
declare
  v_observed integer;
begin
  execute p_sql into v_observed;
  perform pg_temp.reseller_listing_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.reseller_listing_record_result(p_test_name, false, sqlerrm);
end;
$$;

create or replace function pg_temp.reseller_listing_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.reseller_listing_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.reseller_listing_record_result(p_test_name, true, sqlerrm);
end;
$$;

do $$
declare
  v_reseller_profile_id uuid := gen_random_uuid();
  v_other_reseller_profile_id uuid := gen_random_uuid();
  v_customer_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_other_reseller_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_approved_product_id uuid := gen_random_uuid();
  v_pending_product_id uuid := gen_random_uuid();
  v_rejected_product_id uuid := gen_random_uuid();
  v_archived_product_id uuid := gen_random_uuid();
  v_listing_id uuid;
  v_duplicate_id uuid;
  v_observed_price numeric;
begin
  perform pg_temp.reseller_listing_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_reseller_profile_id, 'dev_reseller_listing_reseller', 'dev-reseller-listing-reseller@example.test', 'Dev Reseller Listing Reseller', 'reseller', 'active'),
    (v_other_reseller_profile_id, 'dev_reseller_listing_other_reseller', 'dev-reseller-listing-other-reseller@example.test', 'Dev Reseller Listing Other Reseller', 'reseller', 'active'),
    (v_customer_profile_id, 'dev_reseller_listing_customer', 'dev-reseller-listing-customer@example.test', 'Dev Reseller Listing Customer', 'customer', 'active'),
    (v_supplier_profile_id, 'dev_reseller_listing_supplier', 'dev-reseller-listing-supplier@example.test', 'Dev Reseller Listing Supplier', 'supplier_owner', 'active'),
    (v_admin_profile_id, 'dev_reseller_listing_admin', 'dev-reseller-listing-admin@example.test', 'Dev Reseller Listing Admin', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status)
  values
    (v_reseller_id, v_reseller_profile_id, 'dev_only_listing_reseller', 'approved'),
    (v_other_reseller_id, v_other_reseller_profile_id, 'dev_only_listing_other_reseller', 'approved');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Supplier Listing Test', 'active', 'approved', 'Dev Supplier Listing');

  insert into public.products(
    id,
    supplier_id,
    category,
    name,
    slug,
    description,
    product_status,
    approval_status,
    base_price_amount,
    platform_margin_amount,
    max_reseller_margin_amount,
    created_by_profile_id
  )
  values
    (v_approved_product_id, v_supplier_id, 'QA Test', 'Dev Approved Listing Product', 'dev-approved-listing-product', 'Approved dev-only listing product', 'active', 'approved', 100, 20, 50, v_supplier_profile_id),
    (v_pending_product_id, v_supplier_id, 'QA Test', 'Dev Pending Listing Product', 'dev-pending-listing-product', 'Pending dev-only listing product', 'pending_approval', 'pending_review', 100, 20, 50, v_supplier_profile_id),
    (v_rejected_product_id, v_supplier_id, 'QA Test', 'Dev Rejected Listing Product', 'dev-rejected-listing-product', 'Rejected dev-only listing product', 'rejected', 'rejected', 100, 20, 50, v_supplier_profile_id),
    (v_archived_product_id, v_supplier_id, 'QA Test', 'Dev Archived Listing Product', 'dev-archived-listing-product', 'Archived dev-only listing product', 'archived', 'archived', 100, 20, 50, v_supplier_profile_id);

  insert into public.product_variants(product_id, total_stock_quantity, reserved_stock_quantity, variant_status)
  values (v_approved_product_id, 7, 0, 'active');

  insert into reseller_listing_fixture_ids(fixture_key, fixture_id)
  values ('approved_product', v_approved_product_id);

  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_reseller');

  v_listing_id := public.create_reseller_product_listing(v_approved_product_id, 30);
  insert into reseller_listing_fixture_ids(fixture_key, fixture_id)
  values ('approved_listing', v_listing_id);

  select customer_product_price_amount
  into v_observed_price
  from public.reseller_products
  where id = v_listing_id;

  perform pg_temp.reseller_listing_record_result(
    'approved reseller can list approved product with server-computed customer price',
    v_observed_price = 150,
    'expected=150, observed=' || coalesce(v_observed_price::text, 'null')
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_admin');

  perform pg_temp.reseller_listing_expect_count(
    'create listing writes audit row',
    'select count(*) from public.audit_logs where action = ''create_reseller_product_listing'' and target_entity_id = (select fixture_id from reseller_listing_fixture_ids where fixture_key = ''approved_listing'')',
    1
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_reseller');

  perform pg_temp.reseller_listing_expect_blocked(
    'duplicate active listing is blocked',
    'select public.create_reseller_product_listing((select fixture_id from reseller_listing_fixture_ids where fixture_key = ''approved_product''), 25)'
  );

  perform pg_temp.reseller_listing_expect_blocked(
    'pending product cannot be listed',
    format('select public.create_reseller_product_listing(%L::uuid, 10)', v_pending_product_id)
  );

  perform pg_temp.reseller_listing_expect_blocked(
    'rejected product cannot be listed',
    format('select public.create_reseller_product_listing(%L::uuid, 10)', v_rejected_product_id)
  );

  perform pg_temp.reseller_listing_expect_blocked(
    'archived product cannot be listed',
    format('select public.create_reseller_product_listing(%L::uuid, 10)', v_archived_product_id)
  );

  perform pg_temp.reseller_listing_expect_blocked(
    'negative margin is blocked',
    format('select public.update_reseller_product_listing(%L::uuid, -1, ''active'')', v_listing_id)
  );

  perform pg_temp.reseller_listing_expect_blocked(
    'excessive margin is blocked',
    format('select public.update_reseller_product_listing(%L::uuid, 50000, ''active'')', v_listing_id)
  );

  perform public.update_reseller_product_listing(v_listing_id, 35, 'active');

  perform pg_temp.reseller_listing_expect_count(
    'reseller can update own margin within limits',
    'select count(*) from public.reseller_products where id = (select fixture_id from reseller_listing_fixture_ids where fixture_key = ''approved_listing'') and reseller_margin_amount = 35 and customer_product_price_amount = 155',
    1
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_admin');

  perform pg_temp.reseller_listing_expect_count(
    'update listing writes audit row',
    'select count(*) from public.audit_logs where action = ''update_reseller_product_listing'' and target_entity_id = (select fixture_id from reseller_listing_fixture_ids where fixture_key = ''approved_listing'')',
    1
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_other_reseller');

  perform pg_temp.reseller_listing_expect_blocked(
    'reseller cannot update another reseller listing',
    format('select public.update_reseller_product_listing(%L::uuid, 20, ''active'')', v_listing_id)
  );

  perform pg_temp.reseller_listing_expect_blocked(
    'reseller cannot archive another reseller listing',
    format('select public.archive_reseller_product_listing(%L::uuid)', v_listing_id)
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_customer');

  perform pg_temp.reseller_listing_expect_blocked(
    'customer cannot create reseller listing',
    format('select public.create_reseller_product_listing(%L::uuid, 10)', v_approved_product_id)
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_supplier');

  perform pg_temp.reseller_listing_expect_blocked(
    'supplier cannot create reseller listing',
    format('select public.create_reseller_product_listing(%L::uuid, 10)', v_approved_product_id)
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_reseller');

  perform public.archive_reseller_product_listing(v_listing_id);

  perform pg_temp.reseller_listing_expect_count(
    'reseller can soft archive own listing',
    'select count(*) from public.reseller_products where id = (select fixture_id from reseller_listing_fixture_ids where fixture_key = ''approved_listing'') and listing_status = ''archived'' and deleted_at is not null',
    1
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_admin');

  perform pg_temp.reseller_listing_expect_count(
    'archive listing writes audit row',
    'select count(*) from public.audit_logs where action = ''archive_reseller_product_listing'' and target_entity_id = (select fixture_id from reseller_listing_fixture_ids where fixture_key = ''approved_listing'')',
    1
  );

  perform pg_temp.reseller_listing_reset_context();
  perform pg_temp.reseller_listing_set_context('dev_reseller_listing_reseller');

  perform pg_temp.reseller_listing_expect_count(
    'no stock reservation is created',
    'select count(*) from public.stock_reservations',
    0
  );

  perform pg_temp.reseller_listing_expect_count(
    'no order is created',
    'select count(*) from public.orders',
    0
  );

  perform pg_temp.reseller_listing_expect_count(
    'no commission is created',
    'select count(*) from public.commissions',
    0
  );

  perform pg_temp.reseller_listing_expect_count(
    'no settlement is created',
    'select count(*) from public.settlements',
    0
  );

  select public.create_reseller_product_listing(v_approved_product_id, 40)
  into v_duplicate_id;

  perform pg_temp.reseller_listing_expect_count(
    'archived listing allows new active listing for same product',
    format('select count(*) from public.get_reseller_shop_products() where listing_id = %L::uuid and customer_product_price_amount = 160', v_duplicate_id),
    1
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
  from reseller_listing_test_results
  where passed is false;

  if v_failure_count > 0 then
    select string_agg(test_name || ': ' || coalesce(details, ''), E'\n')
    into v_failure_details
    from reseller_listing_test_results
    where passed is false;

    raise exception 'Reseller listing RPC tests failed: % failure(s): %', v_failure_count, v_failure_details;
  end if;

  raise notice 'Reseller listing RPC tests passed.';
end;
$$;

rollback;
