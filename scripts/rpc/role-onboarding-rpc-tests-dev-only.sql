-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Runnable pass/fail tests for role onboarding request RPCs in the Risellar development Supabase project.
-- This script uses fake fixture data only and rolls back all changes.
-- Do not use real users, emails, phone numbers, business data, production data, or secrets.
-- Do not weaken RLS policies or RPC role checks to make this script pass.

begin;

create temp table role_onboarding_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select on role_onboarding_fixture_ids to public;
grant select, insert on role_onboarding_fixture_ids to authenticated;

create temp table role_onboarding_test_results (
  test_name text primary key,
  passed boolean not null,
  details text not null default ''
) on commit drop;

grant select, insert, update on role_onboarding_test_results to public;

create or replace function pg_temp.role_onboarding_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default ''
)
returns void
language plpgsql
as $$
begin
  insert into role_onboarding_test_results (test_name, passed, details)
  values (p_test_name, p_passed, coalesce(p_details, ''))
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.role_onboarding_expect_count(
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
  perform pg_temp.role_onboarding_record_result(
    p_test_name,
    v_observed_count = p_expected_count,
    'expected=' || p_expected_count || ', observed=' || coalesce(v_observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.role_onboarding_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.role_onboarding_expect_allowed(
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
  perform pg_temp.role_onboarding_record_result(
    p_test_name,
    coalesce(v_affected_count, 0) > 0,
    'expected allowed with affected rows, observed=' || coalesce(v_affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.role_onboarding_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.role_onboarding_expect_blocked_or_zero(
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
  perform pg_temp.role_onboarding_record_result(
    p_test_name,
    coalesce(v_affected_count, 0) = 0,
    'expected blocked or 0 affected, observed=' || coalesce(v_affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.role_onboarding_record_result(p_test_name, true, 'blocked with ' || sqlstate || ': ' || sqlerrm);
end;
$$;

grant execute on function pg_temp.role_onboarding_record_result(text, boolean, text) to public;
grant execute on function pg_temp.role_onboarding_expect_count(text, text, integer) to public;
grant execute on function pg_temp.role_onboarding_expect_allowed(text, text) to public;
grant execute on function pg_temp.role_onboarding_expect_blocked_or_zero(text, text) to public;

insert into public.profiles (clerk_user_id, email, full_name, primary_role)
values
  ('dev_role_onboarding_customer_a', 'dev-role-onboarding-customer-a@example.invalid', 'Dev Role Onboarding Customer A', 'customer'),
  ('dev_role_onboarding_customer_b', 'dev-role-onboarding-customer-b@example.invalid', 'Dev Role Onboarding Customer B', 'customer'),
  ('dev_role_onboarding_customer_c', 'dev-role-onboarding-customer-c@example.invalid', 'Dev Role Onboarding Customer C', 'customer'),
  ('dev_role_onboarding_reseller_a', 'dev-role-onboarding-reseller-a@example.invalid', 'Dev Role Onboarding Reseller A', 'reseller'),
  ('dev_role_onboarding_supplier_owner_a', 'dev-role-onboarding-supplier-owner-a@example.invalid', 'Dev Role Onboarding Supplier Owner A', 'supplier_owner'),
  ('dev_role_onboarding_inventory_manager_a', 'dev-role-onboarding-inventory-manager-a@example.invalid', 'Dev Role Onboarding Inventory Manager A', 'supplier_inventory_manager'),
  ('dev_role_onboarding_admin_operator', 'dev-role-onboarding-admin@example.invalid', 'Dev Role Onboarding Admin Operator', 'customer'),
  ('dev_role_onboarding_super_admin_operator', 'dev-role-onboarding-super-admin@example.invalid', 'Dev Role Onboarding Super Admin Operator', 'customer')
returning clerk_user_id, id;

insert into role_onboarding_fixture_ids (fixture_key, fixture_id)
select clerk_user_id, id
from public.profiles
where clerk_user_id in (
  'dev_role_onboarding_customer_a',
  'dev_role_onboarding_customer_b',
  'dev_role_onboarding_customer_c',
  'dev_role_onboarding_reseller_a',
  'dev_role_onboarding_supplier_owner_a',
  'dev_role_onboarding_inventory_manager_a',
  'dev_role_onboarding_admin_operator',
  'dev_role_onboarding_super_admin_operator'
);

insert into public.admin_staff (profile_id, admin_role, permissions, staff_status)
values
  ((select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_admin_operator'), 'admin', '{}'::jsonb, 'active'),
  ((select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_super_admin_operator'), 'super_admin', '{}'::jsonb, 'active');

reset role;
set local role anon;
set local "request.jwt.claims" = '{}';
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'anonymous cannot submit onboarding request',
  $$with changed as (
    select public.submit_role_onboarding_request('reseller', 'Fake Dev Shop', null, null) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_count(
  'anonymous cannot read onboarding requests',
  $$select count(*) from public.role_onboarding_requests$$,
  0
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_role_onboarding_customer_a"}';
select pg_temp.role_onboarding_expect_allowed(
  'customer can submit reseller onboarding request',
  $$with changed as (
    select public.submit_role_onboarding_request('reseller', 'Fake Dev Reseller Shop', '0000000000', 'Fake development reseller request') as id
  ) select count(*) from changed$$
);
insert into role_onboarding_fixture_ids (fixture_key, fixture_id)
select 'customer_a_reseller_request', id
from public.role_onboarding_requests
where profile_id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_a')
  and requested_role = 'reseller'
  and status = 'pending';
select pg_temp.role_onboarding_expect_count(
  'customer submit writes pending request',
  $$select count(*) from public.role_onboarding_requests where id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request') and status = 'pending'$$,
  1
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'customer duplicate pending request is blocked',
  $$with changed as (
    select public.submit_role_onboarding_request('reseller', 'Fake Dev Duplicate', null, null) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'customer cannot request admin role',
  $$with changed as (
    select public.submit_role_onboarding_request('admin', 'Fake Dev Admin', null, null) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'customer cannot request supplier inventory manager role',
  $$with changed as (
    select public.submit_role_onboarding_request('supplier_inventory_manager', 'Fake Dev Inventory Manager', null, null) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'customer cannot update own request status directly',
  $$with changed as (
    update public.role_onboarding_requests
    set status = 'approved'
    where id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request')
    returning 1
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'customer cannot delete own request directly',
  $$with changed as (
    delete from public.role_onboarding_requests
    where id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request')
    returning 1
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_count(
  'customer cannot read audit logs directly',
  $$select count(*) from public.audit_logs$$,
  0
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'customer cannot review own request',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request'),
      'approved',
      'blocked self review'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_role_onboarding_reseller_a"}';
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'reseller cannot submit onboarding request',
  $$with changed as (
    select public.submit_role_onboarding_request('supplier_owner', 'Fake Dev Supplier', null, null) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'reseller cannot review onboarding request',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request'),
      'approved',
      'blocked reseller review'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_role_onboarding_supplier_owner_a"}';
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'supplier owner cannot review onboarding request',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request'),
      'approved',
      'blocked supplier review'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_role_onboarding_inventory_manager_a"}';
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'supplier inventory manager cannot review onboarding request',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request'),
      'approved',
      'blocked inventory manager review'
    ) as id
  ) select count(*) from changed$$
);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_role_onboarding_customer_b"}';
select pg_temp.role_onboarding_expect_allowed(
  'customer can submit supplier owner onboarding request',
  $$with changed as (
    select public.submit_role_onboarding_request('supplier_owner', 'Fake Dev Supplier Ltd', '0000000001', 'Fake development supplier request') as id
  ) select count(*) from changed$$
);
insert into role_onboarding_fixture_ids (fixture_key, fixture_id)
select 'customer_b_supplier_request', id
from public.role_onboarding_requests
where profile_id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_b')
  and requested_role = 'supplier_owner'
  and status = 'pending';

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_role_onboarding_customer_c"}';
select pg_temp.role_onboarding_expect_allowed(
  'customer can submit second reseller onboarding request for rejection path',
  $$with changed as (
    select public.submit_role_onboarding_request('reseller', 'Fake Dev Rejected Shop', null, 'Fake development rejection path') as id
  ) select count(*) from changed$$
);
insert into role_onboarding_fixture_ids (fixture_key, fixture_id)
select 'customer_c_reseller_request', id
from public.role_onboarding_requests
where profile_id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_c')
  and requested_role = 'reseller'
  and status = 'pending';

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_role_onboarding_admin_operator"}';
select pg_temp.role_onboarding_expect_count(
  'admin can read review queue',
  $$select count(*) from public.role_onboarding_requests where status = 'pending'$$,
  3
);
select pg_temp.role_onboarding_expect_allowed(
  'admin can approve reseller onboarding request',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request'),
      'approved',
      'Fake development approval'
    ) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_count(
  'approved reseller request promotes profile to reseller',
  $$select count(*) from public.profiles where id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_a') and primary_role = 'reseller'$$,
  1
);
select pg_temp.role_onboarding_expect_count(
  'approved reseller request creates reseller foundation',
  $$select count(*) from public.resellers where profile_id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_a') and approval_status = 'approved'$$,
  1
);
select pg_temp.role_onboarding_expect_count(
  'reseller approval writes audit row',
  $$select count(*) from public.audit_logs where action = 'review_role_onboarding_request' and target_entity_id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_a_reseller_request')$$,
  1
);
select pg_temp.role_onboarding_expect_allowed(
  'admin can approve supplier owner onboarding request',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_b_supplier_request'),
      'approved',
      'Fake development supplier approval'
    ) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_count(
  'approved supplier request promotes profile to supplier owner',
  $$select count(*) from public.profiles where id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_b') and primary_role = 'supplier_owner'$$,
  1
);
select pg_temp.role_onboarding_expect_count(
  'approved supplier request creates supplier foundation',
  $$select count(*) from public.suppliers where owner_profile_id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_b') and supplier_status = 'pending' and verification_status = 'pending_review'$$,
  1
);
select pg_temp.role_onboarding_expect_allowed(
  'admin can reject reseller onboarding request',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_c_reseller_request'),
      'rejected',
      'Fake development rejection'
    ) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_count(
  'rejected request does not promote customer profile',
  $$select count(*) from public.profiles where id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'dev_role_onboarding_customer_c') and primary_role = 'customer'$$,
  1
);
select pg_temp.role_onboarding_expect_count(
  'rejection writes audit row',
  $$select count(*) from public.audit_logs where action = 'review_role_onboarding_request' and target_entity_id = (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_c_reseller_request')$$,
  1
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'admin cannot review already reviewed request twice',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_c_reseller_request'),
      'approved',
      'blocked second review'
    ) as id
  ) select count(*) from changed$$
);
select pg_temp.role_onboarding_expect_blocked_or_zero(
  'admin review rejects unsupported decision values',
  $$with changed as (
    select public.review_role_onboarding_request(
      (select fixture_id from role_onboarding_fixture_ids where fixture_key = 'customer_b_supplier_request'),
      'cancelled',
      'blocked unsupported decision'
    ) as id
  ) select count(*) from changed$$
);

reset role;
select test_name, passed, details
from role_onboarding_test_results
order by test_name;

do $$
declare
  v_failure_count integer;
  v_failed_details text;
begin
  select count(*)
  into v_failure_count
  from role_onboarding_test_results
  where not passed;

  select string_agg(test_name || ' - ' || coalesce(nullif(details, ''), '<no details>'), E'\n' order by test_name)
  into v_failed_details
  from role_onboarding_test_results
  where not passed;

  if v_failure_count > 0 then
    raise exception 'Role onboarding RPC boundary tests failed: % failure(s): %', v_failure_count, v_failed_details;
  end if;
end $$;

rollback;

-- Rollback is intentional. This script must not leave fixture data behind.
