-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D6 admin/support investigation and non-financial resolution tests.
-- Creates fake/dev-only fixture rows inside a transaction and rolls everything
-- back. Does not create returns, refunds, finance holds, order/payment/stock/
-- reservation/delivery/commission/settlement/withdrawal mutations, evidence
-- uploads, notification outbox events, UI state, or direct browser grants.

begin;

create temp table dispute_d6_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on dispute_d6_test_results to anon, authenticated;

create temp table dispute_d6_business_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on dispute_d6_business_counts to anon, authenticated;

create or replace function pg_temp.dispute_d6_record_result(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into dispute_d6_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.dispute_d6_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.dispute_d6_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.dispute_d6_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.dispute_d6_expect_true(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  execute p_sql into v_observed;
  perform pg_temp.dispute_d6_record_result(
    p_assertion,
    coalesce(v_observed, false),
    'observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d6_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d6_expect_count(
  p_assertion text,
  p_sql text,
  p_expected bigint
)
returns void
language plpgsql
as $$
declare
  v_observed bigint;
begin
  execute p_sql into v_observed;
  perform pg_temp.dispute_d6_record_result(
    p_assertion,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d6_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d6_expect_blocked(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.dispute_d6_record_result(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.dispute_d6_record_result(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d6_capture_business_counts()
returns void
language plpgsql
as $$
begin
  insert into dispute_d6_business_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('products', (select count(*) from public.products)),
    ('product_variants', (select count(*) from public.product_variants)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('delivery_arrangements', (select count(*) from public.delivery_arrangements)),
    ('supplier_payment_reports', (select count(*) from public.supplier_payment_reports)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals)),
    ('returns', (select count(*) from public.returns)),
    ('notification_outbox', (select count(*) from public.notification_outbox)),
    ('notification_provider_events', (select count(*) from public.notification_provider_events))
  on conflict (table_name) do update set row_count = excluded.row_count;
end;
$$;

create or replace function pg_temp.dispute_d6_business_counts_unchanged()
returns boolean
language sql
as $$
  select
    (select count(*) from public.orders) = (select row_count from dispute_d6_business_counts where table_name = 'orders')
    and (select count(*) from public.order_items) = (select row_count from dispute_d6_business_counts where table_name = 'order_items')
    and (select count(*) from public.products) = (select row_count from dispute_d6_business_counts where table_name = 'products')
    and (select count(*) from public.product_variants) = (select row_count from dispute_d6_business_counts where table_name = 'product_variants')
    and (select count(*) from public.stock_reservations) = (select row_count from dispute_d6_business_counts where table_name = 'stock_reservations')
    and (select count(*) from public.delivery_arrangements) = (select row_count from dispute_d6_business_counts where table_name = 'delivery_arrangements')
    and (select count(*) from public.supplier_payment_reports) = (select row_count from dispute_d6_business_counts where table_name = 'supplier_payment_reports')
    and (select count(*) from public.settlements) = (select row_count from dispute_d6_business_counts where table_name = 'settlements')
    and (select count(*) from public.commissions) = (select row_count from dispute_d6_business_counts where table_name = 'commissions')
    and (select count(*) from public.withdrawals) = (select row_count from dispute_d6_business_counts where table_name = 'withdrawals')
    and (select count(*) from public.returns) = (select row_count from dispute_d6_business_counts where table_name = 'returns')
    and (select count(*) from public.notification_outbox) = (select row_count from dispute_d6_business_counts where table_name = 'notification_outbox')
    and (select count(*) from public.notification_provider_events) = (select row_count from dispute_d6_business_counts where table_name = 'notification_provider_events');
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_profile_id uuid := gen_random_uuid();
  v_other_customer_profile_id uuid := gen_random_uuid();
  v_supplier_a_profile_id uuid := gen_random_uuid();
  v_supplier_b_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_support_a_profile_id uuid := gen_random_uuid();
  v_support_b_profile_id uuid := gen_random_uuid();
  v_admin_profile_id uuid := gen_random_uuid();
  v_super_admin_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_inactive_admin_profile_id uuid := gen_random_uuid();
  v_suspended_admin_profile_id uuid := gen_random_uuid();
  v_plain_customer_admin_profile_id uuid := gen_random_uuid();

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

  v_multi_order_id uuid := gen_random_uuid();
  v_item_a_id uuid := gen_random_uuid();
  v_item_b_id uuid := gen_random_uuid();

  v_open_id uuid := gen_random_uuid();
  v_customer_req_id uuid := gen_random_uuid();
  v_supplier_req_id uuid := gen_random_uuid();
  v_multi_order_scope_id uuid := gen_random_uuid();
  v_status_id uuid := gen_random_uuid();
  v_return_review_id uuid := gen_random_uuid();
  v_refund_review_id uuid := gen_random_uuid();
  v_resolution_customer_id uuid := gen_random_uuid();
  v_resolution_supplier_id uuid := gen_random_uuid();
  v_resolution_partial_id uuid := gen_random_uuid();
  v_resolution_replacement_id uuid := gen_random_uuid();
  v_resolution_redelivery_id uuid := gen_random_uuid();
  v_resolution_no_action_id uuid := gen_random_uuid();
  v_resolution_rejected_id uuid := gen_random_uuid();
  v_resolution_cancelled_id uuid := gen_random_uuid();
  v_resolution_accounting_id uuid := gen_random_uuid();
  v_resolution_return_id uuid := gen_random_uuid();
  v_resolution_refund_id uuid := gen_random_uuid();
  v_closed_open_id uuid := gen_random_uuid();
  v_close_resolved_customer_id uuid := gen_random_uuid();
  v_close_resolved_supplier_id uuid := gen_random_uuid();
  v_close_partial_id uuid := gen_random_uuid();
  v_close_rejected_id uuid := gen_random_uuid();
  v_close_cancelled_id uuid := gen_random_uuid();
  v_already_closed_id uuid := gen_random_uuid();

  v_assign_first record;
  v_assign_retry record;
  v_customer_request record;
  v_supplier_request record;
  v_status_change record;
  v_resolution record;
  v_close record;
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_dispute_d6_customer_' || v_suffix, 'qa-d6-customer@example.test', 'D6 Customer', 'customer', 'active'),
    (v_other_customer_profile_id, 'dev_dispute_d6_other_customer_' || v_suffix, 'qa-d6-other-customer@example.test', 'D6 Other Customer', 'customer', 'active'),
    (v_supplier_a_profile_id, 'dev_dispute_d6_supplier_a_' || v_suffix, 'qa-d6-supplier-a@example.test', 'D6 Supplier A', 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_dispute_d6_supplier_b_' || v_suffix, 'qa-d6-supplier-b@example.test', 'D6 Supplier B', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_dispute_d6_reseller_' || v_suffix, 'qa-d6-reseller@example.test', 'D6 Reseller', 'reseller', 'active'),
    (v_support_a_profile_id, 'dev_dispute_d6_support_a_' || v_suffix, 'qa-d6-support-a@example.test', 'D6 Support A', 'customer', 'active'),
    (v_support_b_profile_id, 'dev_dispute_d6_support_b_' || v_suffix, 'qa-d6-support-b@example.test', 'D6 Support B', 'customer', 'active'),
    (v_admin_profile_id, 'dev_dispute_d6_admin_' || v_suffix, 'qa-d6-admin@example.test', 'D6 Admin', 'customer', 'active'),
    (v_super_admin_profile_id, 'dev_dispute_d6_super_admin_' || v_suffix, 'qa-d6-super-admin@example.test', 'D6 Super Admin', 'customer', 'active'),
    (v_finance_profile_id, 'dev_dispute_d6_finance_' || v_suffix, 'qa-d6-finance@example.test', 'D6 Finance', 'customer', 'active'),
    (v_inactive_admin_profile_id, 'dev_dispute_d6_inactive_admin_' || v_suffix, 'qa-d6-inactive-admin@example.test', 'D6 Inactive Admin', 'customer', 'active'),
    (v_suspended_admin_profile_id, 'dev_dispute_d6_suspended_admin_' || v_suffix, 'qa-d6-suspended-admin@example.test', 'D6 Suspended Admin', 'customer', 'suspended'),
    (v_plain_customer_admin_profile_id, 'dev_dispute_d6_plain_admin_' || v_suffix, 'qa-d6-plain-admin@example.test', 'D6 Plain Admin', 'customer', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_id, v_customer_profile_id, 'active'),
    (v_other_customer_id, v_other_customer_profile_id, 'active');

  insert into public.admin_staff(id, profile_id, admin_role, staff_status)
  values
    (gen_random_uuid(), v_support_a_profile_id, 'support_staff', 'active'),
    (gen_random_uuid(), v_support_b_profile_id, 'support_staff', 'active'),
    (gen_random_uuid(), v_admin_profile_id, 'admin', 'active'),
    (gen_random_uuid(), v_super_admin_profile_id, 'super_admin', 'active'),
    (gen_random_uuid(), v_finance_profile_id, 'finance_staff', 'active'),
    (gen_random_uuid(), v_inactive_admin_profile_id, 'support_staff', 'removed'),
    (gen_random_uuid(), v_suspended_admin_profile_id, 'support_staff', 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'D6 Supplier A', 'active', 'approved', 'D6 Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'D6 Supplier B', 'active', 'approved', 'D6 Supplier B');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
  values (v_shop_id, v_reseller_id, 'd6-dispute-shop-' || lower(left(v_suffix, 10)), 'D6 Dispute Shop', 'active');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
  values
    (v_product_a_id, v_supplier_a_id, 'QA', 'D6 Product A', 'd6-product-a-' || lower(left(v_suffix, 10)), 'Development-only D6 product A', 'active', 'approved', 100, 10, 20, v_supplier_a_profile_id),
    (v_product_b_id, v_supplier_b_id, 'QA', 'D6 Product B', 'd6-product-b-' || lower(left(v_suffix, 10)), 'Development-only D6 product B', 'active', 'approved', 110, 10, 20, v_supplier_b_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_a_id, 'D6-A-' || upper(left(v_suffix, 8)), 'Default', 10, 2, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'D6-B-' || upper(left(v_suffix, 8)), 'Default', 10, 2, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_a_id, 'active', 15, 125, 'd6-listing-a-' || lower(left(v_suffix, 10))),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_b_id, 'active', 15, 135, 'd6-listing-b-' || lower(left(v_suffix, 10)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
  values (v_multi_order_id, 'D6-MULTI-' || upper(left(v_suffix, 10)), v_customer_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 260, 260, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_a_id, v_multi_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_item_b_id, v_multi_order_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 110, 10, 15, 120, 135, 135, 110, 15);

  perform pg_temp.dispute_d6_capture_business_counts();

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, dispute_category, reason_code, description, requested_outcome, status, supplier_action_required)
  values
    (v_open_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'payment', 'customer_paid_not_reported', 'D6 open scoped issue.', 'information_only', 'open', false),
    (v_customer_req_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'delivery_delay', 'D6 customer request issue.', 'information_only', 'open', false),
    (v_supplier_req_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'delivery_not_arranged', 'D6 supplier request issue.', 'redelivery', 'open', false),
    (v_status_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'order_not_received', 'D6 status issue.', 'redelivery', 'under_review', false),
    (v_return_review_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'post_completion', 'return_requested', 'D6 return review issue.', 'return', 'return_review', true),
    (v_refund_review_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'post_completion', 'refund_requested', 'D6 refund review issue.', 'full_refund', 'refund_review', true),
    (v_resolution_customer_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'wrong_item_received', 'D6 customer favoured issue.', 'replacement', 'under_review', false),
    (v_resolution_supplier_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'damaged_item_received', 'D6 supplier favoured issue.', 'replacement', 'under_review', false),
    (v_resolution_partial_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'incomplete_order', 'D6 partial issue.', 'partial_refund', 'under_review', false),
    (v_resolution_replacement_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'post_completion', 'item_not_as_described', 'D6 replacement issue.', 'replacement', 'under_review', false),
    (v_resolution_redelivery_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'unsafe_delivery_issue', 'D6 redelivery issue.', 'redelivery', 'under_review', false),
    (v_resolution_no_action_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'payment', 'supplier_reported_customer_disagrees', 'D6 no action issue.', 'information_only', 'under_review', false),
    (v_resolution_rejected_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'payment', 'duplicate_payment_claim', 'D6 reject issue.', 'other', 'under_review', false),
    (v_resolution_cancelled_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'delivery_fee_disagreement', 'D6 cancel issue.', 'delivery_fee_refund', 'under_review', false),
    (v_resolution_accounting_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'payment', 'wrong_amount_collected', 'D6 accounting issue.', 'accounting_correction', 'under_review', false),
    (v_resolution_return_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'post_completion', 'return_requested', 'D6 return process issue.', 'other', 'under_review', false),
    (v_resolution_refund_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'post_completion', 'refund_requested', 'D6 refund review issue.', 'partial_refund', 'under_review', false),
    (v_closed_open_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'delivery', 'wrong_item_received', 'D6 close blocked open.', 'replacement', 'open', false),
    (v_close_resolved_customer_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'delivery', 'damaged_item_received', 'D6 close resolved customer.', 'replacement', 'resolved_customer', false),
    (v_close_resolved_supplier_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'delivery', 'incomplete_order', 'D6 close resolved supplier.', 'partial_refund', 'resolved_supplier', false),
    (v_close_partial_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'post_completion', 'item_not_as_described', 'D6 close partial.', 'replacement', 'partially_resolved', false),
    (v_close_rejected_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'payment', 'wrong_amount_collected', 'D6 close rejected.', 'accounting_correction', 'rejected', false),
    (v_close_cancelled_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'payment', 'unauthorised_extra_charge', 'D6 close cancelled.', 'other', 'cancelled', false),
    (v_already_closed_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'payment', 'customer_paid_not_reported', 'D6 already closed.', 'information_only', 'closed', false);

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome, status, supplier_action_required)
  values (v_multi_order_scope_id, v_multi_order_id, v_customer_profile_id, 'customer', 'order', 'delivery', 'delivery_delay', 'D6 ambiguous multi supplier order-wide issue.', 'information_only', 'open', false);

  perform pg_temp.dispute_d6_set_anon_context();
  perform pg_temp.dispute_d6_expect_blocked('anonymous blocked from assign', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-anon-assign')$sql$, v_open_id, v_support_a_profile_id));
  perform pg_temp.dispute_d6_expect_blocked('anonymous blocked from request info', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'customer', 'Please add safe details.', null, 'd6-anon-info')$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('anonymous blocked from change status', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'under_review', null, null, 'd6-anon-status')$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('anonymous blocked from resolution', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'customer_favoured', 'Safe decision recorded.', null, 'd6-anon-resolution')$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('anonymous blocked from close', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-anon-close')$sql$, v_close_rejected_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_customer_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('customer blocked from assign', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-customer-assign')$sql$, v_open_id, v_support_a_profile_id));
  perform pg_temp.dispute_d6_expect_blocked('customer blocked from request info', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'customer', 'Please add safe details.', null, 'd6-customer-info')$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('customer blocked from status', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'under_review', null, null, 'd6-customer-status')$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('customer blocked from resolution', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'customer_favoured', 'Safe decision recorded.', null, 'd6-customer-resolution')$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('customer blocked from close', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-customer-close')$sql$, v_close_rejected_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_supplier_a_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('supplier blocked from every D6 support action', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'under_review', null, null, 'd6-supplier-status')$sql$, v_open_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_reseller_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('reseller blocked from every D6 support action', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'under_review', null, null, 'd6-reseller-status')$sql$, v_open_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_finance_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('finance staff only blocked from D6 support mutation', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-finance-assign')$sql$, v_open_id, v_support_a_profile_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_inactive_admin_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('inactive admin_staff row blocked', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-inactive-assign')$sql$, v_open_id, v_support_a_profile_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_suspended_admin_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('suspended admin profile blocked', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-suspended-assign')$sql$, v_open_id, v_support_a_profile_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_plain_admin_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('profile primary role alone grants no admin authority', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-plain-assign')$sql$, v_open_id, v_support_a_profile_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);

  select dispute_id, assigned, safe_assignee_label, status, updated_at
  into v_assign_first
  from public.admin_assign_dispute(v_open_id, v_support_b_profile_id, 'd6-assign-one');

  perform pg_temp.dispute_d6_record_result('active support admin can assign dispute', v_assign_first.assigned = true and v_assign_first.status = 'open', 'assignment result observed');

  select dispute_id, assigned, safe_assignee_label, status, updated_at
  into v_assign_retry
  from public.admin_assign_dispute(v_open_id, v_support_b_profile_id, 'd6-assign-one');

  perform pg_temp.dispute_d6_record_result('assignment retry idempotent', v_assign_retry.assigned = true and v_assign_retry.status = 'open', 'assignment retry returned existing result');
  perform pg_temp.dispute_d6_expect_blocked('assignment same key different target conflicts', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, null, 'd6-assign-one')$sql$, v_open_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_count('assignment retry creates one action log', format($sql$select count(*) from public.dispute_admin_actions where dispute_id = %L::uuid and action_type = 'assign' and idempotency_key = 'd6-assign-one'$sql$, v_open_id), 1);
  perform pg_temp.dispute_d6_expect_count('assignment retry creates one audit row', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'dispute_assigned'$sql$, v_open_id), 1);

  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('assignment to customer profile fails', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-assign-customer')$sql$, v_open_id, v_customer_profile_id));
  perform pg_temp.dispute_d6_expect_blocked('assignment to finance-only profile fails', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-assign-finance')$sql$, v_open_id, v_finance_profile_id));
  perform pg_temp.dispute_d6_expect_blocked('closed case cannot be assigned', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, %L::uuid, 'd6-assign-closed')$sql$, v_already_closed_id, v_support_b_profile_id));
  perform pg_temp.dispute_d6_expect_count('unassignment succeeds through explicit RPC', format($sql$select count(*) from public.admin_assign_dispute(%L::uuid, null, 'd6-unassign-one') where assigned = false$sql$, v_open_id), 1);

  select dispute_id, message_id, internal_message_id, status, target_role, created, updated_at
  into v_customer_request
  from public.admin_request_dispute_information(v_customer_req_id, 'customer', 'Please add safe customer details.', 'Internal triage only.', 'd6-req-customer');

  perform pg_temp.dispute_d6_record_result('customer information request succeeds', v_customer_request.created = true and v_customer_request.status = 'awaiting_customer', 'customer request created');

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_true('customer request sets customer action flag', format($sql$select status = 'awaiting_customer' and customer_action_required = true and supplier_action_required = false from public.order_disputes where id = %L::uuid$sql$, v_customer_req_id));
  perform pg_temp.dispute_d6_expect_true('customer public request message is customer visible', format($sql$select visibility = 'customer_and_admin' and message_type = 'admin_request' from public.dispute_messages where id = %L::uuid$sql$, v_customer_request.message_id));
  perform pg_temp.dispute_d6_expect_true('customer request internal note is admin only', format($sql$select visibility = 'admin_only' and message_type = 'internal_admin_note' from public.dispute_messages where id = %L::uuid$sql$, v_customer_request.internal_message_id));
  perform pg_temp.dispute_d6_expect_count('customer request history created once', format($sql$select count(*) from public.dispute_status_history where dispute_id = %L::uuid and reason_code = 'admin_request'$sql$, v_customer_req_id), 1);
  perform pg_temp.dispute_d6_expect_count('customer request action logged once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'dispute_information_requested'$sql$, v_customer_req_id), 1);
  perform pg_temp.dispute_d6_expect_count('customer request status audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'dispute_status_changed'$sql$, v_customer_req_id), 1);

  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);
  select dispute_id, message_id, internal_message_id, status, target_role, created, updated_at
  into v_supplier_request
  from public.admin_request_dispute_information(v_supplier_req_id, 'supplier', 'Please add safe supplier details.', null, 'd6-req-supplier');

  perform pg_temp.dispute_d6_record_result('supplier information request succeeds', v_supplier_request.created = true and v_supplier_request.status = 'awaiting_supplier', 'supplier request created');

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_true('supplier request sets supplier action flag', format($sql$select status = 'awaiting_supplier' and supplier_action_required = true and customer_action_required = false from public.order_disputes where id = %L::uuid$sql$, v_supplier_req_id));
  perform pg_temp.dispute_d6_expect_true('supplier public request message is supplier visible', format($sql$select visibility = 'supplier_and_admin' and message_type = 'admin_request' from public.dispute_messages where id = %L::uuid$sql$, v_supplier_request.message_id));

  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('supplier information request blocked for ambiguous order-wide case', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'supplier', 'Please add safe details.', null, 'd6-req-ambiguous')$sql$, v_multi_order_scope_id));
  perform pg_temp.dispute_d6_expect_blocked('invalid target role rejected', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'reseller', 'Please add safe details.', null, 'd6-req-invalid-target')$sql$, v_supplier_req_id));
  perform pg_temp.dispute_d6_expect_blocked('empty public request rejected', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'customer', '', null, 'd6-req-empty')$sql$, v_supplier_req_id));
  perform pg_temp.dispute_d6_expect_blocked('oversized public request rejected', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'customer', repeat('x', 1201), null, 'd6-req-long')$sql$, v_supplier_req_id));
  perform pg_temp.dispute_d6_expect_blocked('oversized internal request note rejected', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'customer', 'Please add safe details.', repeat('x', 2001), 'd6-req-long-int')$sql$, v_supplier_req_id));
  perform pg_temp.dispute_d6_expect_count('request retry creates no duplicate message', format($sql$select count(*) from public.admin_request_dispute_information(%L::uuid, 'customer', 'Please add safe customer details.', 'Internal triage only.', 'd6-req-customer') where created = false$sql$, v_customer_req_id), 1);

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_count('request retry message count unchanged', format($sql$select count(*) from public.dispute_messages where dispute_id = %L::uuid and message_type = 'admin_request'$sql$, v_customer_req_id), 1);
  perform pg_temp.dispute_d6_expect_count('request retry history count unchanged', format($sql$select count(*) from public.dispute_status_history where dispute_id = %L::uuid and reason_code = 'admin_request'$sql$, v_customer_req_id), 1);

  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);
  select dispute_id, status, created, updated_at
  into v_status_change
  from public.admin_change_dispute_status(v_status_id, 'return_review', 'Safe public transition note.', 'Internal transition note.', 'd6-status-return');

  perform pg_temp.dispute_d6_record_result('valid status transition succeeds', v_status_change.created = true and v_status_change.status = 'return_review', 'status changed to return_review');

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_true('status flags derived correctly', format($sql$select status = 'return_review' and customer_action_required = false and supplier_action_required = false from public.order_disputes where id = %L::uuid$sql$, v_status_id));
  perform pg_temp.dispute_d6_expect_count('status transition history created once', format($sql$select count(*) from public.dispute_status_history where dispute_id = %L::uuid and new_status = 'return_review'$sql$, v_status_id), 1);
  perform pg_temp.dispute_d6_expect_count('status transition audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'dispute_status_changed'$sql$, v_status_id), 1);

  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('invalid transition rejected', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'open', null, null, 'd6-status-invalid')$sql$, v_status_id));
  perform pg_temp.dispute_d6_expect_blocked('arbitrary terminal status setting rejected', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'resolved_customer', null, null, 'd6-status-terminal')$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_count('status retry idempotent', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'return_review', 'Safe public transition note.', 'Internal transition note.', 'd6-status-return') where created = false$sql$, v_status_id), 1);

  perform pg_temp.dispute_d6_expect_count('customer_favoured maps to resolved_customer', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'customer_favoured', 'Safe customer decision.', null, 'd6-res-customer') where status = 'resolved_customer'$sql$, v_resolution_customer_id), 1);
  perform pg_temp.dispute_d6_expect_count('supplier_favoured maps to resolved_supplier', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'supplier_favoured', 'Safe supplier decision.', null, 'd6-res-supplier') where status = 'resolved_supplier'$sql$, v_resolution_supplier_id), 1);
  perform pg_temp.dispute_d6_expect_count('partial_resolution maps to partially_resolved', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'partial_resolution', 'Safe partial decision.', null, 'd6-res-partial') where status = 'partially_resolved'$sql$, v_resolution_partial_id), 1);
  perform pg_temp.dispute_d6_expect_count('replacement_agreed records agreement only', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'replacement_agreed', 'Replacement agreement recorded only.', null, 'd6-res-replacement') where status = 'partially_resolved'$sql$, v_resolution_replacement_id), 1);
  perform pg_temp.dispute_d6_expect_count('redelivery_agreed records agreement only', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'redelivery_agreed', 'Redelivery agreement recorded only.', null, 'd6-res-redelivery') where status = 'partially_resolved'$sql$, v_resolution_redelivery_id), 1);
  perform pg_temp.dispute_d6_expect_count('no_action maps to resolved_supplier', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'no_action', 'No action decision recorded.', null, 'd6-res-no-action') where status = 'resolved_supplier'$sql$, v_resolution_no_action_id), 1);
  perform pg_temp.dispute_d6_expect_count('case_rejected maps to rejected', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'case_rejected', 'Case rejected safely.', null, 'd6-res-rejected') where status = 'rejected'$sql$, v_resolution_rejected_id), 1);
  perform pg_temp.dispute_d6_expect_count('case_cancelled maps to cancelled', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'case_cancelled', 'Case cancelled safely.', null, 'd6-res-cancelled') where status = 'cancelled'$sql$, v_resolution_cancelled_id), 1);
  perform pg_temp.dispute_d6_expect_count('accounting_correction_required creates no finance mutation', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'accounting_correction_required', 'Future accounting review required only.', null, 'd6-res-accounting') where status = 'partially_resolved'$sql$, v_resolution_accounting_id), 1);
  perform pg_temp.dispute_d6_expect_count('return_process_required creates no return record', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'return_process_required', 'Future return workflow required only.', null, 'd6-res-return') where status = 'partially_resolved'$sql$, v_resolution_return_id), 1);
  perform pg_temp.dispute_d6_expect_count('refund_review_required creates no refund record', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'refund_review_required', 'Future refund review required only.', null, 'd6-res-refund') where status = 'partially_resolved'$sql$, v_resolution_refund_id), 1);

  select dispute_id, resolution_code, status, created, updated_at
  into v_resolution
  from public.admin_record_non_financial_resolution(v_resolution_customer_id, 'customer_favoured', 'Safe customer decision.', null, 'd6-res-customer');

  perform pg_temp.dispute_d6_record_result('resolution retry idempotent', v_resolution.created = false and v_resolution.status = 'resolved_customer', 'resolution retry returned existing result');
  perform pg_temp.dispute_d6_expect_blocked('resolution same key different payload conflicts', format($sql$select count(*) from public.admin_record_non_financial_resolution(%L::uuid, 'supplier_favoured', 'Different safe decision.', null, 'd6-res-customer')$sql$, v_resolution_customer_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_true('resolution public message persisted safely', format($sql$select public_resolution_message = 'Safe customer decision.' and internal_resolution_notes is null from public.order_disputes where id = %L::uuid$sql$, v_resolution_customer_id));
  perform pg_temp.dispute_d6_expect_count('resolution history created once', format($sql$select count(*) from public.dispute_status_history where dispute_id = %L::uuid and reason_code = 'resolution_recorded'$sql$, v_resolution_customer_id), 1);
  perform pg_temp.dispute_d6_expect_count('resolution audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'dispute_resolution_recorded'$sql$, v_resolution_customer_id), 1);

  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);
  perform pg_temp.dispute_d6_expect_blocked('close from open blocked', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-close-open')$sql$, v_closed_open_id));
  perform pg_temp.dispute_d6_expect_blocked('close from return_review blocked', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-close-return-review')$sql$, v_return_review_id));
  perform pg_temp.dispute_d6_expect_blocked('close from refund_review blocked', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-close-refund-review')$sql$, v_refund_review_id));
  perform pg_temp.dispute_d6_expect_count('close from resolved_customer succeeds', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, 'Safe closure note.', 'Internal closure note.', 'd6-close-res-customer') where status = 'closed'$sql$, v_close_resolved_customer_id), 1);
  perform pg_temp.dispute_d6_expect_count('close from resolved_supplier succeeds', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-close-res-supplier') where status = 'closed'$sql$, v_close_resolved_supplier_id), 1);
  perform pg_temp.dispute_d6_expect_count('close from partially_resolved succeeds', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-close-partial') where status = 'closed'$sql$, v_close_partial_id), 1);
  perform pg_temp.dispute_d6_expect_count('close from rejected succeeds', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-close-rejected') where status = 'closed'$sql$, v_close_rejected_id), 1);
  perform pg_temp.dispute_d6_expect_count('close from cancelled succeeds', format($sql$select count(*) from public.admin_close_dispute(%L::uuid, null, null, 'd6-close-cancelled') where status = 'closed'$sql$, v_close_cancelled_id), 1);

  select dispute_id, status, created, closed_at
  into v_close
  from public.admin_close_dispute(v_close_resolved_customer_id, 'Safe closure note.', 'Internal closure note.', 'd6-close-res-customer');

  perform pg_temp.dispute_d6_record_result('close retry idempotent', v_close.created = false and v_close.status = 'closed', 'close retry returned existing result');

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_count('close history created once', format($sql$select count(*) from public.dispute_status_history where dispute_id = %L::uuid and new_status = 'closed'$sql$, v_close_resolved_customer_id), 1);
  perform pg_temp.dispute_d6_expect_count('close audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'dispute_closed'$sql$, v_close_resolved_customer_id), 1);

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_customer_' || v_suffix);
  perform pg_temp.dispute_d6_expect_true('customer sees customer-targeted public request', format($sql$select messages::text like '%%Please add safe customer details.%%' from public.get_customer_dispute_safe(%L::uuid)$sql$, v_customer_req_id));
  perform pg_temp.dispute_d6_expect_true('customer cannot see supplier-only request', format($sql$select messages::text not like '%%Please add safe supplier details.%%' from public.get_customer_dispute_safe(%L::uuid)$sql$, v_supplier_req_id));
  perform pg_temp.dispute_d6_expect_true('customer cannot see internal notes', format($sql$select messages::text not like '%%Internal triage only.%%' from public.get_customer_dispute_safe(%L::uuid)$sql$, v_customer_req_id));
  perform pg_temp.dispute_d6_expect_true('customer sees public resolution message', format($sql$select public_resolution_message = 'Safe customer decision.' from public.get_customer_dispute_safe(%L::uuid)$sql$, v_resolution_customer_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_supplier_a_' || v_suffix);
  perform pg_temp.dispute_d6_expect_true('supplier sees supplier-targeted public request', format($sql$select messages::text like '%%Please add safe supplier details.%%' from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_supplier_req_id));
  perform pg_temp.dispute_d6_expect_true('supplier cannot see customer-only request', format($sql$select messages::text not like '%%Please add safe customer details.%%' from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_customer_req_id));
  perform pg_temp.dispute_d6_expect_true('supplier cannot see internal notes', format($sql$select messages::text not like '%%Internal triage only.%%' from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_customer_req_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_reseller_' || v_suffix);
  perform pg_temp.dispute_d6_expect_true('reseller safe read remains impact-only', format($sql$select safe_summary not like '%%Internal triage only.%%' from public.get_reseller_dispute_impact_safe(%L::uuid, 20)$sql$, v_multi_order_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_support_a_' || v_suffix);
  perform pg_temp.dispute_d6_expect_true('admin safe read shows assignment messages and history', format($sql$select assigned_admin_profile_id is null and messages::text like '%%Internal triage only.%%' and status_history::text like '%%admin_request%%' from public.get_admin_dispute_safe(%L::uuid)$sql$, v_customer_req_id));
  perform pg_temp.dispute_d6_expect_true('support admin safe read does not expose raw finance proof data', format($sql$select finance_context::text not like '%%proof%%' and finance_context::text not like '%%payout%%' from public.get_admin_dispute_safe(%L::uuid)$sql$, v_customer_req_id));

  perform pg_temp.dispute_d6_expect_blocked('direct dispute insert remains blocked', $sql$insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome, status) values (gen_random_uuid(), gen_random_uuid(), 'customer', 'order', 'delivery', 'delivery_delay', 'blocked', 'information_only', 'open')$sql$);
  perform pg_temp.dispute_d6_expect_blocked('direct dispute update remains blocked', format($sql$update public.order_disputes set status = 'closed' where id = %L::uuid$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('direct dispute delete remains blocked', format($sql$delete from public.order_disputes where id = %L::uuid$sql$, v_open_id));
  perform pg_temp.dispute_d6_expect_blocked('direct admin action table insert remains blocked', format($sql$insert into public.dispute_admin_actions(dispute_id, actor_profile_id, action_type, idempotency_key, request_fingerprint) values (%L::uuid, %L::uuid, 'assign', 'd6-direct-action', 'blocked-direct-action')$sql$, v_open_id, v_support_a_profile_id));

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_set_context('dev_dispute_d6_super_admin_' || v_suffix);
  perform pg_temp.dispute_d6_expect_count('super admin allowed through same controlled RPCs', format($sql$select count(*) from public.admin_change_dispute_status(%L::uuid, 'under_review', null, null, 'd6-super-status') where status = 'under_review'$sql$, v_return_review_id), 1);

  perform pg_temp.dispute_d6_reset_context();
  perform pg_temp.dispute_d6_expect_true('no order status changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no payment status changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no settlement changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no commission changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no wallet changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no withdrawal changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no stock changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no reservation changes', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no return rows created', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('no notification rows created', $sql$select pg_temp.dispute_d6_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d6_expect_true('D6 action table is the only new idempotency persistence', $sql$select exists (select 1 from public.dispute_admin_actions)$sql$);
end;
$$;

select assertion, passed, details
from dispute_d6_test_results
order by assertion;

do $$
declare
  v_failed bigint;
  v_total bigint;
begin
  select count(*), count(*) filter (where passed = false)
  into v_total, v_failed
  from dispute_d6_test_results;

  if v_failed > 0 then
    raise exception 'D6_ADMIN_DISPUTE_TEST_FAILURES: % of % assertions failed', v_failed, v_total;
  end if;

  raise notice 'D6 admin dispute tests passed: % assertions', v_total;
end;
$$;

rollback;
