-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Delivery Phase 3 delivered idempotency/concurrency assertions.

begin;

create temp table supplier_order_delivered_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_delivered_concurrency_results to authenticated;

create or replace function pg_temp.supplier_order_delivered_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_delivered_concurrency_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update set passed = excluded.passed, details = excluded.details;
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_id uuid;
  v_supplier_profile_id uuid;
  v_supplier_clerk_user_id text;
  v_reservation_id uuid;
  v_variant_id uuid;
  v_stock_before record;
  v_stock_after record;
  v_delivered_at timestamptz;
  v_audit_before bigint;
  v_audit_after bigint;
begin
  select o.id, oi.supplier_id, s.owner_profile_id, p.clerk_user_id, sr.id, oi.variant_id
  into v_order_id, v_supplier_id, v_supplier_profile_id, v_supplier_clerk_user_id, v_reservation_id, v_variant_id
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.stock_reservations sr on sr.order_id = o.id
  join public.suppliers s on s.id = oi.supplier_id
  join public.profiles p on p.id = s.owner_profile_id
  where o.payment_collection_status = 'not_collected'
    and sr.reservation_status = 'reserved'
    and p.clerk_user_id is not null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
  order by o.updated_at desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.supplier_order_delivered_concurrency_record('out-for-delivery development fixture available', false, 'No reserved order fixture available');
    return;
  end if;

  delete from public.delivery_arrangements where order_id = v_order_id;
  insert into public.delivery_arrangements(
    order_id,
    supplier_id,
    delivery_method,
    agreed_delivery_fee_amount,
    currency_code,
    customer_instruction,
    supplier_private_note,
    arranged_by_profile_id,
    idempotency_key
  ) values (
    v_order_id,
    v_supplier_id,
    'manually_arranged',
    10,
    'GHS',
    'Concurrency delivered customer arrangement instruction',
    'Concurrency delivered supplier private note',
    v_supplier_profile_id,
    'concurrency-delivered-arrangement-key'
  );

  update public.orders
  set order_status = 'out_for_delivery'::text::public.order_status,
      delivery_status = 'out_for_delivery'::public.delivery_status,
      delivery_arranged_at = coalesce(delivery_arranged_at, now()),
      delivery_arranged_by_profile_id = coalesce(delivery_arranged_by_profile_id, v_supplier_profile_id),
      delivery_arrangement_idempotency_key = 'concurrency-delivered-arrangement-key',
      out_for_delivery_at = coalesce(out_for_delivery_at, now()),
      out_for_delivery_by_profile_id = coalesce(out_for_delivery_by_profile_id, v_supplier_profile_id),
      out_for_delivery_idempotency_key = 'concurrency-delivered-dispatch-key',
      dispatch_reference = 'CONCURRENCY-DELIVERED-DISPATCH',
      customer_dispatch_instruction = 'Concurrency delivered dispatch instruction',
      delivered_at = null,
      delivered_by_profile_id = null,
      delivered_idempotency_key = null,
      delivery_confirmation_note = null,
      payment_collection_status = 'not_collected'
  where id = v_order_id;

  update public.stock_reservations
  set reservation_status = 'reserved',
      expires_at = now() + interval '1 day',
      released_at = null,
      committed_at = null
  where id = v_reservation_id;

  delete from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_delivered';

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_before from public.product_variants where id = v_variant_id;
  select count(*) into v_audit_before from public.audit_logs where target_entity_type = 'orders' and target_entity_id = v_order_id and action = 'supplier_order_delivered';

  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;

  perform public.supplier_mark_order_delivered(v_order_id, 'Concurrency delivered note', 'two-delivered-calls');
  perform public.supplier_mark_order_delivered(v_order_id, 'Concurrency delivered note', 'two-delivered-calls');

  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);

  select delivered_at into v_delivered_at from public.orders where id = v_order_id;
  select count(*) into v_audit_after from public.audit_logs where target_entity_type = 'orders' and target_entity_id = v_order_id and action = 'supplier_order_delivered';
  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_after from public.product_variants where id = v_variant_id;

  perform pg_temp.supplier_order_delivered_concurrency_record('one status transition', (select order_status::text from public.orders where id = v_order_id) = 'delivered');
  perform pg_temp.supplier_order_delivered_concurrency_record('one delivered timestamp', v_delivered_at is not null);
  perform pg_temp.supplier_order_delivered_concurrency_record('one audit event', v_audit_after = v_audit_before + 1);
  perform pg_temp.supplier_order_delivered_concurrency_record('one durable note', (select delivery_confirmation_note from public.orders where id = v_order_id) = 'Concurrency delivered note');
  perform pg_temp.supplier_order_delivered_concurrency_record('reservation unchanged', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_delivered_concurrency_record('stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity and v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity and v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
  perform pg_temp.supplier_order_delivered_concurrency_record('payment unchanged', (select payment_collection_status::text from public.orders where id = v_order_id) = 'not_collected');

  begin
    perform set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier_clerk_user_id, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.supplier_mark_order_delivered(v_order_id, 'Different concurrency delivered note', 'different-delivered-key');
    reset role;
    perform set_config('request.jwt.claims', '{}'::text, true);
    perform pg_temp.supplier_order_delivered_concurrency_record('no mixed delivery note', false, 'conflicting payload unexpectedly succeeded');
  exception when others then
    reset role;
    perform set_config('request.jwt.claims', '{}'::text, true);
    perform pg_temp.supplier_order_delivered_concurrency_record('no mixed delivery note', (select delivery_confirmation_note from public.orders where id = v_order_id) = 'Concurrency delivered note');
  end;
end;
$$;

select test_name, passed, details
from supplier_order_delivered_concurrency_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_delivered_concurrency_results where not passed) then
    raise exception 'Supplier delivered concurrency tests failed';
  end if;
end;
$$;

rollback;
