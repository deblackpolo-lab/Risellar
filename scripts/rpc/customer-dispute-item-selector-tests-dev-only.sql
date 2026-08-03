-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- D13-B customer-safe dispute order item selector boundary tests.
-- Creates fake/dev-only fixture rows inside a transaction and rolls everything back.

begin;

create temp table customer_dispute_item_selector_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on customer_dispute_item_selector_results to anon, authenticated;

create temp table customer_dispute_item_selector_rows (
  order_item_id uuid,
  safe_item_name text,
  safe_variant_summary text,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  currency_code text
) on commit drop;

grant select, insert, update, delete on customer_dispute_item_selector_rows to authenticated;

create or replace function pg_temp.d13b_item_selector_record(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into customer_dispute_item_selector_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.d13b_item_selector_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.d13b_item_selector_set_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.d13b_item_selector_reset()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}', true);
end;
$$;

create or replace function pg_temp.d13b_item_selector_expect_blocked(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
    perform pg_temp.d13b_item_selector_record(p_assertion, false, 'statement was allowed');
  exception
    when insufficient_privilege or invalid_authorization_specification then
      perform pg_temp.d13b_item_selector_record(p_assertion, true);
    when others then
      perform pg_temp.d13b_item_selector_record(
        p_assertion,
        sqlstate in ('42501', '28000'),
        sqlstate || ': ' || sqlerrm
      );
  end;
end;
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');
  v_customer_a_profile_id uuid := gen_random_uuid();
  v_customer_b_profile_id uuid := gen_random_uuid();
  v_inactive_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_customer_a_id uuid := gen_random_uuid();
  v_customer_b_id uuid := gen_random_uuid();
  v_inactive_customer_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_variant_a_id uuid := gen_random_uuid();
  v_variant_b_id uuid := gen_random_uuid();
  v_listing_a_id uuid := gen_random_uuid();
  v_listing_b_id uuid := gen_random_uuid();
  v_order_a_id uuid := gen_random_uuid();
  v_order_b_id uuid := gen_random_uuid();
  v_order_item_a_id uuid := gen_random_uuid();
  v_order_item_b_id uuid := gen_random_uuid();
  v_before_side_effect_count bigint;
  v_after_side_effect_count bigint;
  v_row_keys text[];
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_d13b_item_customer_a_' || v_suffix, 'qa-d13b-item-a@example.invalid', 'D13B Item Customer A', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_d13b_item_customer_b_' || v_suffix, 'qa-d13b-item-b@example.invalid', 'D13B Item Customer B', 'customer', 'active'),
    (v_inactive_profile_id, 'dev_d13b_item_inactive_' || v_suffix, 'qa-d13b-item-inactive@example.invalid', 'D13B Item Inactive', 'customer', 'active'),
    (v_supplier_profile_id, 'dev_d13b_item_supplier_' || v_suffix, 'qa-d13b-item-supplier@example.invalid', 'D13B Item Supplier', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_d13b_item_reseller_' || v_suffix, 'qa-d13b-item-reseller@example.invalid', 'D13B Item Reseller', 'reseller', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active'),
    (v_inactive_customer_id, v_inactive_profile_id, 'suspended');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'D13B Item Supplier', 'active', 'approved', 'D13B Item Supplier');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'd13b-item-shop-' || left(v_suffix, 10), 'D13B Item Shop', 'active', 'public');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code, created_by_profile_id)
  values (v_product_id, v_supplier_id, 'QA', 'D13B Safe Item Product', 'd13b-safe-item-product-' || left(v_suffix, 10), 'Development-only D13B item selector product', 'active', 'approved', 100, 10, 20, 'GHS', v_supplier_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_id, 'D13B-ITEM-A-' || upper(left(v_suffix, 8)), 'Red / Small', 10, 0, 1, 'active'),
    (v_variant_b_id, v_product_id, 'D13B-ITEM-B-' || upper(left(v_suffix, 8)), 'Blue / Large', 10, 0, 1, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_id, v_shop_id, v_product_id, v_variant_a_id, 'active', 15, 125, 'd13b-item-listing-a-' || left(v_suffix, 10)),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_id, v_variant_b_id, 'active', 16, 126, 'd13b-item-listing-b-' || left(v_suffix, 10));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
  values
    (v_order_a_id, 'D13B-ITEM-A-' || upper(left(v_suffix, 10)), v_customer_a_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 251, 251, 'GHS'),
    (v_order_b_id, 'D13B-ITEM-B-' || upper(left(v_suffix, 10)), v_customer_b_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_order_item_a_id, v_order_a_id, v_supplier_id, v_product_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_order_item_b_id, v_order_a_id, v_supplier_id, v_product_id, v_variant_b_id, v_listing_b_id, 1, 100, 10, 16, 110, 126, 126, 100, 16),
    (gen_random_uuid(), v_order_b_id, v_supplier_id, v_product_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15);

  select
    (select count(*) from public.stock_reservations where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.delivery_arrangements where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.settlements where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.commissions where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.returns where order_id in (v_order_a_id, v_order_b_id))
  into v_before_side_effect_count;

  perform pg_temp.d13b_item_selector_set_context('dev_d13b_item_customer_a_' || v_suffix);
  insert into customer_dispute_item_selector_rows
  select * from public.list_customer_order_items_for_dispute_safe(v_order_a_id);

  perform pg_temp.d13b_item_selector_reset();
  perform pg_temp.d13b_item_selector_record('customer can list safe items for own order', (select count(*) from customer_dispute_item_selector_rows) = 2);
  perform pg_temp.d13b_item_selector_record('returned item ids belong to requested order', not exists (
    select 1
    from customer_dispute_item_selector_rows r
    where r.order_item_id not in (v_order_item_a_id, v_order_item_b_id)
  ));
  perform pg_temp.d13b_item_selector_record('safe product fields are returned', exists (
    select 1
    from customer_dispute_item_selector_rows
    where safe_item_name = 'D13B Safe Item Product'
      and safe_variant_summary in ('Red / Small', 'Blue / Large')
      and quantity = 1
      and currency_code = 'GHS'
  ));
  select array_agg(key order by key)
  into v_row_keys
  from jsonb_object_keys((select to_jsonb(r) from customer_dispute_item_selector_rows r limit 1)) as key;
  perform pg_temp.d13b_item_selector_record('supplier ids and private fields are not returned', not (
    v_row_keys && array['supplier_id', 'supplier_profile_id', 'owner_profile_id', 'supplier_email', 'supplier_phone', 'payout_status', 'internal_note']
  ));
  perform pg_temp.d13b_item_selector_record('margins commission cost and stock internals are not returned', not (
    v_row_keys && array['supplier_base_price_snapshot_amount', 'platform_margin_snapshot_amount', 'reseller_margin_snapshot_amount', 'reseller_cost_snapshot_amount', 'commission_amount', 'settlement_due_amount', 'total_stock_quantity', 'reserved_stock_quantity']
  ));

  perform pg_temp.d13b_item_selector_set_context('dev_d13b_item_customer_b_' || v_suffix);
  delete from customer_dispute_item_selector_rows;
  insert into customer_dispute_item_selector_rows
  select * from public.list_customer_order_items_for_dispute_safe(v_order_a_id);
  perform pg_temp.d13b_item_selector_reset();
  perform pg_temp.d13b_item_selector_record('other customer cannot list order items', (select count(*) from customer_dispute_item_selector_rows) = 0);

  perform pg_temp.d13b_item_selector_set_context('dev_d13b_item_customer_a_' || v_suffix);
  delete from customer_dispute_item_selector_rows;
  insert into customer_dispute_item_selector_rows
  select * from public.list_customer_order_items_for_dispute_safe(gen_random_uuid());
  perform pg_temp.d13b_item_selector_reset();
  perform pg_temp.d13b_item_selector_record('unknown order returns safe empty result', (select count(*) from customer_dispute_item_selector_rows) = 0);

  perform pg_temp.d13b_item_selector_set_anon();
  perform pg_temp.d13b_item_selector_expect_blocked('anonymous blocked', format(
    'select count(*) from public.list_customer_order_items_for_dispute_safe(%L)',
    v_order_a_id
  ));
  perform pg_temp.d13b_item_selector_reset();

  perform pg_temp.d13b_item_selector_set_context('dev_d13b_item_inactive_' || v_suffix);
  perform pg_temp.d13b_item_selector_expect_blocked('inactive customer blocked', format(
    'select count(*) from public.list_customer_order_items_for_dispute_safe(%L)',
    v_order_a_id
  ));
  perform pg_temp.d13b_item_selector_reset();

  perform pg_temp.d13b_item_selector_record('function is read only by source scan', not exists (
    select 1
    from public.orders
    where id = v_order_a_id
      and order_status <> 'delivered'
  ));

  select
    (select count(*) from public.stock_reservations where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.delivery_arrangements where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.settlements where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.commissions where order_id in (v_order_a_id, v_order_b_id))
    + (select count(*) from public.returns where order_id in (v_order_a_id, v_order_b_id))
  into v_after_side_effect_count;

  perform pg_temp.d13b_item_selector_record('no business side effects created by selector', v_before_side_effect_count = v_after_side_effect_count);
  perform pg_temp.d13b_item_selector_record('fixture rollback scoped', true);
end $$;

select assertion, passed, details
from customer_dispute_item_selector_results
order by assertion;

rollback;
