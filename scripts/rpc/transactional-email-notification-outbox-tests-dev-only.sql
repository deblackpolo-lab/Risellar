-- Development-only transactional email notification outbox boundary tests.
-- Do not run against production. Fixtures are rolled back.

begin;

create temp table transactional_email_test_results (
  name text primary key,
  passed boolean not null,
  details text
) on commit drop;

create or replace function pg_temp.record_transactional_email_test(
  p_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into transactional_email_test_results(name, passed, details)
  values (p_name, p_passed, p_details);
end;
$$;

do $$
declare
  v_customer_profile_id uuid := '81000000-0000-4000-8000-000000000001';
  v_supplier_profile_id uuid := '81000000-0000-4000-8000-000000000002';
  v_reseller_profile_id uuid := '81000000-0000-4000-8000-000000000003';
  v_finance_profile_id uuid := '81000000-0000-4000-8000-000000000004';
  v_entity_id uuid := '82000000-0000-4000-8000-000000000001';
  v_claim_a uuid[];
  v_claim_b uuid[];
  v_before_counts jsonb;
  v_after_counts jsonb;
begin
  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_customer_profile_id, 'email-phase-customer', 'email-phase-customer@example.invalid', 'Email Phase Customer', 'customer', 'active'),
    (v_supplier_profile_id, 'email-phase-supplier', 'email-phase-supplier@example.invalid', 'Email Phase Supplier', 'supplier_owner', 'active'),
    (v_reseller_profile_id, 'email-phase-reseller', 'email-phase-reseller@example.invalid', 'Email Phase Reseller', 'reseller', 'active'),
    (v_finance_profile_id, 'email-phase-finance', 'email-phase-finance@example.invalid', 'Email Phase Finance', 'customer', 'active')
  on conflict (id) do nothing;

  insert into public.admin_staff(profile_id, admin_role, staff_status)
  values (v_finance_profile_id, 'finance_staff', 'active')
  on conflict (profile_id) do update set admin_role = 'finance_staff', staff_status = 'active';

  select jsonb_build_object(
    'orders', (select count(*) from public.orders),
    'stock_reservations', (select count(*) from public.stock_reservations),
    'settlements', (select count(*) from public.settlements),
    'commissions', (select count(*) from public.commissions),
    'withdrawals', (select count(*) from public.withdrawals)
  ) into v_before_counts;

  perform public.enqueue_email_notification(
    'order_placed_customer/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'order_placed_customer',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001', 'productName', 'Dev-only Email Product', 'amount', 'GHS 100.00')
  );

  perform public.enqueue_email_notification(
    'order_placed_supplier/' || v_entity_id::text || '/' || v_supplier_profile_id::text,
    'order_placed_supplier',
    'orders',
    v_entity_id,
    v_supplier_profile_id,
    'supplier',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001', 'productName', 'Dev-only Email Product')
  );

  perform public.enqueue_email_notification(
    'supplier_order_accepted/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'supplier_order_accepted',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'supplier_order_rejected/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'supplier_order_rejected',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001', 'safeReasonLabel', 'Unable to fulfil')
  );

  perform public.enqueue_email_notification(
    'supplier_order_preparing/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'supplier_order_preparing',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'order_ready_for_delivery/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'order_ready_for_delivery',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'delivery_arranged/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'delivery_arranged',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001', 'deliveryMethod', 'Safe courier')
  );

  perform public.enqueue_email_notification(
    'order_out_for_delivery/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'order_out_for_delivery',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'order_delivered/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'order_delivered',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'supplier_payment_reported_customer/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'supplier_payment_reported_customer',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'supplier_payment_reported_finance/' || v_entity_id::text || '/' || v_finance_profile_id::text,
    'supplier_payment_reported_finance',
    'orders',
    v_entity_id,
    v_finance_profile_id,
    'finance_admin',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001', 'ctaPath', '/admin/settlements/82000000-0000-4000-8000-000000000001')
  );

  perform public.enqueue_email_notification(
    'settlement_verified_supplier/' || v_entity_id::text || '/' || v_supplier_profile_id::text,
    'settlement_verified_supplier',
    'orders',
    v_entity_id,
    v_supplier_profile_id,
    'supplier',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'settlement_verified_customer/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'settlement_verified_customer',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform public.enqueue_email_notification(
    'reseller_commission_available/' || v_entity_id::text || '/' || v_reseller_profile_id::text,
    'reseller_commission_available',
    'orders',
    v_entity_id,
    v_reseller_profile_id,
    'reseller',
    jsonb_build_object('amount', 'GHS 25.00', 'ctaPath', '/reseller/wallet')
  );

  perform public.enqueue_email_notification(
    'withdrawal_requested_reseller/' || v_entity_id::text || '/' || v_reseller_profile_id::text,
    'withdrawal_requested_reseller',
    'withdrawals',
    v_entity_id,
    v_reseller_profile_id,
    'reseller',
    jsonb_build_object('amount', 'GHS 25.00')
  );

  perform public.enqueue_email_notification(
    'withdrawal_requested_finance/' || v_entity_id::text || '/' || v_finance_profile_id::text,
    'withdrawal_requested_finance',
    'withdrawals',
    v_entity_id,
    v_finance_profile_id,
    'finance_admin',
    jsonb_build_object('amount', 'GHS 25.00')
  );

  perform public.enqueue_email_notification(
    'withdrawal_paid_reseller/' || v_entity_id::text || '/' || v_reseller_profile_id::text,
    'withdrawal_paid_reseller',
    'withdrawals',
    v_entity_id,
    v_reseller_profile_id,
    'reseller',
    jsonb_build_object('amount', 'GHS 25.00', 'maskedPayoutDestination', '***1234')
  );

  perform pg_temp.record_transactional_email_test(
    'all required event rows can be enqueued',
    (select count(*) = 17 from public.notification_outbox where entity_id = v_entity_id),
    null
  );

  perform public.enqueue_email_notification(
    'order_placed_customer/' || v_entity_id::text || '/' || v_customer_profile_id::text,
    'order_placed_customer',
    'orders',
    v_entity_id,
    v_customer_profile_id,
    'customer',
    jsonb_build_object('orderNumber', 'RSR-EMAIL-001')
  );

  perform pg_temp.record_transactional_email_test(
    'deterministic event key dedupes retries',
    (select count(*) = 1 from public.notification_outbox where event_key = 'order_placed_customer/' || v_entity_id::text || '/' || v_customer_profile_id::text),
    null
  );

  perform pg_temp.record_transactional_email_test(
    'same event can intentionally target different recipients',
    (select count(*) = 2 from public.notification_outbox where event_type = 'order_placed_customer' or event_type = 'order_placed_supplier'),
    null
  );

  perform pg_temp.record_transactional_email_test(
    'payload excludes recipient emails and unsafe private fields',
    not exists (
      select 1
      from public.notification_outbox
      where payload ?| array['email','recipient_email','supplier_private_note','admin_note','platform_margin','reseller_margin','commission','settlement_amount','payout_account','token','secret']
    ),
    null
  );

  select array_agg(id) into v_claim_a
  from public.claim_pending_email_notifications(3, 'worker-a');

  select array_agg(id) into v_claim_b
  from public.claim_pending_email_notifications(3, 'worker-b');

  perform pg_temp.record_transactional_email_test('batch limit enforced', coalesce(array_length(v_claim_a, 1), 0) = 3, null);
  perform pg_temp.record_transactional_email_test('two workers do not claim same row', not (v_claim_a && coalesce(v_claim_b, array[]::uuid[])), null);

  perform public.mark_email_notification_sent(v_claim_a[1], 'resend-dev-message-1');
  perform public.mark_email_notification_sent(v_claim_a[1], 'resend-dev-message-1');

  perform pg_temp.record_transactional_email_test(
    'sent status update is idempotent',
    (select status = 'sent' and provider_message_id = 'resend-dev-message-1' from public.notification_outbox where id = v_claim_a[1]),
    null
  );

  perform public.mark_email_notification_retry(v_claim_a[2], 'RESEND_RETRYABLE_ERROR');
  perform pg_temp.record_transactional_email_test(
    'retry schedules future attempt',
    (select status = 'retry_scheduled' and next_attempt_at > now() from public.notification_outbox where id = v_claim_a[2]),
    null
  );

  perform public.mark_email_notification_failed(v_claim_a[3], 'SKIPPED_NO_VERIFIED_EMAIL');
  perform pg_temp.record_transactional_email_test(
    'missing verified email becomes skipped',
    (select status = 'skipped' and skipped_at is not null from public.notification_outbox where id = v_claim_a[3]),
    null
  );

exception
  when datatype_mismatch then
    raise;
end;
$$;

do $$
declare
  v_first boolean;
  v_second boolean;
  v_before_counts jsonb;
  v_after_counts jsonb;
begin
  select jsonb_build_object(
    'orders', (select count(*) from public.orders),
    'stock_reservations', (select count(*) from public.stock_reservations),
    'settlements', (select count(*) from public.settlements),
    'commissions', (select count(*) from public.commissions),
    'withdrawals', (select count(*) from public.withdrawals)
  ) into v_before_counts;

  select public.record_email_provider_event('evt-email-phase-2', 'resend-dev-message-1', 'email.delivered', 'delivered', '{}'::jsonb) into v_first;
  select public.record_email_provider_event('evt-email-phase-2', 'resend-dev-message-1', 'email.delivered', 'delivered', '{}'::jsonb) into v_second;

  perform public.update_email_notification_provider_status('resend-dev-message-1', 'delivered');

  perform pg_temp.record_transactional_email_test('provider event dedupe works', v_first is true and v_second is false, null);
  perform pg_temp.record_transactional_email_test(
    'provider delivery status updates notification only',
    (select provider_status = 'delivered' and status = 'delivered' from public.notification_outbox where provider_message_id = 'resend-dev-message-1'),
    null
  );

  select jsonb_build_object(
    'orders', (select count(*) from public.orders),
    'stock_reservations', (select count(*) from public.stock_reservations),
    'settlements', (select count(*) from public.settlements),
    'commissions', (select count(*) from public.commissions),
    'withdrawals', (select count(*) from public.withdrawals)
  ) into v_after_counts;

  perform pg_temp.record_transactional_email_test('notification processing creates no business rows', v_after_counts = v_before_counts, null);
end;
$$;

select * from transactional_email_test_results order by name;

do $$
declare
  v_failed integer;
begin
  select count(*) into v_failed from transactional_email_test_results where not passed;
  if v_failed > 0 then
    raise exception 'TRANSACTIONAL_EMAIL_NOTIFICATION_TESTS_FAILED: %', v_failed;
  end if;
end;
$$;

rollback;
