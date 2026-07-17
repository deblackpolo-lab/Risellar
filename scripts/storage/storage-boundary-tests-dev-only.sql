-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Runnable pass/fail storage boundary tests for the Risellar development Supabase project.
-- This script uses fake fixture data and fake storage object metadata only, then rolls back.
-- It does not upload binary files and does not use secrets or production data.
-- Do not weaken storage policies or RLS policies to make this script pass.

begin;

do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise exception 'Supabase storage schema is not available in this database';
  end if;
end;
$$;

create temp table storage_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select on storage_fixture_ids to public;

create temp table storage_test_results (
  test_name text primary key,
  passed boolean not null,
  details text not null default ''
) on commit drop;

grant select, insert, update on storage_test_results to public;

create or replace function pg_temp.storage_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default ''
)
returns void
language plpgsql
as $$
begin
  insert into storage_test_results (test_name, passed, details)
  values (p_test_name, p_passed, coalesce(p_details, ''))
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.storage_expect_count(
  p_test_name text,
  p_sql_text text,
  p_expected_count integer
)
returns void
language plpgsql
as $$
declare
  observed_count integer;
begin
  execute p_sql_text into observed_count;
  perform pg_temp.storage_record_result(
    p_test_name,
    observed_count = p_expected_count,
    'expected=' || p_expected_count || ', observed=' || coalesce(observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.storage_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.storage_expect_allowed(
  p_test_name text,
  p_sql_text text
)
returns void
language plpgsql
as $$
declare
  affected_count integer;
begin
  execute p_sql_text into affected_count;
  perform pg_temp.storage_record_result(
    p_test_name,
    coalesce(affected_count, 0) > 0,
    'expected allowed with affected rows, observed=' || coalesce(affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.storage_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.storage_expect_blocked_or_zero(
  p_test_name text,
  p_sql_text text
)
returns void
language plpgsql
as $$
declare
  affected_count integer;
begin
  execute p_sql_text into affected_count;
  perform pg_temp.storage_record_result(
    p_test_name,
    coalesce(affected_count, 0) = 0,
    'expected blocked or 0 affected, observed=' || coalesce(affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.storage_record_result(p_test_name, true, 'blocked with ' || sqlstate || ': ' || sqlerrm);
end;
$$;

grant execute on function pg_temp.storage_record_result(text, boolean, text) to public;
grant execute on function pg_temp.storage_expect_count(text, text, integer) to public;
grant execute on function pg_temp.storage_expect_allowed(text, text) to public;
grant execute on function pg_temp.storage_expect_blocked_or_zero(text, text) to public;

insert into public.profiles (clerk_user_id, email, full_name, primary_role)
values
  ('dev_storage_supplier_owner_a', 'dev-storage-supplier-owner-a@example.invalid', 'Dev Storage Supplier Owner A', 'supplier_owner'),
  ('dev_storage_supplier_owner_b', 'dev-storage-supplier-owner-b@example.invalid', 'Dev Storage Supplier Owner B', 'supplier_owner'),
  ('dev_storage_inventory_manager_a', 'dev-storage-inventory-manager-a@example.invalid', 'Dev Storage Inventory Manager A', 'supplier_inventory_manager'),
  ('dev_storage_customer_a', 'dev-storage-customer-a@example.invalid', 'Dev Storage Customer A', 'customer'),
  ('dev_storage_admin_operator', 'dev-storage-admin@example.invalid', 'Dev Storage Admin Operator', 'customer')
returning clerk_user_id, id;

insert into storage_fixture_ids (fixture_key, fixture_id)
select clerk_user_id, id
from public.profiles
where clerk_user_id in (
  'dev_storage_supplier_owner_a',
  'dev_storage_supplier_owner_b',
  'dev_storage_inventory_manager_a',
  'dev_storage_customer_a',
  'dev_storage_admin_operator'
);

insert into public.admin_staff (profile_id, admin_role, permissions, staff_status)
values ((select fixture_id from storage_fixture_ids where fixture_key = 'dev_storage_admin_operator'), 'admin', '{}'::jsonb, 'active');

with inserted as (
  insert into public.suppliers (owner_profile_id, business_name, public_display_name, supplier_status, verification_status)
  values
    ((select fixture_id from storage_fixture_ids where fixture_key = 'dev_storage_supplier_owner_a'), 'Dev Storage Supplier A', 'Dev Storage Supplier A Public', 'active', 'approved'),
    ((select fixture_id from storage_fixture_ids where fixture_key = 'dev_storage_supplier_owner_b'), 'Dev Storage Supplier B', 'Dev Storage Supplier B Public', 'active', 'approved')
  returning id, owner_profile_id
)
insert into storage_fixture_ids (fixture_key, fixture_id)
select
  case
    when owner_profile_id = (select fixture_id from storage_fixture_ids where fixture_key = 'dev_storage_supplier_owner_a') then 'supplier_a'
    else 'supplier_b'
  end,
  id
from inserted;

insert into public.supplier_team_members (supplier_id, profile_id, supplier_role, permissions, staff_status)
values (
  (select fixture_id from storage_fixture_ids where fixture_key = 'supplier_a'),
  (select fixture_id from storage_fixture_ids where fixture_key = 'dev_storage_inventory_manager_a'),
  'supplier_inventory_manager',
  '{"products.create": true, "stock.adjust": true}'::jsonb,
  'active'
);

with inserted as (
  insert into public.products (
    supplier_id,
    name,
    slug,
    product_status,
    approval_status,
    base_price_amount,
    platform_margin_amount,
    max_reseller_margin_amount
  )
  values
    ((select fixture_id from storage_fixture_ids where fixture_key = 'supplier_a'), 'Dev Storage Product A', 'dev-storage-product-a', 'active', 'approved', 10000, 1000, 2500),
    ((select fixture_id from storage_fixture_ids where fixture_key = 'supplier_b'), 'Dev Storage Product B', 'dev-storage-product-b', 'active', 'approved', 20000, 2000, 5000)
  returning id, supplier_id
)
insert into storage_fixture_ids (fixture_key, fixture_id)
select
  case
    when supplier_id = (select fixture_id from storage_fixture_ids where fixture_key = 'supplier_a') then 'product_a'
    else 'product_b'
  end,
  id
from inserted;

insert into storage.objects (bucket_id, name, metadata)
values (
  'product-images',
  (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_b') || '/' ||
    (select fixture_id::text from storage_fixture_ids where fixture_key = 'product_b') ||
    '/existing-other-supplier-object.jpg',
  '{"devOnly": true, "source": "storage-boundary-test-fixture"}'::jsonb
);

select pg_temp.storage_expect_count('product-images bucket is private', $$select count(*) from storage.buckets where id = 'product-images' and public = false$$, 1);

reset role;
set local role anon;
set local "request.jwt.claims" = '{}';
select pg_temp.storage_expect_count('anonymous cannot read product image objects through SQL', $$select count(*) from storage.objects where bucket_id = 'product-images'$$, 0);
select pg_temp.storage_expect_blocked_or_zero('anonymous cannot insert product image object metadata', $$with changed as (insert into storage.objects (bucket_id, name, metadata) values ('product-images', (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_a') || '/' || (select fixture_id::text from storage_fixture_ids where fixture_key = 'product_a') || '/anon-blocked.jpg', '{}'::jsonb) returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_storage_customer_a"}';
select pg_temp.storage_expect_count('customer cannot read product image objects through SQL', $$select count(*) from storage.objects where bucket_id = 'product-images'$$, 0);
select pg_temp.storage_expect_blocked_or_zero('customer cannot insert product image object metadata', $$with changed as (insert into storage.objects (bucket_id, name, metadata) values ('product-images', (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_a') || '/' || (select fixture_id::text from storage_fixture_ids where fixture_key = 'product_a') || '/customer-blocked.jpg', '{}'::jsonb) returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_storage_supplier_owner_a"}';
select pg_temp.storage_expect_allowed('supplier owner can insert own supplier product image object metadata', $$with changed as (insert into storage.objects (bucket_id, name, metadata) values ('product-images', (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_a') || '/' || (select fixture_id::text from storage_fixture_ids where fixture_key = 'product_a') || '/supplier-owner-allowed.jpg', '{"devOnly": true}'::jsonb) returning 1) select count(*) from changed$$);
select pg_temp.storage_expect_blocked_or_zero('supplier owner cannot insert other supplier product image object metadata', $$with changed as (insert into storage.objects (bucket_id, name, metadata) values ('product-images', (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_b') || '/' || (select fixture_id::text from storage_fixture_ids where fixture_key = 'product_b') || '/supplier-owner-blocked.jpg', '{"devOnly": true}'::jsonb) returning 1) select count(*) from changed$$);
select pg_temp.storage_expect_blocked_or_zero('supplier owner cannot overwrite other supplier object metadata', $$with changed as (update storage.objects set metadata = '{"blocked": true}'::jsonb where bucket_id = 'product-images' and name like (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_b') || '/%' returning 1) select count(*) from changed$$);
select pg_temp.storage_expect_allowed('supplier owner can update own product image object metadata', $$with changed as (update storage.objects set metadata = '{"devOnly": true, "updated": true}'::jsonb where bucket_id = 'product-images' and name like (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_a') || '/%' returning 1) select count(*) from changed$$);
select pg_temp.storage_expect_blocked_or_zero('supplier owner cannot insert settlement proof object without explicit bucket policy', $$with changed as (insert into storage.objects (bucket_id, name, metadata) values ('settlement-proofs', (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_a') || '/proof-blocked.jpg', '{}'::jsonb) returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_storage_inventory_manager_a"}';
select pg_temp.storage_expect_allowed('permitted inventory manager can insert own supplier product image object metadata', $$with changed as (insert into storage.objects (bucket_id, name, metadata) values ('product-images', (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_a') || '/' || (select fixture_id::text from storage_fixture_ids where fixture_key = 'product_a') || '/inventory-manager-allowed.jpg', '{"devOnly": true}'::jsonb) returning 1) select count(*) from changed$$);
select pg_temp.storage_expect_blocked_or_zero('permitted inventory manager cannot insert other supplier product image object metadata', $$with changed as (insert into storage.objects (bucket_id, name, metadata) values ('product-images', (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_b') || '/' || (select fixture_id::text from storage_fixture_ids where fixture_key = 'product_b') || '/inventory-manager-blocked.jpg', '{"devOnly": true}'::jsonb) returning 1) select count(*) from changed$$);
select pg_temp.storage_expect_count('inventory manager cannot read other supplier product image object metadata', $$select count(*) from storage.objects where bucket_id = 'product-images' and name like (select fixture_id::text from storage_fixture_ids where fixture_key = 'supplier_b') || '/%'$$, 0);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_storage_admin_operator"}';
select pg_temp.storage_expect_count('admin can read product image object metadata', $$select count(*) from storage.objects where bucket_id = 'product-images'$$, 3);
select pg_temp.storage_expect_blocked_or_zero('no direct delete path for product image objects', $$with changed as (delete from storage.objects where bucket_id = 'product-images' returning 1) select count(*) from changed$$);

reset role;
select test_name, passed, details
from storage_test_results
order by test_name;

do $$
declare
  failure_count integer;
  failed_details text;
begin
  select count(*) into failure_count
  from storage_test_results
  where not passed;

  select string_agg(test_name || ' - ' || coalesce(nullif(details, ''), '<no details>'), E'\n' order by test_name)
  into failed_details
  from storage_test_results
  where not passed;

  if failure_count > 0 then
    raise exception 'Storage boundary tests failed: % failure(s): %', failure_count, failed_details;
  end if;
end $$;

rollback;

-- Rollback is intentional. This script must not leave fixture data or storage object metadata behind.
