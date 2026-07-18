-- DEVELOPMENT ONLY — DO NOT RUN AGAINST PRODUCTION.
-- Public reseller shop read-only RPC boundary test plan.
-- Requires the public reseller shop read-only RPC migration to be applied to development first.
-- This script is intentionally not executed during the foundation commit/dry-run step.

begin;

create temp table public_shop_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

create or replace function pg_temp.public_shop_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into public_shop_test_results (test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

-- Assertions to run after migration application with development-only fixtures:
-- 1. get_public_reseller_shop returns only active approved listings for public shop slug.
-- 2. pending/rejected/archived products are absent.
-- 3. archived/hidden/restricted reseller listings are absent.
-- 4. result columns do not include supplier base price, platform margin, reseller margin, supplier contact, payout, risk, settlement, commission, or team data.
-- 5. get_public_reseller_shop_product returns one active approved product by share_slug/product_slug.
-- 6. invalid shop/product slugs return no rows without leaking table errors.
-- 7. anonymous role can execute the RPCs but cannot mutate orders, stock reservations, payments, commissions, settlements, withdrawals, or reseller listings.

select pg_temp.public_shop_record_result(
  'public shop boundary script is scaffolded only',
  true,
  'Apply the migration to development, seed fake public listings, then convert these documented checks to active assertions.'
);

select *
from public_shop_test_results
order by test_name;

rollback;
