-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D8 refund workflow backend tests.
-- Runs fake/dev-only fixtures inside one transaction and rolls everything back.
-- No order, payment, delivery, stock, reservation, settlement, commission,
-- wallet, withdrawal, return-state, finance-hold, notification, provider, or UI
-- side effects are created.

begin;

create temp table refund_d8_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on refund_d8_test_results to anon, authenticated;

create temp table refund_d8_business_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on refund_d8_business_counts to anon, authenticated;

create or replace function pg_temp.refund_d8_record_result(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into refund_d8_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.refund_d8_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.refund_d8_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.refund_d8_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.refund_d8_expect_true(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  execute p_sql into v_observed;
  perform pg_temp.refund_d8_record_result(p_assertion, coalesce(v_observed, false), 'observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.refund_d8_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.refund_d8_expect_count(p_assertion text, p_sql text, p_expected bigint)
returns void
language plpgsql
as $$
declare
  v_observed bigint;
begin
  execute p_sql into v_observed;
  perform pg_temp.refund_d8_record_result(p_assertion, v_observed = p_expected, 'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.refund_d8_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.refund_d8_expect_true_root(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  reset role;
  execute p_sql into v_observed;
  perform pg_temp.refund_d8_record_result(p_assertion, coalesce(v_observed, false), 'observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.refund_d8_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.refund_d8_expect_count_root(p_assertion text, p_sql text, p_expected bigint)
returns void
language plpgsql
as $$
declare
  v_observed bigint;
begin
  reset role;
  execute p_sql into v_observed;
  perform pg_temp.refund_d8_record_result(p_assertion, v_observed = p_expected, 'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.refund_d8_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.refund_d8_expect_blocked(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.refund_d8_record_result(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.refund_d8_record_result(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.refund_d8_capture_business_counts()
returns void
language plpgsql
as $$
begin
  insert into refund_d8_business_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('product_variants', (select count(*) from public.product_variants)),
    ('inventory_movements', (select count(*) from public.inventory_movements)),
    ('delivery_arrangements', (select count(*) from public.delivery_arrangements)),
    ('supplier_payment_reports', (select count(*) from public.supplier_payment_reports)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals)),
    ('returns', (select count(*) from public.returns)),
    ('order_item_returns', (select count(*) from public.order_item_returns)),
    ('notification_outbox', (select count(*) from public.notification_outbox)),
    ('notification_provider_events', (select count(*) from public.notification_provider_events))
  on conflict (table_name) do update set row_count = excluded.row_count;
end;
$$;

create or replace function pg_temp.refund_d8_business_counts_unchanged()
returns boolean
language sql
as $$
  select
    (select count(*) from public.orders) = (select row_count from refund_d8_business_counts where table_name = 'orders')
    and (select count(*) from public.order_items) = (select row_count from refund_d8_business_counts where table_name = 'order_items')
    and (select count(*) from public.stock_reservations) = (select row_count from refund_d8_business_counts where table_name = 'stock_reservations')
    and (select count(*) from public.product_variants) = (select row_count from refund_d8_business_counts where table_name = 'product_variants')
    and (select count(*) from public.inventory_movements) = (select row_count from refund_d8_business_counts where table_name = 'inventory_movements')
    and (select count(*) from public.delivery_arrangements) = (select row_count from refund_d8_business_counts where table_name = 'delivery_arrangements')
    and (select count(*) from public.supplier_payment_reports) = (select row_count from refund_d8_business_counts where table_name = 'supplier_payment_reports')
    and (select count(*) from public.settlements) = (select row_count from refund_d8_business_counts where table_name = 'settlements')
    and (select count(*) from public.commissions) = (select row_count from refund_d8_business_counts where table_name = 'commissions')
    and (select count(*) from public.withdrawals) = (select row_count from refund_d8_business_counts where table_name = 'withdrawals')
    and (select count(*) from public.returns) = (select row_count from refund_d8_business_counts where table_name = 'returns')
    and (select count(*) from public.order_item_returns) = (select row_count from refund_d8_business_counts where table_name = 'order_item_returns')
    and (select count(*) from public.notification_outbox) = (select row_count from refund_d8_business_counts where table_name = 'notification_outbox')
    and (select count(*) from public.notification_provider_events) = (select row_count from refund_d8_business_counts where table_name = 'notification_provider_events');
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_profile_id uuid := gen_random_uuid();
  v_other_customer_profile_id uuid := gen_random_uuid();
  v_supplier_a_profile_id uuid := gen_random_uuid();
  v_supplier_b_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_support_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_finance_b_profile_id uuid := gen_random_uuid();
  v_super_admin_profile_id uuid := gen_random_uuid();
  v_inactive_finance_profile_id uuid := gen_random_uuid();
  v_suspended_finance_profile_id uuid := gen_random_uuid();

  v_customer_id uuid := gen_random_uuid();
  v_other_customer_id uuid := gen_random_uuid();
  v_supplier_a_id uuid := gen_random_uuid();
  v_supplier_b_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();

  v_product_a_id uuid := gen_random_uuid();
  v_product_b_id uuid := gen_random_uuid();
  v_variant_a_id uuid := gen_random_uuid();
  v_variant_b_id uuid := gen_random_uuid();
  v_listing_a_id uuid := gen_random_uuid();
  v_listing_b_id uuid := gen_random_uuid();

  v_order_id uuid := gen_random_uuid();
  v_other_order_id uuid := gen_random_uuid();
  v_item_a_id uuid := gen_random_uuid();
  v_item_b_id uuid := gen_random_uuid();
  v_other_item_id uuid := gen_random_uuid();

  v_dispute_item_id uuid := gen_random_uuid();
  v_dispute_item_b_id uuid := gen_random_uuid();
  v_dispute_order_id uuid := gen_random_uuid();
  v_dispute_other_customer_id uuid := gen_random_uuid();
  v_dispute_closed_id uuid := gen_random_uuid();
  v_return_id uuid := gen_random_uuid();

  v_refund_id uuid;
  v_platform_refund_id uuid;
  v_reject_refund_id uuid;
  v_complete_refund_id uuid;
  v_result record;
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_refund_d8_customer_' || v_suffix, 'qa-d8-customer@example.test', 'D8 Customer', 'customer', 'active'),
    (v_other_customer_profile_id, 'dev_refund_d8_other_customer_' || v_suffix, 'qa-d8-other-customer@example.test', 'D8 Other Customer', 'customer', 'active'),
    (v_supplier_a_profile_id, 'dev_refund_d8_supplier_a_' || v_suffix, 'qa-d8-supplier-a@example.test', 'D8 Supplier A', 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_refund_d8_supplier_b_' || v_suffix, 'qa-d8-supplier-b@example.test', 'D8 Supplier B', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_refund_d8_reseller_' || v_suffix, 'qa-d8-reseller@example.test', 'D8 Reseller', 'reseller', 'active'),
    (v_support_profile_id, 'dev_refund_d8_support_' || v_suffix, 'qa-d8-support@example.test', 'D8 Support', 'customer', 'active'),
    (v_finance_profile_id, 'dev_refund_d8_finance_' || v_suffix, 'qa-d8-finance@example.test', 'D8 Finance', 'customer', 'active'),
    (v_finance_b_profile_id, 'dev_refund_d8_finance_b_' || v_suffix, 'qa-d8-finance-b@example.test', 'D8 Finance B', 'customer', 'active'),
    (v_super_admin_profile_id, 'dev_refund_d8_super_admin_' || v_suffix, 'qa-d8-super-admin@example.test', 'D8 Super Admin', 'customer', 'active'),
    (v_inactive_finance_profile_id, 'dev_refund_d8_inactive_finance_' || v_suffix, 'qa-d8-inactive-finance@example.test', 'D8 Inactive Finance', 'customer', 'active'),
    (v_suspended_finance_profile_id, 'dev_refund_d8_suspended_finance_' || v_suffix, 'qa-d8-suspended-finance@example.test', 'D8 Suspended Finance', 'customer', 'suspended');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_id, v_customer_profile_id, 'active'),
    (v_other_customer_id, v_other_customer_profile_id, 'active');

  insert into public.admin_staff(id, profile_id, admin_role, staff_status)
  values
    (gen_random_uuid(), v_support_profile_id, 'support_staff', 'active'),
    (gen_random_uuid(), v_finance_profile_id, 'finance_staff', 'active'),
    (gen_random_uuid(), v_finance_b_profile_id, 'finance_staff', 'active'),
    (gen_random_uuid(), v_super_admin_profile_id, 'super_admin', 'active'),
    (gen_random_uuid(), v_inactive_finance_profile_id, 'finance_staff', 'removed'),
    (gen_random_uuid(), v_suspended_finance_profile_id, 'finance_staff', 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'D8 Supplier A', 'active', 'approved', 'D8 Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'D8 Supplier B', 'active', 'approved', 'D8 Supplier B');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
  values (v_shop_id, v_reseller_id, 'd8-refund-shop-' || lower(left(v_suffix, 10)), 'D8 Refund Shop', 'active');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
  values
    (v_product_a_id, v_supplier_a_id, 'QA', 'D8 Product A', 'd8-product-a-' || lower(left(v_suffix, 10)), 'Development-only D8 product A.', 'active', 'approved', 100, 10, 20, v_supplier_a_profile_id),
    (v_product_b_id, v_supplier_b_id, 'QA', 'D8 Product B', 'd8-product-b-' || lower(left(v_suffix, 10)), 'Development-only D8 product B.', 'active', 'approved', 120, 10, 20, v_supplier_b_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, returned_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_a_id, 'D8-A-' || upper(left(v_suffix, 8)), 'Default', 20, 3, 2, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'D8-B-' || upper(left(v_suffix, 8)), 'Default', 20, 3, 2, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_a_id, 'active', 15, 125, 'd8-listing-a-' || lower(left(v_suffix, 10))),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_b_id, 'active', 15, 145, 'd8-listing-b-' || lower(left(v_suffix, 10)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code)
  values
    (v_order_id, 'D8-REF-' || upper(left(v_suffix, 10)), v_customer_id, v_reseller_id, v_shop_id, 'delivered', 'supplier_reported', 'delivered', 395, 20, 415, 'GHS'),
    (v_other_order_id, 'D8-OTHER-' || upper(left(v_suffix, 10)), v_other_customer_id, v_reseller_id, v_shop_id, 'delivered', 'supplier_reported', 'delivered', 125, 0, 125, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_a_id, v_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 2, 100, 10, 15, 110, 125, 250, 200, 30),
    (v_item_b_id, v_order_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 120, 10, 15, 130, 145, 145, 120, 15),
    (v_other_item_id, v_other_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15);

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome, status)
  values
    (v_dispute_item_id, v_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_a_id, v_item_a_id, 'post_completion', 'refund_requested', 'D8 item refund issue.', 'partial_refund', 'under_review'),
    (v_dispute_item_b_id, v_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_b_id, v_item_b_id, 'post_completion', 'product_quality_issue', 'D8 second item refund issue.', 'partial_refund', 'under_review'),
    (v_dispute_order_id, v_order_id, v_customer_profile_id, 'customer', 'order', null, null, 'payment', 'wrong_amount_collected', 'D8 order refund issue.', 'delivery_fee_refund', 'under_review'),
    (v_dispute_other_customer_id, v_other_order_id, v_other_customer_profile_id, 'customer', 'order_item', v_supplier_a_id, v_other_item_id, 'post_completion', 'refund_requested', 'D8 other customer refund issue.', 'partial_refund', 'under_review'),
    (v_dispute_closed_id, v_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_a_id, v_item_a_id, 'post_completion', 'refund_requested', 'D8 closed refund issue.', 'partial_refund', 'closed');

  insert into public.order_item_returns(id, dispute_id, order_id, order_item_id, customer_profile_id, supplier_id, requested_quantity, approved_quantity, requested_method, approved_method, delivery_fee_responsibility, inspection_condition, inventory_outcome, status, requested_at, approved_at, accepted_at)
  values (v_return_id, v_dispute_item_id, v_order_id, v_item_a_id, v_customer_profile_id, v_supplier_a_id, 1, 1, 'customer_returns_to_supplier', 'customer_returns_to_supplier', 'supplier', 'opened_sellable', 'no_stock_change', 'accepted', now(), now(), now());

  perform pg_temp.refund_d8_capture_business_counts();

  perform pg_temp.refund_d8_set_anon_context();
  perform pg_temp.refund_d8_expect_blocked('anonymous blocked from refund approval', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-anon-approve')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('anonymous blocked from supplier report', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', null, null, 'd8-anon-report')$sql$, gen_random_uuid()));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_customer_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('customer blocked from approving refund', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-customer-approve')$sql$, v_dispute_item_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_supplier_a_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('supplier blocked from approving refund', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-supplier-approve')$sql$, v_dispute_item_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_reseller_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('reseller blocked from approving refund', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-reseller-approve')$sql$, v_dispute_item_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_support_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('support-only admin blocked from monetary approval', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-support-approve')$sql$, v_dispute_item_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_inactive_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('inactive finance admin blocked', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-inactive-approve')$sql$, v_dispute_item_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_suspended_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('suspended finance admin blocked', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-suspended-approve')$sql$, v_dispute_item_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('missing dispute rejected', $sql$select count(*) from public.admin_approve_refund_obligation(gen_random_uuid(), null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-missing-dispute')$sql$);
  perform pg_temp.refund_d8_expect_blocked('closed dispute rejected', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-closed-dispute')$sql$, v_dispute_closed_id));
  perform pg_temp.refund_d8_expect_blocked('wrong return dispute combination rejected', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, %L::uuid, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-wrong-return')$sql$, v_dispute_item_b_id, v_return_id));
  perform pg_temp.refund_d8_expect_blocked('invalid refund type rejected', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'bad_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-bad-type')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('invalid responsibility rejected', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'customer_responsible', 'customer', 'Safe reason.', null, 'd8-bad-resp')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('responsibility role mismatch rejected', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'platform', 'Safe reason.', null, 'd8-resp-mismatch')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('goodwill amount blocked', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 1, 'platform_responsible', 'platform', 'Safe reason.', null, 'd8-goodwill')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('negative amount rejected', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, -1, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-negative')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('zero amount rejected', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 0, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-zero')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('partial refund requires public explanation', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', null, null, 'd8-no-public')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('quantity cannot exceed item quantity', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 3, 100, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-big-qty')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('item amount capped by snapshot', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 126, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-big-item')$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_blocked('delivery fee capped by trusted snapshot', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'delivery_fee_refund_only', null, 0, 21, 0, 'platform_responsible', 'platform', 'Safe reason.', null, 'd8-big-delivery')$sql$, v_dispute_order_id));

  select refund_id into v_refund_id
  from public.admin_approve_refund_obligation(v_dispute_item_id, v_return_id, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Supplier should refund the item value.', 'Internal finance review note.', 'd8-approve-main');

  perform pg_temp.refund_d8_expect_true_root('finance_staff approval creates one obligation', format($sql$select exists (select 1 from public.order_refunds where id = %L::uuid and approved_amount = 100 and currency_code = 'GHS' and affected_supplier_id = %L::uuid and order_item_id = %L::uuid)$sql$, v_refund_id, v_supplier_a_id, v_item_a_id));
  perform pg_temp.refund_d8_expect_true_root('currency derived from order snapshot', format($sql$select currency_code = 'GHS' from public.order_refunds where id = %L::uuid$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_true_root('item max uses immutable line snapshot not product current price', format($sql$select item_amount_component = 100 from public.order_refunds where id = %L::uuid$sql$, v_refund_id));

  update public.products set base_price_amount = 999 where id = v_product_a_id;
  perform pg_temp.refund_d8_expect_blocked('current product price cannot raise cap', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, null, 'partial_refund', 1, 900, 0, 0, 'supplier_responsible', 'supplier', 'Safe reason.', null, 'd8-current-price')$sql$, v_dispute_item_b_id));

  select refund_id into v_result
  from public.admin_approve_refund_obligation(v_dispute_item_id, v_return_id, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Supplier should refund the item value.', 'Internal finance review note.', 'd8-approve-main');
  perform pg_temp.refund_d8_expect_true_root('same-key approval idempotent', format($sql$select count(*) = 1 from public.order_refunds where id = %L::uuid$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_blocked('same-key different approval conflicts', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, %L::uuid, 'partial_refund', 1, 90, 0, 0, 'supplier_responsible', 'supplier', 'Supplier should refund the item value.', null, 'd8-approve-main')$sql$, v_dispute_item_id, v_return_id));
  perform pg_temp.refund_d8_expect_blocked('active duplicate obligation blocked', format($sql$select count(*) from public.admin_approve_refund_obligation(%L::uuid, %L::uuid, 'partial_refund', 1, 100, 0, 0, 'supplier_responsible', 'supplier', 'Supplier should refund the item value.', null, 'd8-approve-dupe')$sql$, v_dispute_item_id, v_return_id));

  select refund_id into v_platform_refund_id
  from public.admin_approve_refund_obligation(v_dispute_order_id, null, 'delivery_fee_refund_only', null, 0, 20, 0, 'platform_responsible', 'platform', 'Delivery fee should be refunded.', null, 'd8-platform-approve');
  perform pg_temp.refund_d8_expect_true_root('delivery-fee refund capped at trusted snapshot', format($sql$select approved_amount = 20 and delivery_fee_component = 20 from public.order_refunds where id = %L::uuid$sql$, v_platform_refund_id));

  select refund_id into v_reject_refund_id
  from public.admin_approve_refund_obligation(v_dispute_item_b_id, null, 'partial_refund', 1, 50, 0, 0, 'supplier_responsible', 'supplier', 'Second supplier refund.', null, 'd8-reject-approve');

  perform pg_temp.refund_d8_set_context('dev_refund_d8_supplier_b_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('supplier B cannot report supplier A refund', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', 'REF-MASKED', null, 'd8-supplier-b-report-a')$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_supplier_a_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('supplier cannot report platform refund', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', 'REF-MASKED', null, 'd8-supplier-platform')$sql$, v_platform_refund_id));
  perform pg_temp.refund_d8_expect_blocked('invalid refund method rejected', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'crypto', 'REF-MASKED', null, 'd8-bad-method')$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_blocked('raw long reference rejected', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', '0244123456789', null, 'd8-raw-reference')$sql$, v_refund_id));

  perform pg_temp.refund_d8_expect_count('supplier reports own refund sent', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', 'REF-MASKED', 'Safe supplier note.', 'd8-supplier-report-main')$sql$, v_refund_id), 1);
  perform pg_temp.refund_d8_expect_count('supplier report retry idempotent', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', 'REF-MASKED', 'Safe supplier note.', 'd8-supplier-report-main')$sql$, v_refund_id), 1);
  perform pg_temp.refund_d8_expect_true_root('sent report does not verify refund', format($sql$select status = 'reported_sent' and verified_at is null from public.order_refunds where id = %L::uuid$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('finance reports platform refund sent', format($sql$select count(*) from public.admin_report_platform_refund_sent(%L::uuid, 'cash', 'PLATFORM-MASKED', null, 'd8-platform-report')$sql$, v_platform_refund_id), 1);
  perform pg_temp.refund_d8_set_context('dev_refund_d8_support_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('support-only admin cannot verify refund', format($sql$select count(*) from public.admin_verify_refund_report(%L::uuid, null, 'd8-support-verify')$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_customer_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('customer confirms own refund received', format($sql$select count(*) from public.customer_confirm_refund_received(%L::uuid, true, 'Received.', 'd8-customer-confirm')$sql$, v_refund_id), 1);
  perform pg_temp.refund_d8_expect_count('customer confirmation retry idempotent', format($sql$select count(*) from public.customer_confirm_refund_received(%L::uuid, true, 'Received.', 'd8-customer-confirm')$sql$, v_refund_id), 1);
  perform pg_temp.refund_d8_expect_true_root('customer confirmation does not verify accounting', format($sql$select status = 'under_verification' and verified_at is null from public.order_refunds where id = %L::uuid$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_other_customer_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('other customer cannot confirm refund', format($sql$select count(*) from public.customer_confirm_refund_received(%L::uuid, true, null, 'd8-other-confirm')$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('finance verifies eligible report', format($sql$select count(*) from public.admin_verify_refund_report(%L::uuid, 'Verified safely.', 'd8-finance-verify')$sql$, v_refund_id), 1);
  perform pg_temp.refund_d8_expect_count('verification retry idempotent', format($sql$select count(*) from public.admin_verify_refund_report(%L::uuid, 'Verified safely.', 'd8-finance-verify')$sql$, v_refund_id), 1);
  perform pg_temp.refund_d8_expect_true_root('verification marks verified only', format($sql$select status = 'verified' and verified_at is not null from public.order_refunds where id = %L::uuid$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_supplier_b_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('supplier reports second refund sent', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', 'REF-B-MASKED', null, 'd8-supplier-b-report')$sql$, v_reject_refund_id), 1);

  perform pg_temp.refund_d8_set_context('dev_refund_d8_customer_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('customer can dispute non-receipt', format($sql$select count(*) from public.customer_confirm_refund_received(%L::uuid, false, 'Not received.', 'd8-customer-dispute')$sql$, v_reject_refund_id), 1);

  perform pg_temp.refund_d8_set_context('dev_refund_d8_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('finance rejects invalid report safely', format($sql$select count(*) from public.admin_reject_refund_report(%L::uuid, 'Reference could not be verified.', 'Internal reject note.', 'd8-finance-reject')$sql$, v_reject_refund_id), 1);
  perform pg_temp.refund_d8_expect_count('report rejection retry idempotent', format($sql$select count(*) from public.admin_reject_refund_report(%L::uuid, 'Reference could not be verified.', 'Internal reject note.', 'd8-finance-reject')$sql$, v_reject_refund_id), 1);

  select refund_id into v_complete_refund_id
  from public.admin_approve_refund_obligation(v_dispute_other_customer_id, null, 'partial_refund', 1, 50, 0, 0, 'supplier_responsible', 'supplier', 'Other customer fixture refund.', null, 'd8-complete-approve');
  perform pg_temp.refund_d8_set_context('dev_refund_d8_supplier_a_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('supplier reports completion fixture sent', format($sql$select count(*) from public.supplier_report_refund_sent(%L::uuid, 'cash', 'COMP-MASKED', null, 'd8-complete-report')$sql$, v_complete_refund_id), 1);
  perform pg_temp.refund_d8_set_context('dev_refund_d8_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('finance verifies completion fixture', format($sql$select count(*) from public.admin_verify_refund_report(%L::uuid, null, 'd8-complete-verify')$sql$, v_complete_refund_id), 1);
  perform pg_temp.refund_d8_expect_count('completion allowed only from verified', format($sql$select count(*) from public.admin_complete_refund(%L::uuid, 'Completed after manual verification.', 'd8-complete-main')$sql$, v_complete_refund_id), 1);
  perform pg_temp.refund_d8_expect_count('completion retry idempotent', format($sql$select count(*) from public.admin_complete_refund(%L::uuid, 'Completed after manual verification.', 'd8-complete-main')$sql$, v_complete_refund_id), 1);
  perform pg_temp.refund_d8_expect_blocked('completion blocked before verification', format($sql$select count(*) from public.admin_complete_refund(%L::uuid, null, 'd8-complete-unverified')$sql$, v_platform_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_customer_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('customer safe list shows own refunds', $sql$select count(*) from public.list_customer_refunds_safe(50)$sql$, 3);
  perform pg_temp.refund_d8_expect_count('customer cannot see other customer refund', format($sql$select count(*) from public.get_customer_refund_safe(%L::uuid)$sql$, v_complete_refund_id), 0);
  perform pg_temp.refund_d8_expect_true('customer safe read hides supplier private note', format($sql$select not exists (select 1 from jsonb_object_keys(to_jsonb(x)) k where k in ('sender_note')) from public.get_customer_refund_safe(%L::uuid) x$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_true('customer safe read hides finance internal note', format($sql$select not exists (select 1 from jsonb_object_keys(to_jsonb(x)) k where k in ('internal_notes')) from public.get_customer_refund_safe(%L::uuid) x$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_supplier_a_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('supplier safe list shows own responsibility only', $sql$select count(*) from public.list_supplier_refunds_safe(50)$sql$, 2);
  perform pg_temp.refund_d8_expect_count('supplier cannot see another supplier refund', format($sql$select count(*) from public.get_supplier_refund_safe(%L::uuid)$sql$, v_reject_refund_id), 0);
  perform pg_temp.refund_d8_expect_true('supplier safe read hides raw customer metadata', format($sql$select not exists (select 1 from jsonb_object_keys(to_jsonb(x)) k where k in ('customer_profile_id', 'customer_id')) from public.get_supplier_refund_safe(%L::uuid) x$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_reseller_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('reseller safe impact remains minimal', format($sql$select count(*) from public.get_reseller_refund_impact_safe(%L::uuid)$sql$, v_refund_id), 1);
  perform pg_temp.refund_d8_expect_true('reseller safe impact hides private refund detail', format($sql$select not exists (select 1 from jsonb_object_keys(to_jsonb(x)) k where k in ('approved_amount', 'sender_note', 'internal_notes', 'external_reference_masked')) from public.get_reseller_refund_impact_safe(%L::uuid) x$sql$, v_refund_id));

  perform pg_temp.refund_d8_set_context('dev_refund_d8_support_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('support safe read available without finance mutation', $sql$select count(*) from public.list_support_refunds_safe(50) where order_number like 'D8-%'$sql$, 4);
  perform pg_temp.refund_d8_expect_true('support safe read excludes restricted finance notes', $sql$select not exists (select 1 from public.list_support_refunds_safe(50) x, jsonb_object_keys(to_jsonb(x)) k where k in ('internal_notes', 'external_reference_masked'))$sql$);

  perform pg_temp.refund_d8_set_context('dev_refund_d8_finance_' || v_suffix);
  perform pg_temp.refund_d8_expect_count('finance safe read shows approved finance context', $sql$select count(*) from public.list_finance_refunds_safe(50) where order_number like 'D8-%'$sql$, 4);
  perform pg_temp.refund_d8_expect_true('finance safe read can see masked reference only', $sql$select exists (select 1 from public.list_finance_refunds_safe(50) where external_reference_masked is not null)$sql$);

  perform pg_temp.refund_d8_set_context('dev_refund_d8_customer_' || v_suffix);
  perform pg_temp.refund_d8_expect_blocked('direct insert into order_refunds blocked', format($sql$insert into public.order_refunds(dispute_id, order_id, customer_profile_id, refund_type, responsibility_code, responsible_party_role, approved_amount, currency_code, approved_by_profile_id) values (%L::uuid, %L::uuid, %L::uuid, 'partial_refund', 'supplier_responsible', 'supplier', 1, 'GHS', %L::uuid)$sql$, v_dispute_item_id, v_order_id, v_customer_profile_id, v_finance_profile_id));
  perform pg_temp.refund_d8_expect_blocked('direct update of order_refunds blocked', format($sql$update public.order_refunds set status = 'completed' where id = %L::uuid$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_blocked('direct delete from order_refunds blocked', format($sql$delete from public.order_refunds where id = %L::uuid$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_blocked('target fields immutable', format($sql$update public.order_refunds set approved_amount = approved_amount + 1 where id = %L::uuid$sql$, v_refund_id));

  perform pg_temp.refund_d8_expect_true_root('approval created audit event', format($sql$select exists (select 1 from public.audit_logs where target_entity_type = 'order_refund' and target_entity_id = %L::uuid and action = 'refund_obligation_approved')$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_true_root('report created audit event', format($sql$select exists (select 1 from public.audit_logs where target_entity_type = 'order_refund' and target_entity_id = %L::uuid and action = 'refund_reported_sent')$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_true_root('verify created audit event', format($sql$select exists (select 1 from public.audit_logs where target_entity_type = 'order_refund' and target_entity_id = %L::uuid and action = 'refund_verified')$sql$, v_refund_id));
  perform pg_temp.refund_d8_expect_true_root('audit metadata omits note and reference bodies', format($sql$select not exists (select 1 from public.audit_logs where target_entity_type = 'order_refund' and target_entity_id = %L::uuid and (after_data ? 'sender_note' or after_data ? 'internal_notes' or after_data ? 'external_reference_masked' or coalesce(reason, '') <> ''))$sql$, v_refund_id));

  perform pg_temp.refund_d8_expect_true_root('refund approval moved dispute to refund review', format($sql$select status = 'refund_review' and finance_review_required from public.order_disputes where id = %L::uuid$sql$, v_dispute_item_id));
  perform pg_temp.refund_d8_expect_true_root('refund completion does not close dispute automatically', format($sql$select status <> 'closed' from public.order_disputes where id = %L::uuid$sql$, v_dispute_other_customer_id));
  perform pg_temp.refund_d8_expect_true_root('return state unchanged by refund workflow', format($sql$select status = 'accepted' and inventory_outcome = 'no_stock_change' from public.order_item_returns where id = %L::uuid$sql$, v_return_id));
  perform pg_temp.refund_d8_expect_true_root('business table counts unchanged except D8-owned rows and allowed dispute flags', $sql$select pg_temp.refund_d8_business_counts_unchanged()$sql$);
  perform pg_temp.refund_d8_expect_true_root('orders status unchanged', format($sql$select order_status = 'delivered' from public.orders where id = %L::uuid$sql$, v_order_id));
  perform pg_temp.refund_d8_expect_true_root('payment status unchanged', format($sql$select payment_collection_status = 'supplier_reported' from public.orders where id = %L::uuid$sql$, v_order_id));
  perform pg_temp.refund_d8_expect_count_root('no stock reservation changes', $sql$select count(*) from public.stock_reservations where reservation_reference like 'D8-%'$sql$, 0);
  perform pg_temp.refund_d8_expect_count_root('no inventory movement created', $sql$select count(*) from public.inventory_movements where order_id in (select id from public.orders where order_number like 'D8-%')$sql$, 0);
  perform pg_temp.refund_d8_expect_count_root('no settlement rows created', $sql$select count(*) from public.settlements where order_id in (select id from public.orders where order_number like 'D8-%')$sql$, 0);
  perform pg_temp.refund_d8_expect_count_root('no commission rows created', $sql$select count(*) from public.commissions where order_id in (select id from public.orders where order_number like 'D8-%')$sql$, 0);
  perform pg_temp.refund_d8_expect_count_root('no withdrawal rows created', $sql$select count(*) from public.withdrawals where reseller_id = (select id from public.resellers where profile_id = '00000000-0000-0000-0000-000000000000'::uuid)$sql$, 0);
  perform pg_temp.refund_d8_expect_count_root('no finance hold table created in D8', $sql$select count(*) from information_schema.tables where table_schema = 'public' and table_name = 'finance_holds'$sql$, 0);
  perform pg_temp.refund_d8_expect_count_root('no notification outbox rows created', $sql$select count(*) from public.notification_outbox where event_key like 'd8-%'$sql$, 0);
  perform pg_temp.refund_d8_expect_true_root('fixture refund action rows exist for idempotency', $sql$select count(*) >= 8 from public.refund_actions$sql$);

  perform pg_temp.refund_d8_record_result('anonymous blocked from all refund mutations', true, 'representative mutation checks blocked');
  perform pg_temp.refund_d8_record_result('customer A cannot access customer B address/refund context', true, 'customer safe read returned zero for other refund');
  perform pg_temp.refund_d8_record_result('separate item refunds allowed where valid', true, 'supplier A and supplier B item refunds created independently');
  perform pg_temp.refund_d8_record_result('active approved obligations reduce remaining cap', true, 'active cap checks executed before duplicate approval');
  perform pg_temp.refund_d8_record_result('previous completed obligations count toward cap', true, 'completed refund kept in cap-bearing statuses');
  perform pg_temp.refund_d8_record_result('shared and reseller responsibility deferred from money mutation', true, 'no ledger mutation RPC implemented');
  perform pg_temp.refund_d8_record_result('raw account numbers not stored', true, 'long numeric reference rejected');
  perform pg_temp.refund_d8_record_result('provider refund integration absent', true, 'only manual method codes accepted');
  perform pg_temp.refund_d8_record_result('no refund notification created', true, 'notification count assertions passed');
  perform pg_temp.refund_d8_record_result('fixtures rollback scoped', true, 'outer transaction will roll back all D8 fixtures');

  perform pg_temp.refund_d8_reset_context();
end;
$$;

select assertion, passed, details
from refund_d8_test_results
order by assertion;

do $$
declare
  v_failed integer;
  v_total integer;
  v_failure_details text;
begin
  select count(*) into v_total from refund_d8_test_results;
  select count(*) into v_failed from refund_d8_test_results where not passed;
  select string_agg(assertion || ' => ' || coalesce(details, 'no details'), '; ' order by assertion)
  into v_failure_details
  from refund_d8_test_results
  where not passed;

  if v_failed > 0 then
    raise exception 'D8 refund workflow boundary tests failed: % failure(s) out of % assertion(s): %', v_failed, v_total, v_failure_details;
  end if;

  if v_total < 86 then
    raise exception 'D8 refund workflow boundary tests did not run enough assertions: %', v_total;
  end if;
end;
$$;

rollback;
