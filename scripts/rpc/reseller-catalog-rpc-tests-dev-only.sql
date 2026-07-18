-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Verifies the approved reseller catalog RPC boundary after the migration is applied to the development project.
-- This script uses fake/dev-only fixture rows and rolls back all fixture data.

begin;

create temp table reseller_catalog_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

create or replace function pg_temp.record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into reseller_catalog_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.set_test_context(p_clerk_user_id text)
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

create or replace function pg_temp.reset_test_context()
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
  v_reseller_profile_id uuid := gen_random_uuid();
  v_customer_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_approved_product_id uuid := gen_random_uuid();
  v_pending_product_id uuid := gen_random_uuid();
  v_archived_product_id uuid := gen_random_uuid();
  v_visible_count integer;
  v_forbidden_count integer;
begin
  perform pg_temp.reset_test_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_reseller_profile_id, 'dev_reseller_catalog_reseller', 'dev-reseller-catalog-reseller@example.test', 'Dev Reseller Catalog Reseller', 'reseller', 'active'),
    (v_customer_profile_id, 'dev_reseller_catalog_customer', 'dev-reseller-catalog-customer@example.test', 'Dev Reseller Catalog Customer', 'customer', 'active'),
    (v_supplier_profile_id, 'dev_reseller_catalog_supplier', 'dev-reseller-catalog-supplier@example.test', 'Dev Reseller Catalog Supplier', 'supplier_owner', 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_catalog_reseller', 'approved');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Supplier Catalog Test', 'active', 'approved', 'Dev Supplier Catalog');

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
    (v_approved_product_id, v_supplier_id, 'QA Test', 'Dev Approved Catalog Product', 'dev-approved-catalog-product', 'Approved dev-only catalog product', 'active', 'approved', 100, 20, 30, v_supplier_profile_id),
    (v_pending_product_id, v_supplier_id, 'QA Test', 'Dev Pending Catalog Product', 'dev-pending-catalog-product', 'Pending dev-only product', 'pending_approval', 'pending_review', 100, 20, 30, v_supplier_profile_id),
    (v_archived_product_id, v_supplier_id, 'QA Test', 'Dev Archived Catalog Product', 'dev-archived-catalog-product', 'Archived dev-only product', 'archived', 'approved', 100, 20, 30, v_supplier_profile_id);

  insert into public.product_variants(product_id, total_stock_quantity, reserved_stock_quantity, variant_status)
  values (v_approved_product_id, 5, 1, 'active');

  insert into public.product_images(product_id, storage_path, alt_text, image_status, is_primary, created_by_profile_id)
  values (v_approved_product_id, v_supplier_id::text || '/' || v_approved_product_id::text || '/dev-catalog-image.png', 'Dev catalog image', 'active', true, v_supplier_profile_id);

  perform pg_temp.set_test_context('dev_reseller_catalog_reseller');

  select count(*) into v_visible_count
  from public.get_reseller_approved_products()
  where product_id = v_approved_product_id
    and approval_status = 'approved'
    and product_status = 'active';

  perform pg_temp.record_result(
    'approved reseller can see approved active product',
    v_visible_count = 1,
    'expected=1 observed=' || v_visible_count
  );

  select count(*) into v_forbidden_count
  from public.get_reseller_approved_products()
  where product_id in (v_pending_product_id, v_archived_product_id);

  perform pg_temp.record_result(
    'pending and archived products are hidden',
    v_forbidden_count = 0,
    'expected=0 observed=' || v_forbidden_count
  );

  perform pg_temp.reset_test_context();
  perform pg_temp.set_test_context('dev_reseller_catalog_customer');

  begin
    perform public.get_reseller_approved_products();
    perform pg_temp.record_result('customer cannot call reseller catalog RPC', false, 'customer call unexpectedly succeeded');
  exception when others then
    perform pg_temp.record_result('customer cannot call reseller catalog RPC', true, sqlerrm);
  end;

  perform pg_temp.reset_test_context();
  perform pg_temp.set_test_context('dev_reseller_catalog_supplier');

  begin
    perform public.get_reseller_approved_products();
    perform pg_temp.record_result('supplier cannot call reseller catalog RPC', false, 'supplier call unexpectedly succeeded');
  exception when others then
    perform pg_temp.record_result('supplier cannot call reseller catalog RPC', true, sqlerrm);
  end;
end;
$$;

do $$
declare
  v_failure_count integer;
  v_failure_details text;
begin
  select count(*)
  into v_failure_count
  from reseller_catalog_test_results
  where passed is false;

  if v_failure_count > 0 then
    select string_agg(test_name || ': ' || coalesce(details, ''), E'\n')
    into v_failure_details
    from reseller_catalog_test_results
    where passed is false;

    raise exception 'Reseller catalog RPC tests failed: % failure(s): %', v_failure_count, v_failure_details;
  end if;

  raise notice 'Reseller catalog RPC tests passed.';
end;
$$;

rollback;
