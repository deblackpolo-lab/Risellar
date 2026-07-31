-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Delivery Phase 2 out-for-delivery RPC boundary tests.
-- Uses transaction-scoped development order state and rolls back all changes.

begin;

create temp table supplier_order_out_for_delivery_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_out_for_delivery_test_results to anon, authenticated;

create or replace function pg_temp.supplier_order_out_for_delivery_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_out_for_delivery_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_out_for_delivery_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_out_for_delivery_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_out_for_delivery_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_out_for_delivery_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_out_for_delivery_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_id uuid;
  v_supplier_profile_id uuid;
  v_supplier_clerk_user_id text;
  v_order_customer_clerk_user_id text;
  v_product_id uuid;
  v_variant_id uuid;
  v_reseller_product_id uuid;
  v_reservation_id uuid;
  v_stock_before record;
  v_stock_after record;
  v_order_before record;
  v_order_after record;
  v_customer_read record;
  v_audit_before bigint;
  v_audit_after bigint;
  v_audit_after_retry bigint;
  v_delivery_quotes_before bigint := 0;
  v_delivery_quotes_after bigint := 0;
  v_payments_before bigint := 0;
  v_payments_after bigint := 0;
  v_commissions_before bigint := 0;
  v_commissions_after bigint := 0;
  v_settlements_before bigint := 0;
  v_settlements_after bigint := 0;
  v_withdrawals_before bigint := 0;
  v_withdrawals_after bigint := 0;
  v_refunds_before bigint := 0;
  v_refunds_after bigint := 0;
begin
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  select
    o.id,
    oi.supplier_id,
    s.owner_profile_id,
    p.clerk_user_id,
    cp.clerk_user_id,
    oi.product_id,
    oi.variant_id,
    oi.reseller_product_id,
    sr.id
  into
    v_order_id,
    v_supplier_id,
    v_supplier_profile_id,
    v_supplier_clerk_user_id,
    v_order_customer_clerk_user_id,
    v_product_id,
    v_variant_id,
    v_reseller_product_id,
    v_reservation_id
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.stock_reservations sr on sr.order_id = o.id
    and sr.product_id = oi.product_id
    and sr.variant_id = oi.variant_id
    and sr.reseller_product_id = oi.reseller_product_id
  join public.suppliers s on s.id = oi.supplier_id
  join public.profiles p on p.id = s.owner_profile_id
  join public.customers c on c.id = o.customer_id
  join public.profiles cp on cp.id = c.profile_id
  where o.order_status::text in ('delivery_arranged', 'ready_for_delivery', 'supplier_confirmed', 'supplier_preparing')
    and o.payment_collection_status = 'not_collected'
    and o.deleted_at is null
    and sr.reservation_status = 'reserved'
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and p.primary_role = 'supplier_owner'
    and p.account_status = 'active'
    and p.clerk_user_id is not null
    and cp.clerk_user_id is not null
  order by o.updated_at desc, o.id::text desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.supplier_order_out_for_delivery_record_result('delivery-arranged development fixture available', false, 'No reserved development order exists for out-for-delivery testing');
    return;
  end if;

  delete from public.delivery_arrangements where order_id = v_order_id;

  insert into public.delivery_arrangements(
    order_id,
    supplier_id,
    delivery_method,
    agreed_delivery_fee_amount,
    currency_code,
    expected_delivery_date,
    expected_time_window,
    courier_display_name,
    courier_phone,
    customer_instruction,
    supplier_private_note,
    arranged_by_profile_id,
    idempotency_key
  )
  values (
    v_order_id,
    v_supplier_id,
    'manually_arranged',
    20,
    'GHS',
    current_date + 1,
    'Development QA window',
    'Development QA courier',
    '+233200000000',
    'Development QA arrangement instruction',
    'Development QA supplier private note',
    v_supplier_profile_id,
    'dev-out-for-delivery-arrangement'
  );

  update public.orders
  set order_status = 'delivery_arranged'::text::public.order_status,
      payment_collection_status = 'not_collected',
      delivery_arranged_at = coalesce(delivery_arranged_at, now()),
      delivery_arranged_by_profile_id = coalesce(delivery_arranged_by_profile_id, v_supplier_profile_id),
      delivery_arrangement_idempotency_key = 'dev-out-for-delivery-arrangement',
      out_for_delivery_at = null,
      out_for_delivery_by_profile_id = null,
      out_for_delivery_idempotency_key = null,
      dispatch_reference = null,
      customer_dispatch_instruction = null,
      updated_at = now()
  where id = v_order_id;

  update public.stock_reservations
  set reservation_status = 'reserved',
      expires_at = now() + interval '1 day',
      released_at = null,
      committed_at = null,
      updated_at = now()
  where id = v_reservation_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_before
  from public.product_variants
  where id = v_variant_id;

  select order_status, payment_collection_status, total_payable_amount, final_delivery_amount, currency_code
  into v_order_before
  from public.orders
  where id = v_order_id;

  select count(*) into v_audit_before
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_out_for_delivery';

  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_quotes_before; end if;
  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_before; end if;
  if to_regclass('public.commissions') is not null then execute 'select count(*) from public.commissions' into v_commissions_before; end if;
  if to_regclass('public.settlements') is not null then execute 'select count(*) from public.settlements' into v_settlements_before; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_before; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_before; end if;

  perform pg_temp.supplier_order_out_for_delivery_set_context(v_supplier_clerk_user_id);
  execute format($sql$select public.supplier_mark_order_out_for_delivery(%L::uuid, 'DEV-DISPATCH-001', 'Development QA customer dispatch instruction', 'dev-out-for-delivery-key')$sql$, v_order_id);
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  select order_status, payment_collection_status, total_payable_amount, final_delivery_amount, currency_code, out_for_delivery_at, dispatch_reference, customer_dispatch_instruction
  into v_order_after
  from public.orders
  where id = v_order_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after
  from public.product_variants
  where id = v_variant_id;

  select count(*) into v_audit_after
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_out_for_delivery';

  perform pg_temp.supplier_order_out_for_delivery_record_result('supplier can mark arranged order out for delivery', v_order_after.order_status::text = 'out_for_delivery');
  perform pg_temp.supplier_order_out_for_delivery_record_result('out-for-delivery timestamp stored', v_order_after.out_for_delivery_at is not null);
  perform pg_temp.supplier_order_out_for_delivery_record_result('dispatch fields stored safely', v_order_after.dispatch_reference = 'DEV-DISPATCH-001' and v_order_after.customer_dispatch_instruction = 'Development QA customer dispatch instruction');
  perform pg_temp.supplier_order_out_for_delivery_record_result('payment remains not collected', v_order_after.payment_collection_status::text = 'not_collected');
  perform pg_temp.supplier_order_out_for_delivery_record_result('commercial snapshots unchanged', v_order_after.total_payable_amount = v_order_before.total_payable_amount and v_order_after.final_delivery_amount is not distinct from v_order_before.final_delivery_amount and v_order_after.currency_code = v_order_before.currency_code);
  perform pg_temp.supplier_order_out_for_delivery_record_result('reservation remains reserved', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_out_for_delivery_record_result('stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity and v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity and v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
  perform pg_temp.supplier_order_out_for_delivery_record_result('single audit event created', v_audit_after = v_audit_before + 1);

  perform pg_temp.supplier_order_out_for_delivery_set_context(v_supplier_clerk_user_id);
  execute format($sql$select public.supplier_mark_order_out_for_delivery(%L::uuid, 'DEV-DISPATCH-001', 'Development QA customer dispatch instruction', 'dev-out-for-delivery-key')$sql$, v_order_id);
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  select count(*) into v_audit_after_retry
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_out_for_delivery';

  perform pg_temp.supplier_order_out_for_delivery_record_result('idempotent retry has no duplicate audit', v_audit_after_retry = v_audit_after);
  perform pg_temp.supplier_order_out_for_delivery_record_result('idempotent retry has no stock change', (select reserved_stock_quantity from public.product_variants where id = v_variant_id) = v_stock_after.reserved_stock_quantity);

  perform pg_temp.supplier_order_out_for_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_out_for_delivery_expect_blocked(
    'conflicting retry is blocked',
    format($sql$select public.supplier_mark_order_out_for_delivery(%L::uuid, 'DEV-DISPATCH-002', 'Different instruction', 'different-dev-out-for-delivery-key')$sql$, v_order_id)
  );
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  update public.orders
  set order_status = 'delivery_arranged'::text::public.order_status,
      out_for_delivery_at = null,
      out_for_delivery_by_profile_id = null,
      out_for_delivery_idempotency_key = null,
      dispatch_reference = null,
      customer_dispatch_instruction = null
  where id = v_order_id;

  perform pg_temp.supplier_order_out_for_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_out_for_delivery_expect_blocked(
    'live tracking dispatch text is blocked',
    format($sql$select public.supplier_mark_order_out_for_delivery(%L::uuid, 'GPS link', 'Live tracking available', 'blocked-tracking-key')$sql$, v_order_id)
  );
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  update public.orders
  set order_status = 'ready_for_delivery'::text::public.order_status
  where id = v_order_id;

  perform pg_temp.supplier_order_out_for_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_out_for_delivery_expect_blocked(
    'ready order must be arranged before dispatch',
    format($sql$select public.supplier_mark_order_out_for_delivery(%L::uuid, null, null, 'blocked-not-arranged-key')$sql$, v_order_id)
  );
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  update public.orders
  set order_status = 'delivery_arranged'::text::public.order_status
  where id = v_order_id;

  perform pg_temp.supplier_order_out_for_delivery_set_context(v_order_customer_clerk_user_id);
  perform pg_temp.supplier_order_out_for_delivery_expect_blocked(
    'customer cannot mark supplier order out for delivery',
    format($sql$select public.supplier_mark_order_out_for_delivery(%L::uuid, null, null, 'blocked-customer-key')$sql$, v_order_id)
  );
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  update public.orders
  set order_status = 'out_for_delivery'::text::public.order_status,
      out_for_delivery_at = now(),
      customer_dispatch_instruction = 'Development QA customer dispatch instruction'
  where id = v_order_id;

  perform pg_temp.supplier_order_out_for_delivery_set_context(v_order_customer_clerk_user_id);
  select * into v_customer_read from public.get_customer_order_safe(v_order_id);
  perform pg_temp.supplier_order_out_for_delivery_reset_context();

  perform pg_temp.supplier_order_out_for_delivery_record_result('customer read shows safe out-for-delivery status', v_customer_read.order_status_label = 'Your order is out for delivery' and v_customer_read.delivery_status_label = 'Delivery has started outside Risellar');
  perform pg_temp.supplier_order_out_for_delivery_record_result('customer read shows safe dispatch instruction', v_customer_read.customer_dispatch_instruction = 'Development QA customer dispatch instruction' and v_customer_read.dispatch_notice is not null);

  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_quotes_after; end if;
  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_after; end if;
  if to_regclass('public.commissions') is not null then execute 'select count(*) from public.commissions' into v_commissions_after; end if;
  if to_regclass('public.settlements') is not null then execute 'select count(*) from public.settlements' into v_settlements_after; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_after; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_after; end if;

  perform pg_temp.supplier_order_out_for_delivery_record_result('no payment or delivery quote side effects', v_delivery_quotes_after = v_delivery_quotes_before and v_payments_after = v_payments_before);
  perform pg_temp.supplier_order_out_for_delivery_record_result('no finance side effects', v_commissions_after = v_commissions_before and v_settlements_after = v_settlements_before and v_withdrawals_after = v_withdrawals_before and v_refunds_after = v_refunds_before);
end;
$$;

select test_name, passed, details
from supplier_order_out_for_delivery_test_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_out_for_delivery_test_results where not passed) then
    raise exception 'Supplier out-for-delivery RPC tests failed';
  end if;
end;
$$;

rollback;
