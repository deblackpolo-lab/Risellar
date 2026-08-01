-- Disputes, Returns, and Refunds D6: admin/support investigation backend.
-- Forward-only. Adds controlled support/admin dispute actions only: assignment,
-- information requests, approved investigation status changes, non-financial
-- resolution recording, and closure. It does not add UI, returns, refunds,
-- finance holds, settlement/commission/wallet/withdrawal mutations,
-- order/payment/stock/reservation changes, evidence uploads, notifications, or
-- direct dispute-table writes for browser roles.

create table if not exists public.dispute_admin_actions (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  action_type text not null,
  idempotency_key text not null,
  request_fingerprint text not null,
  result_dispute_status text,
  result_assigned_admin_profile_id uuid references public.profiles(id) on delete set null,
  result_message_id uuid references public.dispute_messages(id) on delete set null,
  result_internal_message_id uuid references public.dispute_messages(id) on delete set null,
  result_status_history_id uuid references public.dispute_status_history(id) on delete set null,
  result_resolution_code text,
  created_at timestamptz not null default now(),
  constraint dispute_admin_actions_action_type_allowed check (
    action_type in (
      'assign',
      'request_information',
      'change_status',
      'record_resolution',
      'close'
    )
  ),
  constraint dispute_admin_actions_status_allowed check (
    result_dispute_status is null
    or result_dispute_status in (
      'open',
      'awaiting_customer',
      'awaiting_supplier',
      'under_review',
      'return_review',
      'refund_review',
      'resolved_customer',
      'resolved_supplier',
      'partially_resolved',
      'rejected',
      'cancelled',
      'closed'
    )
  ),
  constraint dispute_admin_actions_key_safe check (
    length(trim(idempotency_key)) between 8 and 140
    and idempotency_key !~* '(password|secret|token|jwt|cookie)'
  ),
  constraint dispute_admin_actions_fingerprint_safe check (
    length(trim(request_fingerprint)) between 8 and 128
    and request_fingerprint !~* '(password|secret|token|jwt|cookie)'
  ),
  unique (dispute_id, actor_profile_id, action_type, idempotency_key)
);

create index if not exists dispute_admin_actions_dispute_created_idx
  on public.dispute_admin_actions(dispute_id, created_at desc);

alter table public.dispute_admin_actions enable row level security;
alter table public.dispute_admin_actions force row level security;
revoke all on public.dispute_admin_actions from public, anon, authenticated;

create or replace function public.current_dispute_support_admin()
returns table (
  profile_id uuid,
  admin_role public.user_role
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, a.admin_role
  from public.profiles p
  join public.admin_staff a on a.profile_id = p.id
  where p.id = public.current_profile_id()
    and p.account_status = 'active'
    and p.deleted_at is null
    and a.staff_status = 'active'
    and a.deleted_at is null
    and a.admin_role in ('support_staff', 'admin', 'super_admin')
  order by
    case a.admin_role
      when 'support_staff' then 1
      when 'admin' then 2
      when 'super_admin' then 3
      else 9
    end,
    a.created_at asc,
    a.id::text asc
  limit 1;
$$;

create or replace function public.dispute_admin_is_active_support_staff(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.admin_staff a on a.profile_id = p.id
    where p.id = p_profile_id
      and p.account_status = 'active'
      and p.deleted_at is null
      and a.staff_status = 'active'
      and a.deleted_at is null
      and a.admin_role in ('support_staff', 'admin', 'super_admin')
  );
$$;

create or replace function public.dispute_admin_message_author_role(p_admin_role public.user_role)
returns text
language sql
immutable
set search_path = public
as $$
  select case when p_admin_role = 'super_admin' then 'super_admin' else 'support_staff' end;
$$;

create or replace function public.dispute_admin_safe_text(
  p_value text,
  p_required boolean,
  p_max_length integer
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_value text := nullif(trim(coalesce(p_value, '')), '');
begin
  if p_required and v_value is null then
    raise exception 'DISPUTE_TEXT_REQUIRED' using errcode = '23514';
  end if;

  if v_value is null then
    return null;
  end if;

  if length(v_value) > p_max_length
    or v_value ~ '<[^>]+>'
    or v_value ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)' then
    raise exception 'INVALID_DISPUTE_TEXT' using errcode = '23514';
  end if;

  return v_value;
end;
$$;

create or replace function public.dispute_admin_valid_transition(
  p_old_status text,
  p_new_status text
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case p_old_status
    when 'open' then p_new_status in ('awaiting_customer', 'awaiting_supplier', 'under_review', 'rejected', 'cancelled')
    when 'awaiting_customer' then p_new_status in ('under_review', 'awaiting_supplier', 'rejected', 'cancelled')
    when 'awaiting_supplier' then p_new_status in ('under_review', 'awaiting_customer', 'rejected', 'cancelled')
    when 'under_review' then p_new_status in ('awaiting_customer', 'awaiting_supplier', 'return_review', 'refund_review', 'rejected', 'cancelled')
    when 'return_review' then p_new_status in ('awaiting_customer', 'awaiting_supplier', 'under_review', 'rejected', 'cancelled')
    when 'refund_review' then p_new_status in ('awaiting_customer', 'awaiting_supplier', 'under_review', 'rejected', 'cancelled')
    else false
  end;
$$;

create or replace function public.dispute_admin_resolution_status(p_resolution_code text)
returns text
language sql
immutable
set search_path = public
as $$
  select case p_resolution_code
    when 'customer_favoured' then 'resolved_customer'
    when 'supplier_favoured' then 'resolved_supplier'
    when 'partial_resolution' then 'partially_resolved'
    when 'replacement_agreed' then 'partially_resolved'
    when 'redelivery_agreed' then 'partially_resolved'
    when 'no_action' then 'resolved_supplier'
    when 'case_rejected' then 'rejected'
    when 'case_cancelled' then 'cancelled'
    when 'accounting_correction_required' then 'partially_resolved'
    when 'return_process_required' then 'partially_resolved'
    when 'refund_review_required' then 'partially_resolved'
    else null
  end;
$$;

create or replace function public.dispute_admin_assert_key(p_idempotency_key text)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
begin
  if v_key is null
    or length(v_key) not between 8 and 140
    or v_key ~* '(password|secret|token|jwt|cookie)' then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '23514';
  end if;

  return v_key;
end;
$$;

create or replace function public.admin_assign_dispute(
  p_dispute_id uuid,
  p_assigned_admin_profile_id uuid,
  p_idempotency_key text
)
returns table (
  dispute_id uuid,
  assigned boolean,
  safe_assignee_label text,
  status text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor_profile_id uuid;
  v_actor_role public.user_role;
  v_key text := public.dispute_admin_assert_key(p_idempotency_key);
  v_fingerprint text := md5(jsonb_build_object('assigned_admin_profile_id', p_assigned_admin_profile_id)::text);
  v_existing public.dispute_admin_actions%rowtype;
  v_dispute public.order_disputes%rowtype;
  v_now timestamptz := now();
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  select c.profile_id, c.admin_role
  into v_actor_profile_id, v_actor_role
  from public.current_dispute_support_admin() c;

  if v_actor_profile_id is null then
    raise exception 'DISPUTE_SUPPORT_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('d6:assign:' || v_actor_profile_id::text || ':' || p_dispute_id::text || ':' || v_key, 0));

  select daa
  into v_existing
  from public.dispute_admin_actions daa
  where daa.dispute_id = p_dispute_id
    and daa.actor_profile_id = v_actor_profile_id
    and daa.action_type = 'assign'
    and daa.idempotency_key = v_key
  limit 1;

  if found then
    if v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    select od
    into v_dispute
    from public.order_disputes od
    where od.id = p_dispute_id
      and od.deleted_at is null;

    if not found then
      raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
    end if;

    dispute_id := p_dispute_id;
    assigned := v_dispute.assigned_admin_profile_id is not null;
    safe_assignee_label := case when v_dispute.assigned_admin_profile_id is null then 'Unassigned' else 'Assigned staff' end;
    status := v_dispute.status;
    updated_at := v_dispute.updated_at;
    return next;
    return;
  end if;

  if p_assigned_admin_profile_id is not null
    and not public.dispute_admin_is_active_support_staff(p_assigned_admin_profile_id) then
    raise exception 'INVALID_ASSIGNEE' using errcode = '42501';
  end if;

  select od
  into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
  for update of od;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.status = 'closed' then
    raise exception 'DISPUTE_CLOSED' using errcode = '23514';
  end if;

  update public.order_disputes od
  set assigned_admin_profile_id = p_assigned_admin_profile_id,
      updated_at = v_now
  where od.id = p_dispute_id;

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    before_data,
    after_data,
    reason,
    created_at
  )
  values (
    v_actor_profile_id,
    v_actor_role,
    case when p_assigned_admin_profile_id is null then 'dispute_unassigned' else 'dispute_assigned' end,
    'order_disputes',
    p_dispute_id,
    jsonb_build_object('status', v_dispute.status, 'was_assigned', v_dispute.assigned_admin_profile_id is not null),
    jsonb_build_object('status', v_dispute.status, 'is_assigned', p_assigned_admin_profile_id is not null, 'actor_role', v_actor_role::text),
    'D6 controlled assignment action',
    v_now
  );

  insert into public.dispute_admin_actions(
    dispute_id,
    actor_profile_id,
    action_type,
    idempotency_key,
    request_fingerprint,
    result_dispute_status,
    result_assigned_admin_profile_id,
    created_at
  )
  values (
    p_dispute_id,
    v_actor_profile_id,
    'assign',
    v_key,
    v_fingerprint,
    v_dispute.status,
    p_assigned_admin_profile_id,
    v_now
  );

  dispute_id := p_dispute_id;
  assigned := p_assigned_admin_profile_id is not null;
  safe_assignee_label := case when p_assigned_admin_profile_id is null then 'Unassigned' else 'Assigned staff' end;
  status := v_dispute.status;
  updated_at := v_now;
  return next;
end;
$fn$;

create or replace function public.admin_request_dispute_information(
  p_dispute_id uuid,
  p_target_role text,
  p_public_message text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  dispute_id uuid,
  message_id uuid,
  internal_message_id uuid,
  status text,
  target_role text,
  created boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor_profile_id uuid;
  v_actor_role public.user_role;
  v_author_role text;
  v_key text := public.dispute_admin_assert_key(p_idempotency_key);
  v_target_role text := nullif(trim(coalesce(p_target_role, '')), '');
  v_public_message text := public.dispute_admin_safe_text(p_public_message, true, 1200);
  v_internal_note text := public.dispute_admin_safe_text(p_internal_note, false, 2000);
  v_fingerprint text;
  v_existing public.dispute_admin_actions%rowtype;
  v_dispute public.order_disputes%rowtype;
  v_now timestamptz := now();
  v_new_status text;
  v_message_id uuid := gen_random_uuid();
  v_internal_message_id uuid := null;
  v_history_id uuid := gen_random_uuid();
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  if v_target_role not in ('customer', 'supplier') then
    raise exception 'INVALID_TARGET_ROLE' using errcode = '23514';
  end if;

  v_fingerprint := md5(jsonb_build_object(
    'target_role', v_target_role,
    'public_message', v_public_message,
    'internal_note_present', v_internal_note is not null
  )::text);

  select c.profile_id, c.admin_role
  into v_actor_profile_id, v_actor_role
  from public.current_dispute_support_admin() c;

  if v_actor_profile_id is null then
    raise exception 'DISPUTE_SUPPORT_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  v_author_role := public.dispute_admin_message_author_role(v_actor_role);

  perform pg_advisory_xact_lock(hashtextextended('d6:request:' || v_actor_profile_id::text || ':' || p_dispute_id::text || ':' || v_key, 0));

  select daa
  into v_existing
  from public.dispute_admin_actions daa
  where daa.dispute_id = p_dispute_id
    and daa.actor_profile_id = v_actor_profile_id
    and daa.action_type = 'request_information'
    and daa.idempotency_key = v_key
  limit 1;

  if found then
    if v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    dispute_id := p_dispute_id;
    message_id := v_existing.result_message_id;
    internal_message_id := v_existing.result_internal_message_id;
    status := v_existing.result_dispute_status;
    target_role := v_target_role;
    created := false;
    updated_at := v_existing.created_at;
    return next;
    return;
  end if;

  select od
  into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
  for update of od;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.status not in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'return_review', 'refund_review') then
    raise exception 'DISPUTE_INFORMATION_REQUEST_NOT_ALLOWED' using errcode = '23514';
  end if;

  if v_target_role = 'supplier' and v_dispute.affected_supplier_id is null then
    raise exception 'SUPPLIER_TARGET_REQUIRED' using errcode = '23514';
  end if;

  v_new_status := case when v_target_role = 'customer' then 'awaiting_customer' else 'awaiting_supplier' end;

  update public.order_disputes od
  set status = v_new_status,
      customer_action_required = (v_target_role = 'customer'),
      supplier_action_required = (v_target_role = 'supplier'),
      updated_at = v_now
  where od.id = p_dispute_id;

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
    v_actor_profile_id,
    v_author_role,
    'admin_request',
    v_public_message,
    case when v_target_role = 'customer' then 'customer_and_admin' else 'supplier_and_admin' end,
    false,
    v_now,
    'd6-req-msg:' || md5(v_key)
  );

  if v_internal_note is not null then
    v_internal_message_id := gen_random_uuid();

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
      v_internal_message_id,
      p_dispute_id,
      v_actor_profile_id,
      v_author_role,
      'internal_admin_note',
      v_internal_note,
      'admin_only',
      false,
      v_now,
      'd6-req-int:' || md5(v_key)
    );
  end if;

  insert into public.dispute_status_history(
    id,
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
    v_history_id,
    p_dispute_id,
    v_dispute.status,
    v_new_status,
    v_actor_profile_id,
    v_author_role,
    'admin_request',
    'Information requested from ' || v_target_role || '.',
    null,
    v_now,
    'd6-req-hist:' || md5(v_key)
  );

  insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, before_data, after_data, reason, created_at)
  values
    (
      v_actor_profile_id,
      v_actor_role,
      'dispute_information_requested',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object('status', v_dispute.status),
      jsonb_build_object('status', v_new_status, 'target_role', v_target_role, 'internal_note_present', v_internal_note is not null),
      'D6 controlled information request',
      v_now
    );

  if v_dispute.status <> v_new_status then
    insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, before_data, after_data, reason, created_at)
    values (
      v_actor_profile_id,
      v_actor_role,
      'dispute_status_changed',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object('status', v_dispute.status),
      jsonb_build_object('status', v_new_status),
      'D6 information request status change',
      v_now
    );
  end if;

  insert into public.dispute_admin_actions(
    dispute_id,
    actor_profile_id,
    action_type,
    idempotency_key,
    request_fingerprint,
    result_dispute_status,
    result_message_id,
    result_internal_message_id,
    result_status_history_id,
    created_at
  )
  values (
    p_dispute_id,
    v_actor_profile_id,
    'request_information',
    v_key,
    v_fingerprint,
    v_new_status,
    v_message_id,
    v_internal_message_id,
    v_history_id,
    v_now
  );

  dispute_id := p_dispute_id;
  message_id := v_message_id;
  internal_message_id := v_internal_message_id;
  status := v_new_status;
  target_role := v_target_role;
  created := true;
  updated_at := v_now;
  return next;
end;
$fn$;

create or replace function public.admin_change_dispute_status(
  p_dispute_id uuid,
  p_new_status text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  dispute_id uuid,
  status text,
  created boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor_profile_id uuid;
  v_actor_role public.user_role;
  v_author_role text;
  v_key text := public.dispute_admin_assert_key(p_idempotency_key);
  v_new_status text := nullif(trim(coalesce(p_new_status, '')), '');
  v_public_note text := public.dispute_admin_safe_text(p_public_note, false, 1200);
  v_internal_note text := public.dispute_admin_safe_text(p_internal_note, false, 2000);
  v_fingerprint text;
  v_existing public.dispute_admin_actions%rowtype;
  v_dispute public.order_disputes%rowtype;
  v_now timestamptz := now();
  v_public_message_id uuid := null;
  v_internal_message_id uuid := null;
  v_history_id uuid := gen_random_uuid();
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  if v_new_status not in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'return_review', 'refund_review', 'rejected', 'cancelled') then
    raise exception 'INVALID_D6_STATUS' using errcode = '23514';
  end if;

  v_fingerprint := md5(jsonb_build_object(
    'new_status', v_new_status,
    'public_note_present', v_public_note is not null,
    'internal_note_present', v_internal_note is not null
  )::text);

  select c.profile_id, c.admin_role
  into v_actor_profile_id, v_actor_role
  from public.current_dispute_support_admin() c;

  if v_actor_profile_id is null then
    raise exception 'DISPUTE_SUPPORT_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  v_author_role := public.dispute_admin_message_author_role(v_actor_role);

  perform pg_advisory_xact_lock(hashtextextended('d6:status:' || v_actor_profile_id::text || ':' || p_dispute_id::text || ':' || v_key, 0));

  select daa
  into v_existing
  from public.dispute_admin_actions daa
  where daa.dispute_id = p_dispute_id
    and daa.actor_profile_id = v_actor_profile_id
    and daa.action_type = 'change_status'
    and daa.idempotency_key = v_key
  limit 1;

  if found then
    if v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    dispute_id := p_dispute_id;
    status := v_existing.result_dispute_status;
    created := false;
    updated_at := v_existing.created_at;
    return next;
    return;
  end if;

  select od
  into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
  for update of od;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if not public.dispute_admin_valid_transition(v_dispute.status, v_new_status) then
    raise exception 'INVALID_STATUS_TRANSITION' using errcode = '23514';
  end if;

  if v_new_status = 'awaiting_supplier' and v_dispute.affected_supplier_id is null then
    raise exception 'SUPPLIER_TARGET_REQUIRED' using errcode = '23514';
  end if;

  update public.order_disputes od
  set status = v_new_status,
      customer_action_required = (v_new_status = 'awaiting_customer'),
      supplier_action_required = (v_new_status = 'awaiting_supplier'),
      updated_at = v_now
  where od.id = p_dispute_id;

  if v_public_note is not null then
    v_public_message_id := gen_random_uuid();

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
      v_public_message_id,
      p_dispute_id,
      v_actor_profile_id,
      v_author_role,
      'public_admin_note',
      v_public_note,
      'all_case_participants',
      false,
      v_now,
      'd6-stat-pub:' || md5(v_key)
    );
  end if;

  if v_internal_note is not null then
    v_internal_message_id := gen_random_uuid();

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
      v_internal_message_id,
      p_dispute_id,
      v_actor_profile_id,
      v_author_role,
      'internal_admin_note',
      v_internal_note,
      'admin_only',
      false,
      v_now,
      'd6-stat-int:' || md5(v_key)
    );
  end if;

  insert into public.dispute_status_history(
    id,
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
    v_history_id,
    p_dispute_id,
    v_dispute.status,
    v_new_status,
    v_actor_profile_id,
    v_author_role,
    case when v_new_status = 'return_review' then 'return_review' when v_new_status = 'refund_review' then 'refund_review' when v_new_status = 'cancelled' then 'case_cancelled' else 'admin_review' end,
    v_public_note,
    null,
    v_now,
    'd6-stat-hist:' || md5(v_key)
  );

  insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, before_data, after_data, reason, created_at)
  values (
    v_actor_profile_id,
    v_actor_role,
    'dispute_status_changed',
    'order_disputes',
    p_dispute_id,
    jsonb_build_object('status', v_dispute.status),
    jsonb_build_object('status', v_new_status, 'public_note_present', v_public_note is not null, 'internal_note_present', v_internal_note is not null),
    'D6 controlled status transition',
    v_now
  );

  if v_internal_note is not null then
    insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, after_data, reason, created_at)
    values (
      v_actor_profile_id,
      v_actor_role,
      'dispute_admin_note_added',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object('visibility', 'admin_only'),
      'D6 internal note recorded',
      v_now
    );
  end if;

  insert into public.dispute_admin_actions(
    dispute_id,
    actor_profile_id,
    action_type,
    idempotency_key,
    request_fingerprint,
    result_dispute_status,
    result_message_id,
    result_internal_message_id,
    result_status_history_id,
    created_at
  )
  values (
    p_dispute_id,
    v_actor_profile_id,
    'change_status',
    v_key,
    v_fingerprint,
    v_new_status,
    v_public_message_id,
    v_internal_message_id,
    v_history_id,
    v_now
  );

  dispute_id := p_dispute_id;
  status := v_new_status;
  created := true;
  updated_at := v_now;
  return next;
end;
$fn$;

create or replace function public.admin_record_non_financial_resolution(
  p_dispute_id uuid,
  p_resolution_code text,
  p_public_resolution_message text,
  p_internal_resolution_notes text,
  p_idempotency_key text
)
returns table (
  dispute_id uuid,
  resolution_code text,
  status text,
  created boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor_profile_id uuid;
  v_actor_role public.user_role;
  v_author_role text;
  v_key text := public.dispute_admin_assert_key(p_idempotency_key);
  v_resolution_code text := nullif(trim(coalesce(p_resolution_code, '')), '');
  v_public_message text := public.dispute_admin_safe_text(p_public_resolution_message, true, 1200);
  v_internal_notes text := public.dispute_admin_safe_text(p_internal_resolution_notes, false, 2000);
  v_new_status text;
  v_fingerprint text;
  v_existing public.dispute_admin_actions%rowtype;
  v_dispute public.order_disputes%rowtype;
  v_now timestamptz := now();
  v_internal_message_id uuid := null;
  v_history_id uuid := gen_random_uuid();
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  v_new_status := public.dispute_admin_resolution_status(v_resolution_code);

  if v_new_status is null then
    raise exception 'INVALID_RESOLUTION_CODE' using errcode = '23514';
  end if;

  v_fingerprint := md5(jsonb_build_object(
    'resolution_code', v_resolution_code,
    'public_message', v_public_message,
    'internal_notes_present', v_internal_notes is not null
  )::text);

  select c.profile_id, c.admin_role
  into v_actor_profile_id, v_actor_role
  from public.current_dispute_support_admin() c;

  if v_actor_profile_id is null then
    raise exception 'DISPUTE_SUPPORT_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  v_author_role := public.dispute_admin_message_author_role(v_actor_role);

  perform pg_advisory_xact_lock(hashtextextended('d6:resolution:' || p_dispute_id::text, 0));

  select daa
  into v_existing
  from public.dispute_admin_actions daa
  where daa.dispute_id = p_dispute_id
    and daa.actor_profile_id = v_actor_profile_id
    and daa.action_type = 'record_resolution'
    and daa.idempotency_key = v_key
  limit 1;

  if found then
    if v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    dispute_id := p_dispute_id;
    resolution_code := v_existing.result_resolution_code;
    status := v_existing.result_dispute_status;
    created := false;
    updated_at := v_existing.created_at;
    return next;
    return;
  end if;

  select od
  into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
  for update of od;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.status not in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'return_review', 'refund_review') then
    raise exception 'DISPUTE_RESOLUTION_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_disputes od
  set status = v_new_status,
      resolution_code = v_resolution_code,
      resolution_summary = v_public_message,
      public_resolution_message = v_public_message,
      internal_resolution_notes = v_internal_notes,
      customer_action_required = false,
      supplier_action_required = false,
      resolved_at = coalesce(od.resolved_at, v_now),
      updated_at = v_now
  where od.id = p_dispute_id;

  if v_internal_notes is not null then
    v_internal_message_id := gen_random_uuid();

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
      v_internal_message_id,
      p_dispute_id,
      v_actor_profile_id,
      v_author_role,
      'internal_admin_note',
      v_internal_notes,
      'admin_only',
      false,
      v_now,
      'd6-res-int:' || md5(v_key)
    );
  end if;

  insert into public.dispute_status_history(
    id,
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
    v_history_id,
    p_dispute_id,
    v_dispute.status,
    v_new_status,
    v_actor_profile_id,
    v_author_role,
    case when v_new_status = 'cancelled' then 'case_cancelled' else 'resolution_recorded' end,
    v_public_message,
    null,
    v_now,
    'd6-res-hist:' || md5(v_key)
  );

  insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, before_data, after_data, reason, created_at)
  values
    (
      v_actor_profile_id,
      v_actor_role,
      'dispute_resolution_recorded',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object('status', v_dispute.status),
      jsonb_build_object('status', v_new_status, 'resolution_code', v_resolution_code, 'internal_notes_present', v_internal_notes is not null),
      'D6 controlled non-financial resolution',
      v_now
    ),
    (
      v_actor_profile_id,
      v_actor_role,
      'dispute_status_changed',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object('status', v_dispute.status),
      jsonb_build_object('status', v_new_status),
      'D6 resolution status change',
      v_now
    );

  if v_internal_notes is not null then
    insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, after_data, reason, created_at)
    values (
      v_actor_profile_id,
      v_actor_role,
      'dispute_admin_note_added',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object('visibility', 'admin_only'),
      'D6 internal resolution note recorded',
      v_now
    );
  end if;

  insert into public.dispute_admin_actions(
    dispute_id,
    actor_profile_id,
    action_type,
    idempotency_key,
    request_fingerprint,
    result_dispute_status,
    result_internal_message_id,
    result_status_history_id,
    result_resolution_code,
    created_at
  )
  values (
    p_dispute_id,
    v_actor_profile_id,
    'record_resolution',
    v_key,
    v_fingerprint,
    v_new_status,
    v_internal_message_id,
    v_history_id,
    v_resolution_code,
    v_now
  );

  dispute_id := p_dispute_id;
  resolution_code := v_resolution_code;
  status := v_new_status;
  created := true;
  updated_at := v_now;
  return next;
end;
$fn$;

create or replace function public.admin_close_dispute(
  p_dispute_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  dispute_id uuid,
  status text,
  created boolean,
  closed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor_profile_id uuid;
  v_actor_role public.user_role;
  v_author_role text;
  v_key text := public.dispute_admin_assert_key(p_idempotency_key);
  v_public_note text := public.dispute_admin_safe_text(p_public_note, false, 1200);
  v_internal_note text := public.dispute_admin_safe_text(p_internal_note, false, 2000);
  v_fingerprint text;
  v_existing public.dispute_admin_actions%rowtype;
  v_dispute public.order_disputes%rowtype;
  v_now timestamptz := now();
  v_public_message_id uuid := null;
  v_internal_message_id uuid := null;
  v_history_id uuid := gen_random_uuid();
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  v_fingerprint := md5(jsonb_build_object(
    'public_note_present', v_public_note is not null,
    'internal_note_present', v_internal_note is not null
  )::text);

  select c.profile_id, c.admin_role
  into v_actor_profile_id, v_actor_role
  from public.current_dispute_support_admin() c;

  if v_actor_profile_id is null then
    raise exception 'DISPUTE_SUPPORT_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  v_author_role := public.dispute_admin_message_author_role(v_actor_role);

  perform pg_advisory_xact_lock(hashtextextended('d6:close:' || p_dispute_id::text, 0));

  select daa
  into v_existing
  from public.dispute_admin_actions daa
  where daa.dispute_id = p_dispute_id
    and daa.actor_profile_id = v_actor_profile_id
    and daa.action_type = 'close'
    and daa.idempotency_key = v_key
  limit 1;

  if found then
    if v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    dispute_id := p_dispute_id;
    status := v_existing.result_dispute_status;
    created := false;
    closed_at := v_existing.created_at;
    return next;
    return;
  end if;

  select od
  into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
  for update of od;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.status not in ('resolved_customer', 'resolved_supplier', 'partially_resolved', 'rejected', 'cancelled') then
    raise exception 'DISPUTE_CLOSE_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_disputes od
  set status = 'closed',
      customer_action_required = false,
      supplier_action_required = false,
      closed_at = coalesce(od.closed_at, v_now),
      updated_at = v_now
  where od.id = p_dispute_id;

  if v_public_note is not null then
    v_public_message_id := gen_random_uuid();

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
      v_public_message_id,
      p_dispute_id,
      v_actor_profile_id,
      v_author_role,
      'public_admin_note',
      v_public_note,
      'all_case_participants',
      false,
      v_now,
      'd6-close-pub:' || md5(v_key)
    );
  end if;

  if v_internal_note is not null then
    v_internal_message_id := gen_random_uuid();

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
      v_internal_message_id,
      p_dispute_id,
      v_actor_profile_id,
      v_author_role,
      'internal_admin_note',
      v_internal_note,
      'admin_only',
      false,
      v_now,
      'd6-close-int:' || md5(v_key)
    );
  end if;

  insert into public.dispute_status_history(
    id,
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
    v_history_id,
    p_dispute_id,
    v_dispute.status,
    'closed',
    v_actor_profile_id,
    v_author_role,
    'case_closed',
    v_public_note,
    null,
    v_now,
    'd6-close-hist:' || md5(v_key)
  );

  insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, before_data, after_data, reason, created_at)
  values (
    v_actor_profile_id,
    v_actor_role,
    'dispute_closed',
    'order_disputes',
    p_dispute_id,
    jsonb_build_object('status', v_dispute.status),
    jsonb_build_object('status', 'closed', 'public_note_present', v_public_note is not null, 'internal_note_present', v_internal_note is not null),
    'D6 controlled closure',
    v_now
  );

  insert into public.dispute_admin_actions(
    dispute_id,
    actor_profile_id,
    action_type,
    idempotency_key,
    request_fingerprint,
    result_dispute_status,
    result_message_id,
    result_internal_message_id,
    result_status_history_id,
    created_at
  )
  values (
    p_dispute_id,
    v_actor_profile_id,
    'close',
    v_key,
    v_fingerprint,
    'closed',
    v_public_message_id,
    v_internal_message_id,
    v_history_id,
    v_now
  );

  dispute_id := p_dispute_id;
  status := 'closed';
  created := true;
  closed_at := v_now;
  return next;
end;
$fn$;

revoke all on function public.current_dispute_support_admin() from public, anon, authenticated;
revoke all on function public.dispute_admin_is_active_support_staff(uuid) from public, anon, authenticated;
revoke all on function public.dispute_admin_message_author_role(public.user_role) from public, anon, authenticated;
revoke all on function public.dispute_admin_safe_text(text, boolean, integer) from public, anon, authenticated;
revoke all on function public.dispute_admin_valid_transition(text, text) from public, anon, authenticated;
revoke all on function public.dispute_admin_resolution_status(text) from public, anon, authenticated;
revoke all on function public.dispute_admin_assert_key(text) from public, anon, authenticated;

revoke all on function public.admin_assign_dispute(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.admin_assign_dispute(uuid, uuid, text) to authenticated;

revoke all on function public.admin_request_dispute_information(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_request_dispute_information(uuid, text, text, text, text) to authenticated;

revoke all on function public.admin_change_dispute_status(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_change_dispute_status(uuid, text, text, text, text) to authenticated;

revoke all on function public.admin_record_non_financial_resolution(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_record_non_financial_resolution(uuid, text, text, text, text) to authenticated;

revoke all on function public.admin_close_dispute(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_close_dispute(uuid, text, text, text) to authenticated;

comment on table public.dispute_admin_actions is
  'D6 support/admin dispute action idempotency log. Browser roles have no direct table grants.';

comment on function public.admin_assign_dispute(uuid, uuid, text) is
  'D6 controlled support/admin assignment RPC. Does not mutate order, payment, stock, finance, return, refund, notification, wallet, withdrawal, settlement, or commission state.';

comment on function public.admin_request_dispute_information(uuid, text, text, text, text) is
  'D6 controlled support/admin information-request RPC. Public messages are targeted; internal notes remain admin_only.';

comment on function public.admin_change_dispute_status(uuid, text, text, text, text) is
  'D6 explicit investigation status transition RPC. Does not set resolved or closed statuses.';

comment on function public.admin_record_non_financial_resolution(uuid, text, text, text, text) is
  'D6 explicit non-financial resolution RPC. Records decision only; no return/refund/finance/stock/order side effects.';

comment on function public.admin_close_dispute(uuid, text, text, text) is
  'D6 explicit closure RPC for eligible resolved/rejected/cancelled disputes only.';
