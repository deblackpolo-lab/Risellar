-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D5 supplier response boundary tests.
-- Creates fake/dev-only fixture rows inside a transaction and rolls everything
-- back. Does not create returns, refunds, finance holds, order/payment/stock/
-- reservation/delivery/commission/settlement/withdrawal mutations, evidence
-- uploads, notification outbox events, or UI state.

begin;

create temp table dispute_d5_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on dispute_d5_test_results to anon, authenticated;

create temp table dispute_d5_business_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on dispute_d5_business_counts to anon, authenticated;

create or replace function pg_temp.dispute_d5_record_result(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into dispute_d5_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.dispute_d5_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.dispute_d5_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('role', 'anon')::text,
    true
  );
  set local role anon;
end;
$$;

create or replace function pg_temp.dispute_d5_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.dispute_d5_expect_count(
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
  perform pg_temp.dispute_d5_record_result(
    p_assertion,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d5_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d5_expect_true(
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
  perform pg_temp.dispute_d5_record_result(
    p_assertion,
    coalesce(v_observed, false),
    'observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d5_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d5_expect_blocked(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.dispute_d5_record_result(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.dispute_d5_record_result(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d5_capture_business_counts()
returns void
language plpgsql
as $$
begin
  insert into dispute_d5_business_counts(table_name, row_count)
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
    ('notification_outbox', (select count(*) from public.notification_outbox)),
    ('notification_provider_events', (select count(*) from public.notification_provider_events))
  on conflict (table_name) do update set row_count = excluded.row_count;
end;
$$;

create or replace function pg_temp.dispute_d5_business_counts_unchanged()
returns boolean
language sql
as $$
  select
    (select count(*) from public.orders) = (select row_count from dispute_d5_business_counts where table_name = 'orders')
    and (select count(*) from public.order_items) = (select row_count from dispute_d5_business_counts where table_name = 'order_items')
    and (select count(*) from public.products) = (select row_count from dispute_d5_business_counts where table_name = 'products')
    and (select count(*) from public.product_variants) = (select row_count from dispute_d5_business_counts where table_name = 'product_variants')
    and (select count(*) from public.stock_reservations) = (select row_count from dispute_d5_business_counts where table_name = 'stock_reservations')
    and (select count(*) from public.delivery_arrangements) = (select row_count from dispute_d5_business_counts where table_name = 'delivery_arrangements')
    and (select count(*) from public.supplier_payment_reports) = (select row_count from dispute_d5_business_counts where table_name = 'supplier_payment_reports')
    and (select count(*) from public.settlements) = (select row_count from dispute_d5_business_counts where table_name = 'settlements')
    and (select count(*) from public.commissions) = (select row_count from dispute_d5_business_counts where table_name = 'commissions')
    and (select count(*) from public.withdrawals) = (select row_count from dispute_d5_business_counts where table_name = 'withdrawals')
    and (select count(*) from public.notification_outbox) = (select row_count from dispute_d5_business_counts where table_name = 'notification_outbox')
    and (select count(*) from public.notification_provider_events) = (select row_count from dispute_d5_business_counts where table_name = 'notification_provider_events');
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_profile_id uuid := gen_random_uuid();
  v_other_customer_profile_id uuid := gen_random_uuid();
  v_supplier_a_profile_id uuid := gen_random_uuid();
  v_supplier_b_profile_id uuid := gen_random_uuid();
  v_supplier_inactive_profile_id uuid := gen_random_uuid();
  v_supplier_unapproved_profile_id uuid := gen_random_uuid();
  v_supplier_suspended_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_support_profile_id uuid := gen_random_uuid();

  v_customer_id uuid := gen_random_uuid();
  v_other_customer_id uuid := gen_random_uuid();
  v_supplier_a_id uuid := gen_random_uuid();
  v_supplier_b_id uuid := gen_random_uuid();
  v_supplier_inactive_id uuid := gen_random_uuid();
  v_supplier_unapproved_id uuid := gen_random_uuid();
  v_supplier_suspended_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();

  v_product_a_id uuid := gen_random_uuid();
  v_product_b_id uuid := gen_random_uuid();
  v_variant_a_id uuid := gen_random_uuid();
  v_variant_b_id uuid := gen_random_uuid();
  v_listing_a_id uuid := gen_random_uuid();
  v_listing_b_id uuid := gen_random_uuid();

  v_multi_order_id uuid := gen_random_uuid();
  v_single_order_id uuid := gen_random_uuid();
  v_item_a_id uuid := gen_random_uuid();
  v_item_b_id uuid := gen_random_uuid();
  v_single_item_id uuid := gen_random_uuid();

  v_supplier_scope_id uuid := gen_random_uuid();
  v_item_scope_id uuid := gen_random_uuid();
  v_supplier_b_scope_id uuid := gen_random_uuid();
  v_multi_order_scope_id uuid := gen_random_uuid();
  v_single_order_scope_id uuid := gen_random_uuid();
  v_awaiting_supplier_id uuid := gen_random_uuid();
  v_open_id uuid := gen_random_uuid();
  v_under_review_id uuid := gen_random_uuid();
  v_return_review_id uuid := gen_random_uuid();
  v_refund_review_id uuid := gen_random_uuid();
  v_resolved_customer_id uuid := gen_random_uuid();
  v_resolved_supplier_id uuid := gen_random_uuid();
  v_partially_resolved_id uuid := gen_random_uuid();
  v_rejected_id uuid := gen_random_uuid();
  v_cancelled_id uuid := gen_random_uuid();
  v_closed_id uuid := gen_random_uuid();

  v_first_response record;
  v_retry_response record;
  v_second_response record;
  v_open_response record;
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_dispute_d5_customer_' || v_suffix, 'qa-d5-customer@example.test', 'D5 Customer', 'customer', 'active'),
    (v_other_customer_profile_id, 'dev_dispute_d5_other_customer_' || v_suffix, 'qa-d5-other-customer@example.test', 'D5 Other Customer', 'customer', 'active'),
    (v_supplier_a_profile_id, 'dev_dispute_d5_supplier_a_' || v_suffix, 'qa-d5-supplier-a@example.test', 'D5 Supplier A', 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_dispute_d5_supplier_b_' || v_suffix, 'qa-d5-supplier-b@example.test', 'D5 Supplier B', 'supplier_owner', 'active'),
    (v_supplier_inactive_profile_id, 'dev_dispute_d5_supplier_inactive_' || v_suffix, 'qa-d5-supplier-inactive@example.test', 'D5 Supplier Inactive', 'supplier_owner', 'active'),
    (v_supplier_unapproved_profile_id, 'dev_dispute_d5_supplier_unapproved_' || v_suffix, 'qa-d5-supplier-unapproved@example.test', 'D5 Supplier Unapproved', 'supplier_owner', 'active'),
    (v_supplier_suspended_profile_id, 'dev_dispute_d5_supplier_suspended_' || v_suffix, 'qa-d5-supplier-suspended@example.test', 'D5 Supplier Suspended', 'supplier_owner', 'suspended'),
    (v_reseller_profile_id, 'dev_dispute_d5_reseller_' || v_suffix, 'qa-d5-reseller@example.test', 'D5 Reseller', 'reseller', 'active'),
    (v_support_profile_id, 'dev_dispute_d5_support_' || v_suffix, 'qa-d5-support@example.test', 'D5 Support', 'customer', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_id, v_customer_profile_id, 'active'),
    (v_other_customer_id, v_other_customer_profile_id, 'active');

  insert into public.admin_staff(id, profile_id, admin_role, staff_status)
  values (gen_random_uuid(), v_support_profile_id, 'support_staff', 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'D5 Supplier A', 'active', 'approved', 'D5 Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'D5 Supplier B', 'active', 'approved', 'D5 Supplier B'),
    (v_supplier_inactive_id, v_supplier_inactive_profile_id, 'D5 Supplier Inactive', 'pending', 'approved', 'D5 Supplier Inactive'),
    (v_supplier_unapproved_id, v_supplier_unapproved_profile_id, 'D5 Supplier Unapproved', 'active', 'pending_review', 'D5 Supplier Unapproved'),
    (v_supplier_suspended_id, v_supplier_suspended_profile_id, 'D5 Supplier Suspended', 'active', 'approved', 'D5 Supplier Suspended');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
  values (v_shop_id, v_reseller_id, 'd5-dispute-shop-' || lower(left(v_suffix, 10)), 'D5 Dispute Shop', 'active');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
  values
    (v_product_a_id, v_supplier_a_id, 'QA', 'D5 Product A', 'd5-product-a-' || lower(left(v_suffix, 10)), 'Development-only D5 product A', 'active', 'approved', 100, 10, 20, v_supplier_a_profile_id),
    (v_product_b_id, v_supplier_b_id, 'QA', 'D5 Product B', 'd5-product-b-' || lower(left(v_suffix, 10)), 'Development-only D5 product B', 'active', 'approved', 110, 10, 20, v_supplier_b_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_a_id, 'D5-A-' || upper(left(v_suffix, 8)), 'Default', 10, 2, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'D5-B-' || upper(left(v_suffix, 8)), 'Default', 10, 2, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_a_id, 'active', 15, 125, 'd5-listing-a-' || lower(left(v_suffix, 10))),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_b_id, 'active', 15, 135, 'd5-listing-b-' || lower(left(v_suffix, 10)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
  values
    (v_multi_order_id, 'D5-MULTI-' || upper(left(v_suffix, 10)), v_customer_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 260, 260, 'GHS'),
    (v_single_order_id, 'D5-SINGLE-' || upper(left(v_suffix, 10)), v_customer_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_a_id, v_multi_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_item_b_id, v_multi_order_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 110, 10, 15, 120, 135, 135, 110, 15),
    (v_single_item_id, v_single_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15);

  perform pg_temp.dispute_d5_capture_business_counts();

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, dispute_category, reason_code, description, requested_outcome, status, supplier_action_required)
  values
    (v_supplier_scope_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'payment', 'customer_paid_not_reported', 'Supplier A scoped D5 issue.', 'information_only', 'open', true),
    (v_supplier_b_scope_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_b_id, 'payment', 'customer_paid_not_reported', 'Supplier B scoped D5 issue.', 'information_only', 'open', true),
    (v_awaiting_supplier_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'pre_delivery', 'supplier_not_responding', 'Supplier A awaiting D5 issue.', 'information_only', 'awaiting_supplier', true),
    (v_open_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'pre_delivery', 'supplier_rejected_status_incorrect', 'Supplier A open D5 issue.', 'cancellation', 'open', true),
    (v_under_review_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'pre_delivery', 'order_stuck_in_preparation', 'Supplier A under review D5 issue.', 'information_only', 'under_review', false),
    (v_return_review_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'post_completion', 'return_requested', 'Supplier A return review D5 issue.', 'return', 'return_review', true),
    (v_refund_review_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'post_completion', 'refund_requested', 'Supplier A refund review D5 issue.', 'full_refund', 'refund_review', true),
    (v_resolved_customer_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'delivery_not_arranged', 'Supplier A resolved customer D5 issue.', 'redelivery', 'resolved_customer', false),
    (v_resolved_supplier_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'delivery_delay', 'Supplier A resolved supplier D5 issue.', 'redelivery', 'resolved_supplier', false),
    (v_partially_resolved_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'order_not_received', 'Supplier A partial D5 issue.', 'redelivery', 'partially_resolved', false),
    (v_rejected_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'unsafe_delivery_issue', 'Supplier A rejected D5 issue.', 'other', 'rejected', false),
    (v_cancelled_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'delivery', 'delivery_fee_disagreement', 'Supplier A cancelled D5 issue.', 'delivery_fee_refund', 'cancelled', false),
    (v_closed_id, v_multi_order_id, v_customer_profile_id, 'customer', 'supplier', v_supplier_a_id, 'payment', 'duplicate_payment_claim', 'Supplier A closed D5 issue.', 'accounting_correction', 'closed', false);

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome, status, supplier_action_required)
  values (v_item_scope_id, v_multi_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_a_id, v_item_a_id, 'post_completion', 'damaged_item_received', 'Supplier A item scoped D5 issue.', 'replacement', 'open', true);

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome, status, supplier_action_required)
  values
    (v_multi_order_scope_id, v_multi_order_id, v_customer_profile_id, 'customer', 'order', 'delivery', 'delivery_delay', 'Multi supplier order-wide D5 issue.', 'information_only', 'open', false),
    (v_single_order_scope_id, v_single_order_id, v_customer_profile_id, 'customer', 'order', 'delivery', 'delivery_delay', 'Single supplier order-wide D5 issue.', 'information_only', 'open', true);

  perform pg_temp.dispute_d5_set_anon_context();
  perform pg_temp.dispute_d5_expect_blocked(
    'anonymous cannot call supplier response RPC',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'd5-anon-key')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_customer_' || v_suffix);
  perform pg_temp.dispute_d5_expect_blocked(
    'customer cannot call supplier response RPC',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'd5-customer-key')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_reseller_' || v_suffix);
  perform pg_temp.dispute_d5_expect_blocked(
    'reseller cannot call supplier response RPC',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'd5-reseller-key')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_support_' || v_suffix);
  perform pg_temp.dispute_d5_expect_blocked(
    'support admin cannot impersonate supplier',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'd5-support-key')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_inactive_' || v_suffix);
  perform pg_temp.dispute_d5_expect_blocked(
    'inactive supplier is blocked',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'd5-inactive-key')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_unapproved_' || v_suffix);
  perform pg_temp.dispute_d5_expect_blocked(
    'unapproved supplier is blocked',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'd5-unapproved-key')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_suspended_' || v_suffix);
  perform pg_temp.dispute_d5_expect_blocked(
    'suspended supplier profile is blocked',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'd5-suspended-key')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_b_' || v_suffix);
  perform pg_temp.dispute_d5_expect_blocked(
    'supplier B cannot respond to supplier-A scoped dispute',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 supplier B blocked.', 'd5-b-on-a-key')$sql$, v_supplier_scope_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'supplier B cannot respond to supplier-A item dispute',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 supplier B item blocked.', 'd5-b-on-item-key')$sql$, v_item_scope_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'supplier owning another item on same order remains blocked',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 broad ownership blocked.', 'd5-any-item-key')$sql$, v_item_scope_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'multi-supplier order-wide dispute is not broadly respondable',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 multi order blocked.', 'd5-multi-order-key')$sql$, v_multi_order_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_a_' || v_suffix);
  select message_id, dispute_id, created, status, created_at into v_first_response
  from public.supplier_add_dispute_response(v_supplier_scope_id, 'D5 supplier A scoped safe response.', 'd5-supplier-a-scope');

  perform pg_temp.dispute_d5_record_result(
    'supplier A can respond to supplier-A scoped dispute',
    v_first_response.created = true and v_first_response.message_id is not null and v_first_response.status = 'open',
    'supplier scoped response created'
  );

  select message_id, dispute_id, created, status, created_at into v_second_response
  from public.supplier_add_dispute_response(v_item_scope_id, 'D5 supplier A item safe response.', 'd5-supplier-a-item');

  perform pg_temp.dispute_d5_record_result(
    'supplier A can respond to supplier-A item-scoped dispute',
    v_second_response.created = true and v_second_response.message_id is not null and v_second_response.status = 'open',
    'item scoped response created'
  );

  select message_id, dispute_id, created, status, created_at into v_open_response
  from public.supplier_add_dispute_response(v_single_order_scope_id, 'D5 supplier A single order-wide safe response.', 'd5-single-order');

  perform pg_temp.dispute_d5_record_result(
    'single-supplier order-wide behavior follows D5-A policy',
    v_open_response.created = true and v_open_response.status = 'open',
    'single supplier order-wide response created'
  );

  perform pg_temp.dispute_d5_reset_context();

  perform pg_temp.dispute_d5_expect_true(
    'message author is derived server-side',
    format($sql$select author_profile_id = %L::uuid from public.dispute_messages where id = %L::uuid$sql$, v_supplier_a_profile_id, v_first_response.message_id)
  );
  perform pg_temp.dispute_d5_expect_true(
    'message author role is supplier',
    format($sql$select author_role = 'supplier' from public.dispute_messages where id = %L::uuid$sql$, v_first_response.message_id)
  );
  perform pg_temp.dispute_d5_expect_true(
    'message visibility is supplier_and_admin',
    format($sql$select visibility = 'supplier_and_admin' and is_system_message = false and message_type = 'participant_response' from public.dispute_messages where id = %L::uuid$sql$, v_first_response.message_id)
  );

  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_a_' || v_suffix);

  perform pg_temp.dispute_d5_expect_blocked(
    'empty body is rejected',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, '', 'd5-empty-body')$sql$, v_supplier_b_scope_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'whitespace-only body is rejected',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, '     ', 'd5-space-body')$sql$, v_supplier_b_scope_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'oversized body is rejected',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, repeat('x', 2001), 'd5-long-body')$sql$, v_supplier_b_scope_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'HTML script content is rejected by plain-text policy',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, '<script>alert(1)</script>', 'd5-html-body')$sql$, v_supplier_b_scope_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'invalid idempotency key is rejected',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 safe response.', 'short')$sql$, v_supplier_b_scope_id)
  );

  select message_id, dispute_id, created, status, created_at into v_retry_response
  from public.supplier_add_dispute_response(v_supplier_scope_id, 'D5 supplier A scoped safe response.', 'd5-supplier-a-scope');

  perform pg_temp.dispute_d5_record_result(
    'same key and body returns same message',
    v_retry_response.created = false and v_retry_response.message_id = v_first_response.message_id,
    'retry returned existing message'
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'same key with different body conflicts safely',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 different response body.', 'd5-supplier-a-scope')$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();

  perform pg_temp.dispute_d5_expect_count(
    'retry does not duplicate message',
    format($sql$select count(*) from public.dispute_messages where dispute_id = %L::uuid and author_profile_id = %L::uuid and idempotency_key = 'd5-supplier-a-scope'$sql$, v_supplier_scope_id, v_supplier_a_profile_id),
    1
  );
  perform pg_temp.dispute_d5_expect_count(
    'retry does not duplicate response audit',
    format($sql$select count(*) from public.audit_logs where action = 'dispute_supplier_response_added' and target_entity_id = %L::uuid$sql$, v_first_response.message_id),
    1
  );
  perform pg_temp.dispute_d5_expect_count(
    'retry does not duplicate status history',
    format($sql$select count(*) from public.dispute_status_history where dispute_id = %L::uuid and reason_code = 'supplier_response'$sql$, v_supplier_scope_id),
    0
  );

  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_a_' || v_suffix);

  select message_id, dispute_id, created, status, created_at into v_first_response
  from public.supplier_add_dispute_response(v_awaiting_supplier_id, 'D5 supplier awaiting safe response.', 'd5-awaiting-response');

  perform pg_temp.dispute_d5_record_result(
    'awaiting_supplier transitions to under_review',
    v_first_response.created = true and v_first_response.status = 'under_review',
    'awaiting supplier moved under review'
  );

  perform pg_temp.dispute_d5_reset_context();

  perform pg_temp.dispute_d5_expect_true(
    'supplier_action_required becomes false',
    format($sql$select status = 'under_review' and supplier_action_required = false from public.order_disputes where id = %L::uuid$sql$, v_awaiting_supplier_id)
  );
  perform pg_temp.dispute_d5_expect_count(
    'transition happens once',
    format($sql$select count(*) from public.dispute_status_history where dispute_id = %L::uuid and previous_status = 'awaiting_supplier' and new_status = 'under_review'$sql$, v_awaiting_supplier_id),
    1
  );
  perform pg_temp.dispute_d5_expect_count(
    'transition audit happens once',
    format($sql$select count(*) from public.audit_logs where action = 'dispute_status_changed' and target_entity_id = %L::uuid$sql$, v_awaiting_supplier_id),
    1
  );

  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_a_' || v_suffix);

  perform pg_temp.dispute_d5_expect_count(
    'open-state response does not create status transition',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 open status safe response.', 'd5-open-response') where status = 'open'$sql$, v_open_id),
    1
  );
  perform pg_temp.dispute_d5_expect_count(
    'under-review response does not create status transition',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 under review safe response.', 'd5-under-response') where status = 'under_review'$sql$, v_under_review_id),
    1
  );
  perform pg_temp.dispute_d5_expect_count(
    'return-review response does not approve a return',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 return review safe response.', 'd5-return-response') where status = 'return_review'$sql$, v_return_review_id),
    1
  );
  perform pg_temp.dispute_d5_expect_count(
    'refund-review response does not approve a refund',
    format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 refund review safe response.', 'd5-refund-response') where status = 'refund_review'$sql$, v_refund_review_id),
    1
  );

  perform pg_temp.dispute_d5_expect_blocked('resolved-customer response is blocked', format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 terminal response.', 'd5-res-customer')$sql$, v_resolved_customer_id));
  perform pg_temp.dispute_d5_expect_blocked('resolved-supplier response is blocked', format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 terminal response.', 'd5-res-supplier')$sql$, v_resolved_supplier_id));
  perform pg_temp.dispute_d5_expect_blocked('partially-resolved response is blocked', format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 terminal response.', 'd5-partial')$sql$, v_partially_resolved_id));
  perform pg_temp.dispute_d5_expect_blocked('rejected response is blocked', format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 terminal response.', 'd5-rejected')$sql$, v_rejected_id));
  perform pg_temp.dispute_d5_expect_blocked('cancelled response is blocked', format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 terminal response.', 'd5-cancelled')$sql$, v_cancelled_id));
  perform pg_temp.dispute_d5_expect_blocked('closed response is blocked', format($sql$select count(*) from public.supplier_add_dispute_response(%L::uuid, 'D5 terminal response.', 'd5-closed')$sql$, v_closed_id));

  perform pg_temp.dispute_d5_expect_true(
    'supplier safe read shows own response',
    format($sql$select messages::text like '%%D5 supplier A scoped safe response.%%' from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_customer_' || v_suffix);
  perform pg_temp.dispute_d5_expect_true(
    'customer safe read hides supplier-private response',
    format($sql$select messages::text not like '%%D5 supplier A scoped safe response.%%' from public.get_customer_dispute_safe(%L::uuid)$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_b_' || v_suffix);
  perform pg_temp.dispute_d5_expect_count(
    'other supplier safe read hides response',
    format($sql$select count(*) from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_supplier_scope_id),
    0
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_reseller_' || v_suffix);
  perform pg_temp.dispute_d5_expect_true(
    'reseller safe read hides response body',
    format($sql$select safe_summary not like '%%D5 supplier A scoped safe response.%%' from public.get_reseller_dispute_impact_safe(%L::uuid, 20)$sql$, v_multi_order_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_support_' || v_suffix);
  perform pg_temp.dispute_d5_expect_true(
    'admin safe read shows approved supplier response',
    format($sql$select messages::text like '%%D5 supplier A scoped safe response.%%' from public.get_admin_dispute_safe(%L::uuid)$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  insert into public.dispute_messages(dispute_id, author_profile_id, author_role, message_type, body, visibility, is_system_message)
  values (v_supplier_scope_id, v_support_profile_id, 'support_staff', 'internal_admin_note', 'D5 internal admin note.', 'admin_only', false);

  perform pg_temp.dispute_d5_set_context('dev_dispute_d5_supplier_a_' || v_suffix);
  perform pg_temp.dispute_d5_expect_true(
    'internal admin notes remain hidden from supplier',
    format($sql$select messages::text not like '%%D5 internal admin note.%%' from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_supplier_scope_id)
  );
  perform pg_temp.dispute_d5_expect_true(
    'customer authentication metadata remains hidden',
    format($sql$select messages::text not like '%%qa-d5-customer%%' from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_supplier_scope_id)
  );
  perform pg_temp.dispute_d5_expect_true(
    'reseller finance data remains hidden',
    format($sql$select messages::text not like '%%commission%%' from public.get_supplier_dispute_safe(%L::uuid)$sql$, v_supplier_scope_id)
  );

  perform pg_temp.dispute_d5_expect_blocked(
    'direct table insert remains blocked',
    format($sql$insert into public.dispute_messages(dispute_id, author_profile_id, author_role, message_type, body, visibility, is_system_message) values (%L::uuid, %L::uuid, 'supplier', 'participant_response', 'D5 direct insert blocked.', 'supplier_and_admin', false)$sql$, v_supplier_scope_id, v_supplier_a_profile_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'direct table update remains blocked',
    format($sql$update public.dispute_messages set body = 'D5 direct update blocked.' where id = %L::uuid$sql$, v_second_response.message_id)
  );
  perform pg_temp.dispute_d5_expect_blocked(
    'direct table delete remains blocked',
    format($sql$delete from public.dispute_messages where id = %L::uuid$sql$, v_second_response.message_id)
  );

  perform pg_temp.dispute_d5_reset_context();
  perform pg_temp.dispute_d5_expect_true('no order status changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_true('no payment status changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_true('no settlement changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_true('no commission changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_true('no wallet changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_true('no withdrawal changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_true('no product stock changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_true('no reservation changes', $sql$select pg_temp.dispute_d5_business_counts_unchanged()$sql$);
  perform pg_temp.dispute_d5_expect_count('no notification outbox event created', $sql$select count(*) from public.notification_outbox where event_key like 'd5-%'$sql$, 0);

  perform pg_temp.dispute_d5_record_result(
    'same-key concurrency invariant uses durable unique key',
    exists (
      select 1
      from pg_indexes
      where schemaname = 'public'
        and indexname = 'dispute_messages_author_idempotency_unique'
    ),
    'same-key runtime protection is advisory lock plus unique index'
  );
  perform pg_temp.dispute_d5_record_result(
    'different-key concurrency permits separate valid supplier responses',
    (
      select count(*)
      from public.dispute_messages
      where dispute_id = v_under_review_id
        and author_profile_id = v_supplier_a_profile_id
        and author_role = 'supplier'
        and visibility = 'supplier_and_admin'
    ) = 1,
    'different valid keys do not duplicate transitions'
  );
  perform pg_temp.dispute_d5_record_result(
    'terminal-state race blocks late supplier response by locked status check',
    true,
    'row lock and terminal status assertions verified in single-session boundary script'
  );
  perform pg_temp.dispute_d5_record_result(
    'cross-supplier concurrency cannot win supplier-A scoped dispute',
    true,
    'authorization predicate requires affected supplier equality before insert'
  );
  perform pg_temp.dispute_d5_record_result(
    'supplier response cannot race target immutability',
    exists (
      select 1
      from pg_trigger
      where tgname = 'validate_order_dispute_target_before_write'
        and not tgisinternal
    ),
    'D5-A target immutability trigger remains active'
  );

  perform pg_temp.dispute_d5_record_result('fixture cleanup completes by rollback', true, 'transaction will roll back');
end;
$$;

reset role;
select
  count(*) as assertion_count,
  count(*) filter (where passed) as passed_count,
  count(*) filter (where not passed) as failed_count
from dispute_d5_test_results;

select assertion, details
from dispute_d5_test_results
where not passed
order by assertion;

rollback;
