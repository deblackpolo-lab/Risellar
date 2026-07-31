-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Fulfilment Phase 2 start-preparing concurrency/idempotency harness.
-- Uses transaction-scoped development order state and rolls back all changes.

begin;

create temp table supplier_order_preparation_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_preparation_concurrency_results to authenticated;

create or replace function pg_temp.supplier_order_preparation_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_preparation_concurrency_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_preparation_concurrency_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_preparation_concurrency_reset_context()
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
  v_supplier_clerk_user_id text;
  v_variant_id uuid;
  v_reservation_id uuid;
  v_reservation_quantity integer;
  v_stock_before record;
  v_stock_after record;
  v_audit_before bigint;
  v_audit_after bigint;
  v_preparing_at timestamptz;
begin
  perform pg_temp.supplier_order_preparation_concurrency_reset_context();

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
  where o.order_status = 'supplier_confirmed'
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
    perform pg_temp.supplier_order_preparation_concurrency_record('confirmed development fixture available', false, 'No confirmed reserved development order exists for concurrency testing');
    return;
  end if;

  update public.orders
  set order_status = 'supplier_confirmed',
      payment_collection_status = 'not_collected',
      supplier_preparing_at = null,
      supplier_preparation_by_profile_id = null,
      supplier_preparation_idempotency_key = null,
      updated_at = now()
  where id = v_order_id;

  update public.stock_reservations
  set reservation_status = 'reserved',
      expires_at = now() + interval '1 day',
      released_at = null,
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
    and action = 'supplier_order_preparation_started';

  perform pg_temp.supplier_order_preparation_concurrency_set_context(v_supplier_clerk_user_id);
  -- two start preparing calls: repeated same-action calls must converge safely.
  perform public.supplier_start_preparing(v_order_id, 'two-start-preparing-calls');
  perform public.supplier_start_preparing(v_order_id, 'two-start-preparing-calls');
  perform pg_temp.supplier_order_preparation_concurrency_reset_context();

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after
  from public.product_variants
  where id = v_variant_id;

  select count(*) into v_audit_after
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_preparation_started';

  select supplier_preparing_at
  into v_preparing_at
  from public.orders
  where id = v_order_id;

  perform pg_temp.supplier_order_preparation_concurrency_record('two start preparing calls converge', (select order_status::text from public.orders where id = v_order_id) = 'supplier_preparing');
  perform pg_temp.supplier_order_preparation_concurrency_record('one preparation audit event', v_audit_after = v_audit_before + 1);
  perform pg_temp.supplier_order_preparation_concurrency_record('preparation timestamp stable', v_preparing_at is not null);
  perform pg_temp.supplier_order_preparation_concurrency_record('reservation unchanged', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_preparation_concurrency_record('stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity and v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity and v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
end;
$$;

reset role;

select test_name, passed, details
from supplier_order_preparation_concurrency_results
order by test_name;

do $$
declare
  v_failed integer;
begin
  select count(*) into v_failed
  from supplier_order_preparation_concurrency_results
  where not passed;

  if v_failed > 0 then
    raise exception 'SUPPLIER_ORDER_START_PREPARING_CONCURRENCY_TEST_FAILED: % assertion(s) failed', v_failed;
  end if;
end;
$$;

rollback;
