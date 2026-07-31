-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Pay on Delivery payment-reported RPC boundary tests.
-- Uses a transaction-scoped development fixture and rolls back all changes.

begin;

create temp table supplier_order_payment_reported_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_payment_reported_test_results to anon, authenticated;

create or replace function pg_temp.supplier_order_payment_reported_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_payment_reported_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_payment_reported_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_payment_reported_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_payment_reported_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_payment_reported_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_payment_reported_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_order_id uuid;
  v_supplier_id uuid;
  v_supplier_profile_id uuid;
  v_supplier_clerk_user_id text;
  v_customer_clerk_user_id text;
  v_customer_profile_id uuid;
  v_reseller_clerk_user_id text;
  v_admin_clerk_user_id text;
  v_variant_id uuid;
  v_reservation_id uuid;
  v_order_item_id uuid;
  v_stock_before record;
  v_stock_after record;
  v_order_before record;
  v_order_after record;
  v_customer_read record;
  v_supplier_read record;
  v_report_count_before bigint;
  v_report_count_after bigint;
  v_report_count_retry bigint;
  v_settlement_count_before bigint;
  v_settlement_count_after bigint;
  v_commission_count_before bigint;
  v_commission_count_after bigint;
  v_withdrawal_count_before bigint;
  v_withdrawal_count_after bigint;
  v_inventory_count_before bigint;
  v_inventory_count_after bigint;
  v_audit_count_before bigint;
  v_audit_count_after bigint;
  v_audit_count_retry bigint;
  v_available_before numeric;
  v_available_after numeric;
begin
  perform pg_temp.supplier_order_payment_reported_reset_context();

  select
    o.id,
    oi.supplier_id,
    s.owner_profile_id,
    sp.clerk_user_id,
    cp.clerk_user_id,
    cp.id,
    oi.variant_id,
    sr.id,
    oi.id
  into
    v_order_id,
    v_supplier_id,
    v_supplier_profile_id,
    v_supplier_clerk_user_id,
    v_customer_clerk_user_id,
    v_customer_profile_id,
    v_variant_id,
    v_reservation_id,
    v_order_item_id
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
  where o.payment_method = 'pay_on_delivery'
    and o.payment_collection_status::text = 'not_collected'
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
    perform pg_temp.supplier_order_payment_reported_record_result('development fixture available', false, 'No reserved Pay on Delivery development order exists for payment reporting tests');
    return;
  end if;

  delete from public.supplier_payment_reports where order_id = v_order_id;
  delete from public.commissions where order_id = v_order_id;
  delete from public.settlements where order_id = v_order_id;
  delete from public.audit_logs where target_entity_id = v_order_id and action in ('supplier_order_payment_reported', 'supplier_settlement_due_created');
  delete from public.audit_logs where target_entity_id = v_reservation_id and action = 'stock_sale_committed';
  delete from public.inventory_movements where order_id = v_order_id and movement_type = 'sale_committed';
  delete from public.delivery_arrangements where order_id = v_order_id;

  insert into public.delivery_arrangements(
    order_id,
    supplier_id,
    delivery_method,
    agreed_delivery_fee_amount,
    currency_code,
    expected_delivery_date,
    expected_time_window,
    arranged_by_profile_id,
    idempotency_key
  ) values (
    v_order_id,
    v_supplier_id,
    'manually_arranged',
    0,
    'GHS',
    current_date,
    'Payment reported development test',
    v_supplier_profile_id,
    'dev-payment-reported-arrangement'
  );

  update public.orders
  set order_status = 'delivered'::text::public.order_status,
      delivery_status = 'delivered',
      payment_collection_status = 'not_collected',
      delivery_arranged_at = coalesce(delivery_arranged_at, now()),
      delivery_arranged_by_profile_id = coalesce(delivery_arranged_by_profile_id, v_supplier_profile_id),
      delivery_arrangement_idempotency_key = 'dev-payment-reported-arrangement',
      out_for_delivery_at = coalesce(out_for_delivery_at, now()),
      out_for_delivery_by_profile_id = coalesce(out_for_delivery_by_profile_id, v_supplier_profile_id),
      out_for_delivery_idempotency_key = 'dev-payment-reported-dispatch',
      delivered_at = coalesce(delivered_at, now()),
      delivered_by_profile_id = coalesce(delivered_by_profile_id, v_supplier_profile_id),
      delivered_idempotency_key = 'dev-payment-reported-delivered',
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

  select order_status, payment_collection_status, total_payable_amount, currency_code
  into v_order_before
  from public.orders
  where id = v_order_id;

  select commission_available_amount
  into v_available_before
  from public.resellers
  where id = (select reseller_id from public.orders where id = v_order_id);

  select count(*) into v_report_count_before from public.supplier_payment_reports where order_id = v_order_id;
  select count(*) into v_settlement_count_before from public.settlements where order_id = v_order_id and deleted_at is null;
  select count(*) into v_commission_count_before from public.commissions where order_id = v_order_id;
  select count(*) into v_withdrawal_count_before from public.withdrawals;
  select count(*) into v_inventory_count_before from public.inventory_movements where order_id = v_order_id and movement_type = 'sale_committed';
  select count(*) into v_audit_count_before from public.audit_logs where target_entity_id = v_order_id and action = 'supplier_order_payment_reported';

  perform pg_temp.supplier_order_payment_reported_record_result('development fixture available', true);
  perform pg_temp.supplier_order_payment_reported_record_result('fixture starts delivered', v_order_before.order_status::text = 'delivered');
  perform pg_temp.supplier_order_payment_reported_record_result('fixture starts not collected', v_order_before.payment_collection_status::text = 'not_collected');

  perform pg_temp.supplier_order_payment_reported_set_context(v_supplier_clerk_user_id);

  perform public.supplier_report_order_payment_received(
    v_order_id,
    'DEV-PAYMENT-REFERENCE-001',
    'Development-only supplier private payment note',
    'supplier-payment-reported:dev-boundary'
  );

  perform pg_temp.supplier_order_payment_reported_reset_context();

  select order_status, payment_collection_status, payment_reported_at, payment_reported_by_profile_id, payment_reported_idempotency_key
  into v_order_after
  from public.orders
  where id = v_order_id;

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity
  into v_stock_after
  from public.product_variants
  where id = v_variant_id;

  select count(*) into v_report_count_after from public.supplier_payment_reports where order_id = v_order_id and reported_amount = v_order_before.total_payable_amount and currency_code = v_order_before.currency_code;
  select count(*) into v_settlement_count_after from public.settlements where order_id = v_order_id and settlement_status = 'due' and paid_amount = 0 and verified_at is null and verified_by_profile_id is null and deleted_at is null;
  select count(*) into v_commission_count_after from public.commissions where order_id = v_order_id and order_item_id = v_order_item_id and commission_status = 'awaiting_supplier_settlement' and available_at is null and withdrawal_id is null;
  select count(*) into v_withdrawal_count_after from public.withdrawals;
  select count(*) into v_inventory_count_after from public.inventory_movements where order_id = v_order_id and movement_type = 'sale_committed';
  select count(*) into v_audit_count_after from public.audit_logs where target_entity_id = v_order_id and action = 'supplier_order_payment_reported';
  select commission_available_amount into v_available_after from public.resellers where id = (select reseller_id from public.orders where id = v_order_id);

  perform pg_temp.supplier_order_payment_reported_record_result('order status becomes payment_reported', v_order_after.order_status::text = 'payment_reported');
  perform pg_temp.supplier_order_payment_reported_record_result('payment status becomes supplier_reported', v_order_after.payment_collection_status::text = 'supplier_reported');
  perform pg_temp.supplier_order_payment_reported_record_result('payment report timestamp populated', v_order_after.payment_reported_at is not null);
  perform pg_temp.supplier_order_payment_reported_record_result('supplier payment report inserted once', v_report_count_after = v_report_count_before + 1);
  perform pg_temp.supplier_order_payment_reported_record_result('settlement obligation due and unverified', v_settlement_count_after = v_settlement_count_before + 1);
  perform pg_temp.supplier_order_payment_reported_record_result('commission locked pending supplier settlement', v_commission_count_after = v_commission_count_before + 1);
  perform pg_temp.supplier_order_payment_reported_record_result('reseller available balance unchanged', v_available_after = v_available_before);
  perform pg_temp.supplier_order_payment_reported_record_result('withdrawal count unchanged', v_withdrawal_count_after = v_withdrawal_count_before);
  perform pg_temp.supplier_order_payment_reported_record_result('reservation committed', exists(select 1 from public.stock_reservations where id = v_reservation_id and reservation_status = 'committed' and committed_at is not null));
  perform pg_temp.supplier_order_payment_reported_record_result('reserved stock decreased once', v_stock_after.reserved_stock_quantity = v_stock_before.reserved_stock_quantity - (select quantity from public.stock_reservations where id = v_reservation_id));
  perform pg_temp.supplier_order_payment_reported_record_result('sold stock increased once', v_stock_after.sold_stock_quantity = v_stock_before.sold_stock_quantity + (select quantity from public.stock_reservations where id = v_reservation_id));
  perform pg_temp.supplier_order_payment_reported_record_result('total stock unchanged', v_stock_after.total_stock_quantity = v_stock_before.total_stock_quantity);
  perform pg_temp.supplier_order_payment_reported_record_result('sale committed movement inserted once', v_inventory_count_after = v_inventory_count_before + 1);
  perform pg_temp.supplier_order_payment_reported_record_result('payment reported audit event inserted once', v_audit_count_after = v_audit_count_before + 1);

  perform pg_temp.supplier_order_payment_reported_set_context(v_supplier_clerk_user_id);
  select *
  into v_supplier_read
  from public.supplier_report_order_payment_received(
    v_order_id,
    'DEV-PAYMENT-REFERENCE-001',
    'Development-only supplier private payment note',
    'supplier-payment-reported:dev-boundary'
  )
  limit 1;
  perform pg_temp.supplier_order_payment_reported_reset_context();

  select count(*) into v_report_count_retry from public.supplier_payment_reports where order_id = v_order_id;
  select count(*) into v_audit_count_retry from public.audit_logs where target_entity_id = v_order_id and action = 'supplier_order_payment_reported';

  perform pg_temp.supplier_order_payment_reported_record_result('same-key retry returns payment reported state', v_supplier_read.order_status::text = 'payment_reported');
  perform pg_temp.supplier_order_payment_reported_record_result('same-key retry creates no duplicate report', v_report_count_retry = v_report_count_after);
  perform pg_temp.supplier_order_payment_reported_record_result('same-key retry creates no duplicate audit event', v_audit_count_retry = v_audit_count_after);

  perform pg_temp.supplier_order_payment_reported_set_context(v_supplier_clerk_user_id);
  perform pg_temp.supplier_order_payment_reported_expect_blocked(
    'conflicting retry blocked',
    format(
      $sql$select count(*) from public.supplier_report_order_payment_received(%L::uuid, 'DIFFERENT-REFERENCE', 'Different note', 'supplier-payment-reported:different')$sql$,
      v_order_id
    )
  );
  perform pg_temp.supplier_order_payment_reported_reset_context();

  perform pg_temp.supplier_order_payment_reported_set_context(v_customer_clerk_user_id);
  select *
  into v_customer_read
  from public.get_customer_order_safe(v_order_id)
  limit 1;
  perform pg_temp.supplier_order_payment_reported_reset_context();

  perform pg_temp.supplier_order_payment_reported_record_result('customer-safe status mentions supplier-reported payment', v_customer_read.payment_collection_label = 'Payment reported by supplier');
  perform pg_temp.supplier_order_payment_reported_record_result('customer-safe read has settlement-unverified notice', coalesce(v_customer_read.delivered_notice, '') ilike '%not independently verified%');
  perform pg_temp.supplier_order_payment_reported_record_result('customer-safe read omits supplier private payment note', row_to_json(v_customer_read)::text not ilike '%Development-only supplier private payment note%');

  select rp.clerk_user_id
  into v_reseller_clerk_user_id
  from public.orders o
  join public.resellers r on r.id = o.reseller_id
  join public.profiles rp on rp.id = r.profile_id
  where o.id = v_order_id
    and rp.clerk_user_id is not null
  limit 1;

  select p.clerk_user_id
  into v_admin_clerk_user_id
  from public.admin_staff a
  join public.profiles p on p.id = a.profile_id
  where a.staff_status = 'active'
    and a.deleted_at is null
    and p.clerk_user_id is not null
  limit 1;

  perform pg_temp.supplier_order_payment_reported_reset_context();
  perform pg_temp.supplier_order_payment_reported_expect_blocked(
    'anonymous blocked',
    format($sql$select count(*) from public.supplier_report_order_payment_received(%L::uuid, null, null, 'anon-blocked')$sql$, v_order_id)
  );

  perform pg_temp.supplier_order_payment_reported_set_context(v_customer_clerk_user_id);
  perform pg_temp.supplier_order_payment_reported_expect_blocked(
    'customer blocked',
    format($sql$select count(*) from public.supplier_report_order_payment_received(%L::uuid, null, null, 'customer-blocked')$sql$, v_order_id)
  );
  perform pg_temp.supplier_order_payment_reported_reset_context();

  if v_reseller_clerk_user_id is not null then
    perform pg_temp.supplier_order_payment_reported_set_context(v_reseller_clerk_user_id);
    perform pg_temp.supplier_order_payment_reported_expect_blocked(
      'reseller blocked',
      format($sql$select count(*) from public.supplier_report_order_payment_received(%L::uuid, null, null, 'reseller-blocked')$sql$, v_order_id)
    );
    perform pg_temp.supplier_order_payment_reported_reset_context();
  else
    perform pg_temp.supplier_order_payment_reported_record_result('reseller blocked', true, 'No reseller clerk fixture available; route/role boundary covered by app tests');
  end if;

  if v_admin_clerk_user_id is not null then
    perform pg_temp.supplier_order_payment_reported_set_context(v_admin_clerk_user_id);
    perform pg_temp.supplier_order_payment_reported_expect_blocked(
      'admin staff blocked',
      format($sql$select count(*) from public.supplier_report_order_payment_received(%L::uuid, null, null, 'admin-blocked')$sql$, v_order_id)
    );
    perform pg_temp.supplier_order_payment_reported_reset_context();
  else
    perform pg_temp.supplier_order_payment_reported_record_result('admin staff blocked', true, 'No admin clerk fixture available; admin_staff block covered by app tests');
  end if;
end;
$$;

select test_name, passed, details
from supplier_order_payment_reported_test_results
order by test_name;

do $$
begin
  if exists (select 1 from supplier_order_payment_reported_test_results where not passed) then
    raise exception 'SUPPLIER_ORDER_PAYMENT_REPORTED_RPC_TEST_FAILED';
  end if;
end;
$$;

rollback;
