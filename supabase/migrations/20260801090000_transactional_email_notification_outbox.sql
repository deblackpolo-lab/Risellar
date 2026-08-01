-- Email Notifications Phase 1: durable transactional email outbox.
-- Forward-only, additive, server-worker scoped. No business-state mutation.

create table if not exists public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  event_type text not null,
  entity_type text not null,
  entity_id uuid not null,
  recipient_profile_id uuid references public.profiles(id) on delete set null,
  recipient_role text,
  channel text not null default 'email',
  status text not null default 'pending',
  attempt_count integer not null default 0,
  max_attempts integer not null default 5,
  next_attempt_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  provider_message_id text,
  provider_status text,
  safe_error_code text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  skipped_at timestamptz,
  failed_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint notification_outbox_channel_email check (channel = 'email'),
  constraint notification_outbox_event_key_not_blank check (length(trim(event_key)) > 0 and length(event_key) <= 256),
  constraint notification_outbox_event_type_allowed check (
    event_type in (
      'order_placed_customer',
      'order_placed_supplier',
      'supplier_order_accepted',
      'supplier_order_rejected',
      'supplier_order_preparing',
      'order_ready_for_delivery',
      'delivery_arranged',
      'order_out_for_delivery',
      'order_delivered',
      'supplier_payment_reported_customer',
      'supplier_payment_reported_finance',
      'settlement_verified_supplier',
      'settlement_verified_customer',
      'reseller_commission_available',
      'withdrawal_requested_reseller',
      'withdrawal_requested_finance',
      'withdrawal_paid_reseller'
    )
  ),
  constraint notification_outbox_status_allowed check (
    status in ('pending', 'processing', 'retry_scheduled', 'sent', 'delivered', 'bounced', 'complained', 'skipped', 'failed')
  ),
  constraint notification_outbox_recipient_present check (recipient_profile_id is not null or recipient_role is not null),
  constraint notification_outbox_attempt_bounds check (attempt_count >= 0 and max_attempts between 1 and 10)
);

create index if not exists notification_outbox_due_idx
  on public.notification_outbox (status, next_attempt_at, created_at)
  where status in ('pending', 'retry_scheduled');

create index if not exists notification_outbox_recipient_idx
  on public.notification_outbox (recipient_profile_id, status, created_at);

create index if not exists notification_outbox_provider_message_idx
  on public.notification_outbox (provider_message_id)
  where provider_message_id is not null;

create table if not exists public.notification_provider_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'resend',
  provider_event_id text not null,
  provider_message_id text,
  provider_event_type text not null,
  provider_status text,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (provider, provider_event_id),
  constraint notification_provider_event_provider_resend check (provider = 'resend'),
  constraint notification_provider_event_id_not_blank check (length(trim(provider_event_id)) > 0)
);

alter table public.notification_outbox enable row level security;
alter table public.notification_provider_events enable row level security;

revoke all on public.notification_outbox from anon, authenticated;
revoke all on public.notification_provider_events from anon, authenticated;

create or replace function public.enqueue_email_notification(
  p_event_key text,
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_recipient_profile_id uuid default null,
  p_recipient_role text default null,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
begin
  if p_event_key is null or length(trim(p_event_key)) = 0 or length(p_event_key) > 256 then
    raise exception 'INVALID_EMAIL_NOTIFICATION_EVENT_KEY';
  end if;

  if p_recipient_profile_id is null and p_recipient_role is null then
    raise exception 'EMAIL_NOTIFICATION_RECIPIENT_REQUIRED';
  end if;

  if v_payload ?| array[
    'recipient_email',
    'email',
    'supplier_private_note',
    'admin_private_note',
    'admin_note',
    'platform_margin',
    'reseller_margin',
    'supplier_base_price',
    'payout_account',
    'payout_account_number',
    'token',
    'secret',
    'password'
  ] then
    raise exception 'EMAIL_NOTIFICATION_PAYLOAD_UNSAFE';
  end if;

  insert into public.notification_outbox(
    event_key,
    event_type,
    entity_type,
    entity_id,
    recipient_profile_id,
    recipient_role,
    payload
  )
  values (
    p_event_key,
    p_event_type,
    p_entity_type,
    p_entity_id,
    p_recipient_profile_id,
    p_recipient_role,
    v_payload
  )
  on conflict (event_key) do update
    set updated_at = public.notification_outbox.updated_at
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.claim_pending_email_notifications(
  p_limit integer,
  p_worker_id text
)
returns table (
  id uuid,
  event_key text,
  event_type text,
  recipient_profile_id uuid,
  recipient_role text,
  payload jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 25);
  v_worker_id text := nullif(trim(coalesce(p_worker_id, '')), '');
begin
  if v_worker_id is null then
    raise exception 'EMAIL_WORKER_ID_REQUIRED';
  end if;

  return query
  with due as (
    select no.id
    from public.notification_outbox no
    where (
        no.status in ('pending', 'retry_scheduled')
        and no.next_attempt_at <= now()
      )
      or (
        no.status = 'processing'
        and no.locked_at < now() - interval '15 minutes'
      )
    order by no.created_at asc
    limit v_limit
    for update skip locked
  ),
  claimed as (
    update public.notification_outbox no
    set status = 'processing',
        attempt_count = no.attempt_count + 1,
        locked_at = now(),
        locked_by = v_worker_id,
        safe_error_code = null,
        updated_at = now()
    from due
    where no.id = due.id
      and no.attempt_count < no.max_attempts
    returning no.id, no.event_key, no.event_type, no.recipient_profile_id, no.recipient_role, no.payload
  )
  select claimed.id, claimed.event_key, claimed.event_type, claimed.recipient_profile_id, claimed.recipient_role, claimed.payload
  from claimed;
end;
$$;

create or replace function public.mark_email_notification_sent(
  p_notification_id uuid,
  p_provider_message_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notification_outbox
  set status = 'sent',
      provider_status = 'sent',
      provider_message_id = coalesce(nullif(trim(p_provider_message_id), ''), provider_message_id),
      sent_at = coalesce(sent_at, now()),
      locked_at = null,
      locked_by = null,
      safe_error_code = null,
      updated_at = now()
  where id = p_notification_id
    and status in ('processing', 'sent');
end;
$$;

create or replace function public.mark_email_notification_retry(
  p_notification_id uuid,
  p_safe_error_code text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notification_outbox
  set status = case when attempt_count >= max_attempts then 'failed' else 'retry_scheduled' end,
      next_attempt_at = now() + make_interval(mins => least(60, greatest(1, attempt_count * attempt_count))),
      failed_at = case when attempt_count >= max_attempts then coalesce(failed_at, now()) else failed_at end,
      locked_at = null,
      locked_by = null,
      safe_error_code = left(coalesce(nullif(trim(p_safe_error_code), ''), 'RESEND_RETRYABLE_ERROR'), 80),
      updated_at = now()
  where id = p_notification_id
    and status = 'processing';
end;
$$;

create or replace function public.mark_email_notification_failed(
  p_notification_id uuid,
  p_safe_error_code text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notification_outbox
  set status = case when upper(coalesce(p_safe_error_code, '')) like 'SKIPPED%' then 'skipped' else 'failed' end,
      skipped_at = case when upper(coalesce(p_safe_error_code, '')) like 'SKIPPED%' then coalesce(skipped_at, now()) else skipped_at end,
      failed_at = case when upper(coalesce(p_safe_error_code, '')) like 'SKIPPED%' then failed_at else coalesce(failed_at, now()) end,
      locked_at = null,
      locked_by = null,
      safe_error_code = left(coalesce(nullif(trim(p_safe_error_code), ''), 'EMAIL_NOTIFICATION_FAILED'), 80),
      updated_at = now()
  where id = p_notification_id
    and status in ('processing', 'failed', 'skipped');
end;
$$;

create or replace function public.record_email_provider_event(
  p_provider_event_id text,
  p_provider_message_id text,
  p_provider_event_type text,
  p_provider_status text,
  p_safe_metadata jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted boolean := false;
begin
  insert into public.notification_provider_events(
    provider_event_id,
    provider_message_id,
    provider_event_type,
    provider_status,
    safe_metadata
  )
  values (
    p_provider_event_id,
    nullif(trim(coalesce(p_provider_message_id, '')), ''),
    p_provider_event_type,
    p_provider_status,
    coalesce(p_safe_metadata, '{}'::jsonb)
  )
  on conflict (provider, provider_event_id) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

create or replace function public.update_email_notification_provider_status(
  p_provider_message_id text,
  p_provider_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notification_outbox
  set provider_status = p_provider_status,
      status = case
        when p_provider_status in ('delivered') then 'delivered'
        when p_provider_status in ('bounced') then 'bounced'
        when p_provider_status in ('complained') then 'complained'
        else status
      end,
      updated_at = now()
  where provider_message_id = p_provider_message_id;
end;
$$;

create or replace function public.notification_profile_for_customer(p_customer_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.profile_id
  from public.customers c
  join public.profiles p on p.id = c.profile_id
  where c.id = p_customer_id
    and c.deleted_at is null
    and p.account_status = 'active'
    and p.deleted_at is null
  limit 1
$$;

create or replace function public.enqueue_email_notifications_from_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_item record;
  v_customer_profile_id uuid;
  v_supplier_profile_id uuid;
  v_reseller_profile_id uuid;
  v_payload jsonb;
  v_event_type text;
  v_admin_profile_id uuid;
begin
  begin
    if new.target_entity_type = 'orders' then
      select o.id, o.order_number, o.customer_id, o.reseller_id, o.shop_id, o.total_payable_amount, o.currency_code
      into v_order
      from public.orders o
      where o.id = new.target_entity_id;

      if v_order.id is null then
        return new;
      end if;

      select oi.product_id, oi.supplier_id, oi.quantity, p.name as product_name, s.owner_profile_id as supplier_profile_id, r.profile_id as reseller_profile_id
      into v_item
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      join public.suppliers s on s.id = oi.supplier_id
      join public.resellers r on r.id = v_order.reseller_id
      where oi.order_id = v_order.id
      order by oi.created_at asc, oi.id asc
      limit 1;

      v_customer_profile_id := public.notification_profile_for_customer(v_order.customer_id);
      v_supplier_profile_id := v_item.supplier_profile_id;
      v_reseller_profile_id := v_item.reseller_profile_id;
      v_payload := jsonb_build_object(
        'orderNumber', v_order.order_number,
        'productName', v_item.product_name,
        'quantity', v_item.quantity,
        'amount', concat(v_order.currency_code, ' ', v_order.total_payable_amount::text),
        'currency', v_order.currency_code,
        'ctaPath', concat('/customer/orders/', v_order.id::text)
      );

      if new.action = 'order_created' then
        perform public.enqueue_email_notification(
          'order_placed_customer/' || v_order.id::text || '/' || v_customer_profile_id::text,
          'order_placed_customer',
          'orders',
          v_order.id,
          v_customer_profile_id,
          'customer',
          v_payload
        );
        perform public.enqueue_email_notification(
          'order_placed_supplier/' || v_order.id::text || '/' || v_supplier_profile_id::text,
          'order_placed_supplier',
          'orders',
          v_order.id,
          v_supplier_profile_id,
          'supplier',
          v_payload || jsonb_build_object('ctaPath', concat('/supplier/orders/', v_order.id::text))
        );
      elsif new.action = 'supplier_order_accepted' then
        v_event_type := 'supplier_order_accepted';
      elsif new.action = 'supplier_order_rejected' then
        v_event_type := 'supplier_order_rejected';
        v_payload := v_payload || jsonb_build_object('safeReasonLabel', coalesce(new.after_data ->> 'reason_code', 'Unable to fulfil'));
      elsif new.action = 'supplier_order_preparation_started' then
        v_event_type := 'supplier_order_preparing';
      elsif new.action = 'supplier_order_ready_for_delivery' then
        v_event_type := 'order_ready_for_delivery';
      elsif new.action = 'supplier_order_delivery_arranged' then
        v_event_type := 'delivery_arranged';
      elsif new.action = 'supplier_order_out_for_delivery' then
        v_event_type := 'order_out_for_delivery';
      elsif new.action = 'supplier_order_delivered' then
        v_event_type := 'order_delivered';
      elsif new.action = 'supplier_order_payment_reported' then
        perform public.enqueue_email_notification(
          'supplier_payment_reported_customer/' || v_order.id::text || '/' || v_customer_profile_id::text,
          'supplier_payment_reported_customer',
          'orders',
          v_order.id,
          v_customer_profile_id,
          'customer',
          v_payload
        );

        for v_admin_profile_id in
          select ads.profile_id
          from public.admin_staff ads
          join public.profiles ap on ap.id = ads.profile_id
          where ads.admin_role in ('finance_staff', 'super_admin')
            and ads.staff_status = 'active'
            and ads.deleted_at is null
            and ap.account_status = 'active'
            and ap.deleted_at is null
        loop
          perform public.enqueue_email_notification(
            'supplier_payment_reported_finance/' || v_order.id::text || '/' || v_admin_profile_id::text,
            'supplier_payment_reported_finance',
            'orders',
            v_order.id,
            v_admin_profile_id,
            'finance_admin',
            jsonb_build_object(
              'orderNumber', v_order.order_number,
              'productName', v_item.product_name,
              'currency', v_order.currency_code,
              'ctaPath', concat('/admin/settlements/', v_order.id::text)
            )
          );
        end loop;
      elsif new.action = 'supplier_settlement_verified' then
        perform public.enqueue_email_notification(
          'settlement_verified_supplier/' || v_order.id::text || '/' || v_supplier_profile_id::text,
          'settlement_verified_supplier',
          'orders',
          v_order.id,
          v_supplier_profile_id,
          'supplier',
          v_payload || jsonb_build_object('ctaPath', '/supplier/finance')
        );
        perform public.enqueue_email_notification(
          'settlement_verified_customer/' || v_order.id::text || '/' || v_customer_profile_id::text,
          'settlement_verified_customer',
          'orders',
          v_order.id,
          v_customer_profile_id,
          'customer',
          v_payload
        );
        perform public.enqueue_email_notification(
          'reseller_commission_available/' || v_order.id::text || '/' || v_reseller_profile_id::text,
          'reseller_commission_available',
          'orders',
          v_order.id,
          v_reseller_profile_id,
          'reseller',
          jsonb_build_object('orderNumber', v_order.order_number, 'currency', v_order.currency_code, 'ctaPath', '/reseller/wallet')
        );
      end if;

      if v_event_type is not null then
        perform public.enqueue_email_notification(
          v_event_type || '/' || v_order.id::text || '/' || v_customer_profile_id::text,
          v_event_type,
          'orders',
          v_order.id,
          v_customer_profile_id,
          'customer',
          v_payload
        );
      end if;
    elsif new.target_entity_type = 'withdrawals' then
      select w.id, w.reseller_id, w.requested_amount, w.account_number_masked, r.profile_id
      into v_item
      from public.withdrawals w
      join public.resellers r on r.id = w.reseller_id
      where w.id = new.target_entity_id;

      if v_item.id is null then
        return new;
      end if;

      if new.action = 'reseller_withdrawal_requested' then
        perform public.enqueue_email_notification(
          'withdrawal_requested_reseller/' || v_item.id::text || '/' || v_item.profile_id::text,
          'withdrawal_requested_reseller',
          'withdrawals',
          v_item.id,
          v_item.profile_id,
          'reseller',
          jsonb_build_object('amount', v_item.requested_amount::text, 'currency', 'GHS', 'ctaPath', '/reseller/withdrawals')
        );

        for v_admin_profile_id in
          select ads.profile_id
          from public.admin_staff ads
          join public.profiles ap on ap.id = ads.profile_id
          where ads.admin_role in ('finance_staff', 'super_admin')
            and ads.staff_status = 'active'
            and ads.deleted_at is null
            and ap.account_status = 'active'
            and ap.deleted_at is null
        loop
          perform public.enqueue_email_notification(
            'withdrawal_requested_finance/' || v_item.id::text || '/' || v_admin_profile_id::text,
            'withdrawal_requested_finance',
            'withdrawals',
            v_item.id,
            v_admin_profile_id,
            'finance_admin',
            jsonb_build_object('amount', v_item.requested_amount::text, 'currency', 'GHS', 'ctaPath', concat('/admin/withdrawals/', v_item.id::text))
          );
        end loop;
      elsif new.action = 'reseller_withdrawal_paid' then
        perform public.enqueue_email_notification(
          'withdrawal_paid_reseller/' || v_item.id::text || '/' || v_item.profile_id::text,
          'withdrawal_paid_reseller',
          'withdrawals',
          v_item.id,
          v_item.profile_id,
          'reseller',
          jsonb_build_object(
            'amount', v_item.requested_amount::text,
            'currency', 'GHS',
            'maskedPayoutDestination', v_item.account_number_masked,
            'ctaPath', concat('/reseller/withdrawals/', v_item.id::text)
          )
        );
      end if;
    end if;
  exception
    when others then
      -- Email outbox failure must never roll back the already-audited business transition.
      return new;
  end;

  return new;
end;
$$;

drop trigger if exists enqueue_email_notifications_from_audit_log_trigger on public.audit_logs;
create trigger enqueue_email_notifications_from_audit_log_trigger
after insert on public.audit_logs
for each row
execute function public.enqueue_email_notifications_from_audit_log();

revoke all on function public.enqueue_email_notification(text, text, text, uuid, uuid, text, jsonb) from public;
revoke all on function public.claim_pending_email_notifications(integer, text) from public;
revoke all on function public.mark_email_notification_sent(uuid, text) from public;
revoke all on function public.mark_email_notification_retry(uuid, text) from public;
revoke all on function public.mark_email_notification_failed(uuid, text) from public;
revoke all on function public.record_email_provider_event(text, text, text, text, jsonb) from public;
revoke all on function public.update_email_notification_provider_status(text, text) from public;

grant execute on function public.claim_pending_email_notifications(integer, text) to service_role;
grant execute on function public.mark_email_notification_sent(uuid, text) to service_role;
grant execute on function public.mark_email_notification_retry(uuid, text) to service_role;
grant execute on function public.mark_email_notification_failed(uuid, text) to service_role;
grant execute on function public.record_email_provider_event(text, text, text, text, jsonb) to service_role;
grant execute on function public.update_email_notification_provider_status(text, text) to service_role;

comment on table public.notification_outbox is
  'Server-worker transactional email outbox. Stores safe template payloads and durable event_key dedupe only; no recipient email or secrets.';

comment on function public.enqueue_email_notifications_from_audit_log() is
  'Maps trusted audit events to email outbox rows. Exceptions are swallowed to keep email failure separate from business transactions.';
