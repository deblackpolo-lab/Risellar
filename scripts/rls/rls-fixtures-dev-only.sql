-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Fake RLS fixture smoke script for the Risellar development Supabase project.
-- This script uses only fake records and rolls back all changes.
-- Do not use real users, emails, phone numbers, addresses, payout data, or secrets.

begin;

create temp table rls_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

insert into public.profiles (clerk_user_id, email, full_name, primary_role)
values
  ('dev_clerk_customer_a', 'customer-a@example.invalid', 'Dev Customer A', 'customer'),
  ('dev_clerk_reseller_a', 'reseller-a@example.invalid', 'Dev Reseller A', 'reseller'),
  ('dev_clerk_supplier_owner_a', 'supplier-owner-a@example.invalid', 'Dev Supplier Owner A', 'supplier_owner'),
  ('dev_clerk_supplier_a_inventory_manager', 'supplier-a-inventory@example.invalid', 'Dev Supplier A Inventory Manager', 'supplier_inventory_manager'),
  ('dev_clerk_admin', 'admin@example.invalid', 'Dev Admin', 'customer')
returning clerk_user_id, id;

insert into rls_fixture_ids (fixture_key, fixture_id)
select clerk_user_id, id
from public.profiles
where clerk_user_id in (
  'dev_clerk_customer_a',
  'dev_clerk_reseller_a',
  'dev_clerk_supplier_owner_a',
  'dev_clerk_supplier_a_inventory_manager',
  'dev_clerk_admin'
);

insert into public.admin_staff (profile_id, admin_role, permissions, staff_status)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_admin'),
  'admin',
  '{}'::jsonb,
  'active'
);

insert into public.customers (profile_id, customer_status)
values ((select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_customer_a'), 'active')
returning 'customer_a', id;

insert into public.resellers (profile_id, business_name, approval_status, payout_status)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_reseller_a'),
  'Dev Reseller A',
  'approved',
  'active'
)
returning 'reseller_a', id;

insert into public.suppliers (owner_profile_id, business_name, public_display_name, supplier_status, verification_status)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_supplier_owner_a'),
  'Dev Supplier A',
  'Dev Supplier A Public',
  'active',
  'approved'
)
returning 'supplier_a', id;

insert into rls_fixture_ids (fixture_key, fixture_id)
select 'supplier_a', id from public.suppliers where business_name = 'Dev Supplier A';

insert into public.supplier_team_members (supplier_id, profile_id, supplier_role, permissions)
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a'),
  (select fixture_id from rls_fixture_ids where fixture_key = 'dev_clerk_supplier_a_inventory_manager'),
  'supplier_inventory_manager',
  '{"stock.adjust": true}'::jsonb
);

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
values (
  (select fixture_id from rls_fixture_ids where fixture_key = 'supplier_a'),
  'Dev RLS Product A',
  'dev-rls-product-a',
  'active',
  'approved',
  10000,
  1000,
  2500
)
returning 'product_a', id;

do $$
declare
  profile_count integer;
  supplier_count integer;
  product_count integer;
begin
  select count(*) into profile_count from public.profiles where clerk_user_id like 'dev_clerk_%';
  select count(*) into supplier_count from public.suppliers where business_name = 'Dev Supplier A';
  select count(*) into product_count from public.products where slug = 'dev-rls-product-a';

  if profile_count <> 5 then
    raise exception 'Fixture smoke failed: expected 5 fake profiles, observed %', profile_count;
  end if;

  if supplier_count <> 1 then
    raise exception 'Fixture smoke failed: expected 1 fake supplier, observed %', supplier_count;
  end if;

  if product_count <> 1 then
    raise exception 'Fixture smoke failed: expected 1 fake product, observed %', product_count;
  end if;
end $$;

rollback;

-- Rollback is intentional. This file verifies fixture shape without leaving data behind.
