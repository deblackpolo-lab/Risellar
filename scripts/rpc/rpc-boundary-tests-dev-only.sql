-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Runnable pass/fail RPC boundary tests for the Risellar development Supabase project.
-- This script uses fake fixture data only and rolls back all changes.
-- Do not use real users, emails, phone numbers, addresses, payout data, production data, or secrets.
-- Do not weaken RLS policies or audited RPC checks to make this script pass.

begin;

create temp table rpc_fixture_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select on rpc_fixture_ids to public;

create temp table rpc_test_results (
  test_name text primary key,
  passed boolean not null,
  details text not null default ''
) on commit drop;

grant select, insert, update on rpc_test_results to public;

create or replace function pg_temp.rpc_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default ''
)
returns void
language plpgsql
as $$
begin
  insert into rpc_test_results (test_name, passed, details)
  values (p_test_name, p_passed, coalesce(p_details, ''))
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.rpc_expect_count(
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
  perform pg_temp.rpc_record_result(
    p_test_name,
    observed_count = p_expected_count,
    'expected=' || p_expected_count || ', observed=' || coalesce(observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rpc_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.rpc_expect_positive(
  p_test_name text,
  p_sql_text text
)
returns void
language plpgsql
as $$
declare
  observed_count integer;
begin
  execute p_sql_text into observed_count;
  perform pg_temp.rpc_record_result(
    p_test_name,
    observed_count > 0,
    'expected>0, observed=' || coalesce(observed_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rpc_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.rpc_expect_allowed(
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
  perform pg_temp.rpc_record_result(
    p_test_name,
    coalesce(affected_count, 0) > 0,
    'expected allowed with affected rows, observed=' || coalesce(affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rpc_record_result(p_test_name, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.rpc_expect_blocked_or_zero(
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
  perform pg_temp.rpc_record_result(
    p_test_name,
    coalesce(affected_count, 0) = 0,
    'expected blocked or 0 affected, observed=' || coalesce(affected_count::text, '<null>')
  );
exception
  when others then
    perform pg_temp.rpc_record_result(p_test_name, true, 'blocked with ' || sqlstate || ': ' || sqlerrm);
end;
$$;

grant execute on function pg_temp.rpc_record_result(text, boolean, text) to public;
grant execute on function pg_temp.rpc_expect_count(text, text, integer) to public;
grant execute on function pg_temp.rpc_expect_positive(text, text) to public;
grant execute on function pg_temp.rpc_expect_allowed(text, text) to public;
grant execute on function pg_temp.rpc_expect_blocked_or_zero(text, text) to public;

insert into public.profiles (clerk_user_id, email, full_name, primary_role)
values
  ('dev_rpc_customer_a', 'dev-rpc-customer-a@example.invalid', 'Dev RPC Customer A', 'customer'),
  ('dev_rpc_customer_b', 'dev-rpc-customer-b@example.invalid', 'Dev RPC Customer B', 'customer'),
  ('dev_rpc_reseller_a', 'dev-rpc-reseller-a@example.invalid', 'Dev RPC Reseller A', 'reseller'),
  ('dev_rpc_supplier_owner_a', 'dev-rpc-supplier-owner-a@example.invalid', 'Dev RPC Supplier Owner A', 'supplier_owner'),
  ('dev_rpc_inventory_manager_a', 'dev-rpc-inventory-manager-a@example.invalid', 'Dev RPC Inventory Manager A', 'supplier_inventory_manager'),
  ('dev_rpc_support_operator', 'dev-rpc-support@example.invalid', 'Dev RPC Support Operator', 'customer'),
  ('dev_rpc_finance_operator', 'dev-rpc-finance@example.invalid', 'Dev RPC Finance Operator', 'customer'),
  ('dev_rpc_admin_operator', 'dev-rpc-admin@example.invalid', 'Dev RPC Admin Operator', 'customer')
returning clerk_user_id, id;

insert into rpc_fixture_ids (fixture_key, fixture_id)
select clerk_user_id, id
from public.profiles
where clerk_user_id in (
  'dev_rpc_customer_a',
  'dev_rpc_customer_b',
  'dev_rpc_reseller_a',
  'dev_rpc_supplier_owner_a',
  'dev_rpc_inventory_manager_a',
  'dev_rpc_support_operator',
  'dev_rpc_finance_operator',
  'dev_rpc_admin_operator'
);

insert into public.admin_staff (profile_id, admin_role, permissions, staff_status)
values
  ((select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_support_operator'), 'support_staff', '{}'::jsonb, 'active'),
  ((select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_finance_operator'), 'finance_staff', '{}'::jsonb, 'active'),
  ((select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_admin_operator'), 'admin', '{}'::jsonb, 'active');

with inserted as (
  insert into public.customers (profile_id, customer_status)
  values
    ((select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_customer_a'), 'active'),
    ((select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_customer_b'), 'active')
  returning id, profile_id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select
  case
    when profile_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_customer_a') then 'customer_a'
    else 'customer_b'
  end,
  id
from inserted;

with inserted as (
  insert into public.resellers (
    profile_id,
    reseller_type,
    approval_status,
    payout_status,
    commission_available_amount,
    commission_pending_amount
  )
  values (
    (select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_reseller_a'),
    'dev_rpc_reseller',
    'approved',
    'active',
    3000,
    0
  )
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'reseller_a', id from inserted;

with inserted as (
  insert into public.reseller_shops (reseller_id, shop_slug, display_name, shop_status, visibility)
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'), 'dev-rpc-shop-a', 'Dev RPC Shop A', 'active', 'public')
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'shop_a', id from inserted;

with inserted as (
  insert into public.suppliers (owner_profile_id, business_name, public_display_name, supplier_status, verification_status)
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_supplier_owner_a'), 'Dev RPC Supplier A', 'Dev RPC Supplier A Public', 'active', 'approved')
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'supplier_a', id from inserted;

insert into public.supplier_team_members (supplier_id, profile_id, supplier_role, permissions, staff_status)
values (
  (select fixture_id from rpc_fixture_ids where fixture_key = 'supplier_a'),
  (select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_inventory_manager_a'),
  'supplier_inventory_manager',
  '{"stock.adjust": true, "products.create": true, "products.update": false}'::jsonb,
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
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'supplier_a'), 'Dev RPC Product A', 'dev-rpc-product-a', 'active', 'approved', 10000, 1000, 2500)
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'product_a', id from inserted;

with inserted as (
  insert into public.product_variants (product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, low_stock_threshold, variant_status)
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'product_a'), 'DEV-RPC-A-ONE', 'Dev RPC Variant A', 20, 1, 3, 'active')
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'variant_a', id from inserted;

insert into public.product_images (product_id, variant_id, storage_path, alt_text, image_status, is_primary)
values (
  (select fixture_id from rpc_fixture_ids where fixture_key = 'product_a'),
  (select fixture_id from rpc_fixture_ids where fixture_key = 'variant_a'),
  'dev-only/rpc/product-a.jpg',
  'Fake development RPC product image',
  'active',
  true
);

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
  values (
    (select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'shop_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'product_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'variant_a'),
    'active',
    1500,
    12500,
    'dev-rpc-share-a'
  )
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'reseller_product_a', id from inserted;

with inserted as (
  insert into public.orders (
    order_number,
    customer_id,
    reseller_id,
    shop_id,
    order_status,
    customer_confirmation_status,
    subtotal_product_amount,
    delivery_estimate_min_amount,
    delivery_estimate_max_amount,
    total_payable_amount,
    delivery_address_snapshot,
    customer_contact_snapshot
  )
  values
    ('RPC-DEV-ORDER-A', (select fixture_id from rpc_fixture_ids where fixture_key = 'customer_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'shop_a'), 'placed_pending_confirmation', 'pending', 12500, 1500, 2500, 14000, '{"city":"Dev RPC City A"}'::jsonb, '{"phone":"0000000100"}'::jsonb),
    ('RPC-DEV-ORDER-B', (select fixture_id from rpc_fixture_ids where fixture_key = 'customer_b'), (select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'shop_a'), 'placed_pending_confirmation', 'pending', 12500, 1500, 2500, 14000, '{"city":"Dev RPC City B"}'::jsonb, '{"phone":"0000000101"}'::jsonb)
  returning id, order_number
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select case when order_number = 'RPC-DEV-ORDER-A' then 'order_a' else 'order_b' end, id
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
    ((select fixture_id from rpc_fixture_ids where fixture_key = 'order_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'supplier_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'product_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'variant_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_product_a'), 1, 10000, 1000, 1500, 11000, 12500, 12500, 2500, 1500),
    ((select fixture_id from rpc_fixture_ids where fixture_key = 'order_b'), (select fixture_id from rpc_fixture_ids where fixture_key = 'supplier_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'product_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'variant_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_product_a'), 1, 10000, 1000, 1500, 11000, 12500, 12500, 2500, 1500)
  returning id, order_id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select case when order_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a') then 'order_item_a' else 'order_item_b' end, id
from inserted;

with inserted as (
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
    'RPC-DEV-RESERVATION-A',
    (select fixture_id from rpc_fixture_ids where fixture_key = 'customer_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_product_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'product_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'variant_a'),
    (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a'),
    1,
    'reserved',
    now() - interval '1 hour'
  )
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'reservation_a', id from inserted;

with inserted as (
  insert into public.delivery_quotes (order_id, delivery_method, quoted_amount, quote_status, expires_at)
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'order_a'), 'dev courier', 1800, 'quoted', now() + interval '1 day')
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'delivery_quote_a', id from inserted;

with inserted as (
  insert into public.settlements (supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount, due_at)
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'supplier_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a'), 'due', 2500, 0, 2500, now() + interval '7 days')
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'settlement_a', id from inserted;

with inserted as (
  insert into public.commissions (reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount)
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'order_item_a'), (select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a'), 'awaiting_supplier_settlement', 1500)
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'commission_a', id from inserted;

with inserted as (
  insert into public.withdrawals (reseller_id, requested_amount, withdrawal_status, requested_by_profile_id, account_name, account_number_masked)
  values ((select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'), 500, 'requested', (select fixture_id from rpc_fixture_ids where fixture_key = 'dev_rpc_reseller_a'), 'Dev RPC Account', '****0100')
  returning id
)
insert into rpc_fixture_ids (fixture_key, fixture_id)
select 'withdrawal_a', id from inserted;

reset role;
set local role anon;
set local "request.jwt.claims" = '{}';
select pg_temp.rpc_expect_blocked_or_zero('anon cannot create audit log through RPC', $$with changed as (select public.create_audit_log_entry('dev.anon', 'fixture') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('anon cannot read settlement summary view', $$select count(*) from public.supplier_settlement_summary$$, 0);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_rpc_customer_a"}';
select pg_temp.rpc_expect_allowed('customer A can confirm own order through audited RPC', $$with changed as (select public.confirm_customer_order((select fixture_id from rpc_fixture_ids where fixture_key = 'order_a'), 'development rpc customer confirmation') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('customer confirmation RPC writes audit row', $$select count(*) from public.audit_logs where action = 'confirm_customer_order' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a')$$, 1);
select pg_temp.rpc_expect_blocked_or_zero('customer A cannot confirm customer B order through RPC', $$with changed as (select public.confirm_customer_order((select fixture_id from rpc_fixture_ids where fixture_key = 'order_b'), 'blocked cross customer confirmation') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_allowed('customer A can approve own delivery quote through audited RPC', $$with changed as (select public.approve_delivery_quote((select fixture_id from rpc_fixture_ids where fixture_key = 'delivery_quote_a'), 'development quote approval') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('delivery quote approval writes audit row', $$select count(*) from public.audit_logs where action = 'approve_delivery_quote' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'delivery_quote_a')$$, 1);
select pg_temp.rpc_expect_blocked_or_zero('customer cannot directly mutate order price totals', $$with changed as (update public.orders set total_payable_amount = 1 where id = (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a') returning 1) select count(*) from changed$$);
select pg_temp.rpc_expect_blocked_or_zero('customer cannot directly mutate price snapshot fields', $$with changed as (update public.order_items set customer_product_price_snapshot_amount = 1 where order_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a') returning 1) select count(*) from changed$$);
select pg_temp.rpc_expect_count('customer cannot read settlement summary view', $$select count(*) from public.supplier_settlement_summary$$, 0);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_rpc_reseller_a"}';
select pg_temp.rpc_expect_blocked_or_zero('reseller cannot release own commission through RPC', $$with changed as (select public.release_commission_after_settlement((select fixture_id from rpc_fixture_ids where fixture_key = 'commission_a'), 'blocked reseller release') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_blocked_or_zero('reseller cannot approve own withdrawal through RPC', $$with changed as (select public.approve_or_reject_withdrawal((select fixture_id from rpc_fixture_ids where fixture_key = 'withdrawal_a'), true, 500, 'blocked reseller approval') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_blocked_or_zero('reseller cannot directly mutate commission status', $$with changed as (update public.commissions set commission_status = 'available' returning 1) select count(*) from changed$$);
select pg_temp.rpc_expect_blocked_or_zero('reseller withdrawal request cannot exceed available balance', $$with changed as (select public.request_commission_withdrawal((select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'), 999999, 'dev-provider', 'Dev RPC Account', '****0100') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_allowed('reseller can request withdrawal within available balance', $$with changed as (select public.request_commission_withdrawal((select fixture_id from rpc_fixture_ids where fixture_key = 'reseller_a'), 250, 'dev-provider', 'Dev RPC Account', '****0100') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('reseller withdrawal request writes audit row', $$select count(*) from public.audit_logs where action = 'request_commission_withdrawal' and target_entity_type = 'withdrawals'$$, 1);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_rpc_supplier_owner_a"}';
select pg_temp.rpc_expect_blocked_or_zero('supplier owner cannot verify own settlement through RPC', $$with changed as (select public.verify_supplier_settlement((select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a'), 2500, 'blocked supplier self verification', true) as id) select count(*) from changed$$);
select pg_temp.rpc_expect_allowed('supplier owner can submit private settlement proof through RPC', $$with changed as (select public.submit_supplier_settlement_proof((select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a'), 'settlement-proofs/dev-only/rpc-proof-a.jpg', 'DEV-RPC-PROOF-A', 'development proof submission') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('settlement proof submission writes audit row', $$select count(*) from public.audit_logs where action = 'submit_supplier_settlement_proof' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a')$$, 1);
select pg_temp.rpc_expect_blocked_or_zero('supplier owner cannot submit public settlement proof URL', $$with changed as (select public.submit_supplier_settlement_proof((select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a'), 'https://example.invalid/proof.jpg', 'DEV-RPC-BLOCKED', 'blocked public proof url') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_blocked_or_zero('supplier owner cannot directly mutate settlement verification status', $$with changed as (update public.settlements set settlement_status = 'paid' returning 1) select count(*) from changed$$);
select pg_temp.rpc_expect_count('supplier owner can read own settlement summary', $$select count(*) from public.supplier_settlement_summary where supplier_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'supplier_a')$$, 1);
select pg_temp.rpc_expect_blocked_or_zero('supplier image review queue does not expose base price column', $$select count(*) from public.supplier_product_image_review_queue where base_price_amount is not null$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_rpc_inventory_manager_a"}';
select pg_temp.rpc_expect_blocked_or_zero('inventory manager cannot verify settlement through RPC', $$with changed as (select public.verify_supplier_settlement((select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a'), 2500, 'blocked inventory manager verification', true) as id) select count(*) from changed$$);
select pg_temp.rpc_expect_blocked_or_zero('inventory manager cannot release commission through RPC', $$with changed as (select public.release_commission_after_settlement((select fixture_id from rpc_fixture_ids where fixture_key = 'commission_a'), 'blocked inventory manager commission release') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('inventory manager cannot read settlement summary view', $$select count(*) from public.supplier_settlement_summary$$, 0);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_rpc_support_operator"}';
select pg_temp.rpc_expect_allowed('support can release expired reservation through audited RPC', $$with changed as (select public.release_expired_reservation((select fixture_id from rpc_fixture_ids where fixture_key = 'reservation_a'), 'development expired reservation release') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('reservation release writes audit row', $$select count(*) from public.audit_logs where action = 'release_expired_reservation' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'reservation_a')$$, 1);
select pg_temp.rpc_expect_allowed('support can record delivery quote through audited RPC', $$with changed as (select public.record_delivery_quote((select fixture_id from rpc_fixture_ids where fixture_key = 'order_b'), 'dev courier b', 1900, now() + interval '1 day', 'development support quote') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_blocked_or_zero('support cannot verify settlement through finance RPC', $$with changed as (select public.verify_supplier_settlement((select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a'), 2500, 'blocked support verification', true) as id) select count(*) from changed$$);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_rpc_finance_operator"}';
select pg_temp.rpc_expect_allowed('finance can verify supplier settlement through audited RPC', $$with changed as (select public.verify_supplier_settlement((select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a'), 2500, 'development finance verification', true) as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('settlement verification writes audit row', $$select count(*) from public.audit_logs where action = 'verify_supplier_settlement' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'settlement_a')$$, 1);
select pg_temp.rpc_expect_allowed('finance can release commission after paid settlement', $$with changed as (select public.release_commission_after_settlement((select fixture_id from rpc_fixture_ids where fixture_key = 'commission_a'), 'development commission release') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('commission release writes audit row', $$select count(*) from public.audit_logs where action = 'release_commission_after_settlement' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'commission_a')$$, 1);
select pg_temp.rpc_expect_allowed('finance can approve requested withdrawal through audited RPC', $$with changed as (select public.approve_or_reject_withdrawal((select fixture_id from rpc_fixture_ids where fixture_key = 'withdrawal_a'), true, 500, 'development withdrawal approval') as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('withdrawal approval writes audit row', $$select count(*) from public.audit_logs where action = 'approve_or_reject_withdrawal' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'withdrawal_a')$$, 1);

reset role;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"dev_rpc_admin_operator"}';
select pg_temp.rpc_expect_allowed('admin can record manual override with reason', $$with changed as (select public.admin_manual_override_record('dev.rpc.override', 'orders', (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a'), 'Development manual override boundary', null, '{"result":"recorded"}'::jsonb) as id) select count(*) from changed$$);
select pg_temp.rpc_expect_count('manual override writes admin action', $$select count(*) from public.admin_actions where action_type = 'dev.rpc.override' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a')$$, 1);
select pg_temp.rpc_expect_count('manual override writes audit row', $$select count(*) from public.audit_logs where action = 'admin_manual_override_record' and target_entity_id = (select fixture_id from rpc_fixture_ids where fixture_key = 'order_a')$$, 1);

reset role;
select test_name, passed, details
from rpc_test_results
order by test_name;

do $$
declare
  failure_count integer;
  failed_details text;
begin
  select count(*) into failure_count
  from rpc_test_results
  where not passed;

  select string_agg(test_name || ' - ' || coalesce(nullif(details, ''), '<no details>'), E'\n' order by test_name)
  into failed_details
  from rpc_test_results
  where not passed;

  if failure_count > 0 then
    raise exception 'RPC boundary tests failed: % failure(s): %', failure_count, failed_details;
  end if;
end $$;

rollback;

-- Rollback is intentional. This script must not leave fixture data behind.
