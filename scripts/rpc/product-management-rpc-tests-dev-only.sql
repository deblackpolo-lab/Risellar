-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Runnable pass/fail tests for supplier product management RPCs in the Risellar development Supabase project.
-- This script uses fake fixture data only and rolls back all changes.
-- Do not use real users, emails, phone numbers, business data, production data, or secrets.
-- Do not weaken RLS, RPC, or storage policies to make this script pass.

begin;

create temp table product_management_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on product_management_fixture_ids to public;
grant select, insert, update on product_management_fixture_ids to authenticated;

create temp table product_management_test_results (
  test_name text primary key,
  passed boolean not null,
  details text not null default ''
) on commit drop;

grant select, insert, update on product_management_test_results to public;
grant select, insert, update on product_management_test_results to authenticated;

create or replace function pg_temp.product_management_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default ''
)
returns void
language plpgsql
as $$
begin
  insert into product_management_test_results (test_name, passed, details)
  values (p_test_name, p_passed, coalesce(p_details, ''))
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.product_management_expect_count(
  p_test_name text,
  p_sql_text text,
  p_expected_count integer
)
returns void
language plpgsql
as $$
declare
  v_observed_count integer;
begin
  execute p_sql_text into v_observed_count;
  perform pg_temp.product_management_record_result(
    p_test_name,
    v_observed_count = p_expected_count,
    'expected=' || p_expected_count || ', observed=' || coalesce(v_observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.product_management_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.product_management_expect_allowed(
  p_test_name text,
  p_sql_text text
)
returns void
language plpgsql
as $$
declare
  v_affected_count integer;
begin
  execute p_sql_text into v_affected_count;
  perform pg_temp.product_management_record_result(
    p_test_name,
    coalesce(v_affected_count, 0) > 0,
    'expected allowed with affected rows, observed=' || coalesce(v_affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.product_management_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.product_management_expect_blocked_or_zero(
  p_test_name text,
  p_sql_text text
)
returns void
language plpgsql
as $$
declare
  v_affected_count integer;
begin
  execute p_sql_text into v_affected_count;
  perform pg_temp.product_management_record_result(
    p_test_name,
    coalesce(v_affected_count, 0) = 0,
    'expected blocked or 0 affected, observed=' || coalesce(v_affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.product_management_record_result(p_test_name, true, 'blocked with ' || sqlstate || ': ' || sqlerrm);
end;
$$;

grant execute on function pg_temp.product_management_record_result(text, boolean, text) to public;
grant execute on function pg_temp.product_management_expect_count(text, text, integer) to public;
grant execute on function pg_temp.product_management_expect_allowed(text, text) to public;
grant execute on function pg_temp.product_management_expect_blocked_or_zero(text, text) to public;

insert into public.profiles (clerk_user_id, email, full_name, primary_role)
values
  ('dev_product_supplier_owner_a', 'dev-product-supplier-owner-a@example.invalid', 'Dev Product Supplier Owner A', 'supplier_owner'),
  ('dev_product_supplier_owner_b', 'dev-product-supplier-owner-b@example.invalid', 'Dev Product Supplier Owner B', 'supplier_owner'),
  ('dev_product_inventory_manager_a', 'dev-product-inventory-manager-a@example.invalid', 'Dev Product Inventory Manager A', 'supplier_inventory_manager'),
  ('dev_product_customer_a', 'dev-product-customer-a@example.invalid', 'Dev Product Customer A', 'customer'),
  ('dev_product_reseller_a', 'dev-product-reseller-a@example.invalid', 'Dev Product Reseller A', 'reseller')
returning clerk_user_id, id;

insert into product_management_fixture_ids (fixture_key, fixture_id)
select clerk_user_id, id
from public.profiles
where clerk_user_id in (
  'dev_product_supplier_owner_a',
  'dev_product_supplier_owner_b',
  'dev_product_inventory_manager_a',
  'dev_product_customer_a',
  'dev_product_reseller_a'
);

insert into public.suppliers (
  owner_profile_id,
  business_name,
  supplier_status,
  verification_status,
  public_display_name
)
values
  (
    (select fixture_id from product_management_fixture_ids where fixture_key = 'dev_product_supplier_owner_a'),
    'Dev Product Supplier A',
    'active',
    'approved',
    'Dev Product Supplier A'
  ),
  (
    (select fixture_id from product_management_fixture_ids where fixture_key = 'dev_product_supplier_owner_b'),
    'Dev Product Supplier B',
    'active',
    'approved',
    'Dev Product Supplier B'
  )
returning business_name, id;

insert into product_management_fixture_ids (fixture_key, fixture_id)
select case business_name
  when 'Dev Product Supplier A' then 'supplier_a'
  when 'Dev Product Supplier B' then 'supplier_b'
end,
id
from public.suppliers
where business_name in ('Dev Product Supplier A', 'Dev Product Supplier B');

insert into public.supplier_team_members (supplier_id, profile_id, supplier_role, staff_status, permissions)
values (
  (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a'),
  (select fixture_id from product_management_fixture_ids where fixture_key = 'dev_product_inventory_manager_a'),
  'supplier_inventory_manager',
  'active',
  '{"products.create": true, "products.update": true, "stock.adjust": true}'::jsonb
);

insert into public.products (
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
values (
  (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_b'),
  'Dev Category',
  'Other Supplier Fixture Product',
  'other-supplier-fixture-product',
  'Fake development product owned by supplier B',
  'pending_approval',
  'pending_review',
  88,
  0,
  0,
  (select fixture_id from product_management_fixture_ids where fixture_key = 'dev_product_supplier_owner_b')
)
returning id;

insert into product_management_fixture_ids (fixture_key, fixture_id)
select 'supplier_b_product', id
from public.products
where slug = 'other-supplier-fixture-product'
  and supplier_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_b');

reset role;
set local "request.jwt.claims" = '{"sub":"dev_product_supplier_owner_a"}';
set local role authenticated;

select pg_temp.product_management_expect_allowed(
  'supplier owner can create own product',
  $$with changed as (
    select public.create_supplier_product(
      'Dev QA Supplier Product',
      'Fake development product for product management RPC tests',
      'Dev Category',
      120,
      9
    ) as id
  ) select count(*) from changed$$
);

insert into product_management_fixture_ids (fixture_key, fixture_id)
select 'supplier_a_product', id
from public.products
where name = 'Dev QA Supplier Product'
  and supplier_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a');

select pg_temp.product_management_expect_count(
  'created product belongs to caller supplier',
  $$select count(*) from public.products where id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product') and supplier_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a')$$,
  1
);

select pg_temp.product_management_expect_count(
  'created product defaults to pending review state',
  $$select count(*) from public.products where id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product') and product_status = 'pending_approval' and approval_status = 'pending_review' and platform_margin_amount = 0 and max_reseller_margin_amount = 0$$,
  1
);

select pg_temp.product_management_expect_count(
  'created product has default stock variant',
  $$select count(*) from public.product_variants where product_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product') and total_stock_quantity = 9 and variant_status = 'active'$$,
  1
);

select pg_temp.product_management_expect_blocked_or_zero(
  'supplier owner cannot approve own product directly',
  $$with changed as (
    update public.products
    set approval_status = 'approved', product_status = 'active'
    where id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product')
    returning 1
  ) select count(*) from changed$$
);

select pg_temp.product_management_expect_blocked_or_zero(
  'supplier owner cannot create product for another supplier through direct insert',
  $$with changed as (
    insert into public.products (supplier_id, name, slug, product_status, approval_status, base_price_amount)
    values ((select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_b'), 'Blocked Other Supplier Product', 'blocked-other-supplier-product', 'pending_approval', 'pending_review', 50)
    returning 1
  ) select count(*) from changed$$
);

select pg_temp.product_management_expect_blocked_or_zero(
  'supplier owner cannot edit another supplier product through RPC',
  $$with changed as (
    select public.update_supplier_product(
      (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_b_product'),
      'Blocked Other Supplier Update',
      null,
      null,
      null,
      null
    ) as id
  ) select count(*) from changed$$
);

select pg_temp.product_management_expect_allowed(
  'supplier owner can update safe editable own product fields',
  $$with changed as (
    select public.update_supplier_product(
      (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product'),
      'Dev QA Supplier Product Updated',
      'Updated fake development description',
      'Updated Dev Category',
      130,
      'Dev Brand'
    ) as id
  ) select count(*) from changed$$
);

select pg_temp.product_management_expect_count(
  'safe update keeps admin approval protected and moves price change to review',
  $$select count(*) from public.products where id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product') and name = 'Dev QA Supplier Product Updated' and base_price_amount = 130 and product_status = 'price_change_pending' and approval_status = 'pending_review'$$,
  1
);

select pg_temp.product_management_expect_allowed(
  'supplier owner can add own product image metadata',
  $$with changed as (
    select public.add_product_image_metadata(
      (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product'),
      (select fixture_id::text from product_management_fixture_ids where fixture_key = 'supplier_a') || '/' || (select fixture_id::text from product_management_fixture_ids where fixture_key = 'supplier_a_product') || '/dev-image.jpg',
      'Fake development product image',
      0,
      true
    ) as id
  ) select count(*) from changed$$
);

select pg_temp.product_management_expect_count(
  'image metadata defaults to pending review and own product',
  $$select count(*) from public.product_images where product_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product') and image_status = 'pending_review' and is_primary is true$$,
  1
);

select pg_temp.product_management_expect_blocked_or_zero(
  'supplier owner cannot add image metadata with another supplier path',
  $$with changed as (
    select public.add_product_image_metadata(
      (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product'),
      (select fixture_id::text from product_management_fixture_ids where fixture_key = 'supplier_b') || '/' || (select fixture_id::text from product_management_fixture_ids where fixture_key = 'supplier_a_product') || '/blocked.jpg',
      'Blocked fake image',
      1,
      false
    ) as id
  ) select count(*) from changed$$
);

select pg_temp.product_management_expect_blocked_or_zero(
  'supplier owner cannot add public URL image metadata',
  $$with changed as (
    select public.add_product_image_metadata(
      (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product'),
      'https://example.invalid/dev-image.jpg',
      'Blocked public URL',
      1,
      false
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local "request.jwt.claims" = '{"sub":"dev_product_inventory_manager_a"}';
set local role authenticated;

select pg_temp.product_management_expect_count(
  'supplier inventory manager can list own supplier operational products',
  $$select count(*) from public.get_supplier_products() where supplier_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a')$$,
  1
);

select pg_temp.product_management_expect_blocked_or_zero(
  'supplier inventory manager cannot create supplier product through owner RPC',
  $$with changed as (
    select public.create_supplier_product('Blocked Inventory Manager Product', 'Blocked', 'Dev Category', 10, 1) as id
  ) select count(*) from changed$$
);

reset role;
set local "request.jwt.claims" = '{"sub":"dev_product_supplier_owner_a"}';
set local role authenticated;

select pg_temp.product_management_expect_allowed(
  'supplier owner can archive own product',
  $$with changed as (
    select public.archive_supplier_product(
      (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product'),
      'Fake development archive test'
    ) as id
  ) select count(*) from changed$$
);

select pg_temp.product_management_expect_count(
  'archive is soft and marks product variant image archived',
  $$select count(*) from public.products p where p.id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product') and p.product_status = 'archived' and p.approval_status = 'archived' and p.deleted_at is not null and exists (select 1 from public.product_variants v where v.product_id = p.id and v.variant_status = 'archived' and v.deleted_at is not null) and exists (select 1 from public.product_images i where i.product_id = p.id and i.image_status = 'archived' and i.deleted_at is not null)$$,
  1
);

select pg_temp.product_management_expect_blocked_or_zero(
  'supplier owner has no direct delete access',
  $$with changed as (
    delete from public.products
    where id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product')
    returning 1
  ) select count(*) from changed$$
);

reset role;
set local "request.jwt.claims" = '{"sub":"dev_product_customer_a"}';
set local role authenticated;

select pg_temp.product_management_expect_blocked_or_zero(
  'normal customer cannot create supplier product',
  $$with changed as (
    select public.create_supplier_product('Blocked Customer Product', 'Blocked', 'Dev Category', 10, 1) as id
  ) select count(*) from changed$$
);

reset role;
set local "request.jwt.claims" = '{"sub":"dev_product_reseller_a"}';
set local role authenticated;

select pg_temp.product_management_expect_blocked_or_zero(
  'reseller cannot create supplier product',
  $$with changed as (
    select public.create_supplier_product('Blocked Reseller Product', 'Blocked', 'Dev Category', 10, 1) as id
  ) select count(*) from changed$$
);

reset role;
set local "request.jwt.claims" = '{"sub":"dev_product_inventory_manager_a"}';
set local role authenticated;

select pg_temp.product_management_expect_count(
  'supplier inventory manager cannot list archived supplier products',
  $$select count(*) from public.get_supplier_products() where supplier_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a')$$,
  0
);

reset role;

select pg_temp.product_management_expect_count(
  'audit log is written for create update image archive',
  $$select count(*) from public.audit_logs where action in ('create_supplier_product', 'update_supplier_product', 'add_product_image_metadata', 'archive_supplier_product') and target_entity_id in ((select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product'), (select id from public.product_images where product_id = (select fixture_id from product_management_fixture_ids where fixture_key = 'supplier_a_product') limit 1))$$,
  4
);

select test_name, passed, details
from product_management_test_results
order by test_name;

do $$
declare
  v_failure_count integer;
  v_failed_details text;
begin
  select count(*)
  into v_failure_count
  from product_management_test_results
  where not passed;

  select string_agg(test_name || ' - ' || coalesce(nullif(details, ''), '<no details>'), E'\n' order by test_name)
  into v_failed_details
  from product_management_test_results
  where not passed;

  if v_failure_count > 0 then
    raise exception 'Supplier product management RPC boundary tests failed: % failure(s): %', v_failure_count, v_failed_details;
  end if;
end $$;

rollback;

-- Rollback is intentional. This script must not leave fixture data behind.
