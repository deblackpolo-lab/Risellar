-- D11 development-only transactional notification boundary tests.
-- Uses rollback-scoped fake fixtures only. Does not send provider emails.

begin;

create temp table d11_notification_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

do $d11$
declare
  v_customer_profile uuid := gen_random_uuid();
  v_supplier_profile_a uuid := gen_random_uuid();
  v_supplier_profile_b uuid := gen_random_uuid();
  v_reseller_profile_a uuid := gen_random_uuid();
  v_reseller_profile_b uuid := gen_random_uuid();
  v_support_profile uuid := gen_random_uuid();
  v_finance_profile uuid := gen_random_uuid();
  v_inactive_profile uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();
  v_supplier_a uuid := gen_random_uuid();
  v_supplier_b uuid := gen_random_uuid();
  v_reseller_a uuid := gen_random_uuid();
  v_reseller_b uuid := gen_random_uuid();
  v_shop_id uuid := gen_random_uuid();
  v_product_a uuid := gen_random_uuid();
  v_product_b uuid := gen_random_uuid();
  v_variant_a uuid := gen_random_uuid();
  v_variant_b uuid := gen_random_uuid();
  v_listing_a uuid := gen_random_uuid();
  v_order_id uuid := gen_random_uuid();
  v_order_item_a uuid := gen_random_uuid();
  v_order_item_b uuid := gen_random_uuid();
  v_commission_id uuid := gen_random_uuid();
  v_settlement_id uuid := gen_random_uuid();
  v_withdrawal_id uuid := gen_random_uuid();
  v_dispute_id uuid := gen_random_uuid();
  v_order_wide_dispute_id uuid := gen_random_uuid();
  v_return_id uuid := gen_random_uuid();
  v_refund_supplier_id uuid := gen_random_uuid();
  v_refund_platform_id uuid := gen_random_uuid();
  v_hold_commission_id uuid := gen_random_uuid();
  v_hold_supplier_id uuid := gen_random_uuid();
  v_hold_withdrawal_id uuid := gen_random_uuid();
  v_liability_id uuid := gen_random_uuid();
  v_recovery_id uuid := gen_random_uuid();
  v_allocation_id uuid := gen_random_uuid();
  v_before jsonb;
  v_after jsonb;
  v_audit_id uuid;
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile, 'd11-customer', 'd11-customer@example.test', 'D11 Customer', 'customer', 'active'),
    (v_supplier_profile_a, 'd11-supplier-a', 'd11-supplier-a@example.test', 'D11 Supplier A', 'customer', 'active'),
    (v_supplier_profile_b, 'd11-supplier-b', 'd11-supplier-b@example.test', 'D11 Supplier B', 'customer', 'active'),
    (v_reseller_profile_a, 'd11-reseller-a', 'd11-reseller-a@example.test', 'D11 Reseller A', 'customer', 'active'),
    (v_reseller_profile_b, 'd11-reseller-b', 'd11-reseller-b@example.test', 'D11 Reseller B', 'customer', 'active'),
    (v_support_profile, 'd11-support', 'd11-support@example.test', 'D11 Support', 'customer', 'active'),
    (v_finance_profile, 'd11-finance', 'd11-finance@example.test', 'D11 Finance', 'customer', 'active'),
    (v_inactive_profile, 'd11-inactive', 'd11-inactive@example.test', 'D11 Inactive', 'customer', 'suspended');

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values
    (v_support_profile, 'support_staff', 'active'),
    (v_finance_profile, 'finance_staff', 'active');

  insert into public.customers(id, profile_id) values (v_customer_id, v_customer_profile);
  insert into public.resellers(id, profile_id, approval_status, payout_status)
  values
    (v_reseller_a, v_reseller_profile_a, 'approved', 'active'),
    (v_reseller_b, v_reseller_profile_b, 'approved', 'active');
  insert into public.reseller_shops(id, reseller_id, shop_slug, display_name)
  values (v_shop_id, v_reseller_a, 'd11-test-shop', 'D11 Test Shop');
  insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
  values
    (v_supplier_a, v_supplier_profile_a, 'D11 Supplier A', 'active', 'approved'),
    (v_supplier_b, v_supplier_profile_b, 'D11 Supplier B', 'active', 'approved');
  insert into public.products(id, supplier_id, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount)
  values
    (v_product_a, v_supplier_a, 'D11 Product A', 'd11-product-a', 'active', 'approved', 100, 10, 20),
    (v_product_b, v_supplier_b, 'D11 Product B', 'd11-product-b', 'active', 'approved', 100, 10, 20);
  insert into public.product_variants(id, product_id, variant_name, total_stock_quantity)
  values
    (v_variant_a, v_product_a, 'Default', 10),
    (v_variant_b, v_product_b, 'Default', 10);
  insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
  values (v_listing_a, v_reseller_a, v_shop_id, v_product_a, v_variant_a, 'active', 15, 125, 'd11-product-a');
  insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, subtotal_product_amount, total_payable_amount, currency_code)
  values (v_order_id, 'D11-ORDER-001', v_customer_id, v_reseller_a, v_shop_id, 125, 125, 'GHS');
  insert into public.order_items(
    id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity,
    supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount,
    reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount,
    settlement_due_amount, commission_amount
  )
  values
    (v_order_item_a, v_order_id, v_supplier_a, v_product_a, v_variant_a, v_listing_a, 1, 100, 10, 15, 110, 125, 125, 100, 15),
    (v_order_item_b, v_order_id, v_supplier_b, v_product_b, v_variant_b, v_listing_a, 1, 100, 10, 15, 110, 125, 125, 100, 15);
  insert into public.settlements(id, supplier_id, order_id, due_amount, outstanding_amount, settlement_status, due_at)
  values (v_settlement_id, v_supplier_a, v_order_id, 100, 100, 'due', now());
  insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_amount, commission_status)
  values (v_commission_id, v_reseller_a, v_order_id, v_order_item_a, v_settlement_id, 15, 'available');

  insert into public.withdrawals(id, reseller_id, requested_amount, withdrawal_status, provider, account_number_masked, account_name)
  values (v_withdrawal_id, v_reseller_a, 15, 'requested', 'mobile_money', '***0000', 'D11 Test');

  insert into public.order_disputes(
    id, order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code,
    requested_outcome, status, scope_type, affected_supplier_id, affected_order_item_id
  )
  values
    (v_dispute_id, v_order_id, v_customer_profile, 'customer', 'post_completion', 'wrong_item_received', 'return', 'open', 'order_item', v_supplier_a, v_order_item_a),
    (v_order_wide_dispute_id, v_order_id, v_customer_profile, 'customer', 'other', 'other', 'information_only', 'open', 'order', null, null);

  insert into public.order_item_returns(id, dispute_id, order_id, order_item_id, customer_profile_id, supplier_id, requested_quantity, requested_method, status)
  values (v_return_id, v_dispute_id, v_order_id, v_order_item_a, v_customer_profile, v_supplier_a, 1, 'customer_returns_to_supplier', 'requested');

  insert into public.order_refunds(
    id, dispute_id, return_id, order_id, order_item_id, customer_profile_id, affected_supplier_id,
    refund_type, status, responsibility_code, responsible_party_role, approved_amount, currency_code,
    item_amount_component, delivery_fee_component, goodwill_component, approved_by_profile_id
  )
  values
    (v_refund_supplier_id, v_dispute_id, v_return_id, v_order_id, v_order_item_a, v_customer_profile, v_supplier_a, 'partial_refund', 'approved', 'supplier_responsible', 'supplier', 10, 'GHS', 10, 0, 0, v_finance_profile),
    (v_refund_platform_id, v_dispute_id, null, v_order_id, null, v_customer_profile, null, 'goodwill_refund', 'approved', 'platform_responsible', 'platform', 5, 'GHS', 0, 0, 5, v_finance_profile);

  insert into public.finance_holds(
    id, dispute_id, refund_id, order_id, order_item_id, supplier_id, reseller_profile_id,
    commission_id, settlement_id, hold_type, amount, currency_code, reason_code,
    source_finance_state, created_by_profile_id, idempotency_key
  )
  values
    (v_hold_commission_id, v_dispute_id, v_refund_supplier_id, v_order_id, v_order_item_a, v_supplier_a, v_reseller_profile_a, v_commission_id, v_settlement_id, 'commission_availability_hold', 10, 'GHS', 'active_dispute', 'commission_available', v_finance_profile, 'd11-hold-key-001'),
    (v_hold_supplier_id, v_dispute_id, v_refund_supplier_id, v_order_id, v_order_item_a, v_supplier_a, v_reseller_profile_a, v_commission_id, v_settlement_id, 'supplier_liability_hold', 10, 'GHS', 'supplier_responsible', 'settlement_pending', v_finance_profile, 'd11-hold-key-002'),
    (v_hold_withdrawal_id, v_dispute_id, v_refund_supplier_id, v_order_id, v_order_item_a, v_supplier_a, v_reseller_profile_a, v_commission_id, v_settlement_id, 'withdrawal_review_hold', 0, 'GHS', 'manual_finance_review', 'withdrawal_pending', v_finance_profile, 'd11-hold-key-003');

  insert into public.reseller_liabilities(
    id, dispute_id, refund_id, finance_hold_id, order_id, order_item_id, commission_id,
    reseller_profile_id, withdrawal_id, liability_type, status, original_amount,
    outstanding_amount, recovered_amount, currency_code, source_finance_state,
    recovery_policy, approved_by_profile_id, idempotency_key
  )
  values (v_liability_id, v_dispute_id, v_refund_supplier_id, v_hold_commission_id, v_order_id, v_order_item_a, v_commission_id, v_reseller_profile_a, v_withdrawal_id, 'commission_recovery', 'approved', 10, 10, 0, 'GHS', 'withdrawal_paid', 'offset_future_earnings', v_finance_profile, 'd11-liability-key-001');

  insert into public.reseller_liability_recoveries(id, liability_id, commission_id, withdrawal_id, recovery_type, amount, currency_code, approved_by_profile_id, idempotency_key)
  values (v_recovery_id, v_liability_id, v_commission_id, v_withdrawal_id, 'future_commission_offset', 5, 'GHS', v_finance_profile, 'd11-recovery-key-001');
  insert into public.withdrawal_commission_allocations(id, withdrawal_id, commission_id, reseller_profile_id, allocated_amount, currency_code, idempotency_key)
  values (v_allocation_id, v_withdrawal_id, v_commission_id, v_reseller_profile_a, 5, 'GHS', 'd11-allocation-key-001');

  v_before := jsonb_build_object(
    'orders', (select count(*) from public.orders),
    'settlements', (select count(*) from public.settlements),
    'commissions', (select count(*) from public.commissions),
    'withdrawals', (select count(*) from public.withdrawals),
    'disputes', (select count(*) from public.order_disputes),
    'returns', (select count(*) from public.order_item_returns),
    'refunds', (select count(*) from public.order_refunds),
    'holds', (select count(*) from public.finance_holds),
    'liabilities', (select count(*) from public.reseller_liabilities),
    'stock_reservations', (select count(*) from public.stock_reservations),
    'inventory_movements', (select count(*) from public.inventory_movements)
  );

  insert into public.audit_logs(id, actor_profile_id, actor_role, action, target_entity_type, target_entity_id, after_data)
  values
    (gen_random_uuid(), v_customer_profile, 'customer', 'dispute_opened', 'order_disputes', v_dispute_id, '{}'::jsonb),
    (gen_random_uuid(), v_customer_profile, 'customer', 'dispute_opened', 'order_disputes', v_order_wide_dispute_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'dispute_information_requested', 'order_disputes', v_dispute_id, '{"target_role":"customer"}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'dispute_information_requested', 'order_disputes', v_dispute_id, '{"target_role":"supplier"}'::jsonb),
    (gen_random_uuid(), v_customer_profile, 'customer', 'dispute_customer_response_added', 'order_disputes', v_dispute_id, '{}'::jsonb),
    (gen_random_uuid(), v_supplier_profile_a, 'supplier_owner', 'dispute_supplier_response_added', 'order_disputes', v_dispute_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'dispute_status_changed', 'order_disputes', v_dispute_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'dispute_resolution_recorded', 'order_disputes', v_dispute_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'dispute_closed', 'order_disputes', v_dispute_id, '{}'::jsonb),
    (gen_random_uuid(), v_customer_profile, 'customer', 'return_requested', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'return_approved', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'return_rejected', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_customer_profile, 'customer', 'return_marked_in_transit', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_supplier_profile_a, 'supplier_owner', 'return_received', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_supplier_profile_a, 'supplier_owner', 'returned_item_inspected', 'order_item_return', v_return_id, '{"inspection_condition":"damaged","admin_internal_note":"hidden"}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'return_accepted', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'return_declined', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_support_profile, 'support_staff', 'return_completed', 'order_item_return', v_return_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'refund_obligation_approved', 'order_refund', v_refund_supplier_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'refund_obligation_approved', 'order_refund', v_refund_platform_id, '{}'::jsonb),
    (gen_random_uuid(), v_supplier_profile_a, 'supplier_owner', 'refund_reported_sent', 'order_refund', v_refund_supplier_id, '{"external_reference_masked":"hidden"}'::jsonb),
    (gen_random_uuid(), v_customer_profile, 'customer', 'refund_customer_disputed_not_received', 'order_refund', v_refund_supplier_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'refund_verified', 'order_refund', v_refund_supplier_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'refund_completed', 'order_refund', v_refund_supplier_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'finance_hold_created', 'finance_holds', v_hold_commission_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'finance_hold_released', 'finance_holds', v_hold_commission_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'finance_hold_created', 'finance_holds', v_hold_supplier_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'finance_hold_created', 'finance_holds', v_hold_withdrawal_id, jsonb_build_object('withdrawal_id', v_withdrawal_id::text)),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'finance_hold_released', 'finance_holds', v_hold_withdrawal_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'reseller_liability_approved', 'reseller_liabilities', v_liability_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'reseller_future_earnings_offset_enabled', 'reseller_liabilities', v_liability_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'reseller_liability_recovery_applied', 'reseller_liabilities', v_liability_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'reseller_liability_waived', 'reseller_liabilities', v_liability_id, '{}'::jsonb),
    (gen_random_uuid(), v_finance_profile, 'finance_staff', 'withdrawal_allocation_released', 'withdrawal_commission_allocations', v_allocation_id, '{}'::jsonb);

  insert into public.audit_logs(id, actor_profile_id, actor_role, action, target_entity_type, target_entity_id, after_data)
  values (gen_random_uuid(), v_customer_profile, 'customer', 'dispute_opened', 'order_disputes', v_dispute_id, '{}'::jsonb)
  returning id into v_audit_id;
  insert into public.audit_logs(id, actor_profile_id, actor_role, action, target_entity_type, target_entity_id, after_data)
  values (v_audit_id, v_customer_profile, 'customer', 'dispute_opened', 'order_disputes', v_dispute_id, '{}'::jsonb)
  on conflict (id) do nothing;

  v_after := jsonb_build_object(
    'orders', (select count(*) from public.orders),
    'settlements', (select count(*) from public.settlements),
    'commissions', (select count(*) from public.commissions),
    'withdrawals', (select count(*) from public.withdrawals),
    'disputes', (select count(*) from public.order_disputes),
    'returns', (select count(*) from public.order_item_returns),
    'refunds', (select count(*) from public.order_refunds),
    'holds', (select count(*) from public.finance_holds),
    'liabilities', (select count(*) from public.reseller_liabilities),
    'stock_reservations', (select count(*) from public.stock_reservations),
    'inventory_movements', (select count(*) from public.inventory_movements)
  );

  insert into d11_notification_test_results(assertion, passed, details)
  values
    ('dispute opened creates customer outbox event', exists(select 1 from public.notification_outbox where event_type = 'dispute_opened_customer' and recipient_profile_id = v_customer_profile), null),
    ('supplier scoped dispute notifies affected supplier only', exists(select 1 from public.notification_outbox where event_type = 'dispute_opened_supplier' and recipient_profile_id = v_supplier_profile_a), null),
    ('other supplier gets no dispute event', not exists(select 1 from public.notification_outbox where event_type like 'dispute%_supplier' and recipient_profile_id = v_supplier_profile_b), null),
    ('multi supplier order wide dispute does not notify all suppliers', (select count(distinct recipient_profile_id) from public.notification_outbox where event_type = 'dispute_opened_supplier') = 1, null),
    ('admin routing creates support event', exists(select 1 from public.notification_outbox where event_type = 'new_dispute_admin' and recipient_profile_id = v_support_profile), null),
    ('customer information request notifies customer', exists(select 1 from public.notification_outbox where event_type = 'dispute_information_requested_customer'), null),
    ('supplier information request notifies affected supplier', exists(select 1 from public.notification_outbox where event_type = 'dispute_information_requested_supplier' and recipient_profile_id = v_supplier_profile_a), null),
    ('customer response notifies admin', exists(select 1 from public.notification_outbox where event_type = 'dispute_response_received_admin'), null),
    ('supplier response notifies admin', (select count(*) from public.notification_outbox where event_type = 'dispute_response_received_admin') >= 2, null),
    ('return request notifies customer', exists(select 1 from public.notification_outbox where event_type = 'return_requested_customer'), null),
    ('return request notifies supplier', exists(select 1 from public.notification_outbox where event_type = 'return_requested_supplier'), null),
    ('return request notifies admin', exists(select 1 from public.notification_outbox where event_type = 'return_requested_admin'), null),
    ('return approval notifies customer', exists(select 1 from public.notification_outbox where event_type = 'return_approved_customer'), null),
    ('return approval notifies supplier', exists(select 1 from public.notification_outbox where event_type = 'return_approved_supplier'), null),
    ('return rejection notifies customer', exists(select 1 from public.notification_outbox where event_type = 'return_rejected_customer'), null),
    ('return in transit notifies supplier', exists(select 1 from public.notification_outbox where event_type = 'return_in_transit_supplier'), null),
    ('return received notifies customer', exists(select 1 from public.notification_outbox where event_type = 'return_received_customer'), null),
    ('return received notifies admin', exists(select 1 from public.notification_outbox where event_type = 'return_received_admin'), null),
    ('return inspection notifies supplier', exists(select 1 from public.notification_outbox where event_type = 'return_inspection_required_supplier'), null),
    ('return inspection notifies admin', exists(select 1 from public.notification_outbox where event_type = 'return_inspected_admin'), null),
    ('refund approval notifies customer', exists(select 1 from public.notification_outbox where event_type = 'refund_approved_customer'), null),
    ('supplier responsible refund notifies affected supplier', exists(select 1 from public.notification_outbox where event_type = 'refund_obligation_supplier' and recipient_profile_id = v_supplier_profile_a), null),
    ('platform responsible refund notifies finance', exists(select 1 from public.notification_outbox where event_type = 'refund_approval_required_finance' and recipient_role = 'finance_admin'), null),
    ('platform responsible refund does not notify supplier', not exists(select 1 from public.notification_outbox where event_type = 'refund_obligation_supplier' and entity_id = v_refund_platform_id), null),
    ('refund reported sent notifies customer', exists(select 1 from public.notification_outbox where event_type = 'refund_reported_sent_customer'), null),
    ('refund reported sent notifies finance', exists(select 1 from public.notification_outbox where event_type = 'refund_reported_sent_finance'), null),
    ('customer disputed refund notifies supplier', exists(select 1 from public.notification_outbox where event_type = 'refund_customer_disputed_not_received_supplier'), null),
    ('customer disputed refund notifies finance', exists(select 1 from public.notification_outbox where event_type = 'refund_customer_disputed_not_received_finance'), null),
    ('refund verified notifies customer', exists(select 1 from public.notification_outbox where event_type = 'refund_verified_customer'), null),
    ('refund verified notifies responsible supplier', exists(select 1 from public.notification_outbox where event_type = 'refund_verified_supplier'), null),
    ('commission hold notifies reseller only', exists(select 1 from public.notification_outbox where event_type = 'commission_hold_created_reseller' and recipient_profile_id = v_reseller_profile_a), null),
    ('other reseller gets no event', not exists(select 1 from public.notification_outbox where recipient_profile_id = v_reseller_profile_b), null),
    ('commission release notifies reseller', exists(select 1 from public.notification_outbox where event_type = 'commission_hold_released_reseller'), null),
    ('supplier liability notifies supplier only', exists(select 1 from public.notification_outbox where event_type = 'supplier_liability_created' and recipient_profile_id = v_supplier_profile_a), null),
    ('reseller liability notifies reseller', exists(select 1 from public.notification_outbox where event_type = 'reseller_liability_approved' and recipient_profile_id = v_reseller_profile_a), null),
    ('future earnings offset notifies reseller', exists(select 1 from public.notification_outbox where event_type = 'future_earnings_offset_enabled'), null),
    ('withdrawal blocked notifies reseller', exists(select 1 from public.notification_outbox where event_type = 'withdrawal_blocked_by_finance_review'), null),
    ('withdrawal blocked notifies finance', exists(select 1 from public.notification_outbox where event_type = 'withdrawal_blocked_finance'), null),
    ('support admin does not receive finance-only notification', not exists(select 1 from public.notification_outbox where recipient_profile_id = v_support_profile and recipient_role = 'finance_admin'), null),
    ('finance staff receives finance notification', exists(select 1 from public.notification_outbox no join public.admin_staff ads on ads.profile_id = no.recipient_profile_id where no.recipient_role = 'finance_admin' and ads.admin_role in ('finance_staff', 'super_admin') and ads.staff_status = 'active'), null),
    ('inactive recipient skipped by routing', not exists(select 1 from public.notification_outbox where recipient_profile_id = v_inactive_profile), null),
    ('duplicate audit mapping creates one logical outbox set', (select count(*) from public.notification_outbox where event_key like 'dispute_opened_customer:%:' || v_audit_id::text || ':%') <= 1, null),
    ('distinct roles create distinct keys', exists(select 1 from public.notification_outbox where event_type = 'dispute_opened_customer') and exists(select 1 from public.notification_outbox where event_type = 'dispute_opened_supplier'), null),
    ('outbox payload has no recipient email', not exists(select 1 from public.notification_outbox where payload ? 'recipient_email' or payload ? 'email'), null),
    ('outbox payload has no phone address private note or reference', not exists(select 1 from public.notification_outbox where payload ?| array['phone','whatsapp','address','customer_address','customerAddress','supplier_private_note','supplierPrivateNote','admin_note','adminInternalNote','admin_internal_note','internal_note','internal_notes','payment_reference','refund_reference','external_reference_masked']), null),
    ('CTA path is relative before rendering', not exists(select 1 from public.notification_outbox where payload ->> 'ctaPath' !~ '^/'), null),
    ('no business table changes from mapper', v_before = v_after, null),
    ('no order status change from mapper', exists(select 1 from public.orders where id = v_order_id and order_status = 'placed_pending_confirmation'), null),
    ('existing notification event types remain allowed', public.enqueue_email_notification('d11-existing-event-key', 'order_placed_customer', 'orders', v_order_id, v_customer_profile, 'customer', jsonb_build_object('ctaPath', '/customer/orders/test')) is not null, null),
    ('event key includes audit and role delimiters', exists(select 1 from public.notification_outbox where event_key like 'refund_verified_customer:%:%:customer'), null);
end;
$d11$;

select assertion, passed, coalesce(details, '') as details
from d11_notification_test_results
where not passed
order by assertion;

select
  count(*) as assertion_count,
  count(*) filter (where passed) as passed_count,
  count(*) filter (where not passed) as failed_count
from d11_notification_test_results;

do $assertions$
declare
  v_failed text;
begin
  select string_agg(assertion, '; ' order by assertion)
  into v_failed
  from d11_notification_test_results
  where not passed;

  if v_failed is not null then
    raise exception 'D11_NOTIFICATION_ASSERTIONS_FAILED: %', v_failed;
  end if;
end;
$assertions$;

rollback;
