-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Verifies Finance Visibility Phase 1 read-only RPC boundaries.
-- This script uses fake/dev-only fixture rows and rolls back all fixture data.

begin;

create temp table finance_history_test_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on finance_history_test_results to authenticated;
grant select, insert, update on finance_history_test_results to anon;

create or replace function pg_temp.finance_history_record_result(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into finance_history_test_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.finance_history_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.finance_history_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.finance_history_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.finance_history_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.finance_history_record_result(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.finance_history_record_result(p_test_name, true, sqlerrm);
end;
$$;

do $$
declare
  v_customer_profile_id uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_other_reseller_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_other_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_other_supplier_profile_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_other_supplier_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_support_profile_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_product_other_id uuid := gen_random_uuid();
  v_variant_id uuid := gen_random_uuid();
  v_variant_other_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_listing_other_id uuid := gen_random_uuid();
  v_order_locked_id uuid := gen_random_uuid();
  v_order_paid_id uuid := gen_random_uuid();
  v_order_other_id uuid := gen_random_uuid();
  v_item_locked_id uuid := gen_random_uuid();
  v_item_paid_id uuid := gen_random_uuid();
  v_item_other_id uuid := gen_random_uuid();
  v_settlement_locked_id uuid := gen_random_uuid();
  v_settlement_paid_id uuid := gen_random_uuid();
  v_settlement_other_id uuid := gen_random_uuid();
  v_withdrawal_pending_id uuid := gen_random_uuid();
  v_withdrawal_paid_id uuid := gen_random_uuid();
  v_orders_before bigint;
  v_settlements_before bigint;
  v_commissions_before bigint;
  v_withdrawals_before bigint;
  v_stock_before bigint;
  v_audit_before bigint;
  v_summary jsonb;
  v_row jsonb;
  v_count bigint;
begin
  perform pg_temp.finance_history_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_finance_customer', 'dev-finance-customer@example.invalid', 'Dev Finance Customer', 'customer', 'active'),
    (v_reseller_profile_id, 'dev_finance_reseller', 'dev-finance-reseller@example.invalid', 'Dev Finance Reseller', 'reseller', 'active'),
    (v_other_reseller_profile_id, 'dev_finance_other_reseller', 'dev-finance-other-reseller@example.invalid', 'Dev Other Reseller', 'reseller', 'active'),
    (v_supplier_profile_id, 'dev_finance_supplier', 'dev-finance-supplier@example.invalid', 'Dev Finance Supplier', 'supplier_owner', 'active'),
    (v_other_supplier_profile_id, 'dev_finance_other_supplier', 'dev-finance-other-supplier@example.invalid', 'Dev Other Supplier', 'supplier_owner', 'active'),
    (v_finance_profile_id, 'dev_finance_staff', 'dev-finance-staff@example.invalid', 'Dev Finance Staff', 'customer', 'active'),
    (v_support_profile_id, 'dev_finance_support', 'dev-finance-support@example.invalid', 'Dev Finance Support', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values
    (v_finance_profile_id, 'finance_staff', 'active'),
    (v_support_profile_id, 'support_staff', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values (v_customer_id, v_customer_profile_id, 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
  values
    (v_reseller_id, v_reseller_profile_id, 'dev_finance', 'approved', 'active', 80.00, 15.00, 30.00, 45.00),
    (v_other_reseller_id, v_other_reseller_profile_id, 'dev_finance_other', 'approved', 'active', 999.00, 999.00, 999.00, 999.00);

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
  values (v_shop_id, v_reseller_id, 'dev-finance-shop', 'Dev Finance Shop', 'active', 'public');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_id, v_supplier_profile_id, 'Dev Finance Supplier', 'active', 'approved', 'Dev Finance Supplier'),
    (v_other_supplier_id, v_other_supplier_profile_id, 'Dev Other Finance Supplier', 'active', 'approved', 'Dev Other Supplier');

  insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
  values
    (v_product_id, v_supplier_id, 'QA', 'Dev Finance Product', 'dev-finance-product', 'active', 'approved', 100, 10, 20, 'GHS'),
    (v_product_other_id, v_other_supplier_id, 'QA', 'Dev Other Finance Product', 'dev-other-finance-product', 'active', 'approved', 100, 10, 20, 'GHS');

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_id, v_product_id, 'DEV-FIN-1', 'Default', 10, 0, 0, 'active'),
    (v_variant_other_id, v_product_other_id, 'DEV-FIN-2', 'Default', 10, 0, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 15, 125, 'dev-finance-product'),
    (v_listing_other_id, v_reseller_id, v_shop_id, v_product_other_id, v_variant_other_id, 'active', 15, 125, 'dev-other-finance-product');

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_method, payment_collection_status, delivery_status, customer_confirmation_status, delivery_quote_status, subtotal_product_amount, total_payable_amount, currency_code, completed_at, payment_reported_at, delivery_address_snapshot, customer_contact_snapshot)
  values
    (v_order_locked_id, 'RSR-DEV-FIN-LOCKED', v_customer_id, v_reseller_id, v_shop_id, 'payment_reported', 'pay_on_delivery', 'supplier_reported', 'delivered', 'confirmed', 'quoted', 125, 125, 'GHS', null, now() - interval '2 days', jsonb_build_object('phone', 'private-address'), jsonb_build_object('email', 'private-customer@example.invalid')),
    (v_order_paid_id, 'RSR-DEV-FIN-PAID', v_customer_id, v_reseller_id, v_shop_id, 'completed', 'pay_on_delivery', 'settlement_verified', 'delivered', 'confirmed', 'quoted', 125, 125, 'GHS', now() - interval '1 day', now() - interval '3 days', jsonb_build_object('phone', 'private-address'), jsonb_build_object('email', 'private-customer@example.invalid')),
    (v_order_other_id, 'RSR-DEV-FIN-OTHER', v_customer_id, v_other_reseller_id, v_shop_id, 'completed', 'pay_on_delivery', 'settlement_verified', 'delivered', 'confirmed', 'quoted', 125, 125, 'GHS', now() - interval '1 day', now() - interval '3 days', '{}'::jsonb, '{}'::jsonb);

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_locked_id, v_order_locked_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_item_paid_id, v_order_paid_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 25, 15),
    (v_item_other_id, v_order_other_id, v_other_supplier_id, v_product_other_id, v_variant_other_id, v_listing_other_id, 1, 100, 10, 15, 110, 125, 125, 25, 15);

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount, due_at, verified_at, verified_by_profile_id)
  values
    (v_settlement_locked_id, v_supplier_id, v_order_locked_id, 'due', 25, 0, 25, now() + interval '1 day', null, null),
    (v_settlement_paid_id, v_supplier_id, v_order_paid_id, 'paid', 25, 25, 0, now() - interval '1 day', now() - interval '1 day', v_finance_profile_id),
    (v_settlement_other_id, v_other_supplier_id, v_order_other_id, 'paid', 25, 25, 0, now() - interval '1 day', now() - interval '1 day', v_finance_profile_id);

  insert into public.supplier_payment_reports(order_id, supplier_id, reported_by_profile_id, reported_amount, currency_code, payment_reference, reported_at)
  values
    (v_order_locked_id, v_supplier_id, v_supplier_profile_id, 125, 'GHS', 'DEV-FIN-LOCKED', now() - interval '2 days'),
    (v_order_paid_id, v_supplier_id, v_supplier_profile_id, 125, 'GHS', 'DEV-FIN-PAID', now() - interval '3 days');

  insert into public.commissions(reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount, available_at)
  values
    (v_reseller_id, v_order_locked_id, v_item_locked_id, v_settlement_locked_id, 'awaiting_supplier_settlement', 15, null),
    (v_reseller_id, v_order_paid_id, v_item_paid_id, v_settlement_paid_id, 'available', 15, now() - interval '1 day'),
    (v_other_reseller_id, v_order_other_id, v_item_other_id, v_settlement_other_id, 'available', 777, now() - interval '1 day');

  insert into public.withdrawals(id, reseller_id, requested_amount, approved_amount, withdrawal_status, provider, account_name, account_number_masked, currency_code, request_reference, requested_by_profile_id, approved_by_profile_id, paid_by_profile_id, paid_at, payout_reference)
  values
    (v_withdrawal_pending_id, v_reseller_id, 30, null, 'requested', 'mobile_money', 'Dev Finance Payout', '********0000', 'GHS', 'WD-DEV-FIN-PENDING', v_reseller_profile_id, null, null, null, null),
    (v_withdrawal_paid_id, v_reseller_id, 45, 45, 'paid', 'mobile_money', 'Dev Finance Payout', '********1111', 'GHS', 'WD-DEV-FIN-PAID', v_reseller_profile_id, v_finance_profile_id, v_finance_profile_id, now() - interval '1 day', 'DEV-PAID');

  select count(*) into v_orders_before from public.orders;
  select count(*) into v_settlements_before from public.settlements;
  select count(*) into v_commissions_before from public.commissions;
  select count(*) into v_withdrawals_before from public.withdrawals;
  select count(*) into v_stock_before from public.stock_reservations;
  select count(*) into v_audit_before from public.audit_logs;

  perform pg_temp.finance_history_set_context('dev_finance_reseller');

  select to_jsonb(x) into v_summary from public.get_reseller_finance_summary_safe(current_date - 7, current_date) x limit 1;
  perform pg_temp.finance_history_record_result('reseller reads own summary', (v_summary->>'available_balance_amount')::numeric = 80.00 and (v_summary->>'locked_commission_amount')::numeric = 15.00);

  select count(*) into v_count from public.list_reseller_earnings_history_safe(null, current_date - 7, current_date, 50, null, null);
  perform pg_temp.finance_history_record_result('reseller reads own earnings history', v_count = 2);

  select count(*) into v_count from public.list_reseller_earnings_history_safe('locked', null, null, 50, null, null);
  perform pg_temp.finance_history_record_result('reseller earnings status filter works', v_count = 1);

  select count(*) into v_count from public.list_reseller_withdrawal_history_safe(null, null, null, 50, null, null);
  perform pg_temp.finance_history_record_result('reseller reads own withdrawal history', v_count = 2);

  select count(*) into v_count from public.list_reseller_earnings_history_safe(null, null, null, 1, null, null);
  perform pg_temp.finance_history_record_result('reseller pagination limit works', v_count = 1);

  select to_jsonb(x) into v_row from public.list_reseller_earnings_history_safe(null, null, null, 1, null, null) x limit 1;
  perform pg_temp.finance_history_record_result('reseller earnings private fields absent', not (v_row ? 'supplier_private_note') and not (v_row ? 'customer_contact_snapshot') and not (v_row ? 'admin_private_note'));

  perform pg_temp.finance_history_set_context('dev_finance_supplier');
  perform pg_temp.finance_history_expect_blocked('supplier blocked from reseller summary', 'select count(*) from public.get_reseller_finance_summary_safe(null, null)');

  select to_jsonb(x) into v_summary from public.get_supplier_finance_summary_safe(current_date - 7, current_date) x limit 1;
  perform pg_temp.finance_history_record_result('supplier reads own finance summary', (v_summary->>'pending_settlement_amount')::numeric = 25.00 and (v_summary->>'verified_settlement_amount')::numeric = 25.00);

  select count(*) into v_count from public.list_supplier_settlement_history_safe(null, null, null, 50, null, null);
  perform pg_temp.finance_history_record_result('supplier reads own settlement history', v_count = 2);

  select count(*) into v_count from public.list_supplier_settlement_history_safe('verified', null, null, 50, null, null);
  perform pg_temp.finance_history_record_result('supplier settlement status filter works', v_count = 1);

  select to_jsonb(x) into v_row from public.list_supplier_settlement_history_safe(null, null, null, 1, null, null) x limit 1;
  perform pg_temp.finance_history_record_result('supplier settlement private fields absent', not (v_row ? 'supplier_private_note') and not (v_row ? 'customer_contact_snapshot') and not (v_row ? 'reseller_email_masked'));

  perform pg_temp.finance_history_set_context('dev_finance_customer');
  perform pg_temp.finance_history_expect_blocked('customer blocked from supplier summary', 'select count(*) from public.get_supplier_finance_summary_safe(null, null)');
  perform pg_temp.finance_history_expect_blocked('customer blocked from reseller earnings', 'select count(*) from public.list_reseller_earnings_history_safe(null, null, null, 50, null, null)');

  perform pg_temp.finance_history_set_context('dev_finance_staff');
  select to_jsonb(x) into v_summary from public.get_admin_finance_summary_safe(current_date - 7, current_date) x limit 1;
  perform pg_temp.finance_history_record_result('finance admin reads summary', (v_summary->>'verified_platform_revenue_amount')::numeric >= 20.00 and (v_summary->>'pending_supplier_settlement_amount')::numeric >= 25.00);
  perform pg_temp.finance_history_record_result('gross sales separate from platform revenue', (v_summary->>'gross_completed_sales_amount')::numeric > (v_summary->>'verified_platform_revenue_amount')::numeric);

  select count(*) into v_count from public.list_admin_settlement_history_safe(null, null, null, 50, null, null);
  perform pg_temp.finance_history_record_result('finance admin reads settlement history', v_count >= 3);

  select count(*) into v_count from public.list_admin_withdrawal_history_safe(null, null, null, 50, null, null);
  perform pg_temp.finance_history_record_result('finance admin reads withdrawal history', v_count >= 2);

  select to_jsonb(x) into v_row from public.list_admin_withdrawal_history_safe(null, null, null, 1, null, null) x limit 1;
  perform pg_temp.finance_history_record_result('admin withdrawal payout data masked', (v_row->>'payout_account_masked') like '%*%' and not (v_row ? 'admin_private_note'));

  perform pg_temp.finance_history_set_context('dev_finance_support');
  perform pg_temp.finance_history_expect_blocked('support admin blocked from finance summary', 'select count(*) from public.get_admin_finance_summary_safe(null, null)');

  perform pg_temp.finance_history_set_anon_context();
  perform pg_temp.finance_history_expect_blocked('anonymous blocked from reseller finance', 'select count(*) from public.get_reseller_finance_summary_safe(null, null)');
  perform pg_temp.finance_history_expect_blocked('anonymous blocked from admin finance', 'select count(*) from public.get_admin_finance_summary_safe(null, null)');

  perform pg_temp.finance_history_reset_context();

  perform pg_temp.finance_history_record_result('no order rows changed by read RPCs', (select count(*) from public.orders) = v_orders_before);
  perform pg_temp.finance_history_record_result('no settlement rows changed by read RPCs', (select count(*) from public.settlements) = v_settlements_before);
  perform pg_temp.finance_history_record_result('no commission rows changed by read RPCs', (select count(*) from public.commissions) = v_commissions_before);
  perform pg_temp.finance_history_record_result('no withdrawal rows changed by read RPCs', (select count(*) from public.withdrawals) = v_withdrawals_before);
  perform pg_temp.finance_history_record_result('no stock rows changed by read RPCs', (select count(*) from public.stock_reservations) = v_stock_before);
  perform pg_temp.finance_history_record_result('no audit rows changed by read RPCs', (select count(*) from public.audit_logs) = v_audit_before);
end;
$$;

select *
from finance_history_test_results
order by test_name;

do $$
begin
  if exists (select 1 from finance_history_test_results where not passed) then
    raise exception 'Finance history safe-read RPC boundary tests failed';
  end if;
end;
$$;

rollback;
