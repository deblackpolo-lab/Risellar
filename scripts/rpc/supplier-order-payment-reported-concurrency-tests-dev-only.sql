-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier payment-reported idempotency/concurrency guard regression.
-- This transaction-scoped script simulates repeated same-key submission and
-- verifies the locked order transition is not duplicated.

begin;

create temp table supplier_order_payment_reported_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_payment_reported_concurrency_results to anon, authenticated;

create or replace function pg_temp.payment_reported_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_payment_reported_concurrency_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.payment_reported_concurrency_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.payment_reported_concurrency_reset_context()
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
  v_order_id uuid;
  v_supplier_id uuid;
  v_supplier_profile_id uuid;
  v_supplier_clerk_user_id text;
  v_variant_id uuid;
  v_reservation_id uuid;
  v_stock_before record;
  v_stock_after_first record;
  v_stock_after_retry record;
  v_audit_after_first bigint;
  v_audit_after_retry bigint;
  v_report_after_first bigint;
  v_report_after_retry bigint;
  v_settlement_after_first bigint;
  v_settlement_after_retry bigint;
  v_commission_after_first bigint;
  v_commission_after_retry bigint;
  v_committed_at_first timestamptz;
  v_committed_at_retry timestamptz;
begin
  perform pg_temp.payment_reported_concurrency_reset_context();

  select
    o.id,
    oi.supplier_id,
    s.owner_profile_id,
    sp.clerk_user_id,
    oi.variant_id,
    sr.id
  into
    v_order_id,
    v_supplier_id,
    v_supplier_profile_id,
    v_supplier_clerk_user_id,
    v_variant_id,
    v_reservation_id
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.stock_reservations sr on sr.order_id = o.id
    and sr.product_id = oi.product_id
    and sr.variant_id = oi.variant_id
    and sr.reseller_product_id = oi.reseller_product_id
  join public.suppliers s on s.id = oi.supplier_id
  join public.profiles sp on sp.id = s.owner_profile_id
  where o.payment_method = 'pay_on_delivery'
    and o.payment_collection_status::text = 'not_collected'
    and o.deleted_at is null
    and sr.reservation_status = 'reserved'
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and sp.primary_role = 'supplier_owner'
    and sp.account_status = 'active'
    and sp.clerk_user_id is not null
  order by o.updated_at desc, o.id::text desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.payment_reported_concurrency_record('development fixture available', false, 'No reserved Pay on Delivery order exists for payment reported concurrency test');
    return;
  end if;

  delete from public.supplier_payment_reports where order_id = v_order_id;
  delete from public.commissions where order_id = v_order_id;
  delete from public.settlements where order_id = v_order_id;
  delete from public.audit_logs where target_entity_id = v_order_id and action in ('supplier_order_payment_reported', 'supplier_settlement_due_created');
  delete from public.audit_logs where target_entity_id = v_reservation_id and action = 'stock_sale_committed';
  delete from public.inventory_movements where order_id = v_order_id and movement_type = 'sale_committed';
  delete from public.delivery_arrangements where order_id = v_order_id;

  insert into public.delivery_arrangements(order_id, supplier_id, delivery_method, currency_code, expected_delivery_date, arranged_by_profile_id, idempotency_key)
  values (v_order_id, v_supplier_id, 'manually_arranged', 'GHS', current_date, v_supplier_profile_id, 'dev-payment-concurrency-arrangement');

  update public.orders
  set order_status = 'delivered'::text::public.order_status,
      delivery_status = 'delivered',
      payment_collection_status = 'not_collected',
      out_for_delivery_at = coalesce(out_for_delivery_at, now()),
      delivered_at = coalesce(delivered_at, now()),
      delivered_by_profile_id = coalesce(delivered_by_profile_id, v_supplier_profile_id),
      payment_reported_at = null,
      payment_reported_by_profile_id = null,
      payment_reported_idempotency_key = null,
      updated_at = now()
  where id = v_order_id;

  update public.stock_reservations
  set reservation_status = 'reserved',
      committed_at = null,
      released_at = null,
      updated_at = now()
  where id = v_reservation_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_before
  from public.product_variants
  where id = v_variant_id;

  perform pg_temp.payment_reported_concurrency_set_context(v_supplier_clerk_user_id);
  perform public.supplier_report_order_payment_received(v_order_id, 'DEV-CONCURRENCY-PAYMENT', null, 'supplier-payment-reported:dev-concurrency');
  perform pg_temp.payment_reported_concurrency_reset_context();

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after_first
  from public.product_variants
  where id = v_variant_id;
  select count(*) into v_report_after_first from public.supplier_payment_reports where order_id = v_order_id;
  select count(*) into v_settlement_after_first from public.settlements where order_id = v_order_id and deleted_at is null;
  select count(*) into v_commission_after_first from public.commissions where order_id = v_order_id;
  select count(*) into v_audit_after_first from public.audit_logs where target_entity_id = v_order_id and action = 'supplier_order_payment_reported';
  select committed_at into v_committed_at_first from public.stock_reservations where id = v_reservation_id;

  perform pg_temp.payment_reported_concurrency_set_context(v_supplier_clerk_user_id);
  perform public.supplier_report_order_payment_received(v_order_id, 'DEV-CONCURRENCY-PAYMENT', null, 'supplier-payment-reported:dev-concurrency');
  perform pg_temp.payment_reported_concurrency_reset_context();

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after_retry
  from public.product_variants
  where id = v_variant_id;
  select count(*) into v_report_after_retry from public.supplier_payment_reports where order_id = v_order_id;
  select count(*) into v_settlement_after_retry from public.settlements where order_id = v_order_id and deleted_at is null;
  select count(*) into v_commission_after_retry from public.commissions where order_id = v_order_id;
  select count(*) into v_audit_after_retry from public.audit_logs where target_entity_id = v_order_id and action = 'supplier_order_payment_reported';
  select committed_at into v_committed_at_retry from public.stock_reservations where id = v_reservation_id;

  perform pg_temp.payment_reported_concurrency_record('development fixture available', true);
  perform pg_temp.payment_reported_concurrency_record('first report commits reserved stock once', v_stock_after_first.reserved_stock_quantity = v_stock_before.reserved_stock_quantity - (select quantity from public.stock_reservations where id = v_reservation_id));
  perform pg_temp.payment_reported_concurrency_record('first report increases sold stock once', v_stock_after_first.sold_stock_quantity = v_stock_before.sold_stock_quantity + (select quantity from public.stock_reservations where id = v_reservation_id));
  perform pg_temp.payment_reported_concurrency_record('retry does not change reserved stock again', v_stock_after_retry.reserved_stock_quantity = v_stock_after_first.reserved_stock_quantity);
  perform pg_temp.payment_reported_concurrency_record('retry does not change sold stock again', v_stock_after_retry.sold_stock_quantity = v_stock_after_first.sold_stock_quantity);
  perform pg_temp.payment_reported_concurrency_record('retry preserves committed timestamp', v_committed_at_retry = v_committed_at_first);
  perform pg_temp.payment_reported_concurrency_record('retry creates no duplicate payment report', v_report_after_retry = v_report_after_first and v_report_after_retry = 1);
  perform pg_temp.payment_reported_concurrency_record('retry creates no duplicate settlement', v_settlement_after_retry = v_settlement_after_first and v_settlement_after_retry = 1);
  perform pg_temp.payment_reported_concurrency_record('retry creates no duplicate commission', v_commission_after_retry = v_commission_after_first);
  perform pg_temp.payment_reported_concurrency_record('retry creates no duplicate audit event', v_audit_after_retry = v_audit_after_first and v_audit_after_retry = 1);
end;
$$;

select test_name, passed, details
from supplier_order_payment_reported_concurrency_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_payment_reported_concurrency_results where not passed) then
    raise exception 'SUPPLIER_ORDER_PAYMENT_REPORTED_CONCURRENCY_TEST_FAILED';
  end if;
end;
$$;

rollback;
