-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Fulfilment Phase 3 ready-for-delivery RPC boundary tests.
-- Uses transaction-scoped development order state and rolls back all changes.

begin;

create temp table supplier_order_ready_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_ready_test_results to anon, authenticated;

create or replace function pg_temp.supplier_order_ready_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_ready_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_ready_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_ready_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.supplier_order_ready_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_ready_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_ready_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_ready_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_id uuid;
  v_supplier_profile_id uuid;
  v_supplier_clerk_user_id text;
  v_product_id uuid;
  v_variant_id uuid;
  v_reseller_product_id uuid;
  v_reservation_id uuid;
  v_reservation_quantity integer;
  v_stock_before record;
  v_stock_after record;
  v_reservation_before record;
  v_reservation_after record;
  v_preparing_at_before timestamptz;
  v_ready_at_after timestamptz;
  v_ready_at_retry timestamptz;
  v_result jsonb;
  v_audit_before bigint;
  v_audit_after bigint;
  v_audit_after_retry bigint;
  v_payments_before bigint := 0;
  v_payments_after bigint := 0;
  v_delivery_before bigint := 0;
  v_delivery_after bigint := 0;
  v_commissions_before bigint := 0;
  v_commissions_after bigint := 0;
  v_settlements_before bigint := 0;
  v_settlements_after bigint := 0;
  v_withdrawals_before bigint := 0;
  v_withdrawals_after bigint := 0;
  v_refunds_before bigint := 0;
  v_refunds_after bigint := 0;
  v_customer_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_other_supplier_profile_id uuid := gen_random_uuid();
  v_other_supplier_id uuid := gen_random_uuid();
begin
  perform pg_temp.supplier_order_ready_reset_context();

  select
    o.id,
    oi.supplier_id,
    s.owner_profile_id,
    p.clerk_user_id,
    oi.product_id,
    oi.variant_id,
    oi.reseller_product_id,
    sr.id,
    sr.quantity
  into
    v_order_id,
    v_supplier_id,
    v_supplier_profile_id,
    v_supplier_clerk_user_id,
    v_product_id,
    v_variant_id,
    v_reseller_product_id,
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
    perform pg_temp.supplier_order_ready_record_result('preparing development fixture available', false, 'No supplier_preparing reserved development order exists for ready testing');
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

  select reservation_status, quantity, released_at, committed_at, expires_at
  into v_reservation_before
  from public.stock_reservations
  where id = v_reservation_id;

  select supplier_preparing_at
  into v_preparing_at_before
  from public.orders
  where id = v_order_id;

  select count(*) into v_audit_before
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_ready_for_delivery';

  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_before; end if;
  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_before; end if;
  if to_regclass('public.commissions') is not null then execute 'select count(*) from public.commissions' into v_commissions_before; end if;
  if to_regclass('public.settlements') is not null then execute 'select count(*) from public.settlements' into v_settlements_before; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_before; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_before; end if;

  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);

  select to_jsonb(x)
  into v_result
  from public.supplier_mark_ready_for_delivery(v_order_id, 'dev-ready-for-delivery-key') x
  limit 1;

  perform pg_temp.supplier_order_ready_reset_context();

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after
  from public.product_variants
  where id = v_variant_id;

  select reservation_status, quantity, released_at, committed_at, expires_at
  into v_reservation_after
  from public.stock_reservations
  where id = v_reservation_id;

  select ready_for_delivery_at
  into v_ready_at_after
  from public.orders
  where id = v_order_id;

  select count(*) into v_audit_after
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_ready_for_delivery';

  perform pg_temp.supplier_order_ready_record_result('supplier marks own preparing order ready', v_result ->> 'order_status' = 'ready_for_delivery');
  perform pg_temp.supplier_order_ready_record_result('status becomes ready_for_delivery', (select order_status::text from public.orders where id = v_order_id) = 'ready_for_delivery');
  perform pg_temp.supplier_order_ready_record_result('ready timestamp populated', v_ready_at_after is not null);
  perform pg_temp.supplier_order_ready_record_result('preparation timestamp preserved', (select supplier_preparing_at from public.orders where id = v_order_id) = v_preparing_at_before);
  perform pg_temp.supplier_order_ready_record_result('reservation remains reserved', v_reservation_after.reservation_status = v_reservation_before.reservation_status and v_reservation_after.reservation_status = 'reserved');
  perform pg_temp.supplier_order_ready_record_result('reservation quantity unchanged', v_reservation_after.quantity = v_reservation_before.quantity);
  perform pg_temp.supplier_order_ready_record_result('reserved stock unchanged', v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity);
  perform pg_temp.supplier_order_ready_record_result('total stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity);
  perform pg_temp.supplier_order_ready_record_result('sold stock unchanged', v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
  perform pg_temp.supplier_order_ready_record_result('payment remains not_collected', (select payment_collection_status::text from public.orders where id = v_order_id) = 'not_collected');
  perform pg_temp.supplier_order_ready_record_result('audit event created', v_audit_after = v_audit_before + 1);

  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform public.supplier_mark_ready_for_delivery(v_order_id, 'dev-ready-for-delivery-key');
  perform pg_temp.supplier_order_ready_reset_context();

  select ready_for_delivery_at
  into v_ready_at_retry
  from public.orders
  where id = v_order_id;

  select count(*) into v_audit_after_retry
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_ready_for_delivery';

  perform pg_temp.supplier_order_ready_record_result('duplicate call returns same ready state', (select order_status::text from public.orders where id = v_order_id) = 'ready_for_delivery');
  perform pg_temp.supplier_order_ready_record_result('duplicate call creates no duplicate transition', v_ready_at_retry = v_ready_at_after);
  perform pg_temp.supplier_order_ready_record_result('duplicate call creates no duplicate audit event', v_audit_after_retry = v_audit_after);

  update public.orders set order_status = 'placed_pending_confirmation', supplier_preparing_at = now(), ready_for_delivery_at = null where id = v_order_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('pending order blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'pending')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  update public.orders set order_status = 'supplier_confirmed', supplier_preparing_at = now(), ready_for_delivery_at = null where id = v_order_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('confirmed-but-not-preparing order blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'confirmed')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  update public.orders set order_status = 'supplier_rejected', supplier_preparing_at = now(), ready_for_delivery_at = null where id = v_order_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('rejected order blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'rejected')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  update public.orders set order_status = 'supplier_preparing', supplier_preparing_at = null, ready_for_delivery_at = null where id = v_order_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('missing preparation timestamp blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'missing-prep')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  update public.orders set order_status = 'supplier_preparing', supplier_preparing_at = now(), ready_for_delivery_at = null where id = v_order_id;
  update public.stock_reservations set expires_at = now() - interval '1 minute', reservation_status = 'reserved' where id = v_reservation_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('expired reservation blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'expired')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  update public.stock_reservations set expires_at = now() + interval '1 day', reservation_status = 'released' where id = v_reservation_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('released reservation blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'released')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  update public.stock_reservations set reservation_status = 'failed' where id = v_reservation_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('failed reservation blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'failed')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  delete from public.stock_reservations where id = v_reservation_id;
  perform pg_temp.supplier_order_ready_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_ready_expect_blocked('missing reservation blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'missing-reservation')$sql$, v_order_id));

  perform pg_temp.supplier_order_ready_reset_context();
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_supplier_order_ready_customer', 'dev-supplier-order-ready-customer@example.test', 'Dev Ready Customer', 'customer', 'active'),
    (v_reseller_profile_id, 'dev_supplier_order_ready_reseller', 'dev-supplier-order-ready-reseller@example.test', 'Dev Ready Reseller', 'reseller', 'active'),
    (v_admin_profile_id, 'dev_supplier_order_ready_admin', 'dev-supplier-order-ready-admin@example.test', 'Dev Ready Admin', 'customer', 'active'),
    (v_other_supplier_profile_id, 'dev_supplier_order_ready_other_supplier', 'dev-supplier-order-ready-other@example.test', 'Dev Ready Other Supplier', 'supplier_owner', 'active');
  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');
  insert into public.resellers(profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_profile_id, 'dev_only_supplier_order_ready_reseller', 'approved', 'active');
  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_other_supplier_id, v_other_supplier_profile_id, 'Dev Supplier Order Ready Other', 'active', 'approved', 'Dev Supplier Order Ready Other');

  perform pg_temp.supplier_order_ready_set_context('dev_supplier_order_ready_other_supplier');
  perform pg_temp.supplier_order_ready_expect_blocked('cross-supplier blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'cross')$sql$, v_order_id));
  perform pg_temp.supplier_order_ready_set_context('dev_supplier_order_ready_customer');
  perform pg_temp.supplier_order_ready_expect_blocked('customer blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'customer')$sql$, v_order_id));
  perform pg_temp.supplier_order_ready_set_context('dev_supplier_order_ready_reseller');
  perform pg_temp.supplier_order_ready_expect_blocked('reseller blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'reseller')$sql$, v_order_id));
  perform pg_temp.supplier_order_ready_set_context('dev_supplier_order_ready_admin');
  perform pg_temp.supplier_order_ready_expect_blocked('admin_staff blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'admin')$sql$, v_order_id));
  perform pg_temp.supplier_order_ready_set_anon_context();
  perform pg_temp.supplier_order_ready_expect_blocked('anonymous blocked', format($sql$select count(*) from public.supplier_mark_ready_for_delivery(%L::uuid, 'anon')$sql$, v_order_id));

  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_after; end if;
  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_after; end if;
  if to_regclass('public.commissions') is not null then execute 'select count(*) from public.commissions' into v_commissions_after; end if;
  if to_regclass('public.settlements') is not null then execute 'select count(*) from public.settlements' into v_settlements_after; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_after; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_after; end if;

  perform pg_temp.supplier_order_ready_record_result(
    'no delivery payment finance side effects',
    v_payments_after = v_payments_before
      and v_delivery_after = v_delivery_before
      and v_commissions_after = v_commissions_before
      and v_settlements_after = v_settlements_before
      and v_withdrawals_after = v_withdrawals_before
      and v_refunds_after = v_refunds_before
  );
  perform pg_temp.supplier_order_ready_record_result('fixture data rolled back', true, 'transaction rollback at end of script');
end;
$$;

reset role;

select test_name, passed, details
from supplier_order_ready_test_results
order by test_name;

do $$
declare
  v_failed integer;
begin
  select count(*) into v_failed
  from supplier_order_ready_test_results
  where not passed;

  if v_failed > 0 then
    raise exception 'SUPPLIER_ORDER_READY_FOR_DELIVERY_TEST_FAILED: % assertion(s) failed', v_failed;
  end if;
end;
$$;

rollback;
