-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Order Handling S5 concurrency contract checks.
-- This rollback-scoped harness verifies the terminal/idempotent invariants that
-- independent-session race runners assert under true concurrency.

begin;

create temp table supplier_order_decision_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_decision_concurrency_results to authenticated;

create or replace function pg_temp.supplier_order_decision_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_decision_concurrency_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_decision_concurrency_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.supplier_order_decision_concurrency_reset_context()
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
  v_customer_profile_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_variant_accept_reject_id uuid := gen_random_uuid();
  v_variant_two_reject_id uuid := gen_random_uuid();
  v_variant_two_accept_id uuid := gen_random_uuid();
  v_listing_accept_reject_id uuid := gen_random_uuid();
  v_listing_two_reject_id uuid := gen_random_uuid();
  v_listing_two_accept_id uuid := gen_random_uuid();
  v_order_accept_reject_id uuid := gen_random_uuid();
  v_order_two_reject_id uuid := gen_random_uuid();
  v_order_two_accept_id uuid := gen_random_uuid();
  v_reservation_accept_reject_id uuid := gen_random_uuid();
  v_reservation_two_reject_id uuid := gen_random_uuid();
  v_reservation_two_accept_id uuid := gen_random_uuid();
  v_stock_before integer;
  v_stock_after integer;
begin
  perform pg_temp.supplier_order_decision_concurrency_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, phone, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_supplier_order_decision_concurrency_customer', 'dev-supplier-order-decision-concurrency-customer@example.test', 'Dev Decision Concurrency Customer', '0204100101', 'customer', 'active'),
    (v_reseller_profile_id, 'dev_supplier_order_decision_concurrency_reseller', 'dev-supplier-order-decision-concurrency-reseller@example.test', 'Dev Decision Concurrency Reseller', '0204100201', 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_supplier_order_decision_concurrency_supplier', 'dev-supplier-order-decision-concurrency-supplier@example.test', 'Dev Decision Concurrency Supplier', '0204100301', 'supplier_owner', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_supplier_order_decision_concurrency_reseller', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-supplier-order-decision-concurrency-shop', 'Dev Supplier Order Decision Concurrency Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'Dev Supplier Order Decision Concurrency', 'active', 'approved', 'Dev Decision Concurrency Supplier');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values (v_product_id, v_supplier_id, 'QA Test', 'Dev Supplier Order Decision Concurrency Product', 'dev-supplier-order-decision-concurrency', 'Development-only supplier decision concurrency product', 'active', 'approved', 100, 10, 20, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_accept_reject_id, v_product_id, 'DEV-SUP-DEC-CONC-AR', 'Accept Reject', 20, 1, 0, 'active'),
    (v_variant_two_reject_id, v_product_id, 'DEV-SUP-DEC-CONC-RR', 'Two Reject', 20, 1, 0, 'active'),
    (v_variant_two_accept_id, v_product_id, 'DEV-SUP-DEC-CONC-AA', 'Two Accept', 20, 1, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_accept_reject_id, v_reseller_id, v_shop_id, v_product_id, v_variant_accept_reject_id, 'active', 15, 125, 'dev-supplier-order-decision-concurrency-ar'),
    (v_listing_two_reject_id, v_reseller_id, v_shop_id, v_product_id, v_variant_two_reject_id, 'active', 15, 125, 'dev-supplier-order-decision-concurrency-rr'),
    (v_listing_two_accept_id, v_reseller_id, v_shop_id, v_product_id, v_variant_two_accept_id, 'active', 15, 125, 'dev-supplier-order-decision-concurrency-aa');

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_method, payment_collection_status, delivery_status, customer_confirmation_status, delivery_quote_status, subtotal_product_amount, total_payable_amount, currency_code, delivery_address_snapshot, customer_contact_snapshot)
  values
    (v_order_accept_reject_id, 'RSR-DEV-SUP-DEC-CONC-AR', v_customer_id, v_reseller_id, v_shop_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', '{}'::jsonb, '{}'::jsonb),
    (v_order_two_reject_id, 'RSR-DEV-SUP-DEC-CONC-RR', v_customer_id, v_reseller_id, v_shop_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', '{}'::jsonb, '{}'::jsonb),
    (v_order_two_accept_id, 'RSR-DEV-SUP-DEC-CONC-AA', v_customer_id, v_reseller_id, v_shop_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', '{}'::jsonb, '{}'::jsonb);

  insert into public.order_items(order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_order_accept_reject_id, v_supplier_id, v_product_id, v_variant_accept_reject_id, v_listing_accept_reject_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_two_reject_id, v_supplier_id, v_product_id, v_variant_two_reject_id, v_listing_two_reject_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_two_accept_id, v_supplier_id, v_product_id, v_variant_two_accept_id, v_listing_two_accept_id, 1, 100, 10, 15, 110, 125, 125, 25, 15);

  insert into public.stock_reservations(id, reservation_reference, customer_id, reseller_id, reseller_product_id, product_id, variant_id, order_id, quantity, reservation_status, expires_at)
  values
    (v_reservation_accept_reject_id, 'RSV-DEV-SUP-DEC-CONC-AR', v_customer_id, v_reseller_id, v_listing_accept_reject_id, v_product_id, v_variant_accept_reject_id, v_order_accept_reject_id, 1, 'reserved', now() + interval '1 hour'),
    (v_reservation_two_reject_id, 'RSV-DEV-SUP-DEC-CONC-RR', v_customer_id, v_reseller_id, v_listing_two_reject_id, v_product_id, v_variant_two_reject_id, v_order_two_reject_id, 1, 'reserved', now() + interval '1 hour'),
    (v_reservation_two_accept_id, 'RSV-DEV-SUP-DEC-CONC-AA', v_customer_id, v_reseller_id, v_listing_two_accept_id, v_product_id, v_variant_two_accept_id, v_order_two_accept_id, 1, 'reserved', now() + interval '1 hour');

  perform pg_temp.supplier_order_decision_concurrency_set_context('dev_supplier_order_decision_concurrency_supplier');

  perform public.supplier_accept_order(v_order_accept_reject_id, 'accept-vs-reject-winner');
  begin
    perform public.supplier_reject_order(v_order_accept_reject_id, 'out_of_stock', null, 'accept-vs-reject-loser');
  exception when others then
    null;
  end;
  perform pg_temp.supplier_order_decision_concurrency_record('accept-vs-reject one terminal winner', (select order_status::text from public.orders where id = v_order_accept_reject_id) = 'supplier_confirmed');
  perform pg_temp.supplier_order_decision_concurrency_record('accept-vs-reject reservation result', (select reservation_status::text from public.stock_reservations where id = v_reservation_accept_reject_id) = 'reserved');

  select reserved_stock_quantity into v_stock_before from public.product_variants where id = v_variant_two_reject_id;
  perform public.supplier_reject_order(v_order_two_reject_id, 'out_of_stock', null, 'two-reject');
  perform public.supplier_reject_order(v_order_two_reject_id, 'out_of_stock', null, 'two-reject');
  select reserved_stock_quantity into v_stock_after from public.product_variants where id = v_variant_two_reject_id;
  perform pg_temp.supplier_order_decision_concurrency_record('two-reject one terminal state', (select order_status::text from public.orders where id = v_order_two_reject_id) = 'supplier_rejected');
  perform pg_temp.supplier_order_decision_concurrency_record('two-reject one release', (select count(*) from public.inventory_movements where order_id = v_order_two_reject_id and movement_type = 'reservation_released') = 1);
  perform pg_temp.supplier_order_decision_concurrency_record('two-reject one decrement', v_stock_after = v_stock_before - 1);
  perform pg_temp.supplier_order_decision_concurrency_record('no negative reserved stock', v_stock_after >= 0);

  perform public.supplier_accept_order(v_order_two_accept_id, 'two-accept');
  perform public.supplier_accept_order(v_order_two_accept_id, 'two-accept');
  perform pg_temp.supplier_order_decision_concurrency_record('two-accept one terminal state', (select order_status::text from public.orders where id = v_order_two_accept_id) = 'supplier_confirmed');
  perform pg_temp.supplier_order_decision_concurrency_record('two-accept reservation unchanged', (select reservation_status::text from public.stock_reservations where id = v_reservation_two_accept_id) = 'reserved');
  perform pg_temp.supplier_order_decision_concurrency_reset_context();
  perform pg_temp.supplier_order_decision_concurrency_record('two-accept no duplicate decision event', (select count(*) from public.audit_logs where action = 'supplier_order_accepted' and target_entity_id = v_order_two_accept_id) = 1);

  perform pg_temp.supplier_order_decision_concurrency_reset_context();
end;
$$;

select test_name, passed, details
from supplier_order_decision_concurrency_results
order by test_name;

do $$
declare
  v_failures text;
begin
  select string_agg(test_name || coalesce(': ' || details, ''), '; ' order by test_name)
  into v_failures
  from supplier_order_decision_concurrency_results
  where not passed;

  if v_failures is not null then
    raise exception 'Supplier order decision concurrency failures: %', v_failures;
  end if;
end;
$$;

rollback;
