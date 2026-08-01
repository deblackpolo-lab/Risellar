-- Disputes D4: customer dispute open/respond mutation RPCs.
-- Development-approved forward migration. This adds only customer-scoped
-- dispute creation and customer response RPCs. It does not add UI, supplier
-- mutations, admin resolution, returns, refunds, finance holds, order/payment
-- changes, stock/reservation changes, settlement/commission/wallet/withdrawal
-- changes, evidence uploads, notifications, or provider integrations.

alter table public.dispute_messages
  add column if not exists idempotency_key text;

alter table public.dispute_messages
  drop constraint if exists dispute_messages_idempotency_key_safe;

alter table public.dispute_messages
  add constraint dispute_messages_idempotency_key_safe
  check (
    idempotency_key is null
    or (
      length(trim(idempotency_key)) between 8 and 140
      and idempotency_key !~* '(password|secret|token|jwt|cookie)'
    )
  );

create unique index if not exists dispute_messages_author_idempotency_unique
  on public.dispute_messages(dispute_id, author_profile_id, idempotency_key)
  where idempotency_key is not null and deleted_at is null;

create or replace function public.customer_dispute_valid_reason_category(
  p_dispute_category text,
  p_reason_code text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_dispute_category = 'pre_delivery' then p_reason_code in (
      'supplier_not_responding',
      'supplier_rejected_status_incorrect',
      'order_stuck_in_preparation',
      'delivery_not_arranged',
      'delivery_delay',
      'customer_requests_cancellation',
      'other'
    )
    when p_dispute_category = 'delivery' then p_reason_code in (
      'delivery_not_arranged',
      'delivery_delay',
      'order_not_received',
      'wrong_item_received',
      'damaged_item_received',
      'incomplete_order',
      'unsafe_delivery_issue',
      'delivery_fee_disagreement',
      'other'
    )
    when p_dispute_category = 'payment' then p_reason_code in (
      'customer_paid_not_reported',
      'supplier_reported_customer_disagrees',
      'duplicate_payment_claim',
      'wrong_amount_collected',
      'unauthorised_extra_charge',
      'refund_requested',
      'other'
    )
    when p_dispute_category = 'post_completion' then p_reason_code in (
      'wrong_item_received',
      'damaged_item_received',
      'incomplete_order',
      'item_not_as_described',
      'product_quality_issue',
      'return_requested',
      'refund_requested',
      'other'
    )
    when p_dispute_category = 'other' then p_reason_code = 'other'
    else false
  end;
$$;

create or replace function public.customer_dispute_reason_allowed_for_order_status(
  p_reason_code text,
  p_order_status text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_reason_code = 'supplier_not_responding' then p_order_status in ('placed_pending_confirmation')
    when p_reason_code = 'supplier_rejected_status_incorrect' then p_order_status in ('supplier_rejected')
    when p_reason_code = 'order_stuck_in_preparation' then p_order_status in ('supplier_confirmed', 'supplier_preparing')
    when p_reason_code = 'delivery_not_arranged' then p_order_status in ('ready_for_delivery', 'ready_for_pickup_or_dispatch')
    when p_reason_code = 'delivery_delay' then p_order_status in ('delivery_arranged', 'out_for_delivery')
    when p_reason_code = 'customer_requests_cancellation' then p_order_status in ('placed_pending_confirmation', 'supplier_confirmed', 'supplier_preparing')
    when p_reason_code = 'order_not_received' then p_order_status in ('out_for_delivery', 'delivered', 'delivered_payment_pending')
    when p_reason_code in ('wrong_item_received', 'damaged_item_received', 'incomplete_order', 'item_not_as_described', 'product_quality_issue', 'return_requested', 'refund_requested')
      then p_order_status in ('delivered', 'delivered_payment_pending', 'payment_reported', 'completed')
    when p_reason_code in ('unsafe_delivery_issue', 'delivery_fee_disagreement')
      then p_order_status in ('delivery_arranged', 'out_for_delivery', 'delivered', 'delivered_payment_pending', 'payment_reported', 'completed')
    when p_reason_code = 'customer_paid_not_reported' then p_order_status in ('delivered', 'delivered_payment_pending')
    when p_reason_code in ('supplier_reported_customer_disagrees', 'duplicate_payment_claim', 'wrong_amount_collected', 'unauthorised_extra_charge')
      then p_order_status in ('payment_reported', 'completed')
    when p_reason_code = 'other'
      then p_order_status in (
        'placed_pending_confirmation',
        'supplier_confirmed',
        'supplier_preparing',
        'ready_for_delivery',
        'ready_for_pickup_or_dispatch',
        'delivery_arranged',
        'out_for_delivery',
        'delivered',
        'delivered_payment_pending',
        'payment_reported',
        'completed'
      )
    else false
  end;
$$;

create or replace function public.customer_open_order_dispute(
  p_order_id uuid,
  p_dispute_category text,
  p_reason_code text,
  p_requested_outcome text,
  p_description text,
  p_idempotency_key text
)
returns table (
  dispute_id uuid,
  status text,
  created boolean,
  opened_at timestamptz,
  safe_order_reference text
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
  v_customer_id uuid;
  v_category text := nullif(trim(coalesce(p_dispute_category, '')), '');
  v_reason text := nullif(trim(coalesce(p_reason_code, '')), '');
  v_outcome text := nullif(trim(coalesce(p_requested_outcome, '')), '');
  v_description text := nullif(trim(coalesce(p_description, '')), '');
  v_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_order record;
  v_existing public.order_disputes%rowtype;
  v_dispute_id uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_supplier_action_required boolean;
  v_finance_review_required boolean;
  v_return_review_required boolean;
begin
  if p_order_id is null then
    raise exception 'ORDER_ID_REQUIRED' using errcode = '23514';
  end if;

  v_profile_id := public.current_profile_id();
  v_customer_id := public.current_dispute_customer_id();

  if v_profile_id is null or v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  if v_key is null
    or length(v_key) not between 8 and 140
    or v_key ~* '(password|secret|token|jwt|cookie)' then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '23514';
  end if;

  if v_category is null or v_category not in ('pre_delivery', 'delivery', 'payment', 'post_completion', 'other') then
    raise exception 'INVALID_DISPUTE_CATEGORY' using errcode = '23514';
  end if;

  if v_reason is null or v_reason not in (
    'supplier_not_responding',
    'supplier_rejected_status_incorrect',
    'order_stuck_in_preparation',
    'delivery_not_arranged',
    'delivery_delay',
    'customer_requests_cancellation',
    'order_not_received',
    'wrong_item_received',
    'damaged_item_received',
    'incomplete_order',
    'unsafe_delivery_issue',
    'delivery_fee_disagreement',
    'customer_paid_not_reported',
    'supplier_reported_customer_disagrees',
    'duplicate_payment_claim',
    'wrong_amount_collected',
    'unauthorised_extra_charge',
    'item_not_as_described',
    'product_quality_issue',
    'return_requested',
    'refund_requested',
    'other'
  ) then
    raise exception 'INVALID_REASON_CODE' using errcode = '23514';
  end if;

  if v_outcome is null or v_outcome not in (
    'information_only',
    'cancellation',
    'redelivery',
    'replacement',
    'return',
    'full_refund',
    'partial_refund',
    'delivery_fee_refund',
    'accounting_correction',
    'other'
  ) then
    raise exception 'INVALID_REQUESTED_OUTCOME' using errcode = '23514';
  end if;

  if not public.customer_dispute_valid_reason_category(v_category, v_reason) then
    raise exception 'INVALID_REASON_CATEGORY' using errcode = '23514';
  end if;

  if v_description is null
    or length(v_description) not between 1 and 1200
    or v_description ~ '<[^>]+>'
    or v_description ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)' then
    raise exception 'INVALID_DESCRIPTION' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('customer_open_order_dispute:key:' || v_profile_id::text || ':' || v_key, 0));

  select *
  into v_existing
  from public.order_disputes od
  where od.opened_by_profile_id = v_profile_id
    and od.idempotency_key = v_key
    and od.deleted_at is null
  order by od.created_at asc, od.id::text asc
  limit 1;

  if found then
    select o.order_number
    into v_order
    from public.orders o
    where o.id = v_existing.order_id
      and o.customer_id = v_customer_id
      and o.deleted_at is null;

    if not found
      or v_existing.order_id <> p_order_id
      or v_existing.dispute_category <> v_category
      or v_existing.reason_code <> v_reason
      or v_existing.requested_outcome <> v_outcome
      or coalesce(v_existing.description, '') <> v_description then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    dispute_id := v_existing.id;
    status := v_existing.status;
    created := false;
    opened_at := v_existing.opened_at;
    safe_order_reference := v_order.order_number;
    return next;
    return;
  end if;

  select o.id, o.order_number, o.order_status::text as order_status
  into v_order
  from public.orders o
  where o.id = p_order_id
    and o.customer_id = v_customer_id
    and o.deleted_at is null
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = '42501';
  end if;

  if not public.customer_dispute_reason_allowed_for_order_status(v_reason, v_order.order_status) then
    raise exception 'DISPUTE_NOT_ALLOWED_FOR_ORDER_STATE' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('customer_open_order_dispute:fingerprint:' || v_profile_id::text || ':' || p_order_id::text || ':' || v_reason, 0));

  select *
  into v_existing
  from public.order_disputes od
  where od.order_id = p_order_id
    and od.opened_by_profile_id = v_profile_id
    and od.reason_code = v_reason
    and od.deleted_at is null
    and od.status not in ('closed', 'cancelled', 'rejected')
  order by od.opened_at asc, od.id::text asc
  limit 1;

  if found then
    if v_existing.dispute_category = v_category
      and v_existing.requested_outcome = v_outcome
      and coalesce(v_existing.description, '') = v_description then
      dispute_id := v_existing.id;
      status := v_existing.status;
      created := false;
      opened_at := v_existing.opened_at;
      safe_order_reference := v_order.order_number;
      return next;
      return;
    end if;

    raise exception 'DUPLICATE_ACTIVE_DISPUTE' using errcode = '23505';
  end if;

  v_finance_review_required := v_category = 'payment'
    or v_reason in (
      'customer_paid_not_reported',
      'supplier_reported_customer_disagrees',
      'duplicate_payment_claim',
      'wrong_amount_collected',
      'unauthorised_extra_charge',
      'refund_requested'
    )
    or v_outcome in ('full_refund', 'partial_refund', 'delivery_fee_refund', 'accounting_correction');

  v_return_review_required := v_reason = 'return_requested' or v_outcome = 'return';

  v_supplier_action_required := v_reason not in (
    'customer_paid_not_reported',
    'duplicate_payment_claim',
    'wrong_amount_collected',
    'unauthorised_extra_charge'
  );

  insert into public.order_disputes(
    id,
    order_id,
    opened_by_profile_id,
    opened_by_role,
    dispute_category,
    reason_code,
    description,
    requested_outcome,
    status,
    priority,
    customer_action_required,
    supplier_action_required,
    finance_review_required,
    return_review_required,
    opened_at,
    created_at,
    updated_at,
    idempotency_key
  )
  values (
    v_dispute_id,
    p_order_id,
    v_profile_id,
    'customer',
    v_category,
    v_reason,
    v_description,
    v_outcome,
    'open',
    'normal',
    false,
    v_supplier_action_required,
    v_finance_review_required,
    v_return_review_required,
    v_now,
    v_now,
    v_now,
    v_key
  );

  insert into public.dispute_messages(
    dispute_id,
    author_profile_id,
    author_role,
    message_type,
    body,
    visibility,
    is_system_message,
    created_at
  )
  values (
    v_dispute_id,
    v_profile_id,
    'customer',
    'participant_response',
    v_description,
    'customer_and_admin',
    false,
    v_now
  );

  insert into public.dispute_status_history(
    dispute_id,
    previous_status,
    new_status,
    changed_by_profile_id,
    changed_by_role,
    reason_code,
    public_note,
    internal_note,
    created_at,
    idempotency_key
  )
  values (
    v_dispute_id,
    null,
    'open',
    v_profile_id,
    'customer',
    'system_event',
    'Dispute opened by customer.',
    null,
    v_now,
    'open:' || v_key
  );

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    after_data,
    reason,
    created_at
  )
  values (
    v_profile_id,
    'customer',
    'dispute_opened',
    'order_disputes',
    v_dispute_id,
    jsonb_build_object(
      'order_id', p_order_id,
      'category', v_category,
      'reason_code', v_reason,
      'requested_outcome', v_outcome,
      'status', 'open',
      'idempotency_key_present', true
    ),
    'customer opened dispute',
    v_now
  );

  dispute_id := v_dispute_id;
  status := 'open';
  created := true;
  opened_at := v_now;
  safe_order_reference := v_order.order_number;
  return next;
end;
$fn$;

create or replace function public.customer_add_dispute_response(
  p_dispute_id uuid,
  p_body text,
  p_idempotency_key text
)
returns table (
  message_id uuid,
  dispute_id uuid,
  created boolean,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
  v_customer_id uuid;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_dispute record;
  v_existing_message public.dispute_messages%rowtype;
  v_message_id uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_new_status text;
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  v_profile_id := public.current_profile_id();
  v_customer_id := public.current_dispute_customer_id();

  if v_profile_id is null or v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  if v_key is null
    or length(v_key) not between 8 and 140
    or v_key ~* '(password|secret|token|jwt|cookie)' then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '23514';
  end if;

  if v_body is null
    or length(v_body) not between 1 and 2000
    or v_body ~ '<[^>]+>'
    or v_body ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)' then
    raise exception 'INVALID_RESPONSE_BODY' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('customer_add_dispute_response:key:' || v_profile_id::text || ':' || p_dispute_id::text || ':' || v_key, 0));

  select *
  into v_existing_message
  from public.dispute_messages dm
  where dm.dispute_id = p_dispute_id
    and dm.author_profile_id = v_profile_id
    and dm.idempotency_key = v_key
    and dm.deleted_at is null
  order by dm.created_at asc, dm.id::text asc
  limit 1;

  if found then
    select od.status
    into v_new_status
    from public.order_disputes od
    join public.orders o on o.id = od.order_id and o.deleted_at is null
    where od.id = p_dispute_id
      and od.deleted_at is null
      and o.customer_id = v_customer_id;

    if v_new_status is null or coalesce(v_existing_message.body, '') <> v_body then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    message_id := v_existing_message.id;
    dispute_id := p_dispute_id;
    created := false;
    status := v_new_status;
    created_at := v_existing_message.created_at;
    return next;
    return;
  end if;

  select
    od.id,
    od.status,
    od.customer_action_required
  into v_dispute
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  where od.id = p_dispute_id
    and od.deleted_at is null
    and o.customer_id = v_customer_id
  for update of od;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.status not in ('open', 'awaiting_customer', 'under_review', 'return_review', 'refund_review') then
    raise exception 'DISPUTE_RESPONSE_NOT_ALLOWED' using errcode = '23514';
  end if;

  insert into public.dispute_messages(
    id,
    dispute_id,
    author_profile_id,
    author_role,
    message_type,
    body,
    visibility,
    is_system_message,
    created_at,
    idempotency_key
  )
  values (
    v_message_id,
    p_dispute_id,
    v_profile_id,
    'customer',
    'participant_response',
    v_body,
    'customer_and_admin',
    false,
    v_now,
    v_key
  );

  v_new_status := v_dispute.status;

  if v_dispute.status = 'awaiting_customer' then
    update public.order_disputes od
    set status = 'under_review',
        customer_action_required = false,
        updated_at = v_now
    where od.id = p_dispute_id;

    v_new_status := 'under_review';

    insert into public.dispute_status_history(
      dispute_id,
      previous_status,
      new_status,
      changed_by_profile_id,
      changed_by_role,
      reason_code,
      public_note,
      internal_note,
      created_at,
      idempotency_key
    )
    values (
      p_dispute_id,
      'awaiting_customer',
      'under_review',
      v_profile_id,
      'customer',
      'customer_response',
      'Customer responded. Case is back under review.',
      null,
      v_now,
      'response-status:' || v_key
    );

    insert into public.audit_logs(
      actor_profile_id,
      actor_role,
      action,
      target_entity_type,
      target_entity_id,
      after_data,
      reason,
      created_at
    )
    values (
      v_profile_id,
      'customer',
      'dispute_status_changed',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object(
        'old_status', 'awaiting_customer',
        'new_status', 'under_review',
        'actor_role', 'customer',
        'idempotency_key_present', true
      ),
      'customer response moved dispute under review',
      v_now
    );
  else
    update public.order_disputes od
    set updated_at = v_now
    where od.id = p_dispute_id;
  end if;

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    after_data,
    reason,
    created_at
  )
  values (
    v_profile_id,
    'customer',
    'dispute_customer_response_added',
    'dispute_messages',
    v_message_id,
    jsonb_build_object(
      'dispute_id', p_dispute_id,
      'status', v_new_status,
      'idempotency_key_present', true
    ),
    'customer added dispute response',
    v_now
  );

  message_id := v_message_id;
  dispute_id := p_dispute_id;
  created := true;
  status := v_new_status;
  created_at := v_now;
  return next;
end;
$fn$;

revoke all on function public.customer_dispute_valid_reason_category(text, text) from public, anon, authenticated;
revoke all on function public.customer_dispute_reason_allowed_for_order_status(text, text) from public, anon, authenticated;

revoke all on function public.customer_open_order_dispute(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.customer_open_order_dispute(uuid, text, text, text, text, text) to authenticated;

revoke all on function public.customer_add_dispute_response(uuid, text, text) from public, anon, authenticated;
grant execute on function public.customer_add_dispute_response(uuid, text, text) to authenticated;

comment on function public.customer_open_order_dispute(uuid, text, text, text, text, text) is
  'D4 customer-only audited dispute creation RPC. Resolves customer identity server-side, validates reason/state eligibility, writes initial case/message/history/audit rows, and does not mutate order/payment/finance/stock/business state.';

comment on function public.customer_add_dispute_response(uuid, text, text) is
  'D4 customer-only audited dispute response RPC. Resolves customer identity server-side, appends customer-safe text response, optionally moves awaiting_customer to under_review, and does not mutate order/payment/finance/stock/business state.';
