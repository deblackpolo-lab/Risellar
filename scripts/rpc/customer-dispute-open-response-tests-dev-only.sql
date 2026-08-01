-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D4 customer open/respond RPC boundary tests.
-- Creates fake/dev-only fixture rows inside a transaction and rolls everything
-- back. Does not mutate orders, payment state, delivery state, stock,
-- reservations, settlements, commissions, withdrawals, wallets, returns,
-- refunds, evidence, or notification outbox outside rollback-scoped fixtures.

begin;

create temp table customer_dispute_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on customer_dispute_test_results to anon, authenticated;

create temp table customer_dispute_test_ids (
  fixture_key text primary key,
  fixture_id uuid not null
) on commit drop;

grant select, insert, update on customer_dispute_test_ids to anon, authenticated;

create temp table customer_dispute_business_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on customer_dispute_business_counts to anon, authenticated;

create or replace function pg_temp.customer_dispute_record_result(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into customer_dispute_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.customer_dispute_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.customer_dispute_set_anon_context()
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

create or replace function pg_temp.customer_dispute_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.customer_dispute_expect_count(
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
  perform pg_temp.customer_dispute_record_result(
    p_assertion,
    v_observed = p_expected,
    'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.customer_dispute_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.customer_dispute_expect_true(
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
  perform pg_temp.customer_dispute_record_result(
    p_assertion,
    coalesce(v_observed, false),
    'observed=' || coalesce(v_observed::text, 'null')
  );
exception when others then
  perform pg_temp.customer_dispute_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.customer_dispute_expect_blocked(
  p_assertion text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.customer_dispute_record_result(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.customer_dispute_record_result(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.customer_dispute_capture_business_counts()
returns void
language plpgsql
as $$
begin
  insert into customer_dispute_business_counts(table_name, row_count)
  values
    ('orders', (select count(*) from public.orders)),
    ('order_items', (select count(*) from public.order_items)),
    ('products', (select count(*) from public.products)),
    ('product_variants', (select count(*) from public.product_variants)),
    ('stock_reservations', (select count(*) from public.stock_reservations)),
    ('settlements', (select count(*) from public.settlements)),
    ('commissions', (select count(*) from public.commissions)),
    ('withdrawals', (select count(*) from public.withdrawals)),
    ('notification_outbox', (select count(*) from public.notification_outbox))
  on conflict (table_name) do update set row_count = excluded.row_count;
end;
$$;

create or replace function pg_temp.customer_dispute_business_counts_unchanged()
returns boolean
language sql
as $$
  select
    (select count(*) from public.orders) = (select row_count from customer_dispute_business_counts where table_name = 'orders')
    and (select count(*) from public.order_items) = (select row_count from customer_dispute_business_counts where table_name = 'order_items')
    and (select count(*) from public.products) = (select row_count from customer_dispute_business_counts where table_name = 'products')
    and (select count(*) from public.product_variants) = (select row_count from customer_dispute_business_counts where table_name = 'product_variants')
    and (select count(*) from public.stock_reservations) = (select row_count from customer_dispute_business_counts where table_name = 'stock_reservations')
    and (select count(*) from public.settlements) = (select row_count from customer_dispute_business_counts where table_name = 'settlements')
    and (select count(*) from public.commissions) = (select row_count from customer_dispute_business_counts where table_name = 'commissions')
    and (select count(*) from public.withdrawals) = (select row_count from customer_dispute_business_counts where table_name = 'withdrawals')
    and (select count(*) from public.notification_outbox) = (select row_count from customer_dispute_business_counts where table_name = 'notification_outbox');
$$;

do $$
declare
  v_suffix text := replace(gen_random_uuid()::text, '-', '');

  v_customer_a_profile_id uuid := gen_random_uuid();
  v_customer_b_profile_id uuid := gen_random_uuid();
  v_inactive_customer_profile_id uuid := gen_random_uuid();
  v_suspended_profile_id uuid := gen_random_uuid();
  v_supplier_profile_id uuid := gen_random_uuid();
  v_reseller_profile_id uuid := gen_random_uuid();
  v_customer_a_id uuid := gen_random_uuid();
  v_customer_b_id uuid := gen_random_uuid();
  v_inactive_customer_id uuid := gen_random_uuid();
  v_suspended_customer_id uuid := gen_random_uuid();
  v_supplier_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_variant_id uuid := gen_random_uuid();
  v_listing_id uuid := gen_random_uuid();
  v_order_a_id uuid := gen_random_uuid();
  v_order_b_id uuid := gen_random_uuid();
  v_ineligible_order_id uuid := gen_random_uuid();
  v_rejected_order_id uuid := gen_random_uuid();
  v_order_item_a_id uuid := gen_random_uuid();
  v_order_item_b_id uuid := gen_random_uuid();
  v_order_item_ineligible_id uuid := gen_random_uuid();
  v_order_item_rejected_id uuid := gen_random_uuid();
  v_awaiting_dispute_id uuid := gen_random_uuid();
  v_closed_dispute_id uuid := gen_random_uuid();
  v_rejected_dispute_id uuid := gen_random_uuid();
  v_cancelled_dispute_id uuid := gen_random_uuid();
  v_open_result record;
  v_retry_result record;
  v_response_result record;
  v_response_retry record;
  v_awaiting_response record;
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_a_profile_id, 'dev_dispute_d4_customer_a_' || v_suffix, 'qa-d4-customer-a@example.test', 'D4 Customer A', 'customer', 'active'),
    (v_customer_b_profile_id, 'dev_dispute_d4_customer_b_' || v_suffix, 'qa-d4-customer-b@example.test', 'D4 Customer B', 'customer', 'active'),
    (v_inactive_customer_profile_id, 'dev_dispute_d4_inactive_customer_' || v_suffix, 'qa-d4-inactive@example.test', 'D4 Inactive Customer', 'customer', 'active'),
    (v_suspended_profile_id, 'dev_dispute_d4_suspended_' || v_suffix, 'qa-d4-suspended@example.test', 'D4 Suspended Customer', 'customer', 'suspended'),
    (v_supplier_profile_id, 'dev_dispute_d4_supplier_' || v_suffix, 'qa-d4-supplier@example.test', 'D4 Supplier', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_dispute_d4_reseller_' || v_suffix, 'qa-d4-reseller@example.test', 'D4 Reseller', 'reseller', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_a_id, v_customer_a_profile_id, 'active'),
    (v_customer_b_id, v_customer_b_profile_id, 'active'),
    (v_inactive_customer_id, v_inactive_customer_profile_id, 'suspended'),
    (v_suspended_customer_id, v_suspended_profile_id, 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values (v_supplier_id, v_supplier_profile_id, 'D4 Supplier', 'active', 'approved', 'D4 Supplier');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
  values (v_shop_id, v_reseller_id, 'd4-dispute-shop-' || lower(left(v_suffix, 10)), 'D4 Dispute Shop', 'active');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
  values (v_product_id, v_supplier_id, 'QA', 'D4 Dispute Product', 'd4-dispute-product-' || lower(left(v_suffix, 10)), 'Development-only D4 fixture product', 'active', 'approved', 100, 10, 20, v_supplier_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
  values (v_variant_id, v_product_id, 'D4-DISPUTE-' || upper(left(v_suffix, 8)), 'Default', 10, 4, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values (v_listing_id, v_reseller_id, v_shop_id, v_product_id, v_variant_id, 'active', 15, 125, 'd4-dispute-listing-' || lower(left(v_suffix, 10)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
  values
    (v_order_a_id, 'D4-DISPUTE-A-' || upper(left(v_suffix, 10)), v_customer_a_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS'),
    (v_order_b_id, 'D4-DISPUTE-B-' || upper(left(v_suffix, 10)), v_customer_b_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS'),
    (v_ineligible_order_id, 'D4-DISPUTE-CANCEL-' || upper(left(v_suffix, 8)), v_customer_a_id, v_reseller_id, v_shop_id, 'cancelled', 'not_collected', 'cancelled', 125, 125, 'GHS'),
    (v_rejected_order_id, 'D4-DISPUTE-REJECT-' || upper(left(v_suffix, 8)), v_customer_a_id, v_reseller_id, v_shop_id, 'supplier_rejected', 'not_collected', 'estimate_selected', 125, 125, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_order_item_a_id, v_order_a_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_order_item_b_id, v_order_b_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_order_item_ineligible_id, v_ineligible_order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_order_item_rejected_id, v_rejected_order_id, v_supplier_id, v_product_id, v_variant_id, v_listing_id, 1, 100, 10, 15, 110, 125, 125, 100, 15);

  perform pg_temp.customer_dispute_capture_business_counts();

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code, description, requested_outcome, status, priority, customer_action_required, supplier_action_required, idempotency_key)
  values
    (v_awaiting_dispute_id, v_order_a_id, v_customer_a_profile_id, 'customer', 'order', 'delivery', 'delivery_delay', 'Awaiting customer D4 fixture', 'information_only', 'awaiting_customer', 'normal', true, false, 'd4-awaiting-' || left(v_suffix, 16)),
    (v_closed_dispute_id, v_order_a_id, v_customer_a_profile_id, 'customer', 'order', 'delivery', 'unsafe_delivery_issue', 'Closed D4 fixture', 'information_only', 'closed', 'normal', false, false, 'd4-closed-' || left(v_suffix, 16)),
    (v_rejected_dispute_id, v_order_a_id, v_customer_a_profile_id, 'customer', 'order', 'payment', 'wrong_amount_collected', 'Rejected D4 fixture', 'information_only', 'rejected', 'normal', false, false, 'd4-rejected-' || left(v_suffix, 16)),
    (v_cancelled_dispute_id, v_order_a_id, v_customer_a_profile_id, 'customer', 'order', 'other', 'other', 'Cancelled D4 fixture', 'other', 'cancelled', 'normal', false, false, 'd4-cancelled-' || left(v_suffix, 16));

  insert into public.dispute_status_history(dispute_id, previous_status, new_status, changed_by_profile_id, changed_by_role, reason_code, public_note, idempotency_key)
  values
    (v_awaiting_dispute_id, null, 'awaiting_customer', v_customer_a_profile_id, 'customer', 'system_event', 'Awaiting customer fixture', 'd4-awaiting-history-' || left(v_suffix, 16)),
    (v_closed_dispute_id, null, 'closed', v_customer_a_profile_id, 'customer', 'case_closed', 'Closed fixture', 'd4-closed-history-' || left(v_suffix, 16)),
    (v_rejected_dispute_id, null, 'rejected', v_customer_a_profile_id, 'customer', 'case_closed', 'Rejected fixture', 'd4-rejected-history-' || left(v_suffix, 16)),
    (v_cancelled_dispute_id, null, 'cancelled', v_customer_a_profile_id, 'customer', 'case_cancelled', 'Cancelled fixture', 'd4-cancelled-history-' || left(v_suffix, 16));

  perform pg_temp.customer_dispute_set_anon_context();
  perform pg_temp.customer_dispute_expect_blocked('anonymous cannot open dispute', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'replacement', 'Valid D4 anonymous attempt', 'd4-anon-open-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('anonymous cannot respond', format(
    'select count(*) from public.customer_add_dispute_response(%L, %L, %L)',
    v_awaiting_dispute_id, 'Valid D4 anonymous response attempt', 'd4-anon-response-' || left(v_suffix, 12)
  ));

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_suspended_' || v_suffix);
  perform pg_temp.customer_dispute_expect_blocked('suspended customer blocked from opening', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'replacement', 'Valid D4 suspended attempt', 'd4-suspended-open-' || left(v_suffix, 12)
  ));

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_inactive_customer_' || v_suffix);
  perform pg_temp.customer_dispute_expect_blocked('inactive customer blocked from opening', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'replacement', 'Valid D4 inactive attempt', 'd4-inactive-open-' || left(v_suffix, 12)
  ));

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  perform pg_temp.customer_dispute_expect_blocked('customer cannot dispute another customer order', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_b_id, v_order_item_b_id, 'delivery', 'wrong_item_received', 'replacement', 'Valid D4 cross-order attempt', 'd4-cross-open-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('direct table write remains blocked', format(
    'insert into public.order_disputes(order_id, opened_by_profile_id, opened_by_role, scope_type, dispute_category, reason_code) values (%L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_customer_a_profile_id, 'customer', 'order', 'delivery', 'other'
  ));
  perform pg_temp.customer_dispute_expect_blocked('invalid category rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'bad_category', 'wrong_item_received', 'replacement', 'Valid D4 bad category', 'd4-bad-cat-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('invalid reason rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'bad_reason', 'replacement', 'Valid D4 bad reason', 'd4-bad-reason-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('invalid outcome rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'bad_outcome', 'Valid D4 bad outcome', 'd4-bad-outcome-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('invalid reason/category combination rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'pre_delivery', 'wrong_item_received', 'replacement', 'Valid D4 bad combo', 'd4-bad-combo-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('invalid reason/order-state combination rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_ineligible_order_id, v_order_item_ineligible_id, 'delivery', 'wrong_item_received', 'replacement', 'Valid D4 bad state', 'd4-bad-state-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('empty description rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'replacement', '', 'd4-empty-description-' || left(v_suffix, 8)
  ));
  perform pg_temp.customer_dispute_expect_blocked('oversized description rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'replacement', repeat('x', 1201), 'd4-long-description-' || left(v_suffix, 8)
  ));
  perform pg_temp.customer_dispute_expect_blocked('invalid idempotency key rejected', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'replacement', 'Valid D4 invalid key', 'short'
  ));

  select *
  into v_open_result
  from public.customer_open_order_dispute(
    v_order_a_id,
    v_order_item_a_id,
    'delivery',
    'wrong_item_received',
    'replacement',
    'Development-only D4 valid customer dispute description',
    'd4-open-main-' || left(v_suffix, 16)
  );

  insert into customer_dispute_test_ids(fixture_key, fixture_id)
  values ('opened_dispute', v_open_result.dispute_id);

  perform pg_temp.customer_dispute_reset_context();
  perform pg_temp.customer_dispute_record_result('valid customer opens own dispute', v_open_result.created = true and v_open_result.status = 'open');
  perform pg_temp.customer_dispute_record_result('open result returns safe order reference only', v_open_result.safe_order_reference like 'D4-%' and v_open_result.safe_order_reference not like '%-%-%-%-%');
  perform pg_temp.customer_dispute_expect_count('initial dispute status is open', format('select count(*) from public.order_disputes where id = %L and status = ''open''', v_open_result.dispute_id), 1);
  perform pg_temp.customer_dispute_expect_count('initial message created once', format('select count(*) from public.dispute_messages where dispute_id = %L and author_role = ''customer'' and body = %L', v_open_result.dispute_id, 'Development-only D4 valid customer dispute description'), 1);
  perform pg_temp.customer_dispute_expect_count('initial status-history row created once', format('select count(*) from public.dispute_status_history where dispute_id = %L and previous_status is null and new_status = ''open''', v_open_result.dispute_id), 1);
  perform pg_temp.customer_dispute_expect_count('audit event created once', format('select count(*) from public.audit_logs where action = ''dispute_opened'' and target_entity_id = %L', v_open_result.dispute_id), 1);

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  select *
  into v_retry_result
  from public.customer_open_order_dispute(
    v_order_a_id,
    v_order_item_a_id,
    'delivery',
    'wrong_item_received',
    'replacement',
    'Development-only D4 valid customer dispute description',
    'd4-open-main-' || left(v_suffix, 16)
  );

  perform pg_temp.customer_dispute_reset_context();
  perform pg_temp.customer_dispute_record_result('retry with same key returns same dispute', v_retry_result.created = false and v_retry_result.dispute_id = v_open_result.dispute_id);
  perform pg_temp.customer_dispute_expect_count('retry does not duplicate initial message', format('select count(*) from public.dispute_messages where dispute_id = %L and body = %L', v_open_result.dispute_id, 'Development-only D4 valid customer dispute description'), 1);
  perform pg_temp.customer_dispute_expect_count('retry does not duplicate history', format('select count(*) from public.dispute_status_history where dispute_id = %L and new_status = ''open''', v_open_result.dispute_id), 1);
  perform pg_temp.customer_dispute_expect_count('retry does not duplicate audit', format('select count(*) from public.audit_logs where action = ''dispute_opened'' and target_entity_id = %L', v_open_result.dispute_id), 1);

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  perform pg_temp.customer_dispute_expect_blocked('same key with different payload conflicts', format(
    'select count(*) from public.customer_open_order_dispute(%L, %L, %L, %L, %L, %L, %L)',
    v_order_a_id, v_order_item_a_id, 'delivery', 'wrong_item_received', 'replacement', 'Different D4 payload should conflict', 'd4-open-main-' || left(v_suffix, 16)
  ));

  select *
  into v_retry_result
  from public.customer_open_order_dispute(
    v_order_a_id,
    v_order_item_a_id,
    'delivery',
    'wrong_item_received',
    'replacement',
    'Development-only D4 valid customer dispute description',
    'd4-open-duplicate-' || left(v_suffix, 16)
  );

  perform pg_temp.customer_dispute_reset_context();
  perform pg_temp.customer_dispute_record_result('duplicate active dispute is not duplicated', v_retry_result.created = false and v_retry_result.dispute_id = v_open_result.dispute_id);
  perform pg_temp.customer_dispute_expect_count('duplicate active fingerprint has one active case', format('select count(*) from public.order_disputes where order_id = %L and opened_by_profile_id = %L and reason_code = ''wrong_item_received'' and status not in (''closed'', ''cancelled'', ''rejected'')', v_order_a_id, v_customer_a_profile_id), 1);

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  select *
  into v_response_result
  from public.customer_add_dispute_response(
    v_open_result.dispute_id,
    'Development-only D4 customer response for open case',
    'd4-response-main-' || left(v_suffix, 16)
  );

  perform pg_temp.customer_dispute_reset_context();
  perform pg_temp.customer_dispute_record_result('valid customer response created once', v_response_result.created = true and v_response_result.status = 'open');
  perform pg_temp.customer_dispute_record_result('response result returns safe status only', v_response_result.status = 'open' and v_response_result.dispute_id = v_open_result.dispute_id);
  perform pg_temp.customer_dispute_expect_count('open-state response does not invent a status transition', format('select count(*) from public.dispute_status_history where dispute_id = %L and new_status <> ''open''', v_open_result.dispute_id), 0);
  perform pg_temp.customer_dispute_expect_count('response audit event created once', format('select count(*) from public.audit_logs where action = ''dispute_customer_response_added'' and target_entity_id = %L', v_response_result.message_id), 1);

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  select *
  into v_response_retry
  from public.customer_add_dispute_response(
    v_open_result.dispute_id,
    'Development-only D4 customer response for open case',
    'd4-response-main-' || left(v_suffix, 16)
  );

  perform pg_temp.customer_dispute_reset_context();
  perform pg_temp.customer_dispute_record_result('response retry returns same message', v_response_retry.created = false and v_response_retry.message_id = v_response_result.message_id);
  perform pg_temp.customer_dispute_expect_count('response retry does not duplicate audit', format('select count(*) from public.audit_logs where action = ''dispute_customer_response_added'' and target_entity_id = %L', v_response_result.message_id), 1);

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  perform pg_temp.customer_dispute_expect_blocked('same response key with different body conflicts', format(
    'select count(*) from public.customer_add_dispute_response(%L, %L, %L)',
    v_open_result.dispute_id, 'Different D4 response body', 'd4-response-main-' || left(v_suffix, 16)
  ));

  select *
  into v_awaiting_response
  from public.customer_add_dispute_response(
    v_awaiting_dispute_id,
    'Development-only D4 customer response for awaiting case',
    'd4-awaiting-response-' || left(v_suffix, 16)
  );

  perform pg_temp.customer_dispute_reset_context();
  perform pg_temp.customer_dispute_record_result('awaiting_customer response transitions to under_review', v_awaiting_response.created = true and v_awaiting_response.status = 'under_review');
  perform pg_temp.customer_dispute_expect_count('awaiting transition creates one status-history row', format('select count(*) from public.dispute_status_history where dispute_id = %L and previous_status = ''awaiting_customer'' and new_status = ''under_review''', v_awaiting_dispute_id), 1);
  perform pg_temp.customer_dispute_expect_count('awaiting transition clears customer_action_required', format('select count(*) from public.order_disputes where id = %L and status = ''under_review'' and customer_action_required = false', v_awaiting_dispute_id), 1);
  perform pg_temp.customer_dispute_expect_count('awaiting transition audit created once', format('select count(*) from public.audit_logs where action = ''dispute_status_changed'' and target_entity_id = %L', v_awaiting_dispute_id), 1);

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  perform pg_temp.customer_dispute_expect_blocked('response to closed dispute rejected', format(
    'select count(*) from public.customer_add_dispute_response(%L, %L, %L)',
    v_closed_dispute_id, 'D4 closed response attempt', 'd4-closed-response-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('response to rejected dispute rejected', format(
    'select count(*) from public.customer_add_dispute_response(%L, %L, %L)',
    v_rejected_dispute_id, 'D4 rejected response attempt', 'd4-rejected-response-' || left(v_suffix, 12)
  ));
  perform pg_temp.customer_dispute_expect_blocked('response to cancelled dispute rejected', format(
    'select count(*) from public.customer_add_dispute_response(%L, %L, %L)',
    v_cancelled_dispute_id, 'D4 cancelled response attempt', 'd4-cancelled-response-' || left(v_suffix, 12)
  ));

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_a_' || v_suffix);
  perform pg_temp.customer_dispute_expect_count('customer safe-read RPC shows newly created case', 'select count(*) from public.list_customer_disputes_safe() where reason_code = ''wrong_item_received''', 1);
  perform pg_temp.customer_dispute_expect_true('customer detail shows only customer-safe messages', format($sql$
    select coalesce((select messages::text from public.get_customer_dispute_safe(%L)), '') like '%%Development-only D4%%'
      and coalesce((select row_to_json(x)::text from public.get_customer_dispute_safe(%L) x), '') not like '%%internal_resolution_notes%%'
  $sql$, v_open_result.dispute_id, v_open_result.dispute_id));

  perform pg_temp.customer_dispute_set_context('dev_dispute_d4_customer_b_' || v_suffix);
  perform pg_temp.customer_dispute_expect_count('other customer cannot discover case through list', 'select count(*) from public.list_customer_disputes_safe() where reason_code = ''wrong_item_received''', 0);
  perform pg_temp.customer_dispute_expect_count('other customer cannot discover case through detail', format('select count(*) from public.get_customer_dispute_safe(%L)', v_open_result.dispute_id), 0);
  perform pg_temp.customer_dispute_expect_blocked('customer cannot respond to another customer dispute', format(
    'select count(*) from public.customer_add_dispute_response(%L, %L, %L)',
    v_open_result.dispute_id, 'D4 cross-customer response attempt', 'd4-cross-response-' || left(v_suffix, 12)
  ));

  perform pg_temp.customer_dispute_reset_context();
  perform pg_temp.customer_dispute_expect_true('no order status changes', format($sql$
    select exists (select 1 from public.orders where id = %L and order_status = 'delivered')
      and exists (select 1 from public.orders where id = %L and order_status = 'cancelled')
  $sql$, v_order_a_id, v_ineligible_order_id));
  perform pg_temp.customer_dispute_expect_true('no payment status changes', format($sql$
    select exists (select 1 from public.orders where id = %L and payment_collection_status = 'not_collected')
  $sql$, v_order_a_id));
  perform pg_temp.customer_dispute_expect_true('no settlement commission wallet withdrawal stock reservation or notification side effects', 'select pg_temp.customer_dispute_business_counts_unchanged()');
  perform pg_temp.customer_dispute_expect_count('no notification outbox event created', 'select count(*) - (select row_count from customer_dispute_business_counts where table_name = ''notification_outbox'') from public.notification_outbox', 0);
  perform pg_temp.customer_dispute_record_result('fixtures clean completely through rollback', true, 'transaction rolls back all fixture rows after result output');
end;
$$;

do $$
declare
  v_failed_count integer;
begin
  select count(*) into v_failed_count
  from customer_dispute_test_results
  where not passed;

  if v_failed_count > 0 then
    raise exception 'CUSTOMER_DISPUTE_D4_TEST_FAILED: % assertion(s) failed', v_failed_count
      using errcode = '23514';
  end if;
end;
$$;

select assertion, passed, details
from customer_dispute_test_results
order by assertion;

rollback;
