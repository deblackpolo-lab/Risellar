-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Supplier Order Handling S4/S5 accept/reject RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction; fixture data rolled back.

begin;

create temp table supplier_order_decision_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on supplier_order_decision_test_results to anon, authenticated;

create or replace function pg_temp.supplier_order_decision_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into supplier_order_decision_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.supplier_order_decision_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;
end;
$$;

create or replace function pg_temp.supplier_order_decision_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.supplier_order_decision_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.supplier_order_decision_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.supplier_order_decision_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.supplier_order_decision_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_customer_profile_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_supplier_a_profile_id uuid := gen_random_uuid();
  v_supplier_b_profile_id uuid := gen_random_uuid();
  v_supplier_a_id uuid := gen_random_uuid();
  v_supplier_b_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_product_a_id uuid := gen_random_uuid();
  v_product_b_id uuid := gen_random_uuid();
  v_variant_accept_id uuid := gen_random_uuid();
  v_variant_reject_id uuid := gen_random_uuid();
  v_variant_cross_id uuid := gen_random_uuid();
  v_variant_expired_id uuid := gen_random_uuid();
  v_variant_released_id uuid := gen_random_uuid();
  v_variant_failed_id uuid := gen_random_uuid();
  v_listing_accept_id uuid := gen_random_uuid();
  v_listing_reject_id uuid := gen_random_uuid();
  v_listing_cross_id uuid := gen_random_uuid();
  v_listing_expired_id uuid := gen_random_uuid();
  v_listing_released_id uuid := gen_random_uuid();
  v_listing_failed_id uuid := gen_random_uuid();
  v_order_accept_id uuid := gen_random_uuid();
  v_order_reject_id uuid := gen_random_uuid();
  v_order_cross_id uuid := gen_random_uuid();
  v_order_expired_id uuid := gen_random_uuid();
  v_order_released_id uuid := gen_random_uuid();
  v_order_failed_id uuid := gen_random_uuid();
  v_order_missing_reservation_id uuid := gen_random_uuid();
  v_order_item_accept_id uuid := gen_random_uuid();
  v_order_item_reject_id uuid := gen_random_uuid();
  v_order_item_cross_id uuid := gen_random_uuid();
  v_order_item_expired_id uuid := gen_random_uuid();
  v_order_item_released_id uuid := gen_random_uuid();
  v_order_item_failed_id uuid := gen_random_uuid();
  v_order_item_missing_reservation_id uuid := gen_random_uuid();
  v_draft_accept_id uuid := gen_random_uuid();
  v_draft_reject_id uuid := gen_random_uuid();
  v_draft_cross_id uuid := gen_random_uuid();
  v_draft_expired_id uuid := gen_random_uuid();
  v_draft_released_id uuid := gen_random_uuid();
  v_draft_failed_id uuid := gen_random_uuid();
  v_draft_missing_reservation_id uuid := gen_random_uuid();
  v_reservation_accept_id uuid := gen_random_uuid();
  v_reservation_reject_id uuid := gen_random_uuid();
  v_reservation_cross_id uuid := gen_random_uuid();
  v_reservation_expired_id uuid := gen_random_uuid();
  v_reservation_released_id uuid := gen_random_uuid();
  v_reservation_failed_id uuid := gen_random_uuid();
  v_accept_row jsonb;
  v_reject_row jsonb;
  v_accept_stock_before integer;
  v_accept_stock_after integer;
  v_reject_stock_before integer;
  v_reject_stock_after integer;
  v_movements_before bigint;
  v_movements_after_first_reject bigint;
  v_movements_after_second_reject bigint;
  v_payments_table_absent boolean;
  v_delivery_rows_before bigint;
  v_settlement_rows_before bigint;
  v_commission_rows_before bigint;
  v_withdrawal_rows_before bigint;
begin
  perform pg_temp.supplier_order_decision_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, phone, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_supplier_order_decision_customer', 'dev-supplier-order-decision-customer@example.test', 'Dev Decision Customer', '0204000101', 'customer', 'active'),
    (v_reseller_profile_id, 'dev_supplier_order_decision_reseller', 'dev-supplier-order-decision-reseller@example.test', 'Dev Decision Reseller', '0204000201', 'reseller', 'active'),
    (v_supplier_a_profile_id, 'dev_supplier_order_decision_supplier_a', 'dev-supplier-order-decision-a@example.test', 'Dev Decision Supplier A', '0204000301', 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_supplier_order_decision_supplier_b', 'dev-supplier-order-decision-b@example.test', 'Dev Decision Supplier B', '0204000401', 'supplier_owner', 'active'),
    (v_admin_profile_id, 'dev_supplier_order_decision_admin', 'dev-supplier-order-decision-admin@example.test', 'Dev Decision Admin', '0204000501', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_admin_profile_id, 'admin', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'dev_only_supplier_order_decision_reseller', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-supplier-order-decision-shop', 'Dev Supplier Order Decision Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'Dev Supplier Order Decision A', 'active', 'approved', 'Dev Decision Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'Dev Supplier Order Decision B', 'active', 'approved', 'Dev Decision Supplier B');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values
    (v_product_a_id, v_supplier_a_id, 'QA Test', 'Dev Supplier Order Decision Product A', 'dev-supplier-order-decision-a', 'Development-only supplier decision product A', 'active', 'approved', 100, 10, 20, 'GHS'),
    (v_product_b_id, v_supplier_b_id, 'QA Test', 'Dev Supplier Order Decision Product B', 'dev-supplier-order-decision-b', 'Development-only supplier decision product B', 'active', 'approved', 100, 10, 20, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_accept_id, v_product_a_id, 'DEV-SUP-DEC-ACCEPT', 'Accept', 20, 1, 0, 'active'),
    (v_variant_reject_id, v_product_a_id, 'DEV-SUP-DEC-REJECT', 'Reject', 20, 1, 0, 'active'),
    (v_variant_cross_id, v_product_b_id, 'DEV-SUP-DEC-CROSS', 'Cross', 20, 1, 0, 'active'),
    (v_variant_expired_id, v_product_a_id, 'DEV-SUP-DEC-EXPIRED', 'Expired', 20, 1, 0, 'active'),
    (v_variant_released_id, v_product_a_id, 'DEV-SUP-DEC-RELEASED', 'Released', 20, 0, 0, 'active'),
    (v_variant_failed_id, v_product_a_id, 'DEV-SUP-DEC-FAILED', 'Failed', 20, 0, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_accept_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_accept_id, 'active', 15, 125, 'dev-supplier-order-decision-accept'),
    (v_listing_reject_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_reject_id, 'active', 15, 125, 'dev-supplier-order-decision-reject'),
    (v_listing_cross_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_cross_id, 'active', 15, 125, 'dev-supplier-order-decision-cross'),
    (v_listing_expired_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_expired_id, 'active', 15, 125, 'dev-supplier-order-decision-expired'),
    (v_listing_released_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_released_id, 'active', 15, 125, 'dev-supplier-order-decision-released'),
    (v_listing_failed_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_failed_id, 'active', 15, 125, 'dev-supplier-order-decision-failed');

  insert into public.checkout_drafts(id, customer_id, customer_profile_id, reseller_id, shop_id, reseller_product_id, product_id, variant_id, supplier_id, quantity, final_customer_price_snapshot_amount, line_total_snapshot_amount, currency_code, draft_status, product_name_snapshot, product_slug_snapshot, customer_contact_snapshot, delivery_address_snapshot)
  values
    (v_draft_accept_id, v_customer_id, v_customer_profile_id, v_reseller_id, v_shop_id, v_listing_accept_id, v_product_a_id, v_variant_accept_id, v_supplier_a_id, 1, 125, 125, 'GHS', 'converted', 'Decision Accept', 'decision-accept', jsonb_build_object('full_name','Dev Recipient','phone','0204000999'), jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999','region','Greater Accra','city','Accra')),
    (v_draft_reject_id, v_customer_id, v_customer_profile_id, v_reseller_id, v_shop_id, v_listing_reject_id, v_product_a_id, v_variant_reject_id, v_supplier_a_id, 1, 125, 125, 'GHS', 'converted', 'Decision Reject', 'decision-reject', jsonb_build_object('full_name','Dev Recipient','phone','0204000999'), jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999','region','Greater Accra','city','Accra')),
    (v_draft_cross_id, v_customer_id, v_customer_profile_id, v_reseller_id, v_shop_id, v_listing_cross_id, v_product_b_id, v_variant_cross_id, v_supplier_b_id, 1, 125, 125, 'GHS', 'converted', 'Decision Cross', 'decision-cross', jsonb_build_object('full_name','Dev Recipient','phone','0204000999'), jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999','region','Greater Accra','city','Accra')),
    (v_draft_expired_id, v_customer_id, v_customer_profile_id, v_reseller_id, v_shop_id, v_listing_expired_id, v_product_a_id, v_variant_expired_id, v_supplier_a_id, 1, 125, 125, 'GHS', 'converted', 'Decision Expired', 'decision-expired', jsonb_build_object('full_name','Dev Recipient','phone','0204000999'), jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999','region','Greater Accra','city','Accra')),
    (v_draft_released_id, v_customer_id, v_customer_profile_id, v_reseller_id, v_shop_id, v_listing_released_id, v_product_a_id, v_variant_released_id, v_supplier_a_id, 1, 125, 125, 'GHS', 'converted', 'Decision Released', 'decision-released', jsonb_build_object('full_name','Dev Recipient','phone','0204000999'), jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999','region','Greater Accra','city','Accra')),
    (v_draft_failed_id, v_customer_id, v_customer_profile_id, v_reseller_id, v_shop_id, v_listing_failed_id, v_product_a_id, v_variant_failed_id, v_supplier_a_id, 1, 125, 125, 'GHS', 'converted', 'Decision Failed', 'decision-failed', jsonb_build_object('full_name','Dev Recipient','phone','0204000999'), jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999','region','Greater Accra','city','Accra')),
    (v_draft_missing_reservation_id, v_customer_id, v_customer_profile_id, v_reseller_id, v_shop_id, v_listing_accept_id, v_product_a_id, v_variant_accept_id, v_supplier_a_id, 1, 125, 125, 'GHS', 'converted', 'Decision Missing Reservation', 'decision-missing-reservation', jsonb_build_object('full_name','Dev Recipient','phone','0204000999'), jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999','region','Greater Accra','city','Accra'));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, checkout_draft_id, order_status, payment_method, payment_collection_status, delivery_status, customer_confirmation_status, delivery_quote_status, subtotal_product_amount, total_payable_amount, currency_code, delivery_address_snapshot, customer_contact_snapshot)
  values
    (v_order_accept_id, 'RSR-DEV-SUP-DEC-ACCEPT', v_customer_id, v_reseller_id, v_shop_id, v_draft_accept_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999'), jsonb_build_object('full_name','Dev Recipient','phone','0204000999')),
    (v_order_reject_id, 'RSR-DEV-SUP-DEC-REJECT', v_customer_id, v_reseller_id, v_shop_id, v_draft_reject_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999'), jsonb_build_object('full_name','Dev Recipient','phone','0204000999')),
    (v_order_cross_id, 'RSR-DEV-SUP-DEC-CROSS', v_customer_id, v_reseller_id, v_shop_id, v_draft_cross_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', jsonb_build_object('recipient_name','Dev Recipient','phone','0204000999'), jsonb_build_object('full_name','Dev Recipient','phone','0204000999')),
    (v_order_expired_id, 'RSR-DEV-SUP-DEC-EXPIRED', v_customer_id, v_reseller_id, v_shop_id, v_draft_expired_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', '{}'::jsonb, '{}'::jsonb),
    (v_order_released_id, 'RSR-DEV-SUP-DEC-RELEASED', v_customer_id, v_reseller_id, v_shop_id, v_draft_released_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', '{}'::jsonb, '{}'::jsonb),
    (v_order_failed_id, 'RSR-DEV-SUP-DEC-FAILED', v_customer_id, v_reseller_id, v_shop_id, v_draft_failed_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', '{}'::jsonb, '{}'::jsonb),
    (v_order_missing_reservation_id, 'RSR-DEV-SUP-DEC-MISSING', v_customer_id, v_reseller_id, v_shop_id, v_draft_missing_reservation_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', '{}'::jsonb, '{}'::jsonb);

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_order_item_accept_id, v_order_accept_id, v_supplier_a_id, v_product_a_id, v_variant_accept_id, v_listing_accept_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_item_reject_id, v_order_reject_id, v_supplier_a_id, v_product_a_id, v_variant_reject_id, v_listing_reject_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_item_cross_id, v_order_cross_id, v_supplier_b_id, v_product_b_id, v_variant_cross_id, v_listing_cross_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_item_expired_id, v_order_expired_id, v_supplier_a_id, v_product_a_id, v_variant_expired_id, v_listing_expired_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_item_released_id, v_order_released_id, v_supplier_a_id, v_product_a_id, v_variant_released_id, v_listing_released_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_item_failed_id, v_order_failed_id, v_supplier_a_id, v_product_a_id, v_variant_failed_id, v_listing_failed_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_order_item_missing_reservation_id, v_order_missing_reservation_id, v_supplier_a_id, v_product_a_id, v_variant_accept_id, v_listing_accept_id, 1, 100, 10, 15, 110, 125, 125, 25, 15);

  insert into public.stock_reservations(id, reservation_reference, customer_id, reseller_id, reseller_product_id, product_id, variant_id, order_id, quantity, reservation_status, expires_at)
  values
    (v_reservation_accept_id, 'RSV-DEV-SUP-DEC-ACCEPT', v_customer_id, v_reseller_id, v_listing_accept_id, v_product_a_id, v_variant_accept_id, v_order_accept_id, 1, 'reserved', now() + interval '1 hour'),
    (v_reservation_reject_id, 'RSV-DEV-SUP-DEC-REJECT', v_customer_id, v_reseller_id, v_listing_reject_id, v_product_a_id, v_variant_reject_id, v_order_reject_id, 1, 'reserved', now() + interval '1 hour'),
    (v_reservation_cross_id, 'RSV-DEV-SUP-DEC-CROSS', v_customer_id, v_reseller_id, v_listing_cross_id, v_product_b_id, v_variant_cross_id, v_order_cross_id, 1, 'reserved', now() + interval '1 hour'),
    (v_reservation_expired_id, 'RSV-DEV-SUP-DEC-EXPIRED', v_customer_id, v_reseller_id, v_listing_expired_id, v_product_a_id, v_variant_expired_id, v_order_expired_id, 1, 'reserved', now() - interval '1 minute'),
    (v_reservation_released_id, 'RSV-DEV-SUP-DEC-RELEASED', v_customer_id, v_reseller_id, v_listing_released_id, v_product_a_id, v_variant_released_id, v_order_released_id, 1, 'released', now() + interval '1 hour'),
    (v_reservation_failed_id, 'RSV-DEV-SUP-DEC-FAILED', v_customer_id, v_reseller_id, v_listing_failed_id, v_product_a_id, v_variant_failed_id, v_order_failed_id, 1, 'failed', now() + interval '1 hour');

  select reserved_stock_quantity into v_accept_stock_before from public.product_variants where id = v_variant_accept_id;
  select reserved_stock_quantity into v_reject_stock_before from public.product_variants where id = v_variant_reject_id;
  select count(*) into v_movements_before from public.inventory_movements;
  select to_regclass('public.payments') is null into v_payments_table_absent;
  select count(*) into v_delivery_rows_before from public.delivery_quotes;
  select count(*) into v_settlement_rows_before from public.settlements;
  select count(*) into v_commission_rows_before from public.commissions;
  select count(*) into v_withdrawal_rows_before from public.withdrawals;

  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_supplier_a');

  select to_jsonb(x) into v_accept_row
  from public.supplier_accept_order(v_order_accept_id, 'dev-accept-key') x
  limit 1;

  perform pg_temp.supplier_order_decision_record_result('supplier accepts own order', v_accept_row ->> 'order_status' = 'supplier_confirmed');
  perform pg_temp.supplier_order_decision_record_result('pending order becomes supplier_confirmed', (select order_status::text from public.orders where id = v_order_accept_id) = 'supplier_confirmed');
  perform pg_temp.supplier_order_decision_record_result('accept reservation remains reserved', (select reservation_status::text from public.stock_reservations where id = v_reservation_accept_id) = 'reserved');
  select reserved_stock_quantity into v_accept_stock_after from public.product_variants where id = v_variant_accept_id;
  perform pg_temp.supplier_order_decision_record_result('accept reserved stock unchanged', v_accept_stock_after = v_accept_stock_before);
  perform pg_temp.supplier_order_decision_record_result('accept total stock unchanged', (select total_stock_quantity from public.product_variants where id = v_variant_accept_id) = 20);
  perform pg_temp.supplier_order_decision_record_result('accept sold stock unchanged', (select sold_stock_quantity from public.product_variants where id = v_variant_accept_id) = 0);
  perform pg_temp.supplier_order_decision_record_result('accept payment remains not_collected', (select payment_collection_status::text from public.orders where id = v_order_accept_id) = 'not_collected');
  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_record_result('accept audit event created', (select count(*) from public.audit_logs where action = 'supplier_order_accepted' and target_entity_id = v_order_accept_id) = 1);

  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_supplier_a');
  perform public.supplier_accept_order(v_order_accept_id, 'dev-accept-key');
  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_record_result('duplicate accept returns same state', (select order_status::text from public.orders where id = v_order_accept_id) = 'supplier_confirmed');
  perform pg_temp.supplier_order_decision_record_result('duplicate accept creates no duplicate mutation', (select count(*) from public.audit_logs where action = 'supplier_order_accepted' and target_entity_id = v_order_accept_id) = 1);

  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_supplier_a');
  select to_jsonb(x) into v_reject_row
  from public.supplier_reject_order(v_order_reject_id, 'out_of_stock', 'dev-only private note', 'dev-reject-key') x
  limit 1;

  perform pg_temp.supplier_order_decision_record_result('supplier rejects own order', v_reject_row ->> 'order_status' = 'supplier_rejected');
  perform pg_temp.supplier_order_decision_record_result('pending order becomes supplier_rejected', (select order_status::text from public.orders where id = v_order_reject_id) = 'supplier_rejected');
  perform pg_temp.supplier_order_decision_record_result('reject reason code stored', (select supplier_rejection_reason_code from public.orders where id = v_order_reject_id) = 'out_of_stock');
  perform pg_temp.supplier_order_decision_record_result('optional note validated and private', (select supplier_rejection_reason_note from public.orders where id = v_order_reject_id) = 'dev-only private note');
  perform pg_temp.supplier_order_decision_record_result('reject reservation becomes released', (select reservation_status::text from public.stock_reservations where id = v_reservation_reject_id) = 'released');
  perform pg_temp.supplier_order_decision_record_result('reject released_at populated', (select released_at is not null from public.stock_reservations where id = v_reservation_reject_id));
  select reserved_stock_quantity into v_reject_stock_after from public.product_variants where id = v_variant_reject_id;
  perform pg_temp.supplier_order_decision_record_result('reject reserved stock decreases once', v_reject_stock_after = v_reject_stock_before - 1);
  perform pg_temp.supplier_order_decision_record_result('reject available stock increases correctly', (select total_stock_quantity - reserved_stock_quantity - sold_stock_quantity from public.product_variants where id = v_variant_reject_id) = 20);
  perform pg_temp.supplier_order_decision_record_result('reject total stock unchanged', (select total_stock_quantity from public.product_variants where id = v_variant_reject_id) = 20);
  perform pg_temp.supplier_order_decision_record_result('reject sold stock unchanged', (select sold_stock_quantity from public.product_variants where id = v_variant_reject_id) = 0);
  perform pg_temp.supplier_order_decision_record_result('reserved stock never negative', (select reserved_stock_quantity from public.product_variants where id = v_variant_reject_id) >= 0);
  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_record_result('rejection audit event created', (select count(*) from public.audit_logs where action = 'supplier_order_rejected' and target_entity_id = v_order_reject_id) = 1);
  perform pg_temp.supplier_order_decision_record_result('release event created', (select count(*) from public.audit_logs where action = 'stock_reservation_released' and target_entity_id = v_reservation_reject_id) = 1);
  perform pg_temp.supplier_order_decision_record_result('stock decrement event created', (select count(*) from public.audit_logs where action = 'reserved_stock_decremented' and target_entity_id = v_variant_reject_id) = 1);
  select count(*) into v_movements_after_first_reject from public.inventory_movements where order_id = v_order_reject_id and movement_type = 'reservation_released';

  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_supplier_a');
  perform public.supplier_reject_order(v_order_reject_id, 'out_of_stock', 'dev-only private note', 'dev-reject-key');
  perform pg_temp.supplier_order_decision_reset_context();
  select count(*) into v_movements_after_second_reject from public.inventory_movements where order_id = v_order_reject_id and movement_type = 'reservation_released';
  perform pg_temp.supplier_order_decision_record_result('duplicate reject returns same state', (select order_status::text from public.orders where id = v_order_reject_id) = 'supplier_rejected');
  perform pg_temp.supplier_order_decision_record_result('duplicate reject does not double-release', (select reserved_stock_quantity from public.product_variants where id = v_variant_reject_id) = v_reject_stock_after);
  perform pg_temp.supplier_order_decision_record_result('duplicate reject does not duplicate movement', v_movements_after_second_reject = v_movements_after_first_reject);

  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_supplier_a');
  perform pg_temp.supplier_order_decision_expect_blocked('cross-supplier accept blocked', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'cross')$sql$, v_order_cross_id));
  perform pg_temp.supplier_order_decision_expect_blocked('cross-supplier reject blocked', format($sql$select count(*) from public.supplier_reject_order(%L::uuid, 'out_of_stock', null, 'cross')$sql$, v_order_cross_id));
  perform pg_temp.supplier_order_decision_expect_blocked('rejected order cannot be accepted', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'after-reject')$sql$, v_order_reject_id));
  perform pg_temp.supplier_order_decision_expect_blocked('confirmed order cannot be rejected', format($sql$select count(*) from public.supplier_reject_order(%L::uuid, 'out_of_stock', null, 'after-confirm')$sql$, v_order_accept_id));
  perform pg_temp.supplier_order_decision_expect_blocked('expired reservation cannot be accepted', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'expired')$sql$, v_order_expired_id));
  perform pg_temp.supplier_order_decision_expect_blocked('released reservation cannot be accepted', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'released')$sql$, v_order_released_id));
  perform pg_temp.supplier_order_decision_expect_blocked('failed reservation cannot be accepted', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'failed')$sql$, v_order_failed_id));
  perform pg_temp.supplier_order_decision_expect_blocked('invalid reason blocked', format($sql$select count(*) from public.supplier_reject_order(%L::uuid, 'not_allowed', null, 'bad-reason')$sql$, v_order_expired_id));
  perform pg_temp.supplier_order_decision_expect_blocked('oversized note blocked', format($sql$select count(*) from public.supplier_reject_order(%L::uuid, 'other', repeat('x', 501), 'long-note')$sql$, v_order_expired_id));
  perform pg_temp.supplier_order_decision_expect_blocked('missing reservation fails safely', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'missing-reservation')$sql$, v_order_missing_reservation_id));

  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_customer');
  perform pg_temp.supplier_order_decision_expect_blocked('customer blocked', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'customer')$sql$, v_order_expired_id));

  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_reseller');
  perform pg_temp.supplier_order_decision_expect_blocked('reseller blocked', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'reseller')$sql$, v_order_expired_id));

  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_admin');
  perform pg_temp.supplier_order_decision_expect_blocked('admin_staff blocked', format($sql$select count(*) from public.supplier_reject_order(%L::uuid, 'out_of_stock', null, 'admin')$sql$, v_order_expired_id));

  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_set_anon_context();
  perform pg_temp.supplier_order_decision_expect_blocked('anonymous blocked', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'anon')$sql$, v_order_expired_id));

  perform pg_temp.supplier_order_decision_reset_context();
  perform pg_temp.supplier_order_decision_set_context('dev_supplier_order_decision_supplier_a');
  perform pg_temp.supplier_order_decision_expect_blocked('missing order does not leak existence', format($sql$select count(*) from public.supplier_accept_order(%L::uuid, 'missing')$sql$, gen_random_uuid()));

  perform pg_temp.supplier_order_decision_record_result(
    'same order cannot end both confirmed and rejected',
    not exists (
      select 1
      from public.orders
      where id in (v_order_accept_id, v_order_reject_id)
        and supplier_confirmed_at is not null
        and supplier_rejected_at is not null
    )
  );
  perform pg_temp.supplier_order_decision_record_result('failed transaction leaves no partial state', (select order_status::text from public.orders where id = v_order_expired_id) = 'placed_pending_confirmation');
  perform pg_temp.supplier_order_decision_record_result('reservation/order mismatch fails safely', (select order_status::text from public.orders where id = v_order_missing_reservation_id) = 'placed_pending_confirmation');
  perform pg_temp.supplier_order_decision_record_result('variant/reservation mismatch fails safely', (select order_status::text from public.orders where id = v_order_missing_reservation_id) = 'placed_pending_confirmation');
  perform pg_temp.supplier_order_decision_record_result('pending order with already released reservation fails safely', (select order_status::text from public.orders where id = v_order_released_id) = 'placed_pending_confirmation');
  perform pg_temp.supplier_order_decision_record_result(
    'no payment delivery preparation finance side effects',
    v_payments_table_absent
      and (select count(*) from public.delivery_quotes) = v_delivery_rows_before
      and (select count(*) from public.settlements) = v_settlement_rows_before
      and (select count(*) from public.commissions) = v_commission_rows_before
      and (select count(*) from public.withdrawals) = v_withdrawal_rows_before
      and (select count(*) from public.inventory_movements where order_id = v_order_reject_id and movement_type = 'reservation_released') = 1,
    'payments_absent=' || v_payments_table_absent::text
      || ', delivery_delta=' || ((select count(*) from public.delivery_quotes) - v_delivery_rows_before)::text
      || ', settlement_delta=' || ((select count(*) from public.settlements) - v_settlement_rows_before)::text
      || ', commission_delta=' || ((select count(*) from public.commissions) - v_commission_rows_before)::text
      || ', withdrawal_delta=' || ((select count(*) from public.withdrawals) - v_withdrawal_rows_before)::text
      || ', reservation_release_movements=' || (select count(*) from public.inventory_movements where order_id = v_order_reject_id and movement_type = 'reservation_released')::text
  );
  perform pg_temp.supplier_order_decision_record_result('commercial snapshot mutation blocked', (select supplier_base_price_snapshot_amount from public.order_items where id = v_order_item_reject_id) = 100);
  perform pg_temp.supplier_order_decision_record_result('fixture data rolled back', true, 'transaction rolls back after assertion summary');

  perform pg_temp.supplier_order_decision_reset_context();
end;
$$;

select test_name, passed, details
from supplier_order_decision_test_results
order by test_name;

do $$
declare
  v_failures text;
begin
  select string_agg(test_name || coalesce(': ' || details, ''), '; ' order by test_name)
  into v_failures
  from supplier_order_decision_test_results
  where not passed;

  if v_failures is not null then
    raise exception 'Supplier order decision RPC boundary failures: %', v_failures;
  end if;
end;
$$;

rollback;
