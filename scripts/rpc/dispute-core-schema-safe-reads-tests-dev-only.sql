-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D3 core schema + safe-read RPC boundary tests.
-- Creates fake/dev-only fixture rows inside a transaction and rolls everything
-- back. Does not create refunds, returns, finance holds, payments, stock
-- movements, settlements/commissions/withdrawals beyond rollback-scoped
-- read-context fixtures, evidence files, notifications, or business mutations.

begin;

create temp table dispute_d2_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on dispute_d2_test_results to anon, authenticated;

create or replace function pg_temp.dispute_d2_record_result(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into dispute_d2_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.dispute_d2_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.dispute_d2_set_anon_context()
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

create or replace function pg_temp.dispute_d2_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.dispute_d2_expect_count(
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
  perform pg_temp.dispute_d2_record_result(
    p_assertion,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d2_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d2_expect_true(
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
  perform pg_temp.dispute_d2_record_result(
    p_assertion,
    coalesce(v_observed, false),
    'observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.dispute_d2_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.dispute_d2_expect_blocked(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.dispute_d2_record_result(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.dispute_d2_record_result(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_a_profile_id uuid := gen_random_uuid();
  v_customer_b_profile_id uuid := gen_random_uuid();
  v_customer_empty_profile_id uuid := gen_random_uuid();
  v_supplier_a_profile_id uuid := gen_random_uuid();
  v_supplier_b_profile_id uuid := gen_random_uuid();
  v_supplier_empty_profile_id uuid := gen_random_uuid();
  v_reseller_a_profile_id uuid := gen_random_uuid();
  v_reseller_b_profile_id uuid := gen_random_uuid();
  v_reseller_empty_profile_id uuid := gen_random_uuid();
  v_support_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_inactive_admin_profile_id uuid := gen_random_uuid();
  v_suspended_profile_id uuid := gen_random_uuid();

  v_customer_a_id uuid := gen_random_uuid();
  v_customer_b_id uuid := gen_random_uuid();
  v_customer_empty_id uuid := gen_random_uuid();
  v_suspended_customer_id uuid := gen_random_uuid();
  v_supplier_a_id uuid := gen_random_uuid();
  v_supplier_b_id uuid := gen_random_uuid();
  v_supplier_empty_id uuid := gen_random_uuid();
  v_reseller_a_id uuid := gen_random_uuid();
  v_reseller_b_id uuid := gen_random_uuid();
  v_reseller_empty_id uuid := gen_random_uuid();
  v_shop_a_id uuid := gen_random_uuid();
  v_shop_b_id uuid := gen_random_uuid();
  v_product_a_id uuid := gen_random_uuid();
  v_product_b_id uuid := gen_random_uuid();
  v_variant_a_id uuid := gen_random_uuid();
  v_variant_b_id uuid := gen_random_uuid();
  v_listing_a_id uuid := gen_random_uuid();
  v_listing_b_id uuid := gen_random_uuid();
  v_order_a_id uuid := gen_random_uuid();
  v_order_b_id uuid := gen_random_uuid();
  v_order_item_a_id uuid := gen_random_uuid();
  v_order_item_b_id uuid := gen_random_uuid();
  v_dispute_a_id uuid := gen_random_uuid();
  v_dispute_b_id uuid := gen_random_uuid();
  v_settlement_id uuid := gen_random_uuid();
  v_commission_id uuid := gen_random_uuid();
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_dispute_d3_customer_a_' || v_suffix, 'qa-dispute-customer-a@example.test', 'D3 Customer A', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_dispute_d3_customer_b_' || v_suffix, 'qa-dispute-customer-b@example.test', 'D3 Customer B', 'customer', 'active'),
    (v_customer_empty_profile_id, 'dev_dispute_d3_customer_empty_' || v_suffix, 'qa-dispute-customer-empty@example.test', 'D3 Customer Empty', 'customer', 'active'),
    (v_supplier_a_profile_id, 'dev_dispute_d3_supplier_a_' || v_suffix, 'qa-dispute-supplier-a@example.test', 'D3 Supplier A', 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_dispute_d3_supplier_b_' || v_suffix, 'qa-dispute-supplier-b@example.test', 'D3 Supplier B', 'supplier_owner', 'active'),
    (v_supplier_empty_profile_id, 'dev_dispute_d3_supplier_empty_' || v_suffix, 'qa-dispute-supplier-empty@example.test', 'D3 Supplier Empty', 'supplier_owner', 'active'),
    (v_reseller_a_profile_id, 'dev_dispute_d3_reseller_a_' || v_suffix, 'qa-dispute-reseller-a@example.test', 'D3 Reseller A', 'reseller', 'active'),
    (v_reseller_b_profile_id, 'dev_dispute_d3_reseller_b_' || v_suffix, 'qa-dispute-reseller-b@example.test', 'D3 Reseller B', 'reseller', 'active'),
    (v_reseller_empty_profile_id, 'dev_dispute_d3_reseller_empty_' || v_suffix, 'qa-dispute-reseller-empty@example.test', 'D3 Reseller Empty', 'reseller', 'active'),
    (v_support_profile_id, 'dev_dispute_d3_support_' || v_suffix, 'qa-dispute-support@example.test', 'D3 Support Admin', 'customer', 'active'),
    (v_finance_profile_id, 'dev_dispute_d3_finance_' || v_suffix, 'qa-dispute-finance@example.test', 'D3 Finance Admin', 'customer', 'active'),
    (v_inactive_admin_profile_id, 'dev_dispute_d3_inactive_admin_' || v_suffix, 'qa-dispute-inactive-admin@example.test', 'D3 Inactive Admin', 'customer', 'active'),
    (v_suspended_profile_id, 'dev_dispute_d3_suspended_' || v_suffix, 'qa-dispute-suspended@example.test', 'D3 Suspended Customer', 'customer', 'suspended');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active'),
    (v_customer_empty_id, v_customer_empty_profile_id, 'active'),
    (v_suspended_customer_id, v_suspended_profile_id, 'active');

  insert into public.admin_staff(id, profile_id, admin_role, staff_status)
  values
    (gen_random_uuid(), v_support_profile_id, 'support_staff', 'active'),
    (gen_random_uuid(), v_finance_profile_id, 'finance_staff', 'active'),
    (gen_random_uuid(), v_inactive_admin_profile_id, 'support_staff', 'removed');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'D3 Supplier A', 'active', 'approved', 'D3 Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'D3 Supplier B', 'active', 'approved', 'D3 Supplier B'),
    (v_supplier_empty_id, v_supplier_empty_profile_id, 'D3 Supplier Empty', 'active', 'approved', 'D3 Supplier Empty');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values
    (v_reseller_a_id, v_reseller_a_profile_id, 'qa', 'approved', 'active'),
    (v_reseller_b_id, v_reseller_b_profile_id, 'qa', 'approved', 'active'),
    (v_reseller_empty_id, v_reseller_empty_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
  values
    (v_shop_a_id, v_reseller_a_id, 'd3-dispute-shop-a-' || lower(left(v_suffix, 10)), 'D3 Dispute Shop A', 'active'),
    (v_shop_b_id, v_reseller_b_id, 'd3-dispute-shop-b-' || lower(left(v_suffix, 10)), 'D3 Dispute Shop B', 'active');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
  values
    (v_product_a_id, v_supplier_a_id, 'QA', 'D3 Dispute Product A', 'd3-dispute-product-a-' || lower(left(v_suffix, 10)), 'Development-only dispute fixture product A', 'active', 'approved', 100, 10, 20, v_supplier_a_profile_id),
    (v_product_b_id, v_supplier_b_id, 'QA', 'D3 Dispute Product B', 'd3-dispute-product-b-' || lower(left(v_suffix, 10)), 'Development-only dispute fixture product B', 'active', 'approved', 120, 12, 24, v_supplier_b_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_a_id, 'D3-DISPUTE-A-' || upper(left(v_suffix, 8)), 'Default', 10, 1, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'D3-DISPUTE-B-' || upper(left(v_suffix, 8)), 'Default', 10, 1, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_a_id, v_shop_a_id, v_product_a_id, v_variant_a_id, 'active', 15, 125, 'd3-dispute-listing-a-' || lower(left(v_suffix, 10))),
    (v_listing_b_id, v_reseller_b_id, v_shop_b_id, v_product_b_id, v_variant_b_id, 'active', 18, 150, 'd3-dispute-listing-b-' || lower(left(v_suffix, 10)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, subtotal_product_amount, total_payable_amount, currency_code)
  values
    (v_order_a_id, 'D3-DISPUTE-A-' || upper(left(v_suffix, 10)), v_customer_a_id, v_reseller_a_id, v_shop_a_id, 'delivered_payment_pending', 'not_collected', 125, 125, 'GHS'),
    (v_order_b_id, 'D3-DISPUTE-B-' || upper(left(v_suffix, 10)), v_customer_b_id, v_reseller_b_id, v_shop_b_id, 'delivered_payment_pending', 'not_collected', 150, 150, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_order_item_a_id, v_order_a_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_order_item_b_id, v_order_b_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 120, 12, 18, 132, 150, 150, 120, 18);

  insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount)
  values (v_settlement_id, v_supplier_a_id, v_order_a_id, 'due', 100, 0, 100);

  insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount)
  values (v_commission_id, v_reseller_a_id, v_order_a_id, v_order_item_a_id, v_settlement_id, 'held', 15);

  insert into public.order_disputes(
    id, order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code,
    description, requested_outcome, status, priority, assigned_admin_profile_id,
    customer_action_required, supplier_action_required, finance_review_required,
    public_resolution_message, internal_resolution_notes, idempotency_key
  )
  values
    (v_dispute_a_id, v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'delivery_delay',
     'Customer safe complaint for D3 verification', 'redelivery', 'under_review', 'high', v_support_profile_id,
     false, true, true, 'Public update for D3 verification', 'Internal admin-only D3 note', 'd3-dispute-a-' || left(v_suffix, 16)),
    (v_dispute_b_id, v_order_b_id, v_customer_b_profile_id, 'customer', 'post_completion', 'wrong_item_received',
     'Other customer complaint for D3 verification', 'replacement', 'open', 'normal', null,
     true, false, false, null, 'Other internal admin-only D3 note', 'd3-dispute-b-' || left(v_suffix, 16));

  insert into public.dispute_messages(dispute_id, author_profile_id, author_role, message_type, body, visibility)
  values
    (v_dispute_a_id, v_customer_a_profile_id, 'customer', 'participant_response', 'Customer-visible message D3', 'customer_and_admin'),
    (v_dispute_a_id, v_supplier_a_profile_id, 'supplier', 'participant_response', 'Supplier-private response D3', 'supplier_and_admin'),
    (v_dispute_a_id, v_support_profile_id, 'support_staff', 'internal_admin_note', 'Internal admin note D3', 'admin_only'),
    (v_dispute_a_id, v_support_profile_id, 'support_staff', 'public_admin_note', 'Shared public update D3', 'all_case_participants'),
    (v_dispute_b_id, v_customer_b_profile_id, 'customer', 'participant_response', 'Other customer-visible message D3', 'customer_and_admin');

  insert into public.dispute_status_history(dispute_id, previous_status, new_status, changed_by_profile_id, changed_by_role, reason_code, public_note, internal_note, idempotency_key)
  values
    (v_dispute_a_id, null, 'open', v_customer_a_profile_id, 'customer', 'system_event', 'Case opened', 'Internal open note D3', 'd3-status-a-' || left(v_suffix, 16)),
    (v_dispute_a_id, 'open', 'under_review', v_support_profile_id, 'support_staff', 'admin_review', 'Case under review', 'Internal review note D3', 'd3-status-b-' || left(v_suffix, 16)),
    (v_dispute_b_id, null, 'open', v_customer_b_profile_id, 'customer', 'system_event', 'Other case opened', 'Other internal note D3', 'd3-status-c-' || left(v_suffix, 16));

  perform pg_temp.dispute_d2_record_result('fixtures created inside rollback transaction', true);

  perform pg_temp.dispute_d2_set_anon_context();
  perform pg_temp.dispute_d2_expect_blocked('anonymous cannot select order_disputes', 'select count(*) from public.order_disputes');
  perform pg_temp.dispute_d2_expect_blocked('anonymous cannot execute customer safe read', 'select count(*) from public.list_customer_disputes_safe()');

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_customer_a_' || v_suffix);
  perform pg_temp.dispute_d2_expect_blocked('authenticated cannot directly select order_disputes', 'select count(*) from public.order_disputes');
  perform pg_temp.dispute_d2_expect_blocked('authenticated cannot directly insert order_disputes', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code) values (%L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'other'
  ));
  perform pg_temp.dispute_d2_expect_blocked('authenticated cannot directly update order_disputes', format('update public.order_disputes set status = %L where id = %L', 'closed', v_dispute_a_id));
  perform pg_temp.dispute_d2_expect_blocked('authenticated cannot directly delete order_disputes', format('delete from public.order_disputes where id = %L', v_dispute_a_id));
  perform pg_temp.dispute_d2_expect_count('customer A lists own dispute only', 'select count(*) from public.list_customer_disputes_safe()', 1);
  perform pg_temp.dispute_d2_expect_count('customer A cannot retrieve customer B dispute', format('select count(*) from public.get_customer_dispute_safe(%L)', v_dispute_b_id), 0);
  perform pg_temp.dispute_d2_expect_true('customer detail hides internal admin notes', format($sql$
    select not (coalesce((select messages::text || status_history::text from public.get_customer_dispute_safe(%L)), '') like '%%Internal%%')
  $sql$, v_dispute_a_id));
  perform pg_temp.dispute_d2_expect_true('customer detail hides supplier-private messages', format($sql$
    select not (coalesce((select messages::text from public.get_customer_dispute_safe(%L)), '') like '%%Supplier-private%%')
  $sql$, v_dispute_a_id));
  perform pg_temp.dispute_d2_expect_true('customer detail hides finance-only fields', format($sql$
    select not (coalesce((select row_to_json(x)::text from public.get_customer_dispute_safe(%L) x), '') like '%%finance%%')
  $sql$, v_dispute_a_id));
  perform pg_temp.dispute_d2_expect_blocked('customer invalid status filter fails safely', 'select count(*) from public.list_customer_disputes_safe(''not_valid'')');
  perform pg_temp.dispute_d2_expect_count('customer pagination cap returns bounded rows', 'select count(*) from public.list_customer_disputes_safe(null, 999)', 1);

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_customer_b_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('customer B lists own dispute only', 'select count(*) from public.list_customer_disputes_safe()', 1);
  perform pg_temp.dispute_d2_expect_count('customer B cannot retrieve customer A dispute', format('select count(*) from public.get_customer_dispute_safe(%L)', v_dispute_a_id), 0);

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_customer_empty_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('customer empty-state list returns zero safely', 'select count(*) from public.list_customer_disputes_safe()', 0);
  perform pg_temp.dispute_d2_expect_count('customer unknown dispute detail returns zero safely', 'select count(*) from public.get_customer_dispute_safe(gen_random_uuid())', 0);
  perform pg_temp.dispute_d2_expect_blocked('customer malformed uuid fails safely', 'select count(*) from public.get_customer_dispute_safe(''not-a-uuid''::uuid)');

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_supplier_a_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('supplier A lists own order-item dispute only', 'select count(*) from public.list_supplier_disputes_safe()', 1);
  perform pg_temp.dispute_d2_expect_count('supplier A cannot retrieve supplier B dispute', format('select count(*) from public.get_supplier_dispute_safe(%L)', v_dispute_b_id), 0);
  perform pg_temp.dispute_d2_expect_true('supplier detail hides internal admin notes', format($sql$
    select not (coalesce((select messages::text || status_history::text from public.get_supplier_dispute_safe(%L)), '') like '%%Internal%%')
  $sql$, v_dispute_a_id));
  perform pg_temp.dispute_d2_expect_true('supplier detail hides reseller wallet and commission details', format($sql$
    select not (coalesce((select row_to_json(x)::text from public.get_supplier_dispute_safe(%L) x), '') ~* '(wallet|commission|settlement|withdrawal)')
  $sql$, v_dispute_a_id));

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_supplier_b_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('supplier B lists own dispute only', 'select count(*) from public.list_supplier_disputes_safe()', 1);
  perform pg_temp.dispute_d2_expect_count('supplier B cannot retrieve supplier A dispute', format('select count(*) from public.get_supplier_dispute_safe(%L)', v_dispute_a_id), 0);

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_supplier_empty_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('supplier empty-state list returns zero safely', 'select count(*) from public.list_supplier_disputes_safe()', 0);

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_reseller_a_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('reseller A receives impact for attributed order only', 'select count(*) from public.get_reseller_dispute_impact_safe()', 1);
  perform pg_temp.dispute_d2_expect_true('reseller impact hides complaint descriptions and messages', 'select not (coalesce((select string_agg(row_to_json(x)::text, '' '') from public.get_reseller_dispute_impact_safe() x), '''') ~* ''(complaint|message|evidence|refund|settlement|Supplier-private|Customer-visible)'')');
  perform pg_temp.dispute_d2_expect_count('reseller A cannot retrieve reseller B order impact by id', format('select count(*) from public.get_reseller_dispute_impact_safe(%L)', v_order_b_id), 0);

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_reseller_empty_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('reseller empty-state impact returns zero safely', 'select count(*) from public.get_reseller_dispute_impact_safe()', 0);

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_support_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('support admin lists disputes', 'select count(*) from public.list_admin_disputes_safe()', 2);
  perform pg_temp.dispute_d2_expect_count('support admin unknown dispute detail returns zero safely', 'select count(*) from public.get_admin_dispute_safe(gen_random_uuid())', 0);
  perform pg_temp.dispute_d2_expect_true('support admin finance context is hidden', format($sql$
    select coalesce((select finance_context ->> 'financeReviewVisible' from public.get_admin_dispute_safe(%L)), 'false') = 'false'
  $sql$, v_dispute_a_id));
  perform pg_temp.dispute_d2_expect_blocked('support admin invalid category filter fails safely', 'select count(*) from public.list_admin_disputes_safe(null, ''not_valid'')');
  perform pg_temp.dispute_d2_expect_count('support admin assigned-only filter works', 'select count(*) from public.list_admin_disputes_safe(null, null, null, true)', 1);

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_finance_' || v_suffix);
  perform pg_temp.dispute_d2_expect_count('finance staff can read admin dispute detail', format('select count(*) from public.get_admin_dispute_safe(%L)', v_dispute_a_id), 1);
  perform pg_temp.dispute_d2_expect_true('finance staff sees finance-review indicator only', format($sql$
    select coalesce((select finance_context ->> 'financeReviewVisible' from public.get_admin_dispute_safe(%L)), 'false') = 'true'
      and coalesce((select finance_context::text from public.get_admin_dispute_safe(%L)), '') not like '%%account_number%%'
  $sql$, v_dispute_a_id, v_dispute_a_id));

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_inactive_admin_' || v_suffix);
  perform pg_temp.dispute_d2_expect_blocked('inactive admin is blocked', 'select count(*) from public.list_admin_disputes_safe()');

  perform pg_temp.dispute_d2_set_context('dev_dispute_d3_suspended_' || v_suffix);
  perform pg_temp.dispute_d2_expect_blocked('suspended profile is blocked', 'select count(*) from public.list_customer_disputes_safe()');

  perform pg_temp.dispute_d2_reset_context();
  perform pg_temp.dispute_d2_expect_blocked('invalid dispute category rejected', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'invalid_category', 'other', 'information_only', 'd3-invalid-category-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('invalid reason code rejected', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'invalid_reason', 'information_only', 'd3-invalid-reason-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('invalid requested outcome rejected', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'other', 'invalid_outcome', 'd3-invalid-outcome-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('invalid status rejected', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, status, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'other', 'information_only', 'invalid_status', 'd3-invalid-status-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('invalid priority rejected', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, priority, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'other', 'information_only', 'invalid_priority', 'd3-invalid-priority-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('invalid message visibility rejected', format(
    'insert into public.dispute_messages(dispute_id, author_role, body, visibility) values (%L, %L, %L, %L)',
    v_dispute_a_id, 'customer', 'Invalid visibility test', 'everyone'
  ));
  perform pg_temp.dispute_d2_expect_blocked('invalid sender role rejected', format(
    'insert into public.dispute_messages(dispute_id, author_role, body, visibility) values (%L, %L, %L, %L)',
    v_dispute_a_id, 'intruder', 'Invalid sender role test', 'customer_and_admin'
  ));
  perform pg_temp.dispute_d2_expect_blocked('invalid actor role rejected', format(
    'insert into public.dispute_status_history(dispute_id, new_status, changed_by_role, idempotency_key) values (%L, %L, %L, %L)',
    v_dispute_a_id, 'open', 'intruder', 'd3-invalid-actor-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('closed timestamp requires closed status', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, status, closed_at, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L, now(), %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'other', 'information_only', 'open', 'd3-invalid-closed-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('short idempotency key rejected', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'other', 'information_only', 'short'
  ));
  perform pg_temp.dispute_d2_expect_blocked('duplicate active dispute blocked', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, idempotency_key) values (%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'delivery', 'delivery_delay', 'information_only', 'd3-duplicate-active-' || left(v_suffix, 8)
  ));
  perform pg_temp.dispute_d2_expect_blocked('duplicate status history idempotency blocked', format(
    'insert into public.dispute_status_history(dispute_id, new_status, changed_by_role, idempotency_key) values (%L, %L, %L, %L)',
    v_dispute_a_id, 'under_review', 'support_staff', 'd3-status-a-' || left(v_suffix, 16)
  ));
end;
$$;

do $$
declare
  v_failed_count integer;
begin
  select count(*) into v_failed_count
  from dispute_d2_test_results
  where not passed;

  if v_failed_count > 0 then
    raise exception 'DISPUTE_D2_BOUNDARY_TEST_FAILED: % assertion(s) failed', v_failed_count
      using errcode = '23514';
  end if;
end;
$$;

select assertion, passed, details
from dispute_d2_test_results
order by assertion;

rollback;
