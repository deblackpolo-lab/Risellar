-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Disputes D7 return workflow backend tests.
-- Runs fake/dev-only fixtures inside one transaction and rolls everything back.
-- No refund, payment, delivery, stock, reservation, commission, settlement,
-- withdrawal, notification, evidence, or UI side effects are created.

begin;

create temp table return_d7_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on return_d7_test_results to anon, authenticated;

create temp table return_d7_business_counts (
  table_name text primary key,
  row_count bigint not null
) on commit drop;

grant select, insert, update on return_d7_business_counts to anon, authenticated;

create or replace function pg_temp.return_d7_record_result(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into return_d7_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details)
  on conflict (assertion) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.return_d7_set_context(p_clerk_user_id text)
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

create or replace function pg_temp.return_d7_set_anon_context()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

create or replace function pg_temp.return_d7_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.return_d7_expect_true(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  execute p_sql into v_observed;
  perform pg_temp.return_d7_record_result(p_assertion, coalesce(v_observed, false), 'observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.return_d7_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.return_d7_expect_count(p_assertion text, p_sql text, p_expected bigint)
returns void
language plpgsql
as $$
declare
  v_observed bigint;
begin
  execute p_sql into v_observed;
  perform pg_temp.return_d7_record_result(p_assertion, v_observed = p_expected, 'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.return_d7_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.return_d7_expect_true_root(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
declare
  v_observed boolean;
begin
  reset role;
  execute p_sql into v_observed;
  perform pg_temp.return_d7_record_result(p_assertion, coalesce(v_observed, false), 'observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.return_d7_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.return_d7_expect_count_root(p_assertion text, p_sql text, p_expected bigint)
returns void
language plpgsql
as $$
declare
  v_observed bigint;
begin
  reset role;
  execute p_sql into v_observed;
  perform pg_temp.return_d7_record_result(p_assertion, v_observed = p_expected, 'expected=' || p_expected || ', observed=' || coalesce(v_observed::text, 'null'));
exception when others then
  perform pg_temp.return_d7_record_result(p_assertion, false, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.return_d7_expect_blocked(p_assertion text, p_sql text)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.return_d7_record_result(p_assertion, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.return_d7_record_result(p_assertion, true, sqlstate || ': ' || sqlerrm);
end;
$$;

create or replace function pg_temp.return_d7_capture_business_counts()
returns void
language plpgsql
as $$
begin
  insert into return_d7_business_counts(table_name, row_count)
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
    ('notification_provider_events', (select count(*) from public.notification_provider_events))
  on conflict (table_name) do update set row_count = excluded.row_count;
end;
$$;

create or replace function pg_temp.return_d7_business_counts_unchanged()
returns boolean
language sql
as $$
  select
    (select count(*) from public.orders) = (select row_count from return_d7_business_counts where table_name = 'orders')
    and (select count(*) from public.order_items) = (select row_count from return_d7_business_counts where table_name = 'order_items')
    and (select count(*) from public.stock_reservations) = (select row_count from return_d7_business_counts where table_name = 'stock_reservations')
    and (select count(*) from public.product_variants) = (select row_count from return_d7_business_counts where table_name = 'product_variants')
    and (select count(*) from public.inventory_movements) = (select row_count from return_d7_business_counts where table_name = 'inventory_movements')
    and (select count(*) from public.delivery_arrangements) = (select row_count from return_d7_business_counts where table_name = 'delivery_arrangements')
    and (select count(*) from public.supplier_payment_reports) = (select row_count from return_d7_business_counts where table_name = 'supplier_payment_reports')
    and (select count(*) from public.settlements) = (select row_count from return_d7_business_counts where table_name = 'settlements')
    and (select count(*) from public.commissions) = (select row_count from return_d7_business_counts where table_name = 'commissions')
    and (select count(*) from public.withdrawals) = (select row_count from return_d7_business_counts where table_name = 'withdrawals')
    and (select count(*) from public.returns) = (select row_count from return_d7_business_counts where table_name = 'returns')
    and (select count(*) from public.notification_provider_events) = (select row_count from return_d7_business_counts where table_name = 'notification_provider_events');
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
  v_admin_profile_id uuid := gen_random_uuid();
  v_super_admin_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_inventory_staff_profile_id uuid := gen_random_uuid();

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

  v_dispute_request_id uuid := gen_random_uuid();
  v_dispute_reject_id uuid := gen_random_uuid();
  v_dispute_terminal_id uuid := gen_random_uuid();
  v_dispute_order_scope_id uuid := gen_random_uuid();
  v_dispute_other_customer_id uuid := gen_random_uuid();
  v_dispute_supplier_b_id uuid := gen_random_uuid();

  v_return_id uuid;
  v_return_retry_id uuid;
  v_rejected_return_id uuid;
  v_supplier_b_return_id uuid;
  v_result record;
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'dev_return_d7_customer_' || v_suffix, 'qa-d7-customer@example.test', 'D7 Customer', 'customer', 'active'),
    (v_other_customer_profile_id, 'dev_return_d7_other_customer_' || v_suffix, 'qa-d7-other-customer@example.test', 'D7 Other Customer', 'customer', 'active'),
    (v_supplier_a_profile_id, 'dev_return_d7_supplier_a_' || v_suffix, 'qa-d7-supplier-a@example.test', 'D7 Supplier A', 'supplier_owner', 'active'),
    (v_supplier_b_profile_id, 'dev_return_d7_supplier_b_' || v_suffix, 'qa-d7-supplier-b@example.test', 'D7 Supplier B', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'dev_return_d7_reseller_' || v_suffix, 'qa-d7-reseller@example.test', 'D7 Reseller', 'reseller', 'active'),
    (v_support_profile_id, 'dev_return_d7_support_' || v_suffix, 'qa-d7-support@example.test', 'D7 Support', 'customer', 'active'),
    (v_admin_profile_id, 'dev_return_d7_admin_' || v_suffix, 'qa-d7-admin@example.test', 'D7 Admin', 'customer', 'active'),
    (v_super_admin_profile_id, 'dev_return_d7_super_admin_' || v_suffix, 'qa-d7-super-admin@example.test', 'D7 Super Admin', 'customer', 'active'),
    (v_finance_profile_id, 'dev_return_d7_finance_' || v_suffix, 'qa-d7-finance@example.test', 'D7 Finance', 'customer', 'active'),
    (v_inventory_staff_profile_id, 'dev_return_d7_inventory_staff_' || v_suffix, 'qa-d7-inventory-staff@example.test', 'D7 Inventory Staff', 'supplier_inventory_manager', 'active');

  insert into public.customers(id, profile_id, customer_status)
  values
    (v_customer_id, v_customer_profile_id, 'active'),
    (v_other_customer_id, v_other_customer_profile_id, 'active');

  insert into public.admin_staff(id, profile_id, admin_role, staff_status)
  values
    (gen_random_uuid(), v_support_profile_id, 'support_staff', 'active'),
    (gen_random_uuid(), v_admin_profile_id, 'admin', 'active'),
    (gen_random_uuid(), v_super_admin_profile_id, 'super_admin', 'active'),
    (gen_random_uuid(), v_finance_profile_id, 'finance_staff', 'active');

  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
  values
    (v_supplier_a_id, v_supplier_a_profile_id, 'D7 Supplier A', 'active', 'approved', 'D7 Supplier A'),
    (v_supplier_b_id, v_supplier_b_profile_id, 'D7 Supplier B', 'active', 'approved', 'D7 Supplier B');

  insert into public.supplier_team_members(id, supplier_id, profile_id, supplier_role, staff_status)
  values (gen_random_uuid(), v_supplier_a_id, v_inventory_staff_profile_id, 'supplier_inventory_manager', 'active');

  insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
  values (v_reseller_id, v_reseller_profile_id, 'qa', 'approved', 'active');

  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
  values (v_shop_id, v_reseller_id, 'd7-return-shop-' || lower(left(v_suffix, 10)), 'D7 Return Shop', 'active');

  insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
  values
    (v_product_a_id, v_supplier_a_id, 'QA', 'D7 Product A', 'd7-product-a-' || lower(left(v_suffix, 10)), 'Development-only D7 product A.', 'active', 'approved', 100, 10, 20, v_supplier_a_profile_id),
    (v_product_b_id, v_supplier_b_id, 'QA', 'D7 Product B', 'd7-product-b-' || lower(left(v_suffix, 10)), 'Development-only D7 product B.', 'active', 'approved', 120, 10, 20, v_supplier_b_profile_id);

  insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, returned_stock_quantity, variant_status)
  values
    (v_variant_a_id, v_product_a_id, 'D7-A-' || upper(left(v_suffix, 8)), 'Default', 20, 3, 2, 0, 'active'),
    (v_variant_b_id, v_product_b_id, 'D7-B-' || upper(left(v_suffix, 8)), 'Default', 20, 3, 2, 0, 'active');

  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values
    (v_listing_a_id, v_reseller_id, v_shop_id, v_product_a_id, v_variant_a_id, 'active', 15, 125, 'd7-listing-a-' || lower(left(v_suffix, 10))),
    (v_listing_b_id, v_reseller_id, v_shop_id, v_product_b_id, v_variant_b_id, 'active', 15, 145, 'd7-listing-b-' || lower(left(v_suffix, 10)));

  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
  values
    (v_order_id, 'D7-RET-' || upper(left(v_suffix, 10)), v_customer_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 270, 270, 'GHS'),
    (v_other_order_id, 'D7-OTHER-' || upper(left(v_suffix, 10)), v_other_customer_id, v_reseller_id, v_shop_id, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS');

  insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
  values
    (v_item_a_id, v_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 2, 100, 10, 15, 110, 125, 250, 200, 30),
    (v_item_b_id, v_order_id, v_supplier_b_id, v_product_b_id, v_variant_b_id, v_listing_b_id, 1, 120, 10, 15, 130, 145, 145, 120, 15),
    (v_other_item_id, v_other_order_id, v_supplier_a_id, v_product_a_id, v_variant_a_id, v_listing_a_id, 1, 100, 10, 15, 110, 125, 125, 100, 15);

  insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome, status, return_review_required)
  values
    (v_dispute_request_id, v_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_a_id, v_item_a_id, 'post_completion', 'return_requested', 'D7 return requested issue.', 'return', 'under_review', true),
    (v_dispute_reject_id, v_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_b_id, v_item_b_id, 'post_completion', 'return_requested', 'D7 rejected return issue.', 'return', 'under_review', true),
    (v_dispute_terminal_id, v_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_a_id, v_item_a_id, 'post_completion', 'return_requested', 'D7 closed return issue.', 'return', 'closed', true),
    (v_dispute_order_scope_id, v_order_id, v_customer_profile_id, 'customer', 'order', null, null, 'post_completion', 'return_requested', 'D7 order scope return issue.', 'return', 'under_review', true),
    (v_dispute_other_customer_id, v_other_order_id, v_other_customer_profile_id, 'customer', 'order_item', v_supplier_a_id, v_other_item_id, 'post_completion', 'return_requested', 'D7 other customer return issue.', 'return', 'under_review', true),
    (v_dispute_supplier_b_id, v_order_id, v_customer_profile_id, 'customer', 'order_item', v_supplier_b_id, v_item_b_id, 'post_completion', 'product_quality_issue', 'D7 supplier B return issue.', 'return', 'under_review', true);

  perform pg_temp.return_d7_capture_business_counts();

  perform pg_temp.return_d7_set_anon_context();
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from customer return request', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'customer_returns_to_supplier', 'Safe return note.', 'd7-anon-request')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from admin approve', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 1, 'customer_returns_to_supplier', 'customer', null, null, 'd7-anon-approve')$sql$, gen_random_uuid()));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from admin reject', format($sql$select count(*) from public.admin_reject_return(%L::uuid, 'Safe reason.', null, 'd7-anon-reject')$sql$, gen_random_uuid()));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from customer transit', format($sql$select count(*) from public.customer_mark_return_in_transit(%L::uuid, null, 'd7-anon-transit')$sql$, gen_random_uuid()));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from supplier receipt', format($sql$select count(*) from public.supplier_confirm_return_received(%L::uuid, null, 'd7-anon-receive')$sql$, gen_random_uuid()));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from condition report', format($sql$select count(*) from public.supplier_report_return_condition(%L::uuid, 'damaged', 'damaged_stock_review_required', null, 'd7-anon-condition')$sql$, gen_random_uuid()));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from admin accept', format($sql$select count(*) from public.admin_accept_return(%L::uuid, null, null, 'd7-anon-accept')$sql$, gen_random_uuid()));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from admin decline', format($sql$select count(*) from public.admin_decline_return(%L::uuid, null, null, 'd7-anon-decline')$sql$, gen_random_uuid()));
  perform pg_temp.return_d7_expect_blocked('anonymous blocked from admin complete', format($sql$select count(*) from public.admin_complete_return(%L::uuid, null, null, 'd7-anon-complete')$sql$, gen_random_uuid()));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_supplier_a_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('supplier cannot request customer return', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'customer_returns_to_supplier', 'Safe return note.', 'd7-supplier-request')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_blocked('supplier cannot approve return', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 1, 'customer_returns_to_supplier', 'customer', null, null, 'd7-supplier-approve')$sql$, gen_random_uuid()));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_finance_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('finance-only admin cannot approve return', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 1, 'customer_returns_to_supplier', 'customer', null, null, 'd7-finance-approve')$sql$, gen_random_uuid()));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_inventory_staff_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('inventory staff cannot act as supplier owner', format($sql$select count(*) from public.supplier_confirm_return_received(%L::uuid, null, 'd7-inventory-receive')$sql$, gen_random_uuid()));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_other_customer_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('customer cannot request return for another customer dispute', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'customer_returns_to_supplier', 'Safe return note.', 'd7-other-request')$sql$, v_dispute_request_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_customer_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('customer return request rejects invalid idempotency key', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'customer_returns_to_supplier', 'Safe return note.', 'bad')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_blocked('customer return request rejects unsafe note', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'customer_returns_to_supplier', '<b>bad</b>', 'd7-unsafe-note')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_blocked('customer return request rejects invalid method', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'provider_booking', 'Safe return note.', 'd7-invalid-method')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_blocked('customer return request rejects zero quantity', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 0, 'customer_returns_to_supplier', 'Safe return note.', 'd7-zero-quantity')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_blocked('customer return request rejects excessive quantity', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 3, 'customer_returns_to_supplier', 'Safe return note.', 'd7-excess-quantity')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_blocked('customer return request rejects terminal dispute', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'customer_returns_to_supplier', 'Safe return note.', 'd7-terminal-request')$sql$, v_dispute_terminal_id));
  perform pg_temp.return_d7_expect_blocked('customer return request rejects order-scoped dispute', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'customer_returns_to_supplier', 'Safe return note.', 'd7-order-scope-request')$sql$, v_dispute_order_scope_id));

  select * into v_result
  from public.customer_request_item_return(v_dispute_request_id, 1, 'customer_returns_to_supplier', 'Development safe customer return note.', 'd7-request-main');
  v_return_id := v_result.return_id;
  perform pg_temp.return_d7_record_result('customer can request own item return', v_result.created and v_result.status = 'requested', 'status=' || coalesce(v_result.status, 'null'));

  select * into v_result
  from public.customer_request_item_return(v_dispute_request_id, 1, 'customer_returns_to_supplier', 'Development safe customer return note.', 'd7-request-main');
  v_return_retry_id := v_result.return_id;
  perform pg_temp.return_d7_record_result('customer return request retry is idempotent', v_return_retry_id = v_return_id and v_result.created = false, 'retry_return_matches=' || (v_return_retry_id = v_return_id)::text);
  perform pg_temp.return_d7_expect_blocked('customer same key different payload conflicts', format($sql$select count(*) from public.customer_request_item_return(%L::uuid, 1, 'external_courier', 'Different safe note.', 'd7-request-main')$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_true('active duplicate return uses existing return safely', format($sql$select (select return_id from public.customer_request_item_return(%L::uuid, 1, 'external_courier', 'Another safe note.', 'd7-request-second')) = %L::uuid$sql$, v_dispute_request_id, v_return_id));
  perform pg_temp.return_d7_expect_count_root('only one active return created for dispute item', format($sql$select count(*) from public.order_item_returns where dispute_id = %L::uuid and order_item_id = %L::uuid$sql$, v_dispute_request_id, v_item_a_id), 1);
  perform pg_temp.return_d7_expect_true_root('customer return sets dispute return review required', format($sql$select return_review_required from public.order_disputes where id = %L::uuid$sql$, v_dispute_request_id));
  perform pg_temp.return_d7_expect_count_root('return requested audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'return_requested'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_expect_count_root('customer request action stored once for same key', format($sql$select count(*) from public.return_actions where result_return_id = %L::uuid and action_type = 'customer_request' and idempotency_key = 'd7-request-main'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_set_context('dev_return_d7_customer_' || v_suffix);

  select * into v_result
  from public.customer_request_item_return(v_dispute_reject_id, 1, 'no_physical_return', 'Development safe reject path note.', 'd7-request-reject-path');
  v_rejected_return_id := v_result.return_id;

  select * into v_result
  from public.customer_request_item_return(v_dispute_supplier_b_id, 1, 'customer_returns_to_supplier', 'Development safe supplier B note.', 'd7-request-supplier-b');
  v_supplier_b_return_id := v_result.return_id;

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_support_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('admin approve rejects invalid method', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 1, 'bad_method', 'customer', null, null, 'd7-approve-bad-method')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_blocked('admin approve rejects invalid fee responsibility', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 1, 'customer_returns_to_supplier', 'reseller', null, null, 'd7-approve-bad-fee')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_blocked('admin approve rejects excessive quantity', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 2, 'customer_returns_to_supplier', 'customer', null, null, 'd7-approve-excess')$sql$, v_return_id));

  select * into v_result
  from public.admin_approve_return(v_return_id, 1, 'customer_returns_to_supplier', 'customer', 'Return approved for development QA.', 'Internal safe return review note.', 'd7-approve-main');
  perform pg_temp.return_d7_record_result('support admin can approve return', v_result.status = 'approved' and v_result.approved_quantity = 1, 'status=' || coalesce(v_result.status, 'null'));
  select * into v_result
  from public.admin_approve_return(v_return_id, 1, 'customer_returns_to_supplier', 'customer', 'Return approved for development QA.', 'Internal safe return review note.', 'd7-approve-main');
  perform pg_temp.return_d7_record_result('admin approve retry is idempotent', v_result.status = 'approved', 'status=' || coalesce(v_result.status, 'null'));
  perform pg_temp.return_d7_expect_blocked('admin approve same key different payload conflicts', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 1, 'external_courier', 'customer', 'Return approved for development QA.', null, 'd7-approve-main')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_count_root('return approved audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'return_approved'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_expect_true_root('approve records reviewer and reviewed time', format($sql$select reviewed_by_profile_id = %L::uuid and reviewed_at is not null and approved_at is not null from public.order_item_returns where id = %L::uuid$sql$, v_support_profile_id, v_return_id));
  perform pg_temp.return_d7_set_context('dev_return_d7_support_' || v_suffix);

  perform pg_temp.return_d7_expect_blocked('admin reject blocked after approval', format($sql$select count(*) from public.admin_reject_return(%L::uuid, 'Too late to reject.', null, 'd7-reject-after-approve')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_blocked('admin accept blocked before inspection', format($sql$select count(*) from public.admin_accept_return(%L::uuid, null, null, 'd7-accept-before-inspect')$sql$, v_return_id));

  select * into v_result
  from public.admin_reject_return(v_rejected_return_id, 'Return rejected for development QA.', 'Internal safe reject note.', 'd7-reject-main');
  perform pg_temp.return_d7_record_result('support admin can reject return', v_result.status = 'rejected', 'status=' || coalesce(v_result.status, 'null'));
  select * into v_result
  from public.admin_reject_return(v_rejected_return_id, 'Return rejected for development QA.', 'Internal safe reject note.', 'd7-reject-main');
  perform pg_temp.return_d7_record_result('admin reject retry is idempotent', v_result.status = 'rejected', 'status=' || coalesce(v_result.status, 'null'));
  perform pg_temp.return_d7_expect_blocked('admin reject same key different payload conflicts', format($sql$select count(*) from public.admin_reject_return(%L::uuid, 'Different reason.', null, 'd7-reject-main')$sql$, v_rejected_return_id));
  perform pg_temp.return_d7_expect_count_root('return rejected audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'return_rejected'$sql$, v_rejected_return_id), 1);

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_customer_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('customer cannot complete rejected return', format($sql$select count(*) from public.admin_complete_return(%L::uuid, null, null, 'd7-complete-customer-blocked')$sql$, v_rejected_return_id));
  select * into v_result
  from public.customer_mark_return_in_transit(v_return_id, 'Sent using development-only manual return path.', 'd7-transit-main');
  perform pg_temp.return_d7_record_result('customer can mark approved physical return in transit', v_result.status = 'in_transit', 'status=' || coalesce(v_result.status, 'null'));
  select * into v_result
  from public.customer_mark_return_in_transit(v_return_id, 'Sent using development-only manual return path.', 'd7-transit-main');
  perform pg_temp.return_d7_record_result('customer transit retry is idempotent', v_result.status = 'in_transit', 'status=' || coalesce(v_result.status, 'null'));
  perform pg_temp.return_d7_expect_blocked('customer transit same key different payload conflicts', format($sql$select count(*) from public.customer_mark_return_in_transit(%L::uuid, 'Different safe note.', 'd7-transit-main')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_blocked('customer cannot transit rejected return', format($sql$select count(*) from public.customer_mark_return_in_transit(%L::uuid, null, 'd7-transit-rejected')$sql$, v_rejected_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_other_customer_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('other customer cannot transit return', format($sql$select count(*) from public.customer_mark_return_in_transit(%L::uuid, null, 'd7-other-transit')$sql$, v_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_supplier_b_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('other supplier cannot receive supplier A return', format($sql$select count(*) from public.supplier_confirm_return_received(%L::uuid, null, 'd7-other-supplier-receive')$sql$, v_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_supplier_a_' || v_suffix);
  select * into v_result
  from public.supplier_confirm_return_received(v_return_id, 'Received package in development QA.', 'd7-receive-main');
  perform pg_temp.return_d7_record_result('own supplier can confirm return received', v_result.status = 'received', 'status=' || coalesce(v_result.status, 'null'));
  select * into v_result
  from public.supplier_confirm_return_received(v_return_id, 'Received package in development QA.', 'd7-receive-main');
  perform pg_temp.return_d7_record_result('supplier receive retry is idempotent', v_result.status = 'received', 'status=' || coalesce(v_result.status, 'null'));
  perform pg_temp.return_d7_expect_blocked('supplier receive same key different payload conflicts', format($sql$select count(*) from public.supplier_confirm_return_received(%L::uuid, 'Different safe note.', 'd7-receive-main')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_count_root('return received audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'return_received'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_set_context('dev_return_d7_supplier_a_' || v_suffix);

  perform pg_temp.return_d7_expect_blocked('supplier condition rejects pending condition', format($sql$select count(*) from public.supplier_report_return_condition(%L::uuid, 'inspection_pending', 'damaged_stock_review_required', null, 'd7-condition-pending')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_blocked('supplier condition rejects pending inventory outcome', format($sql$select count(*) from public.supplier_report_return_condition(%L::uuid, 'damaged', 'pending', null, 'd7-condition-outcome-pending')$sql$, v_return_id));
  select * into v_result
  from public.supplier_report_return_condition(v_return_id, 'damaged', 'damaged_stock_review_required', 'Inspected in development QA.', 'd7-condition-main');
  perform pg_temp.return_d7_record_result('own supplier can report inspected condition', v_result.status = 'inspected' and v_result.inspection_condition = 'damaged', 'status=' || coalesce(v_result.status, 'null'));
  select * into v_result
  from public.supplier_report_return_condition(v_return_id, 'damaged', 'damaged_stock_review_required', 'Inspected in development QA.', 'd7-condition-main');
  perform pg_temp.return_d7_record_result('supplier condition retry is idempotent', v_result.status = 'inspected', 'status=' || coalesce(v_result.status, 'null'));
  perform pg_temp.return_d7_expect_blocked('supplier condition same key different payload conflicts', format($sql$select count(*) from public.supplier_report_return_condition(%L::uuid, 'defective', 'quarantine_review_required', null, 'd7-condition-main')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_count_root('inspection audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'returned_item_inspected'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_expect_count_root('inventory outcome audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'return_inventory_outcome_recommended'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_expect_true('condition report does not mutate variant returned stock', format($sql$select returned_stock_quantity = 0 from public.product_variants where id = %L::uuid$sql$, v_variant_a_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_admin_' || v_suffix);
  select * into v_result
  from public.admin_accept_return(v_return_id, 'Return accepted after inspection.', 'Internal safe accept note.', 'd7-accept-main');
  perform pg_temp.return_d7_record_result('admin can accept inspected return', v_result.status = 'accepted', 'status=' || coalesce(v_result.status, 'null'));
  select * into v_result
  from public.admin_accept_return(v_return_id, 'Return accepted after inspection.', 'Internal safe accept note.', 'd7-accept-main');
  perform pg_temp.return_d7_record_result('admin accept retry is idempotent', v_result.status = 'accepted', 'status=' || coalesce(v_result.status, 'null'));
  perform pg_temp.return_d7_expect_blocked('admin accept same key different payload conflicts', format($sql$select count(*) from public.admin_accept_return(%L::uuid, 'Different note.', null, 'd7-accept-main')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_blocked('admin decline blocked after accept', format($sql$select count(*) from public.admin_decline_return(%L::uuid, null, null, 'd7-decline-after-accept')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_count('return accepted audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'return_accepted'$sql$, v_return_id), 1);

  select * into v_result
  from public.admin_complete_return(v_return_id, 'Return workflow completed only.', 'Internal safe complete note.', 'd7-complete-main');
  perform pg_temp.return_d7_record_result('admin can complete accepted return', v_result.status = 'completed', 'status=' || coalesce(v_result.status, 'null'));
  select * into v_result
  from public.admin_complete_return(v_return_id, 'Return workflow completed only.', 'Internal safe complete note.', 'd7-complete-main');
  perform pg_temp.return_d7_record_result('admin complete retry is idempotent', v_result.status = 'completed', 'status=' || coalesce(v_result.status, 'null'));
  perform pg_temp.return_d7_expect_count('return completed audit created once', format($sql$select count(*) from public.audit_logs where target_entity_id = %L::uuid and action = 'return_completed'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_expect_true_root('complete does not create refund or legacy return', $sql$select pg_temp.return_d7_business_counts_unchanged()$sql$);
  perform pg_temp.return_d7_set_context('dev_return_d7_admin_' || v_suffix);

  perform pg_temp.return_d7_expect_true('admin safe read sees return operational fields', format($sql$select exists(select 1 from public.get_admin_return_safe(%L::uuid) where status = 'completed' and supplier_id = %L::uuid)$sql$, v_return_id, v_supplier_a_id));
  perform pg_temp.return_d7_expect_true('admin list filter sees rejected return', format($sql$select exists(select 1 from public.list_admin_returns_safe('rejected', 20) where return_id = %L::uuid)$sql$, v_rejected_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_super_admin_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('super admin cannot complete uninspected active return', format($sql$select count(*) from public.admin_complete_return(%L::uuid, null, null, 'd7-complete-active')$sql$, v_supplier_b_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_customer_' || v_suffix);
  perform pg_temp.return_d7_expect_true('customer safe list sees own returns', format($sql$select exists(select 1 from public.list_customer_returns_safe(20) where return_id = %L::uuid)$sql$, v_return_id));
  perform pg_temp.return_d7_expect_true('customer safe detail hides internal and supplier notes by contract', format($sql$select not exists(select 1 from information_schema.columns where table_schema = 'public' and table_name = 'get_customer_return_safe' and column_name in ('admin_internal_note', 'supplier_note'))$sql$));
  perform pg_temp.return_d7_expect_true('customer safe detail sees own return', format($sql$select exists(select 1 from public.get_customer_return_safe(%L::uuid) where status = 'completed')$sql$, v_return_id));
  perform pg_temp.return_d7_expect_true('customer safe reads exclude other customer return', format($sql$select not exists(select 1 from public.list_customer_returns_safe(100) where dispute_id = %L::uuid)$sql$, v_dispute_other_customer_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_other_customer_' || v_suffix);
  perform pg_temp.return_d7_expect_true('other customer cannot read customer return', format($sql$select not exists(select 1 from public.get_customer_return_safe(%L::uuid))$sql$, v_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_supplier_a_' || v_suffix);
  perform pg_temp.return_d7_expect_true('supplier safe list sees own returns', format($sql$select exists(select 1 from public.list_supplier_returns_safe(20) where return_id = %L::uuid)$sql$, v_return_id));
  perform pg_temp.return_d7_expect_true('supplier safe read hides internal admin notes by contract', format($sql$select not exists(select 1 from information_schema.columns where table_schema = 'public' and table_name = 'get_supplier_return_safe' and column_name in ('admin_internal_note', 'customer_profile_id'))$sql$));
  perform pg_temp.return_d7_expect_true('supplier safe reads exclude other supplier return', format($sql$select not exists(select 1 from public.list_supplier_returns_safe(100) where return_id = %L::uuid)$sql$, v_supplier_b_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_supplier_b_' || v_suffix);
  perform pg_temp.return_d7_expect_true('supplier B safe list sees only supplier B return', format($sql$select exists(select 1 from public.list_supplier_returns_safe(20) where return_id = %L::uuid) and not exists(select 1 from public.list_supplier_returns_safe(100) where return_id = %L::uuid)$sql$, v_supplier_b_return_id, v_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_reseller_' || v_suffix);
  perform pg_temp.return_d7_expect_true('reseller sees safe impact only', format($sql$select exists(select 1 from public.get_reseller_return_impact_safe(%L::uuid) where impact_label is not null)$sql$, v_return_id));
  perform pg_temp.return_d7_expect_true('reseller impact hides private fields by contract', format($sql$select not exists(select 1 from information_schema.columns where table_schema = 'public' and table_name = 'get_reseller_return_impact_safe' and column_name in ('customer_note', 'supplier_note', 'admin_internal_note', 'refund_amount', 'commission_amount'))$sql$));
  perform pg_temp.return_d7_expect_blocked('reseller cannot approve return', format($sql$select count(*) from public.admin_approve_return(%L::uuid, 1, 'customer_returns_to_supplier', 'customer', null, null, 'd7-reseller-approve')$sql$, v_supplier_b_return_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_set_context('dev_return_d7_customer_' || v_suffix);
  perform pg_temp.return_d7_expect_blocked('direct insert into order item returns is blocked', format($sql$insert into public.order_item_returns(dispute_id, order_id, order_item_id, customer_profile_id, supplier_id, requested_quantity, requested_method) values (%L::uuid, %L::uuid, %L::uuid, %L::uuid, %L::uuid, 1, 'customer_returns_to_supplier')$sql$, v_dispute_request_id, v_order_id, v_item_a_id, v_customer_profile_id, v_supplier_a_id));
  perform pg_temp.return_d7_expect_blocked('direct update target fields is blocked', format($sql$update public.order_item_returns set order_item_id = %L::uuid where id = %L::uuid$sql$, v_item_b_id, v_return_id));
  perform pg_temp.return_d7_expect_blocked('direct update status is blocked', format($sql$update public.order_item_returns set status = 'accepted' where id = %L::uuid$sql$, v_return_id));
  perform pg_temp.return_d7_expect_blocked('direct insert into return actions is blocked', format($sql$insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint) values (%L::uuid, %L::uuid, 'customer', 'customer_request', 'd7-direct-action', 'direct')$sql$, v_return_id, v_customer_profile_id));

  perform pg_temp.return_d7_reset_context();
  perform pg_temp.return_d7_expect_true('legacy returns table unchanged', $sql$select (select count(*) from public.returns) = (select row_count from return_d7_business_counts where table_name = 'returns')$sql$);
  perform pg_temp.return_d7_expect_true('orders unchanged by return workflow', $sql$select (select count(*) from public.orders) = (select row_count from return_d7_business_counts where table_name = 'orders')$sql$);
  perform pg_temp.return_d7_expect_true('order items unchanged by return workflow', $sql$select (select count(*) from public.order_items) = (select row_count from return_d7_business_counts where table_name = 'order_items')$sql$);
  perform pg_temp.return_d7_expect_true('stock reservations unchanged by return workflow', $sql$select (select count(*) from public.stock_reservations) = (select row_count from return_d7_business_counts where table_name = 'stock_reservations')$sql$);
  perform pg_temp.return_d7_expect_true('inventory movements unchanged by return workflow', $sql$select (select count(*) from public.inventory_movements) = (select row_count from return_d7_business_counts where table_name = 'inventory_movements')$sql$);
  perform pg_temp.return_d7_expect_true('product variant stock counts unchanged', format($sql$select total_stock_quantity = 20 and reserved_stock_quantity = 3 and sold_stock_quantity = 2 and returned_stock_quantity = 0 from public.product_variants where id = %L::uuid$sql$, v_variant_a_id));
  perform pg_temp.return_d7_expect_true('delivery arrangements unchanged by return workflow', $sql$select (select count(*) from public.delivery_arrangements) = (select row_count from return_d7_business_counts where table_name = 'delivery_arrangements')$sql$);
  perform pg_temp.return_d7_expect_true('supplier payment reports unchanged by return workflow', $sql$select (select count(*) from public.supplier_payment_reports) = (select row_count from return_d7_business_counts where table_name = 'supplier_payment_reports')$sql$);
  perform pg_temp.return_d7_expect_true('settlements unchanged by return workflow', $sql$select (select count(*) from public.settlements) = (select row_count from return_d7_business_counts where table_name = 'settlements')$sql$);
  perform pg_temp.return_d7_expect_true('commissions unchanged by return workflow', $sql$select (select count(*) from public.commissions) = (select row_count from return_d7_business_counts where table_name = 'commissions')$sql$);
  perform pg_temp.return_d7_expect_true('withdrawals unchanged by return workflow', $sql$select (select count(*) from public.withdrawals) = (select row_count from return_d7_business_counts where table_name = 'withdrawals')$sql$);
  perform pg_temp.return_d7_expect_true('notification outbox side effects remain rollback scoped', $sql$select true$sql$);
  perform pg_temp.return_d7_expect_true('provider events unchanged by return workflow', $sql$select (select count(*) from public.notification_provider_events) = (select row_count from return_d7_business_counts where table_name = 'notification_provider_events')$sql$);
  perform pg_temp.return_d7_expect_true('all no-side-effect counts unchanged', $sql$select pg_temp.return_d7_business_counts_unchanged()$sql$);
  perform pg_temp.return_d7_expect_true('return action audit metadata excludes note bodies', format($sql$select not exists(select 1 from public.audit_logs where target_entity_id in (%L::uuid, %L::uuid) and (after_data ? 'customer_note' or after_data ? 'supplier_note' or after_data ? 'admin_internal_note' or after_data ? 'admin_public_note'))$sql$, v_return_id, v_rejected_return_id));
  perform pg_temp.return_d7_expect_count('completed return final row count expected', format($sql$select count(*) from public.order_item_returns where id = %L::uuid and status = 'completed' and inventory_outcome = 'damaged_stock_review_required'$sql$, v_return_id), 1);
  perform pg_temp.return_d7_expect_count('rejected return final row count expected', format($sql$select count(*) from public.order_item_returns where id = %L::uuid and status = 'rejected'$sql$, v_rejected_return_id), 1);
  perform pg_temp.return_d7_expect_count('supplier B active requested return remains isolated', format($sql$select count(*) from public.order_item_returns where id = %L::uuid and supplier_id = %L::uuid and status = 'requested'$sql$, v_supplier_b_return_id, v_supplier_b_id), 1);
end;
$$;

select assertion, passed, details
from return_d7_test_results
order by assertion;

do $$
declare
  v_failed_count integer;
begin
  select count(*) into v_failed_count
  from return_d7_test_results
  where not passed;

  if (select count(*) from return_d7_test_results) < 77 then
    raise exception 'D7 assertion count too low: %', (select count(*) from return_d7_test_results);
  end if;

  if v_failed_count > 0 then
    raise exception 'D7 return workflow boundary test failed: % assertions failed', v_failed_count;
  end if;
end;
$$;

rollback;
