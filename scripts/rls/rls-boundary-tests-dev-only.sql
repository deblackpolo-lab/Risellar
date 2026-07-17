-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Runnable pass/fail RLS boundary tests for the Risellar development Supabase project.
-- This script uses fake fixture data only and rolls back all changes.
-- Do not use real users, emails, phone numbers, addresses, payout data, production data, or secrets.
-- Do not weaken RLS policies to make this script pass.

begin;

create temp table rls_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

create temp table rls_test_results (
  test_name text primary key,
  passed boolean not null,
  details text not null default ''
) on commit drop;

grant select, insert, update on rls_test_results to public;

create or replace function pg_temp.rls_record_result(
  test_name text,
  passed boolean,
  details text default ''
)
returns void
language plpgsql
as $$
begin
  insert into rls_test_results (test_name, passed, details)
  values (test_name, passed, coalesce(details, ''))
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.rls_expect_count(
  test_name text,
  sql_text text,
  expected_count integer
)
returns void
language plpgsql
as $$
declare
  observed_count integer;
begin
  execute sql_text into observed_count;
  perform pg_temp.rls_record_result(
    test_name,
    observed_count = expected_count,
    'expected=' || expected_count || ', observed=' || coalesce(observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rls_record_result(test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.rls_expect_positive(
  test_name text,
  sql_text text
)
returns void
language plpgsql
as $$
declare
  observed_count integer;
begin
  execute sql_text into observed_count;
  perform pg_temp.rls_record_result(
    test_name,
    observed_count > 0,
    'expected>0, observed=' || coalesce(observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rls_record_result(test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.rls_expect_blocked_or_zero(
  test_name text,
  sql_text text
)
returns void
language plpgsql
as $$
declare
  affected_count integer;
begin
  execute sql_text into affected_count;
  perform pg_temp.rls_record_result(
    test_name,
    coalesce(affected_count, 0) = 0,
    'expected blocked or 0 affected, observed=' || coalesce(affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rls_record_result(test_name, true, 'blocked with ' || sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.rls_expect_allowed(
  test_name text,
  sql_text text
)
returns void
language plpgsql
as $$
declare
  affected_count integer;
begin
  execute sql_text into affected_count;
  perform pg_temp.rls_record_result(
    test_name,
    coalesce(affected_count, 0) > 0,
    'expected allowed with affected rows, observed=' || coalesce(affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rls_record_result(test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

grant execute on function pg_temp.rls_record_result(text, boolean, text) to public;
grant execute on function pg_temp.rls_expect_count(text, text, integer) to public;
grant execute on function pg_temp.rls_expect_positive(text, text) to public;
grant execute on function pg_temp.rls_expect_blocked_or_zero(text, text) to public;
grant execute on function pg_temp.rls_expect_allowed(text, text) to public;

insert into public.profiles (clerk_user_id, email, full_name, primary_role)
values
  ('dev_clerk_customer_a', 'customer-a@example.invalid', 'Dev Customer A', 'customer'),
  ('dev_clerk_customer_b', 'customer-b@example.invalid', 'Dev Customer B', 'customer'),
  ('dev_clerk_reseller_a', 'reseller-a@example.invalid', 'Dev Reseller A', 'reseller'),
  ('dev_clerk_reseller_b', 'reseller-b@example.invalid', 'Dev Reseller B', 'reseller'),
  ('dev_clerk_supplier_owner_a', 'supplier-owner-a@example.invalid', 'Dev Supplier Owner A', 'supplier_owner'),
  ('dev_clerk_supplier_owner_b', 'supplier-owner-b@example.invalid', 'Dev Supplier Owner B', 'supplier_owner'),
  ('dev_clerk_supplier_a_inventory_manager', 'supplier-a-inventory@example.invalid', 'Dev Supplier A Inventory Manager', 'supplier_inventory_manager'),
  ('dev_clerk_support_operator', 'support@example.invalid', 'Dev Support Operator', 'customer'),
  ('dev_clerk_finance_operator', 'finance@example.invalid', 'Dev Finance Operator', 'customer'),
  ('dev_clerk_admin', 'admin@example.invalid', 'Dev Admin', 'customer')
returning clerk_user_id, id;

insert into rls_fixture_ids (fixture_key, fixture_id)
select clerk_user_id, id
from public.profiles
where clerk_user_id in (
  'dev_clerk_customer_a',
  'dev_clerk_customer_b',
  'dev_clerk_reseller_a',
  'dev_clerk_reseller_b',
  'dev_clerk_supplier_owner_a',
  'dev_clerk_supplier_owner_b',
  'dev_clerk_supplier_a_inventory_manager',
  'dev_clerk_support_operator',
  'dev_clerk_finance_operator',
  'dev_clerk_admin'
);

insert into public.admin_staff (profile_id, admin_role, permissions, staff_status)
values
  ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_support_operator'), 'support_staff', '{}'::jsonb, 'active'),
  ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_finance_operator'), 'finance_staff', '{}'::jsonb, 'active'),
  ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_admin'), 'admin', '{}'::jsonb, 'active');

with inserted as (
  insert into public.customers (profile_id, customer_status)
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_customer_a'), 'active'),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_customer_b'), 'active')
  returning id, profile_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when profile_id = (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_customer_a') then 'customer_a'
    else 'customer_b'
  end,
  id
from inserted;

with inserted as (
  insert into public.resellers (profile_id, reseller_type, approval_status, payout_status)
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_reseller_a'), 'dev_social_reseller_a', 'approved', 'active'),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_reseller_b'), 'dev_social_reseller_b', 'approved', 'active')
  returning id, profile_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when profile_id = (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_reseller_a') then 'reseller_a'
    else 'reseller_b'
  end,
  id
from inserted;

with inserted as (
  insert into public.reseller_shops (reseller_id, shop_slug, display_name, shop_status, visibility)
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a'), 'dev-rls-shop-a', 'Dev RLS Shop A', 'active', 'public'),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'reseller_b'), 'dev-rls-shop-b', 'Dev RLS Shop B', 'active', 'public')
  returning id, reseller_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when reseller_id = (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a') then 'shop_a'
    else 'shop_b'
  end,
  id
from inserted;

with inserted as (
  insert into public.suppliers (owner_profile_id, business_name, public_display_name, supplier_status, verification_status)
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_supplier_owner_a'), 'Dev Supplier A', 'Dev Supplier A Public', 'active', 'approved'),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_supplier_owner_b'), 'Dev Supplier B', 'Dev Supplier B Public', 'active', 'approved')
  returning id, owner_profile_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when owner_profile_id = (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_supplier_owner_a') then 'supplier_a'
    else 'supplier_b'
  end,
  id
from inserted;

insert into public.supplier_team_members (supplier_id, profile_id, supplier_role, permissions, staff_status)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a'),
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_supplier_a_inventory_manager'),
  'supplier_inventory_manager',
  '{"stock.adjust": true, "products.update": false}'::jsonb,
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
    ((select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a'), 'Dev RLS Product A', 'dev-rls-product-a', 'active', 'approved', 10000, 1000, 2500),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'supplier_b'), 'Dev RLS Product B', 'dev-rls-product-b', 'active', 'approved', 20000, 2000, 5000)
  returning id, supplier_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when supplier_id = (select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a') then 'product_a'
    else 'product_b'
  end,
  id
from inserted;

with inserted as (
  insert into public.product_variants (product_id, sku, variant_name, total_stock_quantity, low_stock_threshold, variant_status)
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'product_a'), 'DEV-RLS-A-ONE', 'Dev Variant A', 20, 3, 'active'),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'product_b'), 'DEV-RLS-B-ONE', 'Dev Variant B', 20, 3, 'active')
  returning id, product_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when product_id = (select fixture_id from rls_fixture_ids where fixture_key = 'product_a') then 'variant_a'
    else 'variant_b'
  end,
  id
from inserted;

insert into public.product_images (product_id, variant_id, storage_path, alt_text, image_status, is_primary)
values
  ((select fixture_id from rls_fixture_ids where fixture_key = 'product_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'variant_a'), 'dev-only/products/rls-product-a.jpg', 'Fake development product A image', 'active', true),
  ((select fixture_id from rls_fixture_ids where fixture_key = 'product_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'variant_b'), 'dev-only/products/rls-product-b.jpg', 'Fake development product B image', 'active', true);

with inserted as (
  insert into public.reseller_products (
    reseller_id,
    shop_id,
    product_id,
    variant_id,
    listing_status,
    reseller_margin_amount,
    customer_product_price_amount,
    share_slug
  )
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'shop_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'product_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'variant_a'), 'active', 1500, 12500, 'dev-rls-share-a'),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'reseller_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'shop_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'product_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'variant_b'), 'active', 2500, 24500, 'dev-rls-share-b')
  returning id, reseller_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when reseller_id = (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a') then 'reseller_product_a'
    else 'reseller_product_b'
  end,
  id
from inserted;

with inserted as (
  insert into public.orders (
    order_number,
    customer_id,
    reseller_id,
    shop_id,
    order_status,
    subtotal_product_amount,
    delivery_estimate_min_amount,
    delivery_estimate_max_amount,
    total_payable_amount,
    delivery_address_snapshot,
    customer_contact_snapshot
  )
  values
    ('RLS-DEV-ORDER-A', (select fixture_id from rls_fixture_ids where fixture_key = 'customer_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'shop_a'), 'customer_confirmed', 12500, 1500, 2500, 14000, '{"city":"Dev City A"}'::jsonb, '{"phone":"0000000000"}'::jsonb),
    ('RLS-DEV-ORDER-B', (select fixture_id from rls_fixture_ids where fixture_key = 'customer_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'shop_b'), 'customer_confirmed', 24500, 1500, 2500, 26000, '{"city":"Dev City B"}'::jsonb, '{"phone":"0000000001"}'::jsonb)
  returning id, order_number
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case when order_number = 'RLS-DEV-ORDER-A' then 'order_a' else 'order_b' end,
  id
from inserted;

with inserted as (
  insert into public.order_items (
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
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'order_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'product_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'variant_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_product_a'), 1, 10000, 1000, 1500, 11000, 12500, 12500, 10000, 1500),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'order_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'supplier_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'product_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'variant_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_product_b'), 1, 20000, 2000, 2500, 22000, 24500, 24500, 20000, 2500)
  returning id, order_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when order_id = (select fixture_id from rls_fixture_ids where fixture_key = 'order_a') then 'order_item_a'
    else 'order_item_b'
  end,
  id
from inserted;

insert into public.stock_reservations (
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
values (
  'RLS-DEV-RESERVATION-A',
  (select fixture_id from rls_fixture_ids where fixture_key = 'customer_a'),
  (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a'),
  (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_product_a'),
  (select fixture_id from rls_fixture_ids where fixture_key = 'product_a'),
  (select fixture_id from rls_fixture_ids where fixture_key = 'variant_a'),
  (select fixture_id from rls_fixture_ids where fixture_key = 'order_a'),
  1,
  'reserved',
  now() + interval '1 hour'
);

insert into public.delivery_quotes (order_id, delivery_method, quoted_amount, quote_status)
values ((select fixture_id from rls_fixture_ids where fixture_key = 'order_a'), 'dev courier', 1800, 'quoted');

with inserted as (
  insert into public.settlements (supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount, due_at)
  values
    ((select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_a'), 'due', 10000, 0, 10000, now() + interval '7 days'),
    ((select fixture_id from rls_fixture_ids where fixture_key = 'supplier_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_b'), 'due', 20000, 0, 20000, now() + interval '7 days')
  returning id, supplier_id
)
insert into rls_fixture_ids (fixture_key, fixture_id)
select
  case
    when supplier_id = (select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a') then 'settlement_a'
    else 'settlement_b'
  end,
  id
from inserted;

insert into public.commissions (reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount)
values
  ((select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_item_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'settlement_a'), 'available', 1500),
  ((select fixture_id from rls_fixture_ids where fixture_key = 'reseller_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_item_b'), (select fixture_id from rls_fixture_ids where fixture_key = 'settlement_b'), 'available', 2500);

insert into public.withdrawals (reseller_id, requested_amount, approved_amount, withdrawal_status, requested_by_profile_id, account_name, account_number_masked)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'reseller_a'),
  1000,
  null,
  'requested',
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_reseller_a'),
  'Dev Account',
  '****0000'
);

insert into public.disputes (opened_by_profile_id, order_id, dispute_type, dispute_status, priority)
values ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_customer_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_a'), 'dev_delivery_delay', 'open', 'normal');

insert into public.returns (order_id, order_item_id, requested_by_profile_id, return_status, reason)
values ((select fixture_id from rls_fixture_ids where fixture_key = 'order_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'order_item_a'), (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_customer_a'), 'requested', 'Fake development return reason');

insert into public.notifications (recipient_profile_id, channel, notification_status, event_type, title, safe_metadata)
values
  ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_customer_a'), 'in_app', 'queued', 'dev.test', 'Dev Customer Notice', '{}'::jsonb),
  ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_reseller_a'), 'in_app', 'queued', 'dev.test', 'Dev Reseller Notice', '{}'::jsonb);

insert into public.audit_logs (actor_profile_id, actor_role, action, target_entity_type, target_entity_id, reason)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_admin'),
  'admin',
  'dev.rls.fixture.created',
  'fixture',
  (select fixture_id from rls_fixture_ids where fixture_key = 'order_a'),
  'Development-only RLS boundary fixture'
);

insert into public.admin_actions (actor_profile_id, action_type, action_status, target_entity_type, target_entity_id, reason)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_admin'),
  'dev.rls.review',
  'requested',
  'fixture',
  (select fixture_id from rls_fixture_ids where fixture_key = 'order_a'),
  'Development-only RLS boundary review action'
);

reset role;
set local role anon;
set local "request.jwt.claims" = '{}';
select pg_temp.rls_expect_count('anonymous cannot read profiles', $$select count(*) from public.profiles$$, 0);
select pg_temp.rls_expect_count('anonymous cannot read customers', $$select count(*) from public.customers$$, 0);
select pg_temp.rls_expect_count('anonymous cannot read private orders', $$select count(*) from public.orders$$, 0);
select pg_temp.rls_expect_count('anonymous cannot read audit logs', $$select count(*) from public.audit_logs$$, 0);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_clerk_customer_a"}';
select pg_temp.rls_expect_count('customer A sees one customer row', $$select count(*) from public.customers$$, 1);
select pg_temp.rls_expect_count('customer A cannot see customer B order', $$select count(*) from public.orders where order_number = 'RLS-DEV-ORDER-B'$$, 0);
select pg_temp.rls_expect_count('customer A cannot see supplier product base rows', $$select count(*) from public.products$$, 0);
select pg_temp.rls_expect_count('customer A cannot read settlements', $$select count(*) from public.settlements$$, 0);
select pg_temp.rls_expect_count('customer A cannot read audit logs', $$select count(*) from public.audit_logs$$, 0);
select pg_temp.rls_expect_blocked_or_zero('customer A cannot self-promote role', $$with changed as (update public.profiles set primary_role = 'admin' where clerk_user_id = 'dev_clerk_customer_a' returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('customer A cannot mutate order payment status', $$with changed as (update public.orders set payment_collection_status = 'collected' where order_number = 'RLS-DEV-ORDER-A' returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('customer A cannot delete own customer row', $$with changed as (delete from public.customers returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_allowed('customer A can insert own audit event only', $$with changed as (insert into public.audit_logs (actor_profile_id, actor_role, action, target_entity_type, target_entity_id, reason) values ((select id from public.profiles where clerk_user_id = 'dev_clerk_customer_a'), 'customer', 'dev.rls.customer.audit', 'profile', (select id from public.profiles where clerk_user_id = 'dev_clerk_customer_a'), 'Development-only audit insert boundary') returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('customer A cannot update audit logs', $$with changed as (update public.audit_logs set reason = 'blocked' returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_clerk_reseller_a"}';
select pg_temp.rls_expect_count('reseller A sees one reseller row', $$select count(*) from public.resellers$$, 1);
select pg_temp.rls_expect_count('reseller A cannot see reseller B row', $$select count(*) from public.resellers where reseller_type = 'dev_social_reseller_b'$$, 0);
select pg_temp.rls_expect_count('reseller A sees own listing', $$select count(*) from public.reseller_products$$, 1);
select pg_temp.rls_expect_count('reseller A sees own commission', $$select count(*) from public.commissions$$, 1);
select pg_temp.rls_expect_count('reseller A cannot read supplier product base rows', $$select count(*) from public.products$$, 0);
select pg_temp.rls_expect_blocked_or_zero('reseller A cannot update supplier product base data', $$with changed as (update public.products set base_price_amount = base_price_amount + 1 where slug = 'dev-rls-product-a' returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('reseller A cannot approve own reseller record', $$with changed as (update public.resellers set approval_status = 'approved' returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('reseller A cannot directly change commission status', $$with changed as (update public.commissions set commission_status = 'paid' returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('reseller A cannot delete listing rows', $$with changed as (delete from public.reseller_products returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_clerk_supplier_owner_a"}';
select pg_temp.rls_expect_count('supplier owner A sees one supplier row', $$select count(*) from public.suppliers$$, 1);
select pg_temp.rls_expect_count('supplier owner A cannot see supplier B row', $$select count(*) from public.suppliers where business_name = 'Dev Supplier B'$$, 0);
select pg_temp.rls_expect_count('supplier owner A sees own product row', $$select count(*) from public.products$$, 1);
select pg_temp.rls_expect_count('supplier owner A sees own settlement row', $$select count(*) from public.settlements$$, 1);
select pg_temp.rls_expect_blocked_or_zero('supplier owner A cannot self-verify supplier', $$with changed as (update public.suppliers set verification_status = 'approved' returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('supplier owner A cannot edit price snapshot fields', $$with changed as (update public.order_items set supplier_base_price_snapshot_amount = supplier_base_price_snapshot_amount + 1 returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('supplier owner A cannot delete products', $$with changed as (delete from public.products returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_clerk_supplier_a_inventory_manager"}';
select pg_temp.rls_expect_count('inventory manager sees supplier A product row', $$select count(*) from public.products$$, 1);
select pg_temp.rls_expect_count('inventory manager cannot see settlement data', $$select count(*) from public.settlements$$, 0);
select pg_temp.rls_expect_count('inventory manager cannot see payout withdrawal data', $$select count(*) from public.withdrawals$$, 0);
select pg_temp.rls_expect_count('inventory manager cannot read staff permission data', $$select count(*) from public.supplier_team_members where permissions <> '{}'::jsonb$$, 0);
select pg_temp.rls_expect_blocked_or_zero('inventory manager cannot mutate settlement status', $$with changed as (update public.settlements set settlement_status = 'paid' returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('inventory manager cannot mutate supplier permissions', $$with changed as (update public.supplier_team_members set permissions = '{"stock.adjust": false}'::jsonb returning 1) select count(*) from changed$$);
select pg_temp.rls_expect_blocked_or_zero('inventory manager cannot delete inventory movement targets', $$with changed as (delete from public.product_variants returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_clerk_support_operator"}';
select pg_temp.rls_expect_positive('support can read support queue disputes', $$select count(*) from public.disputes$$);
select pg_temp.rls_expect_count('support cannot read finance commissions', $$select count(*) from public.commissions$$, 0);
select pg_temp.rls_expect_blocked_or_zero('support cannot mutate settlement status', $$with changed as (update public.settlements set settlement_status = 'paid' returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_clerk_finance_operator"}';
select pg_temp.rls_expect_count('finance can read settlements', $$select count(*) from public.settlements$$, 2);
select pg_temp.rls_expect_count('finance can read commissions', $$select count(*) from public.commissions$$, 2);
select pg_temp.rls_expect_count('finance cannot read admin staff rows', $$select count(*) from public.admin_staff$$, 0);
select pg_temp.rls_expect_blocked_or_zero('finance cannot delete commissions', $$with changed as (delete from public.commissions returning 1) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_clerk_admin"}';
select pg_temp.rls_expect_positive('admin can read profiles', $$select count(*) from public.profiles$$);
select pg_temp.rls_expect_positive('admin can read admin staff', $$select count(*) from public.admin_staff$$);
select pg_temp.rls_expect_positive('admin can read audit logs', $$select count(*) from public.audit_logs$$);
select pg_temp.rls_expect_allowed('admin can insert admin action', $$with changed as (insert into public.admin_actions (actor_profile_id, action_type, action_status, target_entity_type, target_entity_id, reason) values ((select id from public.profiles where clerk_user_id = 'dev_clerk_admin'), 'dev.rls.admin.action', 'requested', 'fixture', (select id from public.orders where order_number = 'RLS-DEV-ORDER-A'), 'Development-only admin action boundary') returning 1) select count(*) from changed$$);

reset role;
select test_name, passed, details
from rls_test_results
order by test_name;

do $$
declare
  failure_count integer;
begin
  select count(*) into failure_count
  from rls_test_results
  where not passed;

  if failure_count > 0 then
    raise exception 'RLS boundary tests failed: % failure(s). Review rls_test_results output above.', failure_count;
  end if;
end $$;

rollback;

-- Rollback is intentional. This script must not leave fixture data behind.
