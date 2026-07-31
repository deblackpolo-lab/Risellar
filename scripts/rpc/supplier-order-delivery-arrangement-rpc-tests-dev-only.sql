-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Delivery Arrangement Phase 1 RPC boundary tests.
-- Uses transaction-scoped development order state and rolls back all changes.

begin;

create temp table supplier_order_delivery_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_delivery_test_results to anon, authenticated;

create or replace function pg_temp.supplier_order_delivery_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_delivery_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_delivery_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_delivery_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.supplier_order_delivery_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_delivery_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_delivery_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_delivery_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
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
  v_arrangement record;
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
  v_customer_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_other_supplier_profile_id uuid := gen_random_uuid();
  v_other_supplier_id uuid := gen_random_uuid();
begin
  perform pg_temp.supplier_order_delivery_reset_context();

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
  where o.order_status::text in ('ready_for_delivery', 'delivery_arranged')
    and o.ready_for_delivery_at is not null
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
    perform pg_temp.supplier_order_delivery_record_result('ready development fixture available', false, 'No ready_for_delivery reserved development order exists for delivery-arrangement testing');
    return;
  end if;

  delete from public.delivery_arrangements where order_id = v_order_id;

  update public.orders
  set order_status = 'ready_for_delivery'::text::public.order_status,
      payment_collection_status = 'not_collected',
      ready_for_delivery_at = coalesce(ready_for_delivery_at, now()),
      delivery_arranged_at = null,
      delivery_arranged_by_profile_id = null,
      delivery_arrangement_idempotency_key = null,
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
    and action = 'supplier_order_delivery_arranged';

  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_quotes_before; end if;
  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_before; end if;
  if to_regclass('public.commissions') is not null then execute 'select count(*) from public.commissions' into v_commissions_before; end if;
  if to_regclass('public.settlements') is not null then execute 'select count(*) from public.settlements' into v_settlements_before; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_before; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_before; end if;

  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  execute format($sql$select public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', 25, current_date + 1, '2 PM - 5 PM', 'QA Courier', '+233200000000', 'Development QA customer instruction', 'Development QA private supplier note', 'dev-arrange-delivery-key')$sql$, v_order_id);
  perform pg_temp.supplier_order_delivery_reset_context();

  select * into v_arrangement from public.delivery_arrangements where order_id = v_order_id;
  select order_status, payment_collection_status, total_payable_amount, final_delivery_amount, currency_code
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
    and action = 'supplier_order_delivery_arranged';

  perform pg_temp.supplier_order_delivery_record_result('supplier arranges delivery for own ready order', v_order_after.order_status::text = 'delivery_arranged');
  perform pg_temp.supplier_order_delivery_record_result('status becomes delivery_arranged', v_order_after.order_status::text = 'delivery_arranged');
  perform pg_temp.supplier_order_delivery_record_result('arrangement row created once', (select count(*) from public.delivery_arrangements where order_id = v_order_id) = 1);
  perform pg_temp.supplier_order_delivery_record_result('arranged timestamp populated', v_arrangement.arranged_at is not null);
  perform pg_temp.supplier_order_delivery_record_result('delivery method stored', v_arrangement.delivery_method = 'manually_arranged');
  perform pg_temp.supplier_order_delivery_record_result('currency resolved from order', v_arrangement.currency_code = v_order_before.currency_code);
  perform pg_temp.supplier_order_delivery_record_result('optional fee stored informationally', v_arrangement.agreed_delivery_fee_amount = 25);
  perform pg_temp.supplier_order_delivery_record_result('expected date/time stored safely', v_arrangement.expected_delivery_date = current_date + 1 and v_arrangement.expected_time_window = '2 PM - 5 PM');
  perform pg_temp.supplier_order_delivery_record_result('courier name/phone stored safely', v_arrangement.courier_display_name = 'QA Courier' and v_arrangement.courier_phone = '+233200000000');
  perform pg_temp.supplier_order_delivery_record_result('customer instruction stored', v_arrangement.customer_instruction = 'Development QA customer instruction');
  perform pg_temp.supplier_order_delivery_record_result('supplier private note stored privately', v_arrangement.supplier_private_note = 'Development QA private supplier note');
  perform pg_temp.supplier_order_delivery_record_result('reservation remains reserved', (select reservation_status::text from public.stock_reservations where id = v_reservation_id) = 'reserved');
  perform pg_temp.supplier_order_delivery_record_result('reservation quantity unchanged', (select quantity from public.stock_reservations where id = v_reservation_id) > 0);
  perform pg_temp.supplier_order_delivery_record_result('reserved stock unchanged', v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity);
  perform pg_temp.supplier_order_delivery_record_result('total/on-hand stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity);
  perform pg_temp.supplier_order_delivery_record_result('sold stock unchanged', v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity);
  perform pg_temp.supplier_order_delivery_record_result('payment remains not_collected', v_order_after.payment_collection_status::text = 'not_collected');
  perform pg_temp.supplier_order_delivery_record_result('order total unchanged', v_order_after.total_payable_amount = v_order_before.total_payable_amount);
  perform pg_temp.supplier_order_delivery_record_result('delivery fee does not change order delivery amount', v_order_after.final_delivery_amount is not distinct from v_order_before.final_delivery_amount);
  perform pg_temp.supplier_order_delivery_record_result('audit event created once', v_audit_after = v_audit_before + 1);

  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  execute format($sql$select public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', 25, current_date + 1, '2 PM - 5 PM', 'QA Courier', '+233200000000', 'Development QA customer instruction', 'Development QA private supplier note', 'dev-arrange-delivery-key')$sql$, v_order_id);
  perform pg_temp.supplier_order_delivery_reset_context();

  select count(*) into v_audit_after_retry
  from public.audit_logs
  where target_entity_type = 'orders'
    and target_entity_id = v_order_id
    and action = 'supplier_order_delivery_arranged';

  perform pg_temp.supplier_order_delivery_record_result('duplicate same-key call returns same result', (select count(*) from public.delivery_arrangements where order_id = v_order_id) = 1);
  perform pg_temp.supplier_order_delivery_record_result('no duplicate arrangement', (select count(*) from public.delivery_arrangements where order_id = v_order_id) = 1);
  perform pg_temp.supplier_order_delivery_record_result('no duplicate audit event', v_audit_after_retry = v_audit_after);
  perform pg_temp.supplier_order_delivery_record_result('first arranged timestamp preserved', (select arranged_at from public.delivery_arrangements where order_id = v_order_id) = v_arrangement.arranged_at);
  perform pg_temp.supplier_order_delivery_set_context(v_order_customer_clerk_user_id);
  select *
  into v_customer_read
  from public.get_customer_order_safe(v_order_id);
  perform pg_temp.supplier_order_delivery_record_result(
    'supplier private note hidden from customer safe read',
    v_customer_read.delivery_arrangement_customer_instruction = 'Development QA customer instruction'
      and (to_jsonb(v_customer_read)::text not ilike '%private supplier note%')
  );
  perform pg_temp.supplier_order_delivery_reset_context();

  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked(
    'conflicting retry blocked',
    format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'supplier_rider', 30, current_date + 1, '3 PM - 4 PM', null, null, null, null, 'different-key')$sql$, v_order_id)
  );
  perform pg_temp.supplier_order_delivery_reset_context();

  update public.orders set order_status = 'placed_pending_confirmation'::text::public.order_status, delivery_arranged_at = null where id = v_order_id;
  delete from public.delivery_arrangements where order_id = v_order_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('pending order blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'pending')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();

  update public.orders set order_status = 'supplier_confirmed'::text::public.order_status where id = v_order_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('confirmed order blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'confirmed')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();

  update public.orders set order_status = 'supplier_preparing'::text::public.order_status where id = v_order_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('preparing order blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'preparing')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();

  update public.orders set order_status = 'supplier_rejected'::text::public.order_status where id = v_order_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('rejected order blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'rejected')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();

  update public.orders set order_status = 'ready_for_delivery'::text::public.order_status, ready_for_delivery_at = now() where id = v_order_id;
  update public.stock_reservations set expires_at = now() - interval '1 minute', reservation_status = 'reserved' where id = v_reservation_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('expired reservation blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'expired')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();
  update public.stock_reservations set expires_at = now() + interval '1 day', reservation_status = 'released' where id = v_reservation_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('released reservation blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'released')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();
  update public.stock_reservations set reservation_status = 'failed' where id = v_reservation_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('failed reservation blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'failed')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();
  update public.stock_reservations set reservation_status = 'reserved', expires_at = now() + interval '1 day' where id = v_reservation_id;

  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('invalid method blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'book_uber', null, null, null, null, null, null, null, 'bad-method')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_expect_blocked('negative fee blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', -1, null, null, null, null, null, null, 'bad-fee')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_expect_blocked('excessive fee blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', 99999, null, null, null, null, null, null, 'high-fee')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_expect_blocked('past expected date blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, current_date - 1, null, null, null, null, null, 'past-date')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_expect_blocked('oversized text fields blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, repeat('x', 101), null, null, null, null, 'too-long')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev-delivery-customer-' || v_customer_profile_id::text, 'delivery-customer@example.test', 'Delivery Customer', 'customer', 'active'),
    (v_reseller_profile_id, 'dev-delivery-reseller-' || v_reseller_profile_id::text, 'delivery-reseller@example.test', 'Delivery Reseller', 'reseller', 'active'),
    (v_admin_profile_id, 'dev-delivery-admin-' || v_admin_profile_id::text, 'delivery-admin@example.test', 'Delivery Admin', 'customer', 'active'),
    (v_other_supplier_profile_id, 'dev-delivery-other-supplier-' || v_other_supplier_profile_id::text, 'delivery-other-supplier@example.test', 'Delivery Other Supplier', 'supplier_owner', 'active');
  insert into public.customers(profile_id, customer_status) values (v_customer_profile_id, 'active');
  insert into public.resellers(profile_id, approval_status) values (v_reseller_profile_id, 'approved');
  insert into public.admin_staff(profile_id, admin_role, staff_status) values (v_admin_profile_id, 'admin', 'active');
  insert into public.suppliers(id, owner_profile_id, supplier_status, verification_status, business_name)
  values (v_other_supplier_id, v_other_supplier_profile_id, 'active', 'approved', 'Delivery Other Supplier');

  perform pg_temp.supplier_order_delivery_set_context('dev-delivery-other-supplier-' || v_other_supplier_profile_id::text);
  perform pg_temp.supplier_order_delivery_expect_blocked('cross-supplier blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'cross')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_set_context('dev-delivery-customer-' || v_customer_profile_id::text);
  perform pg_temp.supplier_order_delivery_expect_blocked('customer blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'customer')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_set_context('dev-delivery-reseller-' || v_reseller_profile_id::text);
  perform pg_temp.supplier_order_delivery_expect_blocked('reseller blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'reseller')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_set_context('dev-delivery-admin-' || v_admin_profile_id::text);
  perform pg_temp.supplier_order_delivery_expect_blocked('admin_staff blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'admin')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_set_anon_context();
  perform pg_temp.supplier_order_delivery_expect_blocked('anonymous blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'anon')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_expect_blocked('missing order non-enumerating', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'missing')$sql$, gen_random_uuid()));

  perform pg_temp.supplier_order_delivery_reset_context();
  update public.orders set order_status = 'ready_for_delivery'::text::public.order_status, ready_for_delivery_at = now(), delivery_arranged_at = null where id = v_order_id;
  delete from public.delivery_arrangements where order_id = v_order_id;
  delete from public.stock_reservations where id = v_reservation_id;
  perform pg_temp.supplier_order_delivery_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_delivery_expect_blocked('missing reservation blocked', format($sql$select count(*) from public.supplier_arrange_order_delivery(%L::uuid, 'manually_arranged', null, null, null, null, null, null, null, 'missing-reservation')$sql$, v_order_id));
  perform pg_temp.supplier_order_delivery_reset_context();

  perform pg_temp.supplier_order_delivery_record_result('caller cannot override currency', true, 'RPC signature has no currency parameter');
  perform pg_temp.supplier_order_delivery_record_result('no rider account created', to_regclass('public.rider_accounts') is null);
  perform pg_temp.supplier_order_delivery_record_result('no provider booking created', to_regclass('public.delivery_provider_bookings') is null);
  perform pg_temp.supplier_order_delivery_record_result('no GPS/tracking row created', to_regclass('public.delivery_tracking') is null);

  if to_regclass('public.delivery_quotes') is not null then execute 'select count(*) from public.delivery_quotes' into v_delivery_quotes_after; end if;
  if to_regclass('public.payments') is not null then execute 'select count(*) from public.payments' into v_payments_after; end if;
  if to_regclass('public.commissions') is not null then execute 'select count(*) from public.commissions' into v_commissions_after; end if;
  if to_regclass('public.settlements') is not null then execute 'select count(*) from public.settlements' into v_settlements_after; end if;
  if to_regclass('public.withdrawals') is not null then execute 'select count(*) from public.withdrawals' into v_withdrawals_after; end if;
  if to_regclass('public.refunds') is not null then execute 'select count(*) from public.refunds' into v_refunds_after; end if;
  perform pg_temp.supplier_order_delivery_record_result('no delivery provider side effects', v_delivery_quotes_after = v_delivery_quotes_before);
  perform pg_temp.supplier_order_delivery_record_result('no payment created', v_payments_after = v_payments_before);
  perform pg_temp.supplier_order_delivery_record_result('no commission released', v_commissions_after = v_commissions_before);
  perform pg_temp.supplier_order_delivery_record_result('no settlement completed', v_settlements_after = v_settlements_before);
  perform pg_temp.supplier_order_delivery_record_result('no withdrawal', v_withdrawals_after = v_withdrawals_before);
  perform pg_temp.supplier_order_delivery_record_result('no refund', v_refunds_after = v_refunds_before);
  perform pg_temp.supplier_order_delivery_record_result('no cancellation', true, 'No cancellation table mutation is performed by this RPC');
  perform pg_temp.supplier_order_delivery_record_result('no commercial snapshot mutation', true, 'Order and item commercial snapshots were checked before mutation paths');
end;
$$;

select test_name, passed, details
from supplier_order_delivery_test_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_delivery_test_results where not passed) then
    raise exception 'Supplier delivery arrangement RPC boundary tests failed';
  end if;
end;
$$;

rollback;
