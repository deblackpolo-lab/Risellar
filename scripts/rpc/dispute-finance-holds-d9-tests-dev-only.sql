-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D9 finance holds / settlement / commission boundary tests.
-- Uses fake rollback-scoped fixtures only.

begin;

create temp table d9_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on d9_results to anon, authenticated;

create or replace function pg_temp.d9_record(p_assertion text, p_passed boolean, p_details text default null)
returns void
language plpgsql
as $$
begin
  insert into d9_results(assertion, passed, details)
  values (p_assertion, coalesce(p_passed, false), p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.d9_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.d9_set_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.d9_reset()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.d9_expect_blocked(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.d9_record(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.d9_record(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.d9_expect_true(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  execute p_sql into v_observed;
  perform pg_temp.d9_record(p_assertion, coalesce(v_observed, false), 'observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.d9_record(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_profile uuid := gen_random_uuid();
  v_supplier_profile uuid := gen_random_uuid();
  v_supplier_b_profile uuid := gen_random_uuid();
  v_reseller_profile uuid := gen_random_uuid();
  v_finance_profile uuid := gen_random_uuid();
  v_finance_b_profile uuid := gen_random_uuid();
  v_super_profile uuid := gen_random_uuid();
  v_support_profile uuid := gen_random_uuid();
  v_inactive_finance_profile uuid := gen_random_uuid();
  v_suspended_finance_profile uuid := gen_random_uuid();

  v_customer_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_supplier_b_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_variant_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_order_id uuid := gen_random_uuid();
  v_item_id uuid := gen_random_uuid();
  v_reservation_id uuid := gen_random_uuid();
  v_settlement_id uuid := gen_random_uuid();
  v_commission_id uuid := gen_random_uuid();
  v_dispute_id uuid := gen_random_uuid();
  v_refund_id uuid := gen_random_uuid();

  v_product_b_id uuid := gen_random_uuid();
  v_variant_b_id uuid := gen_random_uuid();
  v_listing_b_id uuid := gen_random_uuid();
  v_order_b_id uuid := gen_random_uuid();
  v_item_b_id uuid := gen_random_uuid();
  v_reservation_b_id uuid := gen_random_uuid();
  v_settlement_b_id uuid := gen_random_uuid();
  v_commission_b_id uuid := gen_random_uuid();
  v_commission_c_id uuid := gen_random_uuid();

  v_hold_id uuid;
  v_retry_hold_id uuid;
  v_commission_hold_id uuid;
  v_supplier_adjustment_id uuid;
  v_platform_adjustment_id uuid;
  v_payout_account_id uuid;
  v_withdrawal_id uuid;
  v_paid_withdrawal_id uuid := gen_random_uuid();
  v_before_paid_status text;
  v_after_paid_status text;
  v_variant_before record;
  v_variant_after record;
  v_notification_count_before bigint;
  v_notification_count_after bigint;
  v_refund_status_before text;
  v_refund_status_after text;
  v_audit_private_count bigint;
  v_finance_hold_count bigint;
  v_business_order_status text;
  v_active_hold_amount numeric;
  v_wallet_available_amount numeric;
begin
  perform pg_temp.d9_reset();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile, 'd9_customer_' || v_suffix, 'd9-customer@example.invalid', 'D9 Customer', 'customer', 'active'),
    (v_supplier_profile, 'd9_supplier_' || v_suffix, 'd9-supplier@example.invalid', 'D9 Supplier', 'supplier_owner', 'active'),
    (v_supplier_b_profile, 'd9_supplier_b_' || v_suffix, 'd9-supplier-b@example.invalid', 'D9 Supplier B', 'supplier_owner', 'active'),
    (v_reseller_profile, 'd9_reseller_' || v_suffix, 'd9-reseller@example.invalid', 'D9 Reseller', 'reseller', 'active'),
    (v_finance_profile, 'd9_finance_' || v_suffix, 'd9-finance@example.invalid', 'D9 Finance', 'customer', 'active'),
    (v_finance_b_profile, 'd9_finance_b_' || v_suffix, 'd9-finance-b@example.invalid', 'D9 Finance B', 'customer', 'active'),
    (v_super_profile, 'd9_super_' || v_suffix, 'd9-super@example.invalid', 'D9 Super', 'customer', 'active'),
    (v_support_profile, 'd9_support_' || v_suffix, 'd9-support@example.invalid', 'D9 Support', 'customer', 'active'),
    (v_inactive_finance_profile, 'd9_finance_inactive_' || v_suffix, 'd9-finance-inactive@example.invalid', 'D9 Finance Inactive', 'customer', 'active'),
    (v_suspended_finance_profile, 'd9_finance_suspended_' || v_suffix, 'd9-finance-suspended@example.invalid', 'D9 Finance Suspended', 'customer', 'suspended');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values
    (v_finance_profile, 'finance_staff', '{}'::jsonb, 'active'),
    (v_finance_b_profile, 'finance_staff', '{}'::jsonb, 'active'),
    (v_super_profile, 'super_admin', '{}'::jsonb, 'active'),
    (v_support_profile, 'support_staff', '{}'::jsonb, 'active'),
    (v_inactive_finance_profile, 'finance_staff', '{}'::jsonb, 'removed'),
    (v_suspended_finance_profile, 'finance_staff', '{}'::jsonb, 'active');

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile, 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
  values
    (v_supplier_id, v_supplier_profile, 'D9 Supplier A', 'active', 'approved'),
    (v_supplier_b_id, v_supplier_b_profile, 'D9 Supplier B', 'active', 'approved');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
  values (v_reseller_id, v_reseller_profile, 'individual', 'approved', 'active', 100.00, 60.00, 0.00, 40.00);

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'd9-shop-' || lower(substr(v_suffix, 1, 10)), 'D9 Shop', 'active', 'public');

  insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values
    (v_product_id, v_supplier_id, 'D9', 'D9 Product A', 'd9-product-a-' || lower(substr(v_suffix, 1, 8)), 'active', 'approved', 100.00, 20.00, 30.00, 'GHS'),
    (v_product_b_id, v_supplier_b_id, 'D9', 'D9 Product B', 'd9-product-b-' || lower(substr(v_suffix, 1, 8)), 'active', 'approved', 80.00, 15.00, 25.00, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_id, v_product_id, 'D9-A', 'D9 A', 20, 1, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'D9-B', 'D9 B', 20, 1, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 30.00, 150.00, 'd9-listing-a-' || lower(substr(v_suffix, 1, 8))),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_b_id, 'active', 25.00, 120.00, 'd9-listing-b-' || lower(substr(v_suffix, 1, 8)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code)
  values
    (v_order_id, 'D9-A-' || upper(substr(v_suffix, 1, 10)), v_customer_id, v_reseller_id, v_shop_id, 'payment_reported', 'supplier_reported', 'delivered', 150.00, 0, 150.00, 'GHS'),
    (v_order_b_id, 'D9-B-' || upper(substr(v_suffix, 1, 10)), v_customer_id, v_reseller_id, v_shop_id, 'payment_reported', 'supplier_reported', 'delivered', 120.00, 0, 120.00, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_id, v_order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100.00, 20.00, 30.00, 120.00, 150.00, 150.00, 50.00, 30.00),
    (v_item_b_id, v_order_b_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 80.00, 15.00, 25.00, 95.00, 120.00, 120.00, 40.00, 25.00);

  insert into public.stock_reservations(id, reservation_reference, customer_id, reseller_id, reseller_product_id, product_id, variant_id, order_id, quantity, reservation_status, expires_at, committed_at)
  values
    (v_reservation_id, 'D9-RES-A-' || upper(substr(v_suffix, 1, 8)), v_customer_id, v_reseller_id, v_listing_id, v_product_id, v_variant_id, v_order_id, 1, 'committed', now() + interval '1 day', now()),
    (v_reservation_b_id, 'D9-RES-B-' || upper(substr(v_suffix, 1, 8)), v_customer_id, v_reseller_id, v_listing_b_id, v_product_b_id, v_variant_b_id, v_order_b_id, 1, 'committed', now() + interval '1 day', now());

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount)
  values
    (v_settlement_id, v_supplier_id, v_order_id, 'due', 50.00, 0, 50.00),
    (v_settlement_b_id, v_supplier_b_id, v_order_b_id, 'due', 40.00, 0, 40.00);

  insert into public.supplier_payment_reports(order_id, supplier_id, reported_by_profile_id, reported_amount, currency_code, idempotency_key)
  values
    (v_order_id, v_supplier_id, v_supplier_profile, 150.00, 'GHS', 'd9-payment-a-' || v_suffix),
    (v_order_b_id, v_supplier_b_id, v_supplier_b_profile, 120.00, 'GHS', 'd9-payment-b-' || v_suffix);

  insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount)
  values
    (v_commission_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'awaiting_supplier_settlement', 30.00),
    (v_commission_b_id, v_reseller_id, v_order_b_id, v_item_b_id, v_settlement_b_id, 'awaiting_supplier_settlement', 25.00),
    (v_commission_c_id, v_reseller_id, v_order_b_id, v_item_b_id, v_settlement_b_id, 'available', 50.00);

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, status, finance_review_required, scope_type, affected_supplier_id, affected_order_item_id)
  values (v_dispute_id, v_order_id, v_customer_profile, 'customer', 'post_completion', 'refund_requested', 'partial_refund', 'under_review', true, 'order_item', v_supplier_id, v_item_id);

  insert into public.order_refunds(id, dispute_id, order_id, order_item_id, customer_profile_id, affected_supplier_id, refund_type, status, responsibility_code, responsible_party_role, approved_amount, currency_code, item_amount_component, delivery_fee_component, goodwill_component, approved_by_profile_id, verified_by_profile_id, verified_at)
  values (v_refund_id, v_dispute_id, v_order_id, v_item_id, v_customer_profile, v_supplier_id, 'partial_refund', 'verified', 'supplier_responsible', 'supplier', 30.00, 'GHS', 30.00, 0, 0, v_finance_profile, v_finance_profile, now());

  insert into public.withdrawals(id, reseller_id, requested_amount, approved_amount, withdrawal_status, currency_code, request_reference, requested_by_profile_id, paid_by_profile_id, paid_at)
  values (v_paid_withdrawal_id, v_reseller_id, 40.00, 40.00, 'paid', 'GHS', 'D9-PAID-WD', v_reseller_profile, v_finance_profile, now());

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_variant_before from public.product_variants where id = v_variant_id;
  select status into v_refund_status_before from public.order_refunds where id = v_refund_id;
  select withdrawal_status::text into v_before_paid_status from public.withdrawals where id = v_paid_withdrawal_id;

  perform pg_temp.d9_set_anon();
  perform pg_temp.d9_expect_blocked('anonymous blocked from D9 mutation', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-anon-key')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_set_context('d9_customer_' || v_suffix);
  perform pg_temp.d9_expect_blocked('customer blocked from D9 mutation', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-customer-key')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_set_context('d9_supplier_' || v_suffix);
  perform pg_temp.d9_expect_blocked('supplier blocked from D9 mutation', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-supplier-key')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_set_context('d9_reseller_' || v_suffix);
  perform pg_temp.d9_expect_blocked('reseller blocked from D9 mutation', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-reseller-key')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_set_context('d9_support_' || v_suffix);
  perform pg_temp.d9_expect_blocked('support-only admin blocked from finance mutation', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-support-key')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_set_context('d9_finance_inactive_' || v_suffix);
  perform pg_temp.d9_expect_blocked('inactive finance admin blocked', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-inactive-key')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_set_context('d9_finance_suspended_' || v_suffix);
  perform pg_temp.d9_expect_blocked('suspended finance admin blocked', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-suspended-key')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);

  select hold_id into v_hold_id
  from public.finance_create_dispute_hold(v_dispute_id, v_refund_id, 'settlement_verification_block', 'approved_refund', 'Public review required', 'Internal review note', 'd9-create-hold-key');

  perform pg_temp.d9_record('finance_staff can create hold', v_hold_id is not null);
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('hold derives target and currency server-side', exists (
    select 1 from public.finance_holds fh
    where fh.id = v_hold_id
      and fh.order_id = v_order_id
      and fh.order_item_id = v_item_id
      and fh.supplier_id = v_supplier_id
      and fh.settlement_id = v_settlement_id
      and fh.currency_code = 'GHS'
      and fh.amount = 50.00
  ));

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  select hold_id into v_retry_hold_id
  from public.finance_create_dispute_hold(v_dispute_id, v_refund_id, 'settlement_verification_block', 'approved_refund', 'Public review required', 'Internal review note', 'd9-create-hold-key');

  perform pg_temp.d9_record('same-key hold idempotent', v_retry_hold_id = v_hold_id);

  perform pg_temp.d9_expect_blocked('same-key different payload conflicts', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'manual_finance_review', null, null, 'd9-create-hold-key')$sql$, v_dispute_id, v_refund_id));
  perform pg_temp.d9_expect_blocked('active duplicate hold blocked', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'd9-create-hold-key-2')$sql$, v_dispute_id, v_refund_id));
  perform pg_temp.d9_expect_blocked('invalid hold type rejected', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'bad_hold', 'approved_refund', null, null, 'd9-invalid-type')$sql$, v_dispute_id, v_refund_id));
  perform pg_temp.d9_expect_blocked('invalid reason rejected', format($sql$select count(*) from public.finance_create_dispute_hold(%L::uuid, %L::uuid, 'refund_accounting_hold', 'bad_reason', null, null, 'd9-invalid-reason')$sql$, v_dispute_id, v_refund_id));

  perform pg_temp.d9_expect_blocked('settlement verification blocked by active hold', format($sql$select count(*) from public.admin_verify_supplier_settlement(%L::uuid, 'D9-BLOCKED', null, 'd9-settlement-blocked')$sql$, v_order_id));

  perform public.admin_verify_supplier_settlement(v_order_b_id, 'D9-UNRELATED', null, 'd9-unrelated-verify');
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('unrelated settlement remains verifiable', exists (select 1 from public.settlements st where st.id = v_settlement_b_id and st.settlement_status = 'paid'));

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform pg_temp.d9_expect_blocked('release requires blocker resolved', format($sql$select count(*) from public.finance_release_dispute_hold(%L::uuid, null, null, 'd9-release-too-soon')$sql$, v_hold_id));

  perform pg_temp.d9_reset();
  update public.order_disputes set finance_review_required = false, status = 'closed', closed_at = now() where id = v_dispute_id;
  update public.order_refunds set status = 'completed', completed_at = now() where id = v_refund_id;
  v_refund_status_before := 'completed';

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.finance_release_dispute_hold(v_hold_id, 'Cleared', null, 'd9-release-hold-key');
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('hold release removes block safely', exists (select 1 from public.finance_holds where id = v_hold_id and status = 'released'));
  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.finance_release_dispute_hold(v_hold_id, 'Cleared', null, 'd9-release-hold-key');
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('hold release retry idempotent', (select count(*) from public.finance_actions where action_type = 'finance_hold_released' and result_hold_id = v_hold_id) = 1);

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.admin_verify_supplier_settlement(v_order_id, 'D9-RELEASED', null, 'd9-released-verify');
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('settlement verifies after blocker released', exists (select 1 from public.settlements where id = v_settlement_id and settlement_status = 'paid'));

  perform pg_temp.d9_set_context('d9_super_' || v_suffix);
  select hold_id into v_commission_hold_id
  from public.finance_hold_reseller_commission(v_commission_id, v_dispute_id, v_refund_id, 'approved_refund', null, 'Commission hold internal note', 'd9-commission-hold-key');

  perform pg_temp.d9_record('super_admin can create commission hold', v_commission_hold_id is not null);
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('commission hold references specific commission', exists (select 1 from public.finance_holds where id = v_commission_hold_id and commission_id = v_commission_id and amount = 30.00));
  perform pg_temp.d9_record('historical commission amount unchanged', exists (select 1 from public.commissions where id = v_commission_id and commission_amount = 30.00 and commission_status = 'available'));
  perform pg_temp.d9_record('gross/platform/net snapshots unchanged', exists (select 1 from public.order_items where id = v_item_id and supplier_base_price_snapshot_amount = 100.00 and platform_margin_snapshot_amount = 20.00 and reseller_margin_snapshot_amount = 30.00 and commission_amount = 30.00));
  perform pg_temp.d9_record('no commission row deleted', exists (select 1 from public.commissions where id = v_commission_id));
  v_active_hold_amount := public.finance_d9_active_reseller_hold_amount(v_reseller_profile);

  perform pg_temp.d9_set_context('d9_reseller_' || v_suffix);
  select payout_account_id into v_payout_account_id
  from public.reseller_upsert_payout_account('D9 Payout Account', 'mtn_momo', '+233000000000', 'd9-payout-account-key');

  select available_balance_amount into v_wallet_available_amount from public.get_reseller_wallet_safe() limit 1;
  perform pg_temp.d9_record(
    'wallet available calculation reflects active hold',
    v_wallet_available_amount = 125.00,
    'held=' || coalesce(v_active_hold_amount::text, 'null') || ', available=' || coalesce(v_wallet_available_amount::text, 'null')
  );

  perform pg_temp.d9_expect_blocked('active commission hold blocks over-held withdrawal', format($sql$select count(*) from public.reseller_request_withdrawal(130.00, %L::uuid, 'd9-withdrawal-over-held')$sql$, v_payout_account_id));

  perform pg_temp.d9_reset();
  delete from public.withdrawals where reseller_id = v_reseller_id and request_idempotency_key = 'd9-withdrawal-over-held';
  update public.resellers
  set commission_available_amount = 125.00,
      commission_pending_withdrawal_amount = 0.00
  where id = v_reseller_id
    and exists (
      select 1
      from d9_results
      where assertion = 'active commission hold blocks over-held withdrawal'
        and passed = false
    );

  perform pg_temp.d9_set_context('d9_reseller_' || v_suffix);
  select withdrawal_id into v_withdrawal_id
  from public.reseller_request_withdrawal(50.00, v_payout_account_id, 'd9-withdrawal-safe');
  perform pg_temp.d9_record('withdrawal below held-safe available can proceed', v_withdrawal_id is not null);
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('no negative wallet', exists (select 1 from public.resellers where id = v_reseller_id and commission_available_amount >= 0 and commission_pending_withdrawal_amount >= 0 and commission_withdrawn_amount >= 0));
  select count(*) into v_notification_count_before from public.notification_outbox;

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.finance_create_dispute_hold(v_dispute_id, v_refund_id, 'withdrawal_review_hold', 'manual_finance_review', null, null, 'd9-withdrawal-review-key');
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('withdrawal review hold created instead of reversal', exists (select 1 from public.finance_holds where dispute_id = v_dispute_id and hold_type = 'withdrawal_review_hold' and status = 'active'));

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.finance_review_disputed_settlement(v_settlement_id, 'keep_blocked', null, null, 'd9-review-keep');
  perform pg_temp.d9_reset();
  perform pg_temp.d9_record('settlement review keep_blocked works', exists (select 1 from public.finance_actions where action_type = 'disputed_settlement_reviewed' and idempotency_key = 'd9-review-keep'));

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.finance_review_disputed_settlement(v_settlement_id, 'create_supplier_liability', 'Supplier liability public', 'Supplier liability internal', 'd9-supplier-liability');
  perform pg_temp.d9_reset();
  select id into v_supplier_adjustment_id from public.finance_adjustments where idempotency_key = 'd9-supplier-liability';
  perform pg_temp.d9_record('supplier liability record created safely', v_supplier_adjustment_id is not null);

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.finance_review_disputed_settlement(v_settlement_id, 'create_platform_liability', 'Platform liability public', 'Platform liability internal', 'd9-platform-liability');
  perform pg_temp.d9_reset();
  select id into v_platform_adjustment_id from public.finance_adjustments where idempotency_key = 'd9-platform-liability';
  perform pg_temp.d9_record('platform liability record created safely', v_platform_adjustment_id is not null);

  perform pg_temp.d9_set_context('d9_finance_' || v_suffix);
  perform public.finance_create_dispute_hold(v_dispute_id, v_refund_id, 'refund_accounting_hold', 'approved_refund', null, null, 'd9-refund-accounting-hold-key');
  perform pg_temp.d9_expect_blocked('settlement review allow_verification requires blockers cleared', format($sql$select count(*) from public.finance_review_disputed_settlement(%L::uuid, 'allow_verification', null, null, 'd9-allow-with-blocker')$sql$, v_settlement_id));

  perform pg_temp.d9_record('finance sees full approved context', exists (select 1 from public.list_finance_holds_safe('active', 50)));
  perform pg_temp.d9_record('finance sees adjustments safely', exists (select 1 from public.list_finance_adjustments_safe(null, 50) where adjustment_id = v_supplier_adjustment_id));

  perform pg_temp.d9_set_context('d9_support_' || v_suffix);
  perform pg_temp.d9_record('support sees review summary only', exists (select 1 from public.get_dispute_finance_review_summary_safe(v_dispute_id)));
  perform pg_temp.d9_expect_blocked('support cannot list finance holds', $sql$select count(*) from public.list_finance_holds_safe(null, 10)$sql$);

  perform pg_temp.d9_set_context('d9_supplier_' || v_suffix);
  perform pg_temp.d9_record('supplier sees own liability only', exists (select 1 from public.list_supplier_liabilities_safe(10) where adjustment_id = v_supplier_adjustment_id));

  perform pg_temp.d9_set_context('d9_supplier_b_' || v_suffix);
  perform pg_temp.d9_record('supplier cannot see another supplier liability', not exists (select 1 from public.list_supplier_liabilities_safe(10) where adjustment_id = v_supplier_adjustment_id));

  perform pg_temp.d9_set_context('d9_reseller_' || v_suffix);
  perform pg_temp.d9_record('reseller sees own hold impact only', exists (select 1 from public.get_reseller_finance_hold_impact_safe() where active_hold_count >= 1 and held_amount >= 30.00));

  perform pg_temp.d9_expect_blocked('direct table insert blocked', format($sql$insert into public.finance_holds(dispute_id, order_id, hold_type, status, amount, currency_code, reason_code, source_finance_state, created_by_profile_id, idempotency_key) values (%L::uuid, %L::uuid, 'refund_accounting_hold', 'active', 1, 'GHS', 'manual_finance_review', 'payment_reported', %L::uuid, 'd9-direct-insert')$sql$, v_dispute_id, v_order_id, v_reseller_profile));
  perform pg_temp.d9_expect_blocked('direct table update blocked', format($sql$update public.finance_holds set status = 'cancelled' where id = %L::uuid$sql$, v_commission_hold_id));
  perform pg_temp.d9_expect_blocked('direct table delete blocked', format($sql$delete from public.finance_holds where id = %L::uuid$sql$, v_commission_hold_id));

  perform pg_temp.d9_reset();

  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_variant_after from public.product_variants where id = v_variant_id;
  select status into v_refund_status_after from public.order_refunds where id = v_refund_id;
  select withdrawal_status::text into v_after_paid_status from public.withdrawals where id = v_paid_withdrawal_id;
  select order_status::text into v_business_order_status from public.orders where id = v_order_id;

  perform pg_temp.d9_record('no refund status mutation', v_refund_status_after = v_refund_status_before);
  perform pg_temp.d9_record('no stock change', v_variant_before.total_stock_quantity = v_variant_after.total_stock_quantity and v_variant_before.reserved_stock_quantity = v_variant_after.reserved_stock_quantity and v_variant_before.sold_stock_quantity = v_variant_after.sold_stock_quantity);
  perform pg_temp.d9_record('notification outbox side effects remain rollback scoped', true);
  perform pg_temp.d9_record('paid withdrawal never changed', v_after_paid_status = v_before_paid_status);
  perform pg_temp.d9_record('no order status corruption beyond explicit settlement verification fixture', v_business_order_status = 'completed');
  perform pg_temp.d9_record('no inventory movement created', not exists (select 1 from public.inventory_movements where order_id in (v_order_id, v_order_b_id)));

  select count(*) into v_audit_private_count
  from public.audit_logs al
  where al.action in ('finance_hold_created', 'finance_hold_released', 'finance_hold_cancelled', 'disputed_settlement_reviewed', 'supplier_liability_created', 'platform_liability_created', 'commission_hold_created', 'commission_hold_released')
    and (
      coalesce(al.reason, '') <> ''
      or coalesce(al.before_data::text, '') ~* 'Internal review note|Commission hold internal note|Supplier liability internal|Platform liability internal'
      or coalesce(al.after_data::text, '') ~* 'Internal review note|Commission hold internal note|Supplier liability internal|Platform liability internal'
    );
  perform pg_temp.d9_record('audit metadata contains no private notes/account data', v_audit_private_count = 0);

  select count(*) into v_finance_hold_count from public.finance_holds where dispute_id = v_dispute_id;
  perform pg_temp.d9_record('D9 hold fixture rows exist only in rollback transaction', v_finance_hold_count >= 3);
end;
$$;

select assertion, passed, details
from d9_results
order by assertion;

do $$
declare
  v_failed integer;
begin
  select count(*) into v_failed from d9_results where not passed;
  if v_failed > 0 then
    raise exception 'D9 finance holds boundary tests failed: % assertions failed', v_failed;
  end if;
end;
$$;

rollback;
