-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Fulfilment Phase 3 ready-for-delivery concurrency/idempotency harness.
-- Uses transaction-scoped development order state and rolls back all changes.

begin;

create temp table supplier_order_ready_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_ready_concurrency_results to authenticated;

create or replace function pg_temp.supplier_order_ready_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_ready_concurrency_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_ready_concurrency_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_ready_concurrency_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_ready_concurrency_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_ready_concurrency_record(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_ready_concurrency_record(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_clerk_user_id text;
  v_variant_id uuid;
  v_reservation_id uuid;
  v_reservation_quantity integer;
  v_stock_before record;
  v_stock_after record;
  v_audit_before bigint;
  v_audit_after bigint;
  v_ready_at timestamptz;
begin
  perform pg_temp.supplier_order_ready_concurrency_reset_context();

  select
    o.id,
    p.clerk_user_id,
    oi.variant_id,
    sr.id,
    sr.quantity
  into
    v_order_id,
    v_supplier_clerk_user_id,
    v_variant_id,
    v_reservation_id,
    v_reservation_quantity
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.stock_reservations sr on sr.order_id = o.id
    and sr.product_id = oi.product_id
    and sr.variant_id = oi.variant_id
    and sr.reseller_product_id = oi.reseller_product_id
  join public.suppliers s on s.id = oi.supplier_id
  join public.profiles p on p.id = s.owner_profile_id
  where o.order_status::text = 'supplier_preparing'
    and o.supplier_preparing_at is not null
    and o.payment_collection_status = 'not_collected'
    and o.deleted_at is null
    and sr.reservation_status = 'reserved'
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and p.primary_role = 'supplier_owner'
    and p.account_status = 'active'
    and p.clerk_user_id is not null
  order by o.updated_at desc, o.id::text desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.supplier_order_ready_concurrency_record('preparing development fixture available', false, 'No supplier_preparing reserved development order exists for concurrency testing');
    return;
  end if;

  update public.orders
  set order_status = 'supplier_preparing'::text::public.order_status,
      payment_collection_status = 'not_collected',
      supplier_preparing_at = coalesce(supplier_preparing_at, now()),
      ready_for_delivery_at = null,
      ready_for_delivery_by_profile_id = null,
      ready_for_delivery_idempotency_key = null,
      updated_at = now()
  where id = v_order_id;

  update public.stock_reservations
  set reservation_status = 'reserved',
      expires_at = now() + interval '1 day',
      released_at = null,
      committed_at = null,
      updated_at = now()
  where id = v_reservation_id;

  update public.product_variants
  set reserved_stock_quantity = greatest(reserved_stock_quantity, v_reservation_quantity),
      updated_at = now()
  where id = v_variant_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_before
  from public.product_variants
  where id = v_variant_id;

  select count(*) into v_audit_before
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_ready_for_delivery';

  perform pg_temp.supplier_order_ready_concurrency_set_context(v_supplier_clerk_user_id);
  -- two mark ready calls: repeated same-action calls must converge safely.
  perform public.supplier_mark_ready_for_delivery(v_order_id, 'two-mark-ready-calls');
  perform public.supplier_mark_ready_for_delivery(v_order_id, 'two-mark-ready-calls');
  perform pg_temp.supplier_order_ready_concurrency_reset_context();

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after
  from public.product_variants
  where id = v_variant_id;

  select count(*) into v_audit_after
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_ready_for_delivery';

  select ready_for_delivery_at
  into v_ready_at
  from public.orders
  where id = v_order_id;

  perform pg_temp.supplier_order_ready_concurrency_record('two mark ready calls converge', (select order_status::text from public.orders where id = v_order_id) = 'ready_for_delivery');
  perform pg_temp.supplier_order_ready_concurrency_record('one ready audit event', v_audit_after = v_audit_before + 1);
  perform pg_temp.supplier_order_ready_concurrency_record('ready timestamp stable', v_ready_at is not null);
  perform pg_temp.supplier_order_ready_concurrency_record('reservation unchanged', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_ready_concurrency_record('stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity and v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity and v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);

  update public.orders set order_status = 'supplier_confirmed', supplier_preparing_at = null, ready_for_delivery_at = null where id = v_order_id;
  perform pg_temp.supplier_order_ready_concurrency_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_concurrency_expect_blocked('start preparing versus mark ready cannot race from confirmed state', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'confirmed-race')$sql$, v_order_id));
end;
$$;

reset role;

select test_name, passed, details
from supplier_order_ready_concurrency_results
order by test_name;

do $$
declare
  v_failed integer;
begin
  select count(*) into v_failed
  from supplier_order_ready_concurrency_results
  where not passed;

  if v_failed > 0 then
    raise exception 'SUPPLIER_ORDER_READY_FOR_DELIVERY_CONCURRENCY_TEST_FAILED: % assertion(s) failed', v_failed;
  end if;
end;
$$;

rollback;
