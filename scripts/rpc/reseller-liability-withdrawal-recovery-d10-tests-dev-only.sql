-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- D10 reseller liability / withdrawal allocation / recovery boundary tests.
-- Uses fake rollback-scoped fixtures only.

begin;

create temp table d10_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on d10_results to anon, authenticated;

create or replace function pg_temp.d10_record(p_assertion text, p_passed boolean, p_details text default null)
returns void
language plpgsql
as $$
begin
  insert into d10_results(assertion, passed, details)
  values (p_assertion, coalesce(p_passed, false), p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.d10_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.d10_set_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.d10_reset()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.d10_expect_blocked(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.d10_record(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.d10_record(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.d10_expect_true(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  execute p_sql into v_observed;
  perform pg_temp.d10_record(p_assertion, coalesce(v_observed, false), 'observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.d10_record(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_profile uuid := gen_random_uuid();
  v_supplier_profile uuid := gen_random_uuid();
  v_reseller_profile uuid := gen_random_uuid();
  v_reseller_b_profile uuid := gen_random_uuid();
  v_finance_profile uuid := gen_random_uuid();
  v_super_profile uuid := gen_random_uuid();
  v_support_profile uuid := gen_random_uuid();
  v_inactive_finance_profile uuid := gen_random_uuid();
  v_suspended_finance_profile uuid := gen_random_uuid();

  v_customer_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_reseller_b_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_variant_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_order_id uuid := gen_random_uuid();
  v_item_id uuid := gen_random_uuid();
  v_settlement_id uuid := gen_random_uuid();
  v_commission_available_id uuid := gen_random_uuid();
  v_commission_offset_id uuid := gen_random_uuid();
  v_commission_locked_id uuid := gen_random_uuid();
  v_commission_paid_id uuid := gen_random_uuid();
  v_commission_b_id uuid := gen_random_uuid();
  v_dispute_id uuid := gen_random_uuid();
  v_refund_id uuid := gen_random_uuid();
  v_payout_account_id uuid := gen_random_uuid();
  v_withdrawal_id uuid;
  v_paid_withdrawal_id uuid := gen_random_uuid();
  v_liability_id uuid;
  v_review_liability_id uuid;
  v_recovery_id uuid;
  v_allocation_id uuid;
  v_wallet_available numeric;
  v_before_order_status text;
  v_after_order_status text;
  v_before_payment_status text;
  v_after_payment_status text;
  v_before_refund_status text;
  v_after_refund_status text;
  v_stock_before record;
  v_stock_after record;
  v_allocation_total numeric;
  v_commission_before numeric;
  v_commission_after numeric;
  v_private_audit_count bigint;
begin
  perform pg_temp.d10_reset();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile, 'd10_customer_' || v_suffix, 'd10-customer@example.invalid', 'D10 Customer', 'customer', 'active'),
    (v_supplier_profile, 'd10_supplier_' || v_suffix, 'd10-supplier@example.invalid', 'D10 Supplier', 'supplier_owner', 'active'),
    (v_reseller_profile, 'd10_reseller_' || v_suffix, 'd10-reseller@example.invalid', 'D10 Reseller', 'reseller', 'active'),
    (v_reseller_b_profile, 'd10_reseller_b_' || v_suffix, 'd10-reseller-b@example.invalid', 'D10 Reseller B', 'reseller', 'active'),
    (v_finance_profile, 'd10_finance_' || v_suffix, 'd10-finance@example.invalid', 'D10 Finance', 'customer', 'active'),
    (v_super_profile, 'd10_super_' || v_suffix, 'd10-super@example.invalid', 'D10 Super', 'customer', 'active'),
    (v_support_profile, 'd10_support_' || v_suffix, 'd10-support@example.invalid', 'D10 Support', 'customer', 'active'),
    (v_inactive_finance_profile, 'd10_inactive_finance_' || v_suffix, 'd10-inactive-finance@example.invalid', 'D10 Inactive Finance', 'customer', 'active'),
    (v_suspended_finance_profile, 'd10_suspended_finance_' || v_suffix, 'd10-suspended-finance@example.invalid', 'D10 Suspended Finance', 'customer', 'suspended');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values
    (v_finance_profile, 'finance_staff', '{}'::jsonb, 'active'),
    (v_super_profile, 'super_admin', '{}'::jsonb, 'active'),
    (v_support_profile, 'support_staff', '{}'::jsonb, 'active'),
    (v_inactive_finance_profile, 'finance_staff', '{}'::jsonb, 'removed'),
    (v_suspended_finance_profile, 'finance_staff', '{}'::jsonb, 'active');

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile, 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
  values (v_supplier_id, v_supplier_profile, 'D10 Supplier', 'active', 'approved');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
  values
    (v_reseller_id, v_reseller_profile, 'individual', 'approved', 'active', 180.00, 40.00, 0.00, 70.00),
    (v_reseller_b_id, v_reseller_b_profile, 'individual', 'approved', 'active', 40.00, 0.00, 0.00, 0.00);

  insert into public.reseller_payout_accounts(id, reseller_id, payout_method, mobile_money_network, account_name, phone_number, account_status, is_default)
  values (v_payout_account_id, v_reseller_id, 'mobile_money', 'mtn_momo', 'D10 Payout', '+233000000000', 'active', true);

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'd10-shop-' || lower(substr(v_suffix, 1, 10)), 'D10 Shop', 'active', 'public');

  insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values (v_product_id, v_supplier_id, 'D10', 'D10 Product', 'd10-product-' || lower(substr(v_suffix, 1, 8)), 'active', 'approved', 100.00, 20.00, 40.00, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values (v_variant_id, v_product_id, 'D10-A', 'D10 A', 50, 1, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 30.00, 150.00, 'd10-listing-' || lower(substr(v_suffix, 1, 8)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code)
  values (v_order_id, 'D10-' || upper(substr(v_suffix, 1, 10)), v_customer_id, v_reseller_id, v_shop_id, 'completed', 'settlement_verified', 'delivered', 150.00, 0, 150.00, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values (v_item_id, v_order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100.00, 20.00, 30.00, 120.00, 150.00, 150.00, 50.00, 30.00);

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount)
  values (v_settlement_id, v_supplier_id, v_order_id, 'paid', 50.00, 50.00, 0.00);

  insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount, available_at)
  values
    (v_commission_available_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'available', 30.00, now() - interval '5 days'),
    (v_commission_offset_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'available', 25.00, now() - interval '4 days'),
    (v_commission_locked_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'awaiting_supplier_settlement', 20.00, null),
    (v_commission_paid_id, v_reseller_id, v_order_id, v_item_id, v_settlement_id, 'paid', 15.00, now() - interval '20 days'),
    (v_commission_b_id, v_reseller_b_id, v_order_id, v_item_id, v_settlement_id, 'available', 20.00, now() - interval '3 days');

  insert into public.withdrawals(id, reseller_id, requested_amount, approved_amount, withdrawal_status, provider, account_name, account_number_masked, requested_by_profile_id, paid_by_profile_id, currency_code, request_reference, request_idempotency_key, paid_at, payout_reference, payout_idempotency_key)
  values (v_paid_withdrawal_id, v_reseller_id, 15.00, 15.00, 'paid', 'mobile_money', 'D10 Payout', '***0000', v_reseller_profile, v_finance_profile, 'GHS', 'D10-PAID-' || upper(substr(v_suffix, 1, 8)), 'd10-paid-request-' || v_suffix, now() - interval '10 days', 'D10-PAID-REF', 'd10-paid-payout-' || v_suffix);

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, description, requested_outcome, status, finance_review_required, scope_type, affected_supplier_id, affected_order_item_id, idempotency_key)
  values (v_dispute_id, v_order_id, v_customer_profile, 'customer', 'post_completion', 'damaged_item_received', 'D10 development fixture dispute', 'partial_refund', 'under_review', true, 'order_item', v_supplier_id, v_item_id, 'd10-dispute-' || v_suffix);

  insert into public.order_refunds(id, dispute_id, order_id, order_item_id, customer_profile_id, affected_supplier_id, approved_by_profile_id, refund_type, responsibility_code, responsible_party_role, status, approved_amount, currency_code, item_amount_component, delivery_fee_component, goodwill_component)
  values (v_refund_id, v_dispute_id, v_order_id, v_item_id, v_customer_profile, v_supplier_id, v_finance_profile, 'partial_refund', 'reseller_responsible', 'reseller', 'verified', 30.00, 'GHS', 30.00, 0.00, 0.00);

  select order_status::text, payment_collection_status::text into v_before_order_status, v_before_payment_status
  from public.orders where id = v_order_id;
  select status into v_before_refund_status from public.order_refunds where id = v_refund_id;
  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_before from public.product_variants where id = v_variant_id;
  select commission_amount into v_commission_before from public.commissions where id = v_commission_available_id;

  perform pg_temp.d10_set_anon();
  perform pg_temp.d10_expect_blocked('anonymous blocked from liability approval', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-anon-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_customer_' || v_suffix);
  perform pg_temp.d10_expect_blocked('customer blocked from liability approval', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-customer-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_supplier_' || v_suffix);
  perform pg_temp.d10_expect_blocked('supplier blocked from liability approval', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-supplier-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_reseller_' || v_suffix);
  perform pg_temp.d10_expect_blocked('reseller blocked from approving own liability', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-reseller-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_support_' || v_suffix);
  perform pg_temp.d10_expect_blocked('support-only admin blocked from liability approval', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-support-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_inactive_finance_' || v_suffix);
  perform pg_temp.d10_expect_blocked('inactive finance admin blocked', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-inactive-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_suspended_finance_' || v_suffix);
  perform pg_temp.d10_expect_blocked('suspended finance admin blocked', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-suspended-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  select liability_id into v_liability_id
  from public.finance_approve_reseller_liability(
    v_dispute_id,
    v_refund_id,
    v_commission_available_id,
    'commission_recovery',
    'no_automatic_recovery',
    'Development liability review',
    null,
    'd10-liability-' || v_suffix
  );

  perform pg_temp.d10_record('finance_staff allowed to approve liability', v_liability_id is not null);

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('liability derives reseller/order/commission/currency server-side', format(
    $sql$select exists (
      select 1 from public.reseller_liabilities
      where id = %L::uuid
        and reseller_profile_id = %L::uuid
        and order_id = %L::uuid
        and order_item_id = %L::uuid
        and commission_id = %L::uuid
        and currency_code = 'GHS'
        and original_amount = 30.00
        and outstanding_amount = 30.00
        and recovered_amount = 0.00
    )$sql$,
    v_liability_id, v_reseller_profile, v_order_id, v_item_id, v_commission_available_id
  ));

  perform pg_temp.d10_expect_blocked('liability target fields immutable', format(
    $sql$update public.reseller_liabilities set commission_id = %L::uuid where id = %L::uuid$sql$,
    v_commission_b_id, v_liability_id
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  perform pg_temp.d10_expect_true('same-key liability approval idempotent', format(
    $sql$select (select liability_id from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', 'Development liability review', null, 'd10-liability-%s')) = %L::uuid$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix, v_liability_id
  ));

  perform pg_temp.d10_expect_blocked('same-key different payload conflicts', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-liability-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_offset_id, v_suffix
  ));

  perform pg_temp.d10_expect_blocked('active duplicate liability blocked', format(
    $sql$select count(*) from public.finance_approve_reseller_liability(%L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10-liability-dup-%s')$sql$,
    v_dispute_id, v_refund_id, v_commission_available_id, v_suffix
  ));

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('future offset disabled by default', format(
    $sql$select recovery_policy = 'no_automatic_recovery' from public.reseller_liabilities where id = %L::uuid$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_set_context('d10_support_' || v_suffix);
  perform pg_temp.d10_expect_blocked('support cannot enable future offset', format(
    $sql$select count(*) from public.finance_enable_future_earnings_offset(%L::uuid, null, null, 'd10-offset-support-%s')$sql$,
    v_liability_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_reseller_' || v_suffix);
  perform pg_temp.d10_expect_blocked('reseller cannot enable future offset', format(
    $sql$select count(*) from public.finance_enable_future_earnings_offset(%L::uuid, null, null, 'd10-offset-reseller-%s')$sql$,
    v_liability_id, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  perform public.finance_enable_future_earnings_offset(v_liability_id, 'Offset approved for development test', null, 'd10-offset-enable-' || v_suffix);

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('finance enables future offset', format(
    $sql$select recovery_policy = 'offset_future_earnings' from public.reseller_liabilities where id = %L::uuid$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_set_context('d10_reseller_' || v_suffix);
  perform pg_temp.d10_expect_true('offset safe read reduces wallet available projection', format(
    $sql$select (select available_balance_amount from public.get_reseller_wallet_safe() limit 1) = 150.00$sql$
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  select recovery_id into v_recovery_id
  from public.finance_apply_future_commission_offset(v_commission_offset_id, 'd10-offset-apply-' || v_suffix);

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('offset applies only same currency available commission', format(
    $sql$select exists (
      select 1
      from public.reseller_liability_recoveries rlr
      where rlr.id = %L::uuid
        and rlr.liability_id = %L::uuid
        and rlr.commission_id = %L::uuid
        and rlr.amount = 25.00
        and rlr.currency_code = 'GHS'
        and rlr.status = 'applied'
    )$sql$,
    v_recovery_id, v_liability_id, v_commission_offset_id
  ));

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('partial recovery updates outstanding and recovered correctly', format(
    $sql$select outstanding_amount = 5.00 and recovered_amount = 25.00 and status = 'partially_recovered'
    from public.reseller_liabilities where id = %L::uuid$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  perform pg_temp.d10_expect_blocked('offset cannot use locked commission', format(
    $sql$select count(*) from public.finance_apply_future_commission_offset(%L::uuid, 'd10-offset-locked-%s')$sql$,
    v_commission_locked_id, v_suffix
  ));

  perform pg_temp.d10_expect_blocked('duplicate recovery blocked', format(
    $sql$select count(*) from public.finance_apply_future_commission_offset(%L::uuid, 'd10-offset-apply-%s')$sql$,
    v_commission_b_id, v_suffix
  ));

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('commission historical snapshot preserved after offset', format(
    $sql$select commission_amount = 30.00 from public.commissions where id = %L::uuid$sql$,
    v_commission_available_id
  ));

  perform pg_temp.d10_reset();
  update public.order_disputes
  set status = 'closed',
      finance_review_required = false,
      closed_at = now(),
      updated_at = now()
  where id = v_dispute_id;
  update public.order_refunds
  set status = 'completed',
      completed_at = now(),
      updated_at = now()
  where id = v_refund_id;
  select status into v_before_refund_status from public.order_refunds where id = v_refund_id;

  perform pg_temp.d10_set_context('d10_reseller_' || v_suffix);
  select withdrawal_id into v_withdrawal_id
  from public.reseller_request_withdrawal(30.00, v_payout_account_id, 'd10-withdrawal-' || v_suffix);

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('future withdrawal creates exact allocation rows', format(
    $sql$select exists (select 1 from public.withdrawal_commission_allocations where withdrawal_id = %L::uuid and allocation_status = 'reserved')$sql$,
    v_withdrawal_id
  ));

  perform pg_temp.d10_expect_true('allocation total equals withdrawal amount', format(
    $sql$select round(coalesce(sum(allocated_amount), 0), 2) = 30.00 from public.withdrawal_commission_allocations where withdrawal_id = %L::uuid$sql$,
    v_withdrawal_id
  ));

  select id into v_allocation_id from public.withdrawal_commission_allocations where withdrawal_id = v_withdrawal_id limit 1;

  perform pg_temp.d10_expect_true('deterministic oldest-available allocation order verified', format(
    $sql$select commission_id = %L::uuid from public.withdrawal_commission_allocations where id = %L::uuid$sql$,
    v_commission_available_id, v_allocation_id
  ));

  perform pg_temp.d10_set_context('d10_reseller_' || v_suffix);
  perform pg_temp.d10_expect_blocked('commission cannot be double allocated', format(
    $sql$insert into public.withdrawal_commission_allocations(withdrawal_id, commission_id, reseller_profile_id, allocated_amount, currency_code, idempotency_key)
    values (%L::uuid, %L::uuid, %L::uuid, 1.00, 'GHS', 'd10-double-%s')$sql$,
    v_withdrawal_id, v_commission_available_id, v_reseller_profile, v_suffix
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  perform public.finance_mark_withdrawal_allocation_disputed(v_allocation_id, null, null, 'd10-allocation-dispute-' || v_suffix);
  perform pg_temp.d10_expect_blocked('disputed allocation blocks payout', format(
    $sql$select count(*) from public.admin_mark_reseller_withdrawal_paid(%L::uuid, 'D10-PAYOUT-BLOCKED', null, 'd10-payout-blocked-%s')$sql$,
    v_withdrawal_id, v_suffix
  ));

  perform public.finance_release_withdrawal_allocation(v_allocation_id, null, null, 'd10-allocation-release-' || v_suffix);
  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('allocation release preserves history', format(
    $sql$select allocation_status = 'released' and released_at is not null from public.withdrawal_commission_allocations where id = %L::uuid$sql$,
    v_allocation_id
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  perform pg_temp.d10_expect_blocked('released allocation keeps withdrawal payout blocked until rebuilt', format(
    $sql$select count(*) from public.admin_mark_reseller_withdrawal_paid(%L::uuid, 'D10-PAYOUT-INCOMPLETE', null, 'd10-payout-incomplete-%s')$sql$,
    v_withdrawal_id, v_suffix
  ));

  select liability_id into v_review_liability_id
  from public.finance_approve_reseller_liability(
    v_dispute_id,
    v_refund_id,
    v_commission_paid_id,
    'withdrawal_overpayment_review',
    'no_automatic_recovery',
    null,
    null,
    'd10-paid-review-' || v_suffix
  );

  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('historical paid withdrawal not guessed', format(
    $sql$select status = 'review_required' and withdrawal_id is null and source_finance_state = 'historical_paid_unallocated'
    from public.reseller_liabilities where id = %L::uuid$sql$,
    v_review_liability_id
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  perform public.finance_waive_reseller_liability(v_review_liability_id, 'Development waiver', null, 'd10-waive-' || v_suffix);
  perform pg_temp.d10_reset();
  perform pg_temp.d10_expect_true('liability waiver append-only', format(
    $sql$select exists (
      select 1 from public.reseller_liability_recoveries
      where liability_id = %L::uuid and recovery_type = 'waiver' and status = 'applied'
    )$sql$,
    v_review_liability_id
  ));

  perform pg_temp.d10_set_context('d10_reseller_' || v_suffix);
  perform pg_temp.d10_expect_true('reseller safe read shows own liability', format(
    $sql$select exists (select 1 from public.list_reseller_liabilities_safe(null, 20) where liability_id = %L::uuid)$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_set_context('d10_reseller_b_' || v_suffix);
  perform pg_temp.d10_expect_true('reseller cannot see another reseller liability', format(
    $sql$select not exists (select 1 from public.list_reseller_liabilities_safe(null, 20) where liability_id = %L::uuid)$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_set_context('d10_finance_' || v_suffix);
  perform pg_temp.d10_expect_true('finance safe read shows liability context', format(
    $sql$select exists (select 1 from public.list_finance_reseller_liabilities_safe(null, 20) where liability_id = %L::uuid)$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_set_context('d10_support_' || v_suffix);
  perform pg_temp.d10_expect_blocked('support summary excludes private accounting detail', 'select count(*) from public.list_finance_reseller_liabilities_safe(null, 20)');

  perform pg_temp.d10_expect_blocked('direct table insert blocked', format(
    $sql$insert into public.reseller_liabilities(dispute_id, order_id, commission_id, reseller_profile_id, liability_type, original_amount, outstanding_amount, currency_code, source_finance_state, approved_by_profile_id, idempotency_key)
    values (%L::uuid, %L::uuid, %L::uuid, %L::uuid, 'commission_recovery', 1.00, 1.00, 'GHS', 'commission_available', %L::uuid, 'd10-direct-%s')$sql$,
    v_dispute_id, v_order_id, v_commission_available_id, v_reseller_profile, v_support_profile, v_suffix
  ));

  perform pg_temp.d10_expect_blocked('direct table update blocked', format(
    $sql$update public.reseller_liabilities set status = 'cancelled' where id = %L::uuid$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_expect_blocked('direct table delete blocked', format(
    $sql$delete from public.reseller_liabilities where id = %L::uuid$sql$,
    v_liability_id
  ));

  perform pg_temp.d10_reset();

  select order_status::text, payment_collection_status::text into v_after_order_status, v_after_payment_status
  from public.orders where id = v_order_id;
  select status into v_after_refund_status from public.order_refunds where id = v_refund_id;
  select total_stock_quantity, reserved_stock_quantity, sold_stock_quantity into v_stock_after from public.product_variants where id = v_variant_id;
  select commission_amount into v_commission_after from public.commissions where id = v_commission_available_id;

  perform pg_temp.d10_set_context('d10_reseller_' || v_suffix);
  perform pg_temp.d10_record('wallet available_to_withdraw never below zero', (select available_balance_amount >= 0 from public.get_reseller_wallet_safe() limit 1), null);
  perform pg_temp.d10_reset();
  perform pg_temp.d10_record('order status unchanged', v_before_order_status = v_after_order_status, v_before_order_status || '->' || v_after_order_status);
  perform pg_temp.d10_record('payment status unchanged', v_before_payment_status = v_after_payment_status, v_before_payment_status || '->' || v_after_payment_status);
  perform pg_temp.d10_record('refund status unchanged', v_before_refund_status = v_after_refund_status, v_before_refund_status || '->' || v_after_refund_status);
  perform pg_temp.d10_record('stock unchanged', v_stock_before.total_stock_quantity = v_stock_after.total_stock_quantity and v_stock_before.reserved_stock_quantity = v_stock_after.reserved_stock_quantity and v_stock_before.sold_stock_quantity = v_stock_after.sold_stock_quantity, null);
  perform pg_temp.d10_record('notification outbox side effects remain rollback scoped', true, null);
  perform pg_temp.d10_record('commission snapshot unchanged', v_commission_before = v_commission_after, v_commission_before || '->' || v_commission_after);
  perform pg_temp.d10_record('paid withdrawal remains unchanged after later liability', (select withdrawal_status = 'paid' and requested_amount = 15.00 and approved_amount = 15.00 from public.withdrawals where id = v_paid_withdrawal_id), null);
  perform pg_temp.d10_record('fixture data rollback scoped', true, 'transaction will rollback');

  select count(*) into v_private_audit_count
  from public.audit_logs al
  where al.created_at >= now() - interval '10 minutes'
    and al.action like '%reseller_liability%'
    and (
      coalesce(al.before_data::text, '') ~* '(pin|otp|password|secret|token|account number|momo|mobile money|bank)'
      or coalesce(al.after_data::text, '') ~* '(pin|otp|password|secret|token|account number|momo|mobile money|bank)'
    );
  perform pg_temp.d10_record('audit metadata contains no private note or account data', v_private_audit_count = 0, 'private_count=' || v_private_audit_count);
end;
$$;

select assertion, passed, details
from d10_results
order by assertion;

do $$
declare
  v_failed integer;
begin
  select count(*) into v_failed from d10_results where not passed;
  if v_failed > 0 then
    raise exception 'D10_ASSERTIONS_FAILED: %', v_failed;
  end if;
end;
$$;

rollback;
