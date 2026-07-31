-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Delivery Phase 2 out-for-delivery idempotency/concurrency assertions.

begin;

create temp table supplier_order_out_for_delivery_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_out_for_delivery_concurrency_results to authenticated;

create or replace function pg_temp.supplier_order_out_for_delivery_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_out_for_delivery_concurrency_results(test_name, passed, details)
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
  v_audit_before bigint;
  v_audit_after bigint;
  v_dispatched_at timestamptz;
begin
  select o.id, oi.supplier_id, s.owner_profile_id, p.clerk_user_id, sr.id, oi.variant_id
  into v_order_id, v_supplier_id, v_supplier_profile_id, v_supplier_clerk_user_id, v_reservation_id, v_variant_id
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.stock_reservations sr on sr.order_id = o.id
  join public.suppliers s on s.id = oi.supplier_id
  join public.profiles p on p.id = s.owner_profile_id
  where o.order_status::text in ('delivery_arranged', 'ready_for_delivery', 'supplier_confirmed', 'supplier_preparing')
    and o.payment_collection_status = 'not_collected'
    and sr.reservation_status = 'reserved'
    and p.clerk_user_id is not null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
  order by o.updated_at desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.supplier_order_out_for_delivery_concurrency_record('delivery-arranged development fixture available', false, 'No reserved order fixture available');
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
  )
  values (
    v_order_id,
    v_supplier_id,
    'manually_arranged',
    10,
    'GHS',
    'Concurrency customer arrangement instruction',
    'Concurrency supplier private note',
    v_supplier_profile_id,
    'concurrency-arrangement-key'
  );

  update public.orders
  set order_status = 'delivery_arranged'::text::public.order_status,
      delivery_arranged_at = coalesce(delivery_arranged_at, now()),
      delivery_arranged_by_profile_id = coalesce(delivery_arranged_by_profile_id, v_supplier_profile_id),
      delivery_arrangement_idempotency_key = 'concurrency-arrangement-key',
      out_for_delivery_at = null,
      out_for_delivery_by_profile_id = null,
      out_for_delivery_idempotency_key = null,
      dispatch_reference = null,
      customer_dispatch_instruction = null,
      payment_collection_status = 'not_collected'
  where id = v_order_id;

  update public.stock_reservations
  set reservation_status = 'reserved',
      expires_at = now() + interval '1 day',
      released_at = null,
      committed_at = null
  where id = v_reservation_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_before from public.product_variants where id = v_variant_id;
  select count(*) into v_audit_before from public.audit_logs where target_entity_type = 'orders' and target_entity_id = v_order_id and action = 'supplier_order_out_for_delivery';

  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;

  perform public.supplier_mark_order_out_for_delivery(v_order_id, 'CONCURRENCY-DISPATCH-001', 'Concurrency customer dispatch instruction', 'two-out-for-delivery-calls');
  perform public.supplier_mark_order_out_for_delivery(v_order_id, 'CONCURRENCY-DISPATCH-001', 'Concurrency customer dispatch instruction', 'two-out-for-delivery-calls');

  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);

  select out_for_delivery_at into v_dispatched_at from public.orders where id = v_order_id;
  select count(*) into v_audit_after from public.audit_logs where target_entity_type = 'orders' and target_entity_id = v_order_id and action = 'supplier_order_out_for_delivery';
  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_after from public.product_variants where id = v_variant_id;

  perform pg_temp.supplier_order_out_for_delivery_concurrency_record('one status transition', (select order_status::text from public.orders where id = v_order_id) = 'out_for_delivery');
  perform pg_temp.supplier_order_out_for_delivery_concurrency_record('one dispatch timestamp', v_dispatched_at is not null);
  perform pg_temp.supplier_order_out_for_delivery_concurrency_record('one audit event', v_audit_after = v_audit_before + 1);
  perform pg_temp.supplier_order_out_for_delivery_concurrency_record('reservation unchanged', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_out_for_delivery_concurrency_record('stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity and v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity and v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
  perform pg_temp.supplier_order_out_for_delivery_concurrency_record('payment unchanged', (select payment_collection_status::text from public.orders where id = v_order_id) = 'not_collected');

  begin
    perform set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier_clerk_user_id, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.supplier_mark_order_out_for_delivery(v_order_id, 'CONCURRENCY-DISPATCH-002', 'Different customer dispatch instruction', 'conflict-out-for-delivery-key');
    reset role;
    perform set_config('request.jwt.claims', '{}'::text, true);
    perform pg_temp.supplier_order_out_for_delivery_concurrency_record('no mixed dispatch fields', false, 'conflicting payload unexpectedly succeeded');
  exception when others then
    reset role;
    perform set_config('request.jwt.claims', '{}'::text, true);
    perform pg_temp.supplier_order_out_for_delivery_concurrency_record('no mixed dispatch fields', (select dispatch_reference from public.orders where id = v_order_id) = 'CONCURRENCY-DISPATCH-001');
  end;
end;
$$;

select test_name, passed, details
from supplier_order_out_for_delivery_concurrency_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_out_for_delivery_concurrency_results where not passed) then
    raise exception 'Supplier out-for-delivery concurrency tests failed';
  end if;
end;
$$;

rollback;
