-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Verifies customer profile/contact and delivery address RPC boundaries in the Risellar development Supabase project.
-- This script uses fake/dev-only fixture rows and rolls back all fixture data.
-- Do not use real users, emails, phone numbers, addresses, production data, or secrets.

begin;

create temp table customer_phase_a_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on customer_phase_a_test_results to public;
grant select, insert, update on customer_phase_a_test_results to authenticated;

create temp table customer_phase_a_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on customer_phase_a_fixture_ids to public;
grant select, insert, update on customer_phase_a_fixture_ids to authenticated;

create or replace function pg_temp.customer_phase_a_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into customer_phase_a_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.customer_phase_a_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.customer_phase_a_set_anon_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.customer_phase_a_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.customer_phase_a_expect_count(
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
  perform pg_temp.customer_phase_a_record_result(
    p_test_name,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.customer_phase_a_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.customer_phase_a_expect_allowed(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_affected_count integer;
begin
  execute p_sql into v_affected_count;
  perform pg_temp.customer_phase_a_record_result(
    p_test_name,
    coalesce(v_affected_count, 0) > 0,
    'expected affected rows > 0, observed=' || coalesce(v_affected_count::text, 'null')
  );
exception when others then
  perform pg_temp.customer_phase_a_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.customer_phase_a_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.customer_phase_a_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.customer_phase_a_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

grant execute on function pg_temp.customer_phase_a_record_result(text, boolean, text) to public;
grant execute on function pg_temp.customer_phase_a_set_context(text) to public;
grant execute on function pg_temp.customer_phase_a_set_anon_context() to public;
grant execute on function pg_temp.customer_phase_a_reset_context() to public;
grant execute on function pg_temp.customer_phase_a_expect_count(text, text, integer) to public;
grant execute on function pg_temp.customer_phase_a_expect_allowed(text, text) to public;
grant execute on function pg_temp.customer_phase_a_expect_blocked(text, text) to public;

do $$
declare
  v_customer_a_profile_id uuid := gen_random_uuid();
  v_customer_b_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_address_a_id uuid;
  v_address_a_active_id uuid;
  v_address_b_id uuid;
begin
  perform pg_temp.customer_phase_a_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_customer_phase_a_customer_a', 'dev-customer-phase-a-customer-a@example.invalid', 'Dev Customer Phase A Customer A', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_customer_phase_a_customer_b', 'dev-customer-phase-a-customer-b@example.invalid', 'Dev Customer Phase A Customer B', 'customer', 'active'),
    (v_reseller_profile_id, 'dev_customer_phase_a_reseller', 'dev-customer-phase-a-reseller@example.invalid', 'Dev Customer Phase A Reseller', 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_customer_phase_a_supplier', 'dev-customer-phase-a-supplier@example.invalid', 'Dev Customer Phase A Supplier', 'supplier_owner', 'active'),
    (v_admin_profile_id, 'dev_customer_phase_a_admin', 'dev-customer-phase-a-admin@example.invalid', 'Dev Customer Phase A Admin', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');

  insert into customer_phase_a_fixture_ids(fixture_key, fixture_id)
  values
    ('customer_a_profile', v_customer_a_profile_id),
    ('customer_b_profile', v_customer_b_profile_id),
    ('reseller_profile', v_reseller_profile_id),
    ('supplier_profile', v_supplier_profile_id),
    ('admin_profile', v_admin_profile_id);

  perform pg_temp.customer_phase_a_set_anon_context();
  perform pg_temp.customer_phase_a_expect_blocked(
    'anonymous cannot upsert customer contact',
    $sql$select count(*) from public.upsert_customer_contact('Anonymous Dev User', '0200000000', null, null)$sql$
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'anonymous cannot create delivery address',
    $sql$select count(*) from public.create_customer_delivery_address('Home', 'Anonymous Dev User', '0200000000', 'Greater Accra', 'Accra', 'East Legon', 'Fake dev street', null, true)$sql$
  );

  perform pg_temp.customer_phase_a_reset_context();
  perform pg_temp.customer_phase_a_set_context('dev_customer_phase_a_customer_a');
  perform pg_temp.customer_phase_a_expect_allowed(
    'customer can upsert own contact',
    $sql$select count(*) from public.upsert_customer_contact('Dev Customer A Updated', '0200000001', '0200000002', null)$sql$
  );
  perform pg_temp.customer_phase_a_expect_count(
    'customer contact update preserves customer role',
    $sql$select count(*) from public.profiles where clerk_user_id = 'dev_customer_phase_a_customer_a' and primary_role = 'customer' and full_name = 'Dev Customer A Updated' and phone = '0200000001' and whatsapp = '0200000002'$sql$,
    1
  );
  perform pg_temp.customer_phase_a_expect_count(
    'customer contact upsert creates customer foundation',
    $sql$select count(*) from public.customers c join public.profiles p on p.id = c.profile_id where p.clerk_user_id = 'dev_customer_phase_a_customer_a' and c.customer_status = 'active'$sql$,
    1
  );
  perform pg_temp.customer_phase_a_expect_allowed(
    'customer can create own delivery address',
    $sql$select count(*) from public.create_customer_delivery_address('Home', 'Dev Customer A Updated', '0200000001', 'Greater Accra', 'Accra', 'East Legon', 'Fake dev street', 'Fake dev landmark', true)$sql$
  );

  select id
  into v_address_a_id
  from public.customer_delivery_addresses
  where customer_id = (select id from public.customers where profile_id = v_customer_a_profile_id)
    and deleted_at is null;

  insert into customer_phase_a_fixture_ids(fixture_key, fixture_id)
  values ('customer_a_address', v_address_a_id);

  perform pg_temp.customer_phase_a_expect_count(
    'customer can read own delivery address through RPC',
    $sql$select count(*) from public.get_customer_delivery_addresses() where id = (select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_address')$sql$,
    1
  );
  perform pg_temp.customer_phase_a_expect_count(
    'default address is marked default',
    $sql$select count(*) from public.customer_delivery_addresses where id = (select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_address') and is_default is true$sql$,
    1
  );
  perform pg_temp.customer_phase_a_expect_allowed(
    'customer can update own address',
    $sql$select count(*) from public.update_customer_delivery_address((select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_address'), 'Campus', 'Dev Customer A Updated', '0200000003', 'Greater Accra', 'Accra', 'Legon', 'Fake dev campus street', 'Fake dev campus landmark', true)$sql$
  );
  perform pg_temp.customer_phase_a_expect_count(
    'customer own address update persisted',
    $sql$select count(*) from public.customer_delivery_addresses where id = (select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_address') and label = 'Campus' and area = 'Legon' and phone = '0200000003' and is_default is true$sql$,
    1
  );
  perform pg_temp.customer_phase_a_expect_allowed(
    'customer can create second active address',
    $sql$select count(*) from public.create_customer_delivery_address('Office', 'Dev Customer A Updated', '0200000004', 'Greater Accra', 'Accra', 'Airport', 'Fake dev office street', null, false)$sql$
  );

  select id
  into v_address_a_active_id
  from public.customer_delivery_addresses
  where customer_id = (select id from public.customers where profile_id = v_customer_a_profile_id)
    and label = 'Office'
    and deleted_at is null;

  insert into customer_phase_a_fixture_ids(fixture_key, fixture_id)
  values ('customer_a_active_address', v_address_a_active_id);

  perform pg_temp.customer_phase_a_expect_count(
    'second active address is visible to owner',
    $sql$select count(*) from public.get_customer_delivery_addresses() where id = (select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_active_address')$sql$,
    1
  );
  perform pg_temp.customer_phase_a_expect_allowed(
    'customer can archive own address',
    $sql$select count(*) from public.archive_customer_delivery_address((select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_address'))$sql$
  );
  perform pg_temp.customer_phase_a_expect_count(
    'archived address is soft deleted',
    $sql$select count(*) from public.customer_delivery_addresses where id = (select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_address') and deleted_at is not null$sql$,
    1
  );
  perform pg_temp.customer_phase_a_expect_count(
    'archived address hidden from customer RPC',
    $sql$select count(*) from public.get_customer_delivery_addresses() where id = (select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_address')$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'customer cannot create address with missing phone',
    $sql$select count(*) from public.create_customer_delivery_address('Bad Address', 'Dev Customer A Updated', '', 'Greater Accra', 'Accra', 'East Legon', 'Fake dev street', null, false)$sql$
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'customer cannot create address with missing recipient',
    $sql$select count(*) from public.create_customer_delivery_address('Bad Address', '', '0200000001', 'Greater Accra', 'Accra', 'East Legon', 'Fake dev street', null, false)$sql$
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'customer cannot create address with missing city area or street',
    $sql$select count(*) from public.create_customer_delivery_address('Bad Address', 'Dev Customer A Updated', '0200000001', 'Greater Accra', '', '', '', null, false)$sql$
  );

  perform pg_temp.customer_phase_a_reset_context();
  perform pg_temp.customer_phase_a_set_context('dev_customer_phase_a_customer_b');
  perform pg_temp.customer_phase_a_expect_allowed(
    'second customer can create own contact',
    $sql$select count(*) from public.upsert_customer_contact('Dev Customer B', '0200000010', null, null)$sql$
  );
  perform pg_temp.customer_phase_a_expect_allowed(
    'second customer can create own delivery address',
    $sql$select count(*) from public.create_customer_delivery_address('Home', 'Dev Customer B', '0200000010', 'Ashanti', 'Kumasi', 'Adum', 'Fake dev Adum street', null, true)$sql$
  );

  select id
  into v_address_b_id
  from public.customer_delivery_addresses
  where customer_id = (select id from public.customers where profile_id = v_customer_b_profile_id)
    and deleted_at is null;

  insert into customer_phase_a_fixture_ids(fixture_key, fixture_id)
  values ('customer_b_address', v_address_b_id);

  perform pg_temp.customer_phase_a_expect_count(
    'customer B cannot read customer A active address',
    $sql$select count(*) from public.get_customer_delivery_addresses() where id = (select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_active_address')$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'customer B cannot update customer A active address',
    $sql$select count(*) from public.update_customer_delivery_address((select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_active_address'), 'Blocked', 'Dev Customer B', '0200000010', 'Ashanti', 'Kumasi', 'Adum', 'Fake blocked street', null, false)$sql$
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'customer B cannot archive customer A active address',
    $sql$select count(*) from public.archive_customer_delivery_address((select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_a_active_address'))$sql$
  );

  perform pg_temp.customer_phase_a_set_context('dev_customer_phase_a_reseller');
  perform pg_temp.customer_phase_a_expect_allowed(
    'reseller can use customer contact RPC only for own customer foundation',
    $sql$select count(*) from public.upsert_customer_contact('Dev Reseller As Customer', '0200000020', null, null)$sql$
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'reseller cannot update another customer address',
    $sql$select count(*) from public.update_customer_delivery_address((select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_b_address'), 'Blocked', 'Dev Reseller', '0200000020', 'Greater Accra', 'Accra', 'Osu', 'Fake blocked street', null, false)$sql$
  );

  perform pg_temp.customer_phase_a_set_context('dev_customer_phase_a_supplier');
  perform pg_temp.customer_phase_a_expect_allowed(
    'supplier can use customer contact RPC only for own customer foundation',
    $sql$select count(*) from public.upsert_customer_contact('Dev Supplier As Customer', '0200000030', null, null)$sql$
  );
  perform pg_temp.customer_phase_a_expect_blocked(
    'supplier cannot archive another customer address',
    $sql$select count(*) from public.archive_customer_delivery_address((select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_b_address'))$sql$
  );

  perform pg_temp.customer_phase_a_set_context('dev_customer_phase_a_admin');
  perform pg_temp.customer_phase_a_expect_blocked(
    'admin role does not bypass address ownership through customer RPC',
    $sql$select count(*) from public.update_customer_delivery_address((select fixture_id from customer_phase_a_fixture_ids where fixture_key = 'customer_b_address'), 'Blocked Admin', 'Dev Admin', '0200000040', 'Greater Accra', 'Accra', 'Osu', 'Fake admin blocked street', null, false)$sql$
  );

  perform pg_temp.customer_phase_a_expect_count(
    'no order rows are created',
    $sql$select count(*) from public.orders$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_count(
    'no order item rows are created',
    $sql$select count(*) from public.order_items$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_count(
    'no stock reservation rows are created',
    $sql$select count(*) from public.stock_reservations$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_count(
    'no delivery quote rows are created',
    $sql$select count(*) from public.delivery_quotes$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_count(
    'no commission rows are created',
    $sql$select count(*) from public.commissions$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_count(
    'no settlement rows are created',
    $sql$select count(*) from public.settlements$sql$,
    0
  );
  perform pg_temp.customer_phase_a_expect_count(
    'no withdrawal rows are created',
    $sql$select count(*) from public.withdrawals$sql$,
    0
  );
end;
$$;

reset role;

select test_name, passed, details
from customer_phase_a_test_results
order by test_name;

do $$
declare
  v_failure_count integer;
  v_failure_details text;
begin
  select count(*)
  into v_failure_count
  from customer_phase_a_test_results
  where passed is false;

  if v_failure_count > 0 then
    select string_agg(test_name || ': ' || coalesce(details, ''), E'\n' order by test_name)
    into v_failure_details
    from customer_phase_a_test_results
    where passed is false;

    raise exception 'Customer Phase A profile/address RPC tests failed: % failure(s): %', v_failure_count, v_failure_details;
  end if;

  raise notice 'Customer Phase A profile/address RPC tests passed.';
end;
$$;

rollback;

-- Rollback is intentional. This script must not leave fixture data behind.
