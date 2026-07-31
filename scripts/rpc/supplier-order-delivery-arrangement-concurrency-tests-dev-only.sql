-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Delivery Arrangement Phase 1 idempotency/concurrency assertions.

begin;

create temp table supplier_order_delivery_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_delivery_concurrency_results to authenticated;

create or replace function pg_temp.supplier_order_delivery_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_delivery_concurrency_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update set passed = excluded.passed, details = excluded.details;
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_clerk_user_id text;
  v_reservation_id uuid;
  v_variant_id uuid;
  v_audit_before bigint;
  v_audit_after bigint;
  v_stock_before record;
  v_stock_after record;
  v_arranged_at timestamptz;
begin
  select o.id, p.clerk_user_id, sr.id, oi.variant_id
  into v_order_id, v_supplier_clerk_user_id, v_reservation_id, v_variant_id
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.stock_reservations sr on sr.order_id = o.id
  join public.suppliers s on s.id = oi.supplier_id
  join public.profiles p on p.id = s.owner_profile_id
  where o.order_status::text in ('ready_for_delivery', 'delivery_arranged')
    and o.ready_for_delivery_at is not null
    and sr.reservation_status = 'reserved'
    and p.clerk_user_id is not null
  order by o.updated_at desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.supplier_order_delivery_concurrency_record('ready development fixture available', false, 'No ready order fixture available');
    return;
  end if;

  delete from public.delivery_arrangements where order_id = v_order_id;
  update public.orders
  set order_status = 'ready_for_delivery'::text::public.order_status,
      ready_for_delivery_at = coalesce(ready_for_delivery_at, now()),
      delivery_arranged_at = null,
      delivery_arranged_by_profile_id = null,
      delivery_arrangement_idempotency_key = null
  where id = v_order_id;
  update public.stock_reservations set reservation_status = 'reserved', expires_at = now() + interval '1 day' where id = v_reservation_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_before from public.product_variants where id = v_variant_id;
  select count(*) into v_audit_before from public.audit_logs where target_entity_type = 'orders' and target_entity_id = v_order_id and action = 'supplier_order_delivery_arranged';

  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;

  perform public.supplier_arrange_order_delivery(v_order_id, 'supplier_rider', 10, current_date + 1, 'Morning', 'QA Rider', '+233200000000', 'QA instruction', 'QA private note', 'two-arrange-delivery-calls');
  perform public.supplier_arrange_order_delivery(v_order_id, 'supplier_rider', 10, current_date + 1, 'Morning', 'QA Rider', '+233200000000', 'QA instruction', 'QA private note', 'two-arrange-delivery-calls');

  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);

  select arranged_at into v_arranged_at from public.delivery_arrangements where order_id = v_order_id;
  select count(*) into v_audit_after from public.audit_logs where target_entity_type = 'orders' and target_entity_id = v_order_id and action = 'supplier_order_delivery_arranged';
  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_after from public.product_variants where id = v_variant_id;

  perform pg_temp.supplier_order_delivery_concurrency_record('one arrangement row', (select count(*) from public.delivery_arrangements where order_id = v_order_id) = 1);
  perform pg_temp.supplier_order_delivery_concurrency_record('one status transition', (select order_status::text from public.orders where id = v_order_id) = 'delivery_arranged');
  perform pg_temp.supplier_order_delivery_concurrency_record('one arranged timestamp', v_arranged_at is not null);
  perform pg_temp.supplier_order_delivery_concurrency_record('one audit event', v_audit_after = v_audit_before + 1);
  perform pg_temp.supplier_order_delivery_concurrency_record('reservation unchanged', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_delivery_concurrency_record('stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity and v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity and v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
  perform pg_temp.supplier_order_delivery_concurrency_record('payment unchanged', (select payment_collection_status::text from public.orders where id = v_order_id) = 'not_collected');

  begin
    perform set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier_clerk_user_id, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.supplier_arrange_order_delivery(v_order_id, 'third_party_courier', 20, current_date + 2, 'Afternoon', 'Other Courier', null, null, null, 'conflict-arrange-key');
    reset role;
    perform set_config('request.jwt.claims', '{}'::text, true);
    perform pg_temp.supplier_order_delivery_concurrency_record('no mixed arrangement fields', false, 'conflicting payload unexpectedly succeeded');
  exception when others then
    reset role;
    perform set_config('request.jwt.claims', '{}'::text, true);
    perform pg_temp.supplier_order_delivery_concurrency_record('no mixed arrangement fields', (select delivery_method from public.delivery_arrangements where order_id = v_order_id) = 'supplier_rider');
  end;
end;
$$;

select test_name, passed, details
from supplier_order_delivery_concurrency_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_delivery_concurrency_results where not passed) then
    raise exception 'Supplier delivery arrangement concurrency tests failed';
  end if;
end;
$$;

rollback;
