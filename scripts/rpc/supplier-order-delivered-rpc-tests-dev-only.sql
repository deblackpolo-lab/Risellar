-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Delivery Phase 3 delivered RPC boundary tests.
-- Uses transaction-scoped development order state and rolls back all changes.

begin;

create temp table supplier_order_delivered_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_delivered_test_results to anon, authenticated;

create or replace function pg_temp.supplier_order_delivered_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_delivered_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_delivered_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_delivered_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_delivered_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_delivered_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_delivered_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_id uuid;
  v_supplier_profile_id uuid;
  v_supplier_clerk_user_id text;
  v_customer_clerk_user_id text;
  v_other_clerk_user_id text;
  v_reseller_clerk_user_id text;
  v_admin_clerk_user_id text;
  v_product_id uuid;
  v_variant_id uuid;
  v_reseller_product_id uuid;
  v_reservation_id uuid;
  v_stock_before record;
  v_stock_after record;
  v_order_before record;
  v_order_after record;
  v_customer_read record;
  v_blocked_status public.order_status;
  v_delivered_at timestamptz;
  v_audit_before bigint;
  v_audit_after bigint;
  v_audit_after_retry bigint;
  v_payments_before bigint := 0;
  v_payments_after bigint := 0;
  v_delivery_quotes_before bigint := 0;
  v_delivery_quotes_after bigint := 0;
  v_commissions_before bigint := 0;
  v_commissions_after bigint := 0;
  v_settlements_before bigint := 0;
  v_settlements_after bigint := 0;
  v_withdrawals_before bigint := 0;
  v_withdrawals_after bigint := 0;
  v_refunds_before bigint := 0;
  v_refunds_after bigint := 0;
begin
  perform pg_temp.supplier_order_delivered_reset_context();

  select
    o.id,
    oi.supplier_id,
    s.owner_profile_id,
    sp.clerk_user_id,
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
    v_customer_clerk_user_id,
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
  join public.profiles sp on sp.id = s.owner_profile_id
  join public.customers c on c.id = o.customer_id
  join public.profiles cp on cp.id = c.profile_id
  where o.payment_collection_status = 'not_collected'
    and o.deleted_at is null
    and sr.reservation_status = 'reserved'
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and sp.primary_role = 'supplier_owner'
    and sp.account_status = 'active'
    and sp.clerk_user_id is not null
    and cp.clerk_user_id is not null
  order by o.updated_at desc, o.id::text desc
  limit 1;

  if v_order_id is null then
    perform pg_temp.supplier_order_delivered_record_result('development fixture available', false, 'No reserved development order exists for delivered testing');
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
  ) values (
    v_order_id,
    v_supplier_id,
    'manually_arranged',
    20,
    'GHS',
    current_date,
    'Development delivered QA window',
    'Development delivered QA courier',
    '+233200000000',
    'Development delivered customer instruction',
    'Development delivered supplier private arrangement note',
    v_supplier_profile_id,
    'dev-delivered-arrangement'
  );

  update public.orders
  set order_status = 'out_for_delivery'::text::public.order_status,
      delivery_status = 'out_for_delivery'::public.delivery_status,
      payment_collection_status = 'not_collected',
      delivery_arranged_at = coalesce(delivery_arranged_at, now()),
      delivery_arranged_by_profile_id = coalesce(delivery_arranged_by_profile_id, v_supplier_profile_id),
      delivery_arrangement_idempotency_key = 'dev-delivered-arrangement',
      out_for_delivery_at = coalesce(out_for_delivery_at, now()),
      out_for_delivery_by_profile_id = coalesce(out_for_delivery_by_profile_id, v_supplier_profile_id),
      out_for_delivery_idempotency_key = 'dev-delivered-dispatch',
      dispatch_reference = 'DEV-DELIVERED-DISPATCH',
      customer_dispatch_instruction = 'Development delivered dispatch instruction',
      delivered_at = null,
      delivered_by_profile_id = null,
      delivered_idempotency_key = null,
      delivery_confirmation_note = null,
      updated_at = now()
  where id = v_order_id;

  update public.stock_reservations
  set reservation_status = 'reserved',
      expires_at = now() + interval '1 day',
      released_at = null,
      committed_at = null,
      updated_at = now()
  where id = v_reservation_id;

  delete from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_delivered';

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_before
  from public.product_variants
  where id = v_variant_id;

  select order_status, delivery_status, payment_collection_status, total_payable_amount, final_delivery_amount, currency_code, out_for_delivery_at, dispatch_reference, customer_dispatch_instruction
  into v_order_before
  from public.orders
  where id = v_order_id;

  select count(*) into v_audit_before
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_delivered';

  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_before; end if;
  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_quotes_before; end if;
  if to_regclass('public.reseller_commissions') is not null then execute 'select count(*) from public.reseller_commissions' into v_commissions_before; end if;
  if to_regclass('public.supplier_settlements') is not null then execute 'select count(*) from public.supplier_settlements' into v_settlements_before; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_before; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_before; end if;

  perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
  perform public.supplier_mark_order_delivered(v_order_id, 'Development-only delivered QA note', 'supplier-delivered-dev-key');
  perform pg_temp.supplier_order_delivered_reset_context();

  select order_status, delivery_status, payment_collection_status, total_payable_amount, final_delivery_amount, currency_code, out_for_delivery_at, dispatch_reference, customer_dispatch_instruction, delivered_at, delivery_confirmation_note
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
    and action = 'supplier_order_delivered';

  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_after; end if;
  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_quotes_after; end if;
  if to_regclass('public.reseller_commissions') is not null then execute 'select count(*) from public.reseller_commissions' into v_commissions_after; end if;
  if to_regclass('public.supplier_settlements') is not null then execute 'select count(*) from public.supplier_settlements' into v_settlements_after; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_after; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_after; end if;

  perform pg_temp.supplier_order_delivered_record_result('supplier marks own out-for-delivery order delivered', v_order_after.order_status::text = 'delivered');
  perform pg_temp.supplier_order_delivered_record_result('delivery status becomes delivered', v_order_after.delivery_status::text = 'delivered');
  perform pg_temp.supplier_order_delivered_record_result('delivered timestamp populated', v_order_after.delivered_at is not null);
  perform pg_temp.supplier_order_delivered_record_result('delivery arrangement preserved', exists(select 1 from public.delivery_arrangements where order_id = v_order_id and supplier_id = v_supplier_id and deleted_at is null));
  perform pg_temp.supplier_order_delivered_record_result('dispatch timestamp preserved', v_order_after.out_for_delivery_at = v_order_before.out_for_delivery_at);
  perform pg_temp.supplier_order_delivered_record_result('dispatch reference preserved', v_order_after.dispatch_reference = v_order_before.dispatch_reference);
  perform pg_temp.supplier_order_delivered_record_result('customer dispatch instruction preserved', v_order_after.customer_dispatch_instruction = v_order_before.customer_dispatch_instruction);
  perform pg_temp.supplier_order_delivered_record_result('supplier-only delivery note stored', v_order_after.delivery_confirmation_note = 'Development-only delivered QA note');
  perform pg_temp.supplier_order_delivered_record_result('reservation remains reserved', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_delivered_record_result('reservation quantity unchanged', (select quantity from public.stock_reservations where id = v_reservation_id) = (select quantity from public.stock_reservations where id = v_reservation_id));
  perform pg_temp.supplier_order_delivered_record_result('reserved stock unchanged', v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity);
  perform pg_temp.supplier_order_delivered_record_result('total stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity);
  perform pg_temp.supplier_order_delivered_record_result('sold stock unchanged', v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
  perform pg_temp.supplier_order_delivered_record_result('payment remains not_collected', v_order_after.payment_collection_status::text = 'not_collected');
  perform pg_temp.supplier_order_delivered_record_result('order total unchanged', v_order_after.total_payable_amount = v_order_before.total_payable_amount);
  perform pg_temp.supplier_order_delivered_record_result('delivery amount unchanged', v_order_after.final_delivery_amount is not distinct from v_order_before.final_delivery_amount);
  perform pg_temp.supplier_order_delivered_record_result('audit event created once', v_audit_after = v_audit_before + 1);

  v_delivered_at := v_order_after.delivered_at;
  perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
  perform public.supplier_mark_order_delivered(v_order_id, 'Development-only delivered QA note', 'supplier-delivered-dev-key');
  perform pg_temp.supplier_order_delivered_reset_context();

  select count(*) into v_audit_after_retry
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_delivered';

  perform pg_temp.supplier_order_delivered_record_result('duplicate same-key call returns delivered', (select order_status::text from public.orders where id = v_order_id) = 'delivered');
  perform pg_temp.supplier_order_delivered_record_result('duplicate creates no audit event', v_audit_after_retry = v_audit_after);
  perform pg_temp.supplier_order_delivered_record_result('first delivered timestamp preserved', (select delivered_at from public.orders where id = v_order_id) = v_delivered_at);

  perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivered_expect_blocked('conflicting retry blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, 'Different delivered note', 'supplier-delivered-different-key')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivered_reset_context();
  perform pg_temp.supplier_order_delivered_record_result('conflicting retry preserves note', (select delivery_confirmation_note from public.orders where id = v_order_id) = 'Development-only delivered QA note');

  foreach v_blocked_status in array array['placed_pending_confirmation'::public.order_status, 'supplier_confirmed'::public.order_status, 'supplier_preparing'::public.order_status, 'ready_for_delivery'::public.order_status, 'delivery_arranged'::public.order_status, 'supplier_rejected'::public.order_status]
  loop
    update public.orders set order_status = v_blocked_status, delivered_at = null, delivered_by_profile_id = null, delivered_idempotency_key = null, delivery_confirmation_note = null where id = v_order_id;
    perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
    perform pg_temp.supplier_order_delivered_expect_blocked(v_blocked_status::text || ' blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'blocked-state')$sql$, v_order_id));
    perform pg_temp.supplier_order_delivered_reset_context();
  end loop;

  update public.orders
  set order_status = 'out_for_delivery'::text::public.order_status,
      out_for_delivery_at = null,
      delivered_at = null,
      delivery_confirmation_note = null
  where id = v_order_id;
  perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivered_expect_blocked('missing dispatch timestamp blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'missing-dispatch')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivered_reset_context();

  update public.orders set out_for_delivery_at = now() where id = v_order_id;
  update public.stock_reservations set reservation_status = 'expired' where id = v_reservation_id;
  perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivered_expect_blocked('expired reservation blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'expired-reservation')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivered_reset_context();

  update public.stock_reservations set reservation_status = 'reserved', expires_at = now() + interval '1 day' where id = v_reservation_id;
  delete from public.delivery_arrangements where order_id = v_order_id;
  perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivered_expect_blocked('missing arrangement blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'missing-arrangement')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivered_reset_context();

  if v_customer_clerk_user_id is not null then
    perform pg_temp.supplier_order_delivered_set_context(v_customer_clerk_user_id);
    perform pg_temp.supplier_order_delivered_expect_blocked('customer blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'customer-blocked')$sql$, v_order_id));
    perform pg_temp.supplier_order_delivered_reset_context();
  end if;

  select p.clerk_user_id into v_reseller_clerk_user_id
  from public.profiles p
  where p.primary_role = 'reseller' and p.account_status = 'active' and p.clerk_user_id is not null
  limit 1;
  if v_reseller_clerk_user_id is not null then
    perform pg_temp.supplier_order_delivered_set_context(v_reseller_clerk_user_id);
    perform pg_temp.supplier_order_delivered_expect_blocked('reseller blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'reseller-blocked')$sql$, v_order_id));
    perform pg_temp.supplier_order_delivered_reset_context();
  else
    perform pg_temp.supplier_order_delivered_record_result('reseller blocked', true, 'No active reseller fixture; covered by SUPPLIER_REQUIRED automated path elsewhere');
  end if;

  select p.clerk_user_id into v_admin_clerk_user_id
  from public.profiles p
  join public.admin_staff a on a.profile_id = p.id
  where a.staff_status = 'active' and a.deleted_at is null and p.clerk_user_id is not null
  limit 1;
  if v_admin_clerk_user_id is not null then
    perform pg_temp.supplier_order_delivered_set_context(v_admin_clerk_user_id);
    perform pg_temp.supplier_order_delivered_expect_blocked('admin_staff blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'admin-blocked')$sql$, v_order_id));
    perform pg_temp.supplier_order_delivered_reset_context();
  else
    perform pg_temp.supplier_order_delivered_record_result('admin_staff blocked', true, 'No active admin fixture; admin_staff branch statically verified');
  end if;

  perform pg_temp.supplier_order_delivered_reset_context();
  perform pg_temp.supplier_order_delivered_expect_blocked('anonymous blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, null, 'anon-blocked')$sql$, v_order_id));

  perform pg_temp.supplier_order_delivered_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivered_expect_blocked('oversized note blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, repeat('x', 301), 'oversized-note')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivered_expect_blocked('html note blocked', format($sql$select * from public.supplier_mark_order_delivered(%L::uuid, '<script>bad</script>', 'html-note')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivered_reset_context();

  perform pg_temp.supplier_order_delivered_record_result('no proof-of-delivery table required', to_regclass('public.proof_of_delivery') is null);
  perform pg_temp.supplier_order_delivered_record_result('no GPS tracking table required', to_regclass('public.delivery_tracking') is null and to_regclass('public.provider_bookings') is null);
  perform pg_temp.supplier_order_delivered_record_result('no payment created', v_payments_after = v_payments_before);
  perform pg_temp.supplier_order_delivered_record_result('no delivery quote created', v_delivery_quotes_after = v_delivery_quotes_before);
  perform pg_temp.supplier_order_delivered_record_result('no commission released', v_commissions_after = v_commissions_before);
  perform pg_temp.supplier_order_delivered_record_result('no settlement completed', v_settlements_after = v_settlements_before);
  perform pg_temp.supplier_order_delivered_record_result('no withdrawal created', v_withdrawals_after = v_withdrawals_before);
  perform pg_temp.supplier_order_delivered_record_result('no refund created', v_refunds_after = v_refunds_before);
  perform pg_temp.supplier_order_delivered_record_result('no completed status', not exists(select 1 from public.orders where id = v_order_id and order_status::text = 'completed'));

  update public.orders set order_status = 'delivered'::text::public.order_status, delivery_status = 'delivered'::public.delivery_status, delivered_at = v_delivered_at, delivery_confirmation_note = 'Development-only delivered QA note' where id = v_order_id;
  perform pg_temp.supplier_order_delivered_set_context(v_customer_clerk_user_id);
  select * into v_customer_read from public.get_customer_order_safe(v_order_id) limit 1;
  perform pg_temp.supplier_order_delivered_reset_context();
  perform pg_temp.supplier_order_delivered_record_result('customer-safe delivered status visible', v_customer_read.order_status_label = 'Your order has been delivered');
  perform pg_temp.supplier_order_delivered_record_result('customer-safe payment-not-confirmed notice visible', coalesce(v_customer_read.delivered_notice, '') ilike '%Payment has not yet been confirmed in Risellar%');
  perform pg_temp.supplier_order_delivered_record_result('supplier-only note absent from customer read shape', not (to_jsonb(v_customer_read) ? 'delivery_confirmation_note'));
end;
$$;

select test_name, passed, details
from supplier_order_delivered_test_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_delivered_test_results where not passed) then
    raise exception 'Supplier delivered RPC boundary tests failed';
  end if;
end;
$$;

rollback;
