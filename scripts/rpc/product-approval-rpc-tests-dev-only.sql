-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Runnable pass/fail tests for admin supplier product approval RPCs in the Risellar development Supabase project.
-- This script uses fake fixture data only and rolls back all changes.
-- Do not use real users, emails, phone numbers, business data, production data, or secrets.
-- Do not weaken RLS, RPC, or storage policies to make this script pass.

begin;

create temp table product_approval_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on product_approval_fixture_ids to public;
grant select, insert, update on product_approval_fixture_ids to authenticated;

create temp table product_approval_test_results (
  test_name text primary key,
  passed boolean not null,
  details text not null default ''
) on commit drop;

grant select, insert, update on product_approval_test_results to public;
grant select, insert, update on product_approval_test_results to authenticated;

create or replace function pg_temp.product_approval_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default ''
)
returns void
language plpgsql
as $$
begin
  insert into product_approval_test_results (test_name, passed, details)
  values (p_test_name, p_passed, coalesce(p_details, ''))
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.product_approval_expect_count(
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
  perform pg_temp.product_approval_record_result(
    p_test_name,
    v_observed_count = p_expected_count,
    'expected=' || p_expected_count || ', observed=' || coalesce(v_observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.product_approval_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.product_approval_expect_allowed(
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
  perform pg_temp.product_approval_record_result(
    p_test_name,
    coalesce(v_affected_count, 0) > 0,
    'expected allowed with affected rows, observed=' || coalesce(v_affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.product_approval_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.product_approval_expect_blocked_or_zero(
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
  perform pg_temp.product_approval_record_result(
    p_test_name,
    coalesce(v_affected_count, 0) = 0,
    'expected blocked or 0 affected, observed=' || coalesce(v_affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.product_approval_record_result(p_test_name, true, 'blocked with ' || sqlstate || ': ' || sqlerrm);
end;
$$;

grant execute on function pg_temp.product_approval_record_result(text, boolean, text) to public;
grant execute on function pg_temp.product_approval_expect_count(text, text, integer) to public;
grant execute on function pg_temp.product_approval_expect_allowed(text, text) to public;
grant execute on function pg_temp.product_approval_expect_blocked_or_zero(text, text) to public;

insert into public.profiles (clerk_user_id, email, full_name, primary_role)
values
  ('dev_product_approval_supplier_owner', 'dev-product-approval-supplier-owner@example.invalid', 'Dev Product Approval Supplier Owner', 'supplier_owner'),
  ('dev_product_approval_admin', 'dev-product-approval-admin@example.invalid', 'Dev Product Approval Admin', 'customer'),
  ('dev_product_approval_customer', 'dev-product-approval-customer@example.invalid', 'Dev Product Approval Customer', 'customer'),
  ('dev_product_approval_reseller', 'dev-product-approval-reseller@example.invalid', 'Dev Product Approval Reseller', 'reseller')
returning clerk_user_id, id;

insert into product_approval_fixture_ids (fixture_key, fixture_id)
select clerk_user_id, id
from public.profiles
where clerk_user_id in (
  'dev_product_approval_supplier_owner',
  'dev_product_approval_admin',
  'dev_product_approval_customer',
  'dev_product_approval_reseller'
);

insert into public.admin_staff (profile_id, admin_role, permissions, staff_status)
values (
  (select fixture_id from product_approval_fixture_ids where fixture_key = 'dev_product_approval_admin'),
  'admin',
  '{}'::jsonb,
  'active'
);

insert into public.suppliers (
  owner_profile_id,
  business_name,
  supplier_status,
  verification_status,
  public_display_name
)
values (
  (select fixture_id from product_approval_fixture_ids where fixture_key = 'dev_product_approval_supplier_owner'),
  'Dev Product Approval Supplier',
  'active',
  'approved',
  'Dev Product Approval Supplier'
);

insert into product_approval_fixture_ids (fixture_key, fixture_id)
select 'supplier', id
from public.suppliers
where business_name = 'Dev Product Approval Supplier';

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
values
  (
    (select fixture_id from product_approval_fixture_ids where fixture_key = 'supplier'),
    'Dev QA',
    'Dev Product Approval Approve Target',
    'dev-product-approval-approve-target',
    'Fake development-only approval target',
    'pending_approval',
    'pending_review',
    50,
    0,
    0,
    (select fixture_id from product_approval_fixture_ids where fixture_key = 'dev_product_approval_supplier_owner')
  ),
  (
    (select fixture_id from product_approval_fixture_ids where fixture_key = 'supplier'),
    'Dev QA',
    'Dev Product Approval Reject Target',
    'dev-product-approval-reject-target',
    'Fake development-only rejection target',
    'pending_approval',
    'pending_review',
    60,
    0,
    0,
    (select fixture_id from product_approval_fixture_ids where fixture_key = 'dev_product_approval_supplier_owner')
  )
returning slug, id;

insert into product_approval_fixture_ids (fixture_key, fixture_id)
select case slug
  when 'dev-product-approval-approve-target' then 'approve_product'
  when 'dev-product-approval-reject-target' then 'reject_product'
end,
id
from public.products
where slug in ('dev-product-approval-approve-target', 'dev-product-approval-reject-target');

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_product_approval_customer"}';
select pg_temp.product_approval_expect_blocked_or_zero(
  'customer cannot review supplier product',
  $$with changed as (
    select public.review_supplier_product(
      (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product'),
      'approved',
      'customer should be blocked'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_product_approval_reseller"}';
select pg_temp.product_approval_expect_blocked_or_zero(
  'reseller cannot review supplier product',
  $$with changed as (
    select public.review_supplier_product(
      (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product'),
      'approved',
      'reseller should be blocked'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_product_approval_supplier_owner"}';
select pg_temp.product_approval_expect_blocked_or_zero(
  'supplier owner cannot self approve product',
  $$with changed as (
    select public.review_supplier_product(
      (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product'),
      'approved',
      'supplier self-approval should be blocked'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_product_approval_admin"}';
select pg_temp.product_approval_expect_blocked_or_zero(
  'admin invalid decision is blocked',
  $$with changed as (
    select public.review_supplier_product(
      (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product'),
      'pending_review',
      'invalid decision'
    ) as id
  ) select count(*) from changed$$
);
select pg_temp.product_approval_expect_blocked_or_zero(
  'admin missing product id is blocked',
  $$with changed as (
    select public.review_supplier_product(null, 'approved', 'missing product id') as id
  ) select count(*) from changed$$
);
select pg_temp.product_approval_expect_allowed(
  'admin can approve pending supplier product',
  $$with changed as (
    select public.review_supplier_product(
      (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product'),
      'approved',
      'approved in development product approval boundary test'
    ) as id
  ) select count(*) from changed$$
);
select pg_temp.product_approval_expect_count(
  'approved product becomes active and approved',
  $$select count(*) from public.products
    where id = (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product')
      and product_status = 'active'
      and approval_status = 'approved'
      and approved_by_profile_id = (select fixture_id from product_approval_fixture_ids where fixture_key = 'dev_product_approval_admin')
      and approved_at is not null$$,
  1
);
select pg_temp.product_approval_expect_allowed(
  'admin can reject pending supplier product',
  $$with changed as (
    select public.review_supplier_product(
      (select fixture_id from product_approval_fixture_ids where fixture_key = 'reject_product'),
      'rejected',
      'rejected in development product approval boundary test'
    ) as id
  ) select count(*) from changed$$
);
select pg_temp.product_approval_expect_count(
  'rejected product becomes rejected without approval actor',
  $$select count(*) from public.products
    where id = (select fixture_id from product_approval_fixture_ids where fixture_key = 'reject_product')
      and product_status = 'rejected'
      and approval_status = 'rejected'
      and approved_by_profile_id is null
      and approved_at is null
      and rejection_reason = 'rejected in development product approval boundary test'$$,
  1
);
select pg_temp.product_approval_expect_count(
  'product review writes audit logs',
  $$select count(*) from public.audit_logs
    where action = 'review_supplier_product'
      and target_entity_type = 'products'
      and target_entity_id in (
        (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product'),
        (select fixture_id from product_approval_fixture_ids where fixture_key = 'reject_product')
      )$$,
  2
);
select pg_temp.product_approval_expect_blocked_or_zero(
  'admin cannot review already reviewed product again',
  $$with changed as (
    select public.review_supplier_product(
      (select fixture_id from product_approval_fixture_ids where fixture_key = 'approve_product'),
      'rejected',
      'second review should be blocked'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_product_approval_supplier_owner"}';
select pg_temp.product_approval_expect_blocked_or_zero(
  'supplier owner cannot directly update approval status',
  $$with changed as (
    update public.products
    set approval_status = 'approved',
        product_status = 'active'
    where id = (select fixture_id from product_approval_fixture_ids where fixture_key = 'reject_product')
    returning 1
  ) select count(*) from changed$$
);

reset role;
select * from product_approval_test_results order by test_name;

do $$
declare
  v_failures integer;
  v_failed_details text;
begin
  select count(*)
  into v_failures
  from product_approval_test_results
  where passed = false;

  if v_failures > 0 then
    select string_agg(test_name || ': ' || coalesce(details, ''), E'\n')
    into v_failed_details
    from product_approval_test_results
    where passed = false;

    raise exception 'Product approval RPC boundary tests failed: % failure(s): %', v_failures, v_failed_details;
  end if;
end;
$$;

rollback;
