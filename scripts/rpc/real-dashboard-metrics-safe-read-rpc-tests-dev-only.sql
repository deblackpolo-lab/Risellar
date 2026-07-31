-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Real Dashboard Metrics Phase 1 dashboard safe-read RPC boundary tests.
-- Uses fake/dev-only fixture rows inside a transaction and rolls everything back.

begin;

create temp table real_dashboard_metrics_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on real_dashboard_metrics_test_results to anon, authenticated;

create or replace function pg_temp.real_dashboard_metrics_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into real_dashboard_metrics_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.real_dashboard_metrics_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.real_dashboard_metrics_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.real_dashboard_metrics_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.real_dashboard_metrics_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.real_dashboard_metrics_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.real_dashboard_metrics_record_result(p_test_name, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_customer_profile_id uuid := gen_random_uuid();
  v_other_customer_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_other_reseller_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_other_supplier_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_support_profile_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_other_customer_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_other_reseller_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_other_supplier_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_other_product_id uuid := gen_random_uuid();
  v_variant_id uuid := gen_random_uuid();
  v_other_variant_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_other_listing_id uuid := gen_random_uuid();
  v_order_pending_id uuid := gen_random_uuid();
  v_order_confirmed_id uuid := gen_random_uuid();
  v_order_payment_reported_id uuid := gen_random_uuid();
  v_order_completed_id uuid := gen_random_uuid();
  v_order_rejected_id uuid := gen_random_uuid();
  v_order_other_id uuid := gen_random_uuid();
  v_item_pending_id uuid := gen_random_uuid();
  v_item_confirmed_id uuid := gen_random_uuid();
  v_item_payment_reported_id uuid := gen_random_uuid();
  v_item_completed_id uuid := gen_random_uuid();
  v_item_rejected_id uuid := gen_random_uuid();
  v_item_other_id uuid := gen_random_uuid();
  v_settlement_pending_id uuid := gen_random_uuid();
  v_settlement_paid_id uuid := gen_random_uuid();
  v_withdrawal_pending_id uuid := gen_random_uuid();
  v_withdrawal_paid_id uuid := gen_random_uuid();
  v_orders_before bigint;
  v_payment_reports_before bigint;
  v_settlements_before bigint;
  v_commissions_before bigint;
  v_withdrawals_before bigint;
  v_stock_before bigint;
  v_audit_before bigint;
  v_row jsonb;
begin
  perform pg_temp.real_dashboard_metrics_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_real_dashboard_customer', 'dev-real-dashboard-customer@example.invalid', 'Dev Real Dashboard Customer', 'customer', 'active'),
    (v_other_customer_profile_id, 'dev_real_dashboard_other_customer', 'dev-real-dashboard-other-customer@example.invalid', 'Dev Other Customer', 'customer', 'active'),
    (v_reseller_profile_id, 'dev_real_dashboard_reseller', 'dev-real-dashboard-reseller@example.invalid', 'Dev Real Dashboard Reseller', 'reseller', 'active'),
    (v_other_reseller_profile_id, 'dev_real_dashboard_other_reseller', 'dev-real-dashboard-other-reseller@example.invalid', 'Dev Other Reseller', 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_real_dashboard_supplier', 'dev-real-dashboard-supplier@example.invalid', 'Dev Real Dashboard Supplier', 'supplier_owner', 'active'),
    (v_other_supplier_profile_id, 'dev_real_dashboard_other_supplier', 'dev-real-dashboard-other-supplier@example.invalid', 'Dev Other Supplier', 'supplier_owner', 'active'),
    (v_finance_profile_id, 'dev_real_dashboard_finance', 'dev-real-dashboard-finance@example.invalid', 'Dev Finance Staff', 'customer', 'active'),
    (v_support_profile_id, 'dev_real_dashboard_support', 'dev-real-dashboard-support@example.invalid', 'Dev Support Staff', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values
    (v_finance_profile_id, 'finance_staff', 'active'),
    (v_support_profile_id, 'support_staff', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_id, v_customer_profile_id, 'active'),
    (v_other_customer_id, v_other_customer_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
  values
    (v_reseller_id, v_reseller_profile_id, 'dev_dashboard', 'approved', 'active', 80.00, 15.00, 30.00, 45.00),
    (v_other_reseller_id, v_other_reseller_profile_id, 'dev_dashboard_other', 'approved', 'active', 999.00, 999.00, 999.00, 999.00);

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-real-dashboard-shop', 'Dev Real Dashboard Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_id, v_supplier_profile_id, 'Dev Real Dashboard Supplier', 'active', 'approved', 'Dev Real Dashboard Supplier'),
    (v_other_supplier_id, v_other_supplier_profile_id, 'Dev Other Dashboard Supplier', 'active', 'approved', 'Dev Other Supplier');

  insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values
    (v_product_id, v_supplier_id, 'QA', 'Dev Dashboard Product', 'dev-dashboard-product', 'active', 'approved', 100, 10, 20, 'GHS'),
    (v_other_product_id, v_other_supplier_id, 'QA', 'Dev Other Dashboard Product', 'dev-other-dashboard-product', 'active', 'approved', 100, 10, 20, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_id, v_product_id, 'DEV-DASH-1', 'Default', 50, 0, 0, 'active'),
    (v_other_variant_id, v_other_product_id, 'DEV-DASH-2', 'Default', 50, 0, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 15, 125, 'dev-dashboard-product'),
    (v_other_listing_id, v_other_reseller_id, v_shop_id, v_other_product_id, v_other_variant_id, 'active', 15, 125, 'dev-other-dashboard-product');

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_method, payment_collection_status, delivery_status, customer_confirmation_status, delivery_quote_status, subtotal_product_amount, total_payable_amount, currency_code, completed_at, payment_reported_at)
  values
    (v_order_pending_id, 'RSR-DEV-DASH-PENDING', v_customer_id, v_reseller_id, v_shop_id, 'placed_pending_confirmation', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'pending', 'pending', 125, 125, 'GHS', null, null),
    (v_order_confirmed_id, 'RSR-DEV-DASH-CONFIRMED', v_customer_id, v_reseller_id, v_shop_id, 'supplier_confirmed', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'confirmed', 'pending', 125, 125, 'GHS', null, null),
    (v_order_payment_reported_id, 'RSR-DEV-DASH-REPORTED', v_customer_id, v_reseller_id, v_shop_id, 'payment_reported', 'pay_on_delivery', 'supplier_reported', 'delivered', 'confirmed', 'quoted', 125, 125, 'GHS', null, now() - interval '2 days'),
    (v_order_completed_id, 'RSR-DEV-DASH-COMPLETE', v_customer_id, v_reseller_id, v_shop_id, 'completed', 'pay_on_delivery', 'settlement_verified', 'delivered', 'confirmed', 'quoted', 125, 125, 'GHS', now() - interval '1 day', now() - interval '2 days'),
    (v_order_rejected_id, 'RSR-DEV-DASH-REJECTED', v_customer_id, v_reseller_id, v_shop_id, 'supplier_rejected', 'pay_on_delivery', 'not_collected', 'estimate_selected', 'confirmed', 'pending', 125, 125, 'GHS', null, null),
    (v_order_other_id, 'RSR-DEV-DASH-OTHER', v_other_customer_id, v_other_reseller_id, v_shop_id, 'completed', 'pay_on_delivery', 'settlement_verified', 'delivered', 'confirmed', 'quoted', 999, 999, 'GHS', now() - interval '1 day', now() - interval '2 days');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_pending_id, v_order_pending_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_item_confirmed_id, v_order_confirmed_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_item_payment_reported_id, v_order_payment_reported_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_item_completed_id, v_order_completed_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_item_rejected_id, v_order_rejected_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_item_other_id, v_order_other_id, v_other_supplier_id, v_other_product_id, v_other_variant_id, v_other_listing_id, 1, 100, 10, 15, 110, 125, 999, 25, 777);

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount, due_at, verified_at, verified_by_profile_id)
  values
    (v_settlement_pending_id, v_supplier_id, v_order_payment_reported_id, 'due', 25, 0, 25, now() + interval '1 day', null, null),
    (v_settlement_paid_id, v_supplier_id, v_order_completed_id, 'paid', 25, 25, 0, now() - interval '1 day', now() - interval '1 day', v_finance_profile_id);

  insert into public.supplier_payment_reports(order_id, supplier_id, reported_by_profile_id, reported_amount, currency_code, payment_reference, reported_at)
  values (v_order_payment_reported_id, v_supplier_id, v_supplier_profile_id, 125, 'GHS', 'DEV-DASH-REPORT', now() - interval '2 days');

  insert into public.commissions(reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount, available_at)
  values
    (v_reseller_id, v_order_payment_reported_id, v_item_payment_reported_id, v_settlement_pending_id, 'awaiting_supplier_settlement', 15, null),
    (v_reseller_id, v_order_completed_id, v_item_completed_id, v_settlement_paid_id, 'available', 15, now() - interval '1 day'),
    (v_other_reseller_id, v_order_other_id, v_item_other_id, null, 'available', 777, now() - interval '1 day');

  insert into public.withdrawals(id, reseller_id, requested_amount, approved_amount, withdrawal_status, provider, account_name, account_number_masked, currency_code, request_reference, requested_by_profile_id, paid_by_profile_id, paid_at)
  values
    (v_withdrawal_pending_id, v_reseller_id, 30, null, 'requested', 'mobile_money', 'Dev Dashboard Payout', '********0000', 'GHS', 'WD-DEV-DASH-PENDING', v_reseller_profile_id, null, null),
    (v_withdrawal_paid_id, v_reseller_id, 45, 45, 'paid', 'mobile_money', 'Dev Dashboard Payout', '********1111', 'GHS', 'WD-DEV-DASH-PAID', v_reseller_profile_id, v_finance_profile_id, now() - interval '1 day');

  select count(*) into v_orders_before from public.orders;
  select count(*) into v_payment_reports_before from public.supplier_payment_reports;
  select count(*) into v_settlements_before from public.settlements;
  select count(*) into v_commissions_before from public.commissions;
  select count(*) into v_withdrawals_before from public.withdrawals;
  select count(*) into v_stock_before from public.stock_reservations;
  select count(*) into v_audit_before from public.audit_logs;

  perform pg_temp.real_dashboard_metrics_set_context('dev_real_dashboard_customer');
  select to_jsonb(x) into v_row from public.get_customer_dashboard_summary_safe() x limit 1;
  perform pg_temp.real_dashboard_metrics_record_result('customer reads own dashboard counts', (v_row->>'active_orders_count')::bigint = 3 and (v_row->>'completed_orders_count')::bigint = 1 and (v_row->>'rejected_orders_count')::bigint = 1 and (v_row->>'total_orders_count')::bigint = 5);
  perform pg_temp.real_dashboard_metrics_record_result('latest active order belongs to customer', v_row->>'latest_active_order_number' in ('RSR-DEV-DASH-PENDING', 'RSR-DEV-DASH-CONFIRMED', 'RSR-DEV-DASH-REPORTED'));
  perform pg_temp.real_dashboard_metrics_record_result('customer dashboard safe fields only', not (v_row ? 'supplier_id') and not (v_row ? 'reseller_id') and not (v_row ? 'customer_contact_snapshot'));
  perform pg_temp.real_dashboard_metrics_expect_blocked('customer blocked from reseller dashboard', 'select count(*) from public.get_reseller_dashboard_summary_safe(null, null)');

  perform pg_temp.real_dashboard_metrics_set_context('dev_real_dashboard_reseller');
  select to_jsonb(x) into v_row from public.get_reseller_dashboard_summary_safe(current_date - 7, current_date) x limit 1;
  perform pg_temp.real_dashboard_metrics_record_result('reseller reads own dashboard balances', (v_row->>'available_balance_amount')::numeric = 80 and (v_row->>'locked_commission_amount')::numeric = 15 and (v_row->>'pending_withdrawal_amount')::numeric = 30 and (v_row->>'withdrawn_amount')::numeric = 45);
  perform pg_temp.real_dashboard_metrics_record_result('reseller period metrics correct', (v_row->>'attributed_orders_count')::bigint = 5 and (v_row->>'completed_sales_count')::bigint = 1 and (v_row->>'rejected_orders_count')::bigint = 1 and (v_row->>'commission_earned_amount')::numeric = 30);
  perform pg_temp.real_dashboard_metrics_record_result('locked not counted as available', (v_row->>'locked_commission_amount')::numeric <> (v_row->>'available_balance_amount')::numeric);
  perform pg_temp.real_dashboard_metrics_record_result('reseller private fields absent', not (v_row ? 'supplier_private_note') and not (v_row ? 'customer_contact_snapshot') and not (v_row ? 'payout_details_masked'));

  perform pg_temp.real_dashboard_metrics_set_context('dev_real_dashboard_supplier');
  select to_jsonb(x) into v_row from public.get_supplier_dashboard_summary_safe(current_date - 7, current_date) x limit 1;
  perform pg_temp.real_dashboard_metrics_record_result('supplier reads own order status counts', (v_row->>'placed_pending_confirmation_count')::bigint = 1 and (v_row->>'supplier_confirmed_count')::bigint = 1 and (v_row->>'payment_reported_count')::bigint = 1 and (v_row->>'completed_count')::bigint = 1 and (v_row->>'supplier_rejected_count')::bigint = 1);
  perform pg_temp.real_dashboard_metrics_record_result('supplier finance period metrics correct', (v_row->>'pending_settlement_amount')::numeric = 25 and (v_row->>'customer_payments_reported_amount')::numeric = 125 and (v_row->>'verified_settlement_amount')::numeric = 25 and (v_row->>'completed_orders_count')::bigint = 1);
  perform pg_temp.real_dashboard_metrics_record_result('supplier dashboard private fields absent', not (v_row ? 'reseller_wallet') and not (v_row ? 'customer_contact_snapshot') and not (v_row ? 'admin_notes'));
  perform pg_temp.real_dashboard_metrics_expect_blocked('supplier blocked from admin dashboard', 'select count(*) from public.get_admin_dashboard_summary_safe(null, null)');

  perform pg_temp.real_dashboard_metrics_set_context('dev_real_dashboard_finance');
  select to_jsonb(x) into v_row from public.get_admin_dashboard_summary_safe(current_date - 7, current_date) x limit 1;
  perform pg_temp.real_dashboard_metrics_record_result('finance admin reads dashboard finance metrics', (v_row->>'pending_supplier_settlement_amount')::numeric >= 25 and (v_row->>'pending_reseller_withdrawal_amount')::numeric >= 30 and (v_row->>'verified_platform_revenue_amount')::numeric >= 10 and (v_row->>'gross_completed_sales_amount')::numeric >= 125);
  perform pg_temp.real_dashboard_metrics_record_result('gross sales separate from verified platform revenue', (v_row->>'gross_completed_sales_amount')::numeric > (v_row->>'verified_platform_revenue_amount')::numeric);
  perform pg_temp.real_dashboard_metrics_record_result('admin operational counts are current state', (v_row->>'active_supplier_count')::bigint >= 1 and (v_row->>'active_reseller_count')::bigint >= 1 and (v_row->>'orders_waiting_supplier_confirmation_count')::bigint >= 1);
  perform pg_temp.real_dashboard_metrics_record_result('multi-currency grouped by currency', v_row ? 'currency_code');
  perform pg_temp.real_dashboard_metrics_record_result('admin dashboard private fields absent', not (v_row ? 'customer_contact_snapshot') and not (v_row ? 'account_number') and not (v_row ? 'supplier_private_note'));

  perform pg_temp.real_dashboard_metrics_set_context('dev_real_dashboard_support');
  perform pg_temp.real_dashboard_metrics_expect_blocked('support staff cannot read finance dashboard', 'select count(*) from public.get_admin_dashboard_summary_safe(null, null)');

  perform pg_temp.real_dashboard_metrics_set_anon_context();
  perform pg_temp.real_dashboard_metrics_expect_blocked('anonymous blocked from customer dashboard', 'select count(*) from public.get_customer_dashboard_summary_safe()');

  perform pg_temp.real_dashboard_metrics_reset_context();

  perform pg_temp.real_dashboard_metrics_record_result('no order rows changed by dashboard reads', (select count(*) from public.orders) = v_orders_before);
  perform pg_temp.real_dashboard_metrics_record_result('no payment rows changed by dashboard reads', (select count(*) from public.supplier_payment_reports) = v_payment_reports_before);
  perform pg_temp.real_dashboard_metrics_record_result('no settlement rows changed by dashboard reads', (select count(*) from public.settlements) = v_settlements_before);
  perform pg_temp.real_dashboard_metrics_record_result('no commission rows changed by dashboard reads', (select count(*) from public.commissions) = v_commissions_before);
  perform pg_temp.real_dashboard_metrics_record_result('no withdrawal rows changed by dashboard reads', (select count(*) from public.withdrawals) = v_withdrawals_before);
  perform pg_temp.real_dashboard_metrics_record_result('no stock rows changed by dashboard reads', (select count(*) from public.stock_reservations) = v_stock_before);
  perform pg_temp.real_dashboard_metrics_record_result('no audit rows changed by dashboard reads', (select count(*) from public.audit_logs) = v_audit_before);
end;
$$;

select *
from real_dashboard_metrics_test_results
order by test_name;

do $$
declare
  v_failed_tests text;
begin
  if exists (select 1 from real_dashboard_metrics_test_results where not passed) then
    select string_agg(test_name, ', ' order by test_name)
    into v_failed_tests
    from real_dashboard_metrics_test_results
    where not passed;

    raise exception 'Real dashboard metrics safe-read RPC boundary tests failed: %', v_failed_tests;
  end if;
end;
$$;

rollback;
