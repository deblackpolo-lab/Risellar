-- Disputes, Returns, and Refunds D7: return workflow backend foundation.
-- Backend-only, forward-only. Does not issue refunds, create finance holds,
-- mutate stock/reservations, create delivery provider work, or activate UI.

create table if not exists public.order_item_returns (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  customer_profile_id uuid not null references public.profiles(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  requested_quantity integer not null,
  approved_quantity integer,
  requested_method text not null,
  approved_method text,
  delivery_fee_responsibility text not null default 'pending_decision',
  inspection_condition text not null default 'inspection_pending',
  inventory_outcome text not null default 'pending',
  status text not null default 'requested',
  customer_note text,
  admin_public_note text,
  admin_internal_note text,
  supplier_note text,
  requested_at timestamptz not null default now(),
  reviewed_by_profile_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  in_transit_at timestamptz,
  received_at timestamptz,
  inspected_at timestamptz,
  accepted_at timestamptz,
  declined_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint order_item_returns_quantity_positive check (requested_quantity > 0),
  constraint order_item_returns_approved_quantity_positive check (approved_quantity is null or approved_quantity > 0),
  constraint order_item_returns_status_allowed check (
    status in ('requested', 'under_review', 'approved', 'rejected', 'in_transit', 'received', 'inspected', 'accepted', 'declined', 'completed', 'cancelled')
  ),
  constraint order_item_returns_requested_method_allowed check (
    requested_method in ('customer_returns_to_supplier', 'supplier_pickup', 'external_courier', 'no_physical_return', 'other_manual_method')
  ),
  constraint order_item_returns_approved_method_allowed check (
    approved_method is null
    or approved_method in ('customer_returns_to_supplier', 'supplier_pickup', 'external_courier', 'no_physical_return', 'other_manual_method')
  ),
  constraint order_item_returns_fee_responsibility_allowed check (
    delivery_fee_responsibility in ('customer', 'supplier', 'platform', 'shared', 'not_applicable', 'pending_decision')
  ),
  constraint order_item_returns_condition_allowed check (
    inspection_condition in ('unopened_sellable', 'opened_sellable', 'damaged', 'defective', 'used', 'incomplete', 'expired', 'not_as_described', 'inspection_pending')
  ),
  constraint order_item_returns_inventory_outcome_allowed check (
    inventory_outcome in ('pending', 'restock_review_required', 'damaged_stock_review_required', 'quarantine_review_required', 'disposal_review_required', 'no_stock_change')
  ),
  constraint order_item_returns_notes_safe check (
    (customer_note is null or (length(trim(customer_note)) between 1 and 1200 and customer_note !~ '<[^>]+>' and customer_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
    and (admin_public_note is null or (length(trim(admin_public_note)) between 1 and 1200 and admin_public_note !~ '<[^>]+>' and admin_public_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
    and (admin_internal_note is null or (length(trim(admin_internal_note)) between 1 and 2000 and admin_internal_note !~ '<[^>]+>' and admin_internal_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
    and (supplier_note is null or (length(trim(supplier_note)) between 1 and 1200 and supplier_note !~ '<[^>]+>' and supplier_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
  )
);

create table if not exists public.return_actions (
  id uuid primary key default gen_random_uuid(),
  return_id uuid references public.order_item_returns(id) on delete restrict,
  dispute_id uuid references public.order_disputes(id) on delete restrict,
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  actor_role text not null,
  action_type text not null,
  idempotency_key text not null,
  request_fingerprint text not null,
  result_return_id uuid references public.order_item_returns(id) on delete restrict,
  result_status text,
  created_at timestamptz not null default now(),
  constraint return_actions_target_scope check ((return_id is null) <> (dispute_id is null)),
  constraint return_actions_role_allowed check (actor_role in ('customer', 'supplier', 'support_staff', 'admin', 'super_admin')),
  constraint return_actions_type_allowed check (
    action_type in (
      'customer_request',
      'admin_approve',
      'admin_reject',
      'customer_in_transit',
      'supplier_received',
      'supplier_condition',
      'admin_accept',
      'admin_decline',
      'admin_complete'
    )
  ),
  constraint return_actions_key_safe check (
    length(trim(idempotency_key)) between 8 and 140
    and idempotency_key !~* '(password|secret|token|jwt|cookie)'
  )
);

create unique index if not exists order_item_returns_one_active_per_dispute_item_idx
  on public.order_item_returns(dispute_id, order_item_id)
  where deleted_at is null
    and status in ('requested', 'under_review', 'approved', 'in_transit', 'received', 'inspected', 'accepted');

create index if not exists order_item_returns_customer_status_idx
  on public.order_item_returns(customer_profile_id, status, created_at desc)
  where deleted_at is null;

create index if not exists order_item_returns_supplier_status_idx
  on public.order_item_returns(supplier_id, status, created_at desc)
  where deleted_at is null;

create index if not exists order_item_returns_dispute_idx
  on public.order_item_returns(dispute_id, created_at desc)
  where deleted_at is null;

create unique index if not exists return_actions_dispute_key_idx
  on public.return_actions(dispute_id, actor_profile_id, action_type, idempotency_key)
  where dispute_id is not null;

create unique index if not exists return_actions_return_key_idx
  on public.return_actions(return_id, actor_profile_id, action_type, idempotency_key)
  where return_id is not null;

alter table public.order_item_returns enable row level security;
alter table public.order_item_returns force row level security;
alter table public.return_actions enable row level security;
alter table public.return_actions force row level security;

revoke all on public.order_item_returns from public, anon, authenticated;
revoke all on public.return_actions from public, anon, authenticated;

create or replace function public.return_workflow_safe_text(
  p_value text,
  p_required boolean,
  p_max_length integer
)
returns text
language plpgsql
stable
set search_path = public
as $fn$
declare
  v_value text := nullif(trim(coalesce(p_value, '')), '');
begin
  if p_required and v_value is null then
    raise exception 'RETURN_TEXT_REQUIRED' using errcode = '23514';
  end if;

  if v_value is null then
    return null;
  end if;

  if length(v_value) > p_max_length
    or v_value ~ '<[^>]+>'
    or v_value ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)' then
    raise exception 'INVALID_RETURN_TEXT' using errcode = '23514';
  end if;

  return v_value;
end;
$fn$;

create or replace function public.return_workflow_assert_key(p_idempotency_key text)
returns text
language plpgsql
stable
set search_path = public
as $fn$
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
$fn$;

create or replace function public.return_workflow_admin_actor_role(p_admin_role public.user_role)
returns text
language sql
immutable
set search_path = public
as $fn$
  select case
    when p_admin_role = 'super_admin' then 'super_admin'
    when p_admin_role = 'admin' then 'admin'
    else 'support_staff'
  end;
$fn$;

create or replace function public.return_workflow_is_method(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('customer_returns_to_supplier', 'supplier_pickup', 'external_courier', 'no_physical_return', 'other_manual_method');
$fn$;

create or replace function public.return_workflow_is_physical_method(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('customer_returns_to_supplier', 'supplier_pickup', 'external_courier', 'other_manual_method');
$fn$;

create or replace function public.return_workflow_is_fee_responsibility(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('customer', 'supplier', 'platform', 'shared', 'not_applicable', 'pending_decision');
$fn$;

create or replace function public.return_workflow_is_condition(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('unopened_sellable', 'opened_sellable', 'damaged', 'defective', 'used', 'incomplete', 'expired', 'not_as_described', 'inspection_pending');
$fn$;

create or replace function public.return_workflow_is_inventory_outcome(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('pending', 'restock_review_required', 'damaged_stock_review_required', 'quarantine_review_required', 'disposal_review_required', 'no_stock_change');
$fn$;

create or replace function public.return_workflow_prevent_target_update()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
  if old.dispute_id is distinct from new.dispute_id
    or old.order_id is distinct from new.order_id
    or old.order_item_id is distinct from new.order_item_id
    or old.customer_profile_id is distinct from new.customer_profile_id
    or old.supplier_id is distinct from new.supplier_id then
    raise exception 'RETURN_TARGET_IMMUTABLE' using errcode = '23514';
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists order_item_returns_prevent_target_update on public.order_item_returns;
create trigger order_item_returns_prevent_target_update
before update on public.order_item_returns
for each row execute function public.return_workflow_prevent_target_update();

create or replace function public.return_workflow_audit(
  p_actor_profile_id uuid,
  p_actor_role public.user_role,
  p_action text,
  p_return_id uuid,
  p_after_data jsonb default '{}'::jsonb,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, after_data, reason, created_at)
  values (
    p_actor_profile_id,
    p_actor_role,
    p_action,
    'order_item_return',
    p_return_id,
    coalesce(p_after_data, '{}'::jsonb) - 'customer_note' - 'supplier_note' - 'admin_internal_note' - 'admin_public_note',
    p_reason,
    now()
  );
end;
$fn$;

create or replace function public.return_workflow_record_dispute_status(
  p_dispute_id uuid,
  p_previous_status text,
  p_new_status text,
  p_actor_profile_id uuid,
  p_actor_role text,
  p_reason_code text,
  p_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if p_previous_status is distinct from p_new_status then
    insert into public.dispute_status_history(
      dispute_id,
      previous_status,
      new_status,
      changed_by_profile_id,
      changed_by_role,
      reason_code,
      created_at
    )
    values (
      p_dispute_id,
      p_previous_status,
      p_new_status,
      p_actor_profile_id,
      p_actor_role,
      p_reason_code,
      now()
    )
    on conflict do nothing;
  end if;
end;
$fn$;

create or replace function public.customer_request_item_return(
  p_dispute_id uuid,
  p_requested_quantity integer,
  p_requested_method text,
  p_customer_note text,
  p_idempotency_key text
)
returns table (
  return_id uuid,
  status text,
  requested_quantity integer,
  created boolean
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_customer_profile_id uuid := public.current_profile_id();
  v_customer_id uuid := public.current_dispute_customer_id();
  v_note text := public.return_workflow_safe_text(p_customer_note, true, 1200);
  v_method text := lower(trim(coalesce(p_requested_method, '')));
  v_dispute public.order_disputes%rowtype;
  v_item public.order_items%rowtype;
  v_existing public.order_item_returns%rowtype;
  v_return public.order_item_returns%rowtype;
  v_fingerprint text;
  v_previous_status text;
  v_new_status text;
begin
  if v_customer_profile_id is null or v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  if p_requested_quantity is null or p_requested_quantity <= 0 then
    raise exception 'INVALID_RETURN_QUANTITY' using errcode = '23514';
  end if;

  if not public.return_workflow_is_method(v_method) then
    raise exception 'INVALID_RETURN_METHOD' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('d7:return-request:' || p_dispute_id::text, 0));

  select *
  into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
  for update;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.orders o
    where o.id = v_dispute.order_id
      and o.customer_id = v_customer_id
      and o.deleted_at is null
  ) then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.scope_type <> 'order_item'
    or v_dispute.affected_order_item_id is null
    or v_dispute.affected_supplier_id is null then
    raise exception 'RETURN_REQUIRES_ITEM_SCOPED_DISPUTE' using errcode = '23514';
  end if;

  if v_dispute.reason_code <> 'return_requested' and v_dispute.requested_outcome <> 'return' then
    raise exception 'DISPUTE_NOT_RETURN_ELIGIBLE' using errcode = '23514';
  end if;

  if v_dispute.status in ('closed', 'cancelled', 'rejected', 'resolved_supplier', 'resolved_customer') then
    raise exception 'DISPUTE_NOT_RETURN_ELIGIBLE' using errcode = '23514';
  end if;

  select *
  into v_item
  from public.order_items oi
  where oi.id = v_dispute.affected_order_item_id
    and oi.order_id = v_dispute.order_id
    and oi.supplier_id = v_dispute.affected_supplier_id;

  if not found then
    raise exception 'RETURN_TARGET_NOT_FOUND' using errcode = '23514';
  end if;

  if p_requested_quantity > v_item.quantity then
    raise exception 'RETURN_QUANTITY_EXCEEDS_ITEM' using errcode = '23514';
  end if;

  v_fingerprint := md5(p_dispute_id::text || ':' || p_requested_quantity::text || ':' || v_method || ':' || v_note);

  select r.*
  into v_existing
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.dispute_id = p_dispute_id
    and ra.actor_profile_id = v_customer_profile_id
    and ra.action_type = 'customer_request'
    and ra.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.return_actions ra
      where ra.dispute_id = p_dispute_id
        and ra.actor_profile_id = v_customer_profile_id
        and ra.action_type = 'customer_request'
        and ra.idempotency_key = v_key
        and ra.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    return query select v_existing.id, v_existing.status, v_existing.requested_quantity, false;
    return;
  end if;

  select *
  into v_existing
  from public.order_item_returns r
  where r.dispute_id = p_dispute_id
    and r.order_item_id = v_item.id
    and r.deleted_at is null
    and r.status in ('requested', 'under_review', 'approved', 'in_transit', 'received', 'inspected', 'accepted')
  order by r.created_at asc, r.id::text asc
  limit 1;

  if found then
    insert into public.return_actions(dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
    values (p_dispute_id, v_customer_profile_id, 'customer', 'customer_request', v_key, v_fingerprint, v_existing.id, v_existing.status);

    return query select v_existing.id, v_existing.status, v_existing.requested_quantity, false;
    return;
  end if;

  insert into public.order_item_returns(
    dispute_id,
    order_id,
    order_item_id,
    customer_profile_id,
    supplier_id,
    requested_quantity,
    requested_method,
    customer_note,
    status
  )
  values (
    p_dispute_id,
    v_dispute.order_id,
    v_item.id,
    v_customer_profile_id,
    v_item.supplier_id,
    p_requested_quantity,
    v_method,
    v_note,
    'requested'
  )
  returning * into v_return;

  insert into public.return_actions(dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_dispute_id, v_customer_profile_id, 'customer', 'customer_request', v_key, v_fingerprint, v_return.id, v_return.status);

  v_previous_status := v_dispute.status;
  v_new_status := v_previous_status;
  if public.dispute_admin_valid_transition(v_previous_status, 'return_review') then
    update public.order_disputes
    set status = 'return_review',
        return_review_required = true,
        customer_action_required = false,
        supplier_action_required = false,
        updated_at = now()
    where id = p_dispute_id;
    v_new_status := 'return_review';
    perform public.return_workflow_record_dispute_status(p_dispute_id, v_previous_status, v_new_status, v_customer_profile_id, 'customer', 'return_requested', v_key);
  else
    update public.order_disputes
    set return_review_required = true,
        updated_at = now()
    where id = p_dispute_id;
  end if;

  perform public.return_workflow_audit(
    v_customer_profile_id,
    'customer',
    'return_requested',
    v_return.id,
    jsonb_build_object('status', v_return.status, 'requested_quantity', v_return.requested_quantity, 'requested_method', v_return.requested_method),
    'return_requested'
  );

  return query select v_return.id, v_return.status, v_return.requested_quantity, true;
end;
$fn$;

create or replace function public.admin_approve_return(
  p_return_id uuid,
  p_approved_quantity integer,
  p_approved_method text,
  p_delivery_fee_responsibility text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text, approved_quantity integer, approved_method text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_admin record;
  v_actor_role text;
  v_return public.order_item_returns%rowtype;
  v_public_note text := public.return_workflow_safe_text(p_public_note, false, 1200);
  v_internal_note text := public.return_workflow_safe_text(p_internal_note, false, 2000);
  v_method text := lower(trim(coalesce(p_approved_method, '')));
  v_fee text := lower(trim(coalesce(p_delivery_fee_responsibility, '')));
  v_fingerprint text;
begin
  select * into v_admin from public.current_dispute_support_admin();
  if v_admin.profile_id is null then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  v_actor_role := public.return_workflow_admin_actor_role(v_admin.admin_role);

  if p_approved_quantity is null or p_approved_quantity <= 0 then
    raise exception 'INVALID_APPROVED_QUANTITY' using errcode = '23514';
  end if;
  if not public.return_workflow_is_method(v_method) then
    raise exception 'INVALID_RETURN_METHOD' using errcode = '23514';
  end if;
  if not public.return_workflow_is_fee_responsibility(v_fee) then
    raise exception 'INVALID_FEE_RESPONSIBILITY' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('d7:return-review:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || p_approved_quantity::text || ':' || v_method || ':' || v_fee || ':' || coalesce(v_public_note, '') || ':' || coalesce(v_internal_note, ''));

  select r.* into v_return
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id
    and ra.actor_profile_id = v_admin.profile_id
    and ra.action_type = 'admin_approve'
    and ra.idempotency_key = v_key;
  if found then
    if exists (
      select 1 from public.return_actions ra
      where ra.return_id = p_return_id
        and ra.actor_profile_id = v_admin.profile_id
        and ra.action_type = 'admin_approve'
        and ra.idempotency_key = v_key
        and ra.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status, v_return.approved_quantity, v_return.approved_method;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status not in ('requested', 'under_review') then raise exception 'RETURN_NOT_REVIEWABLE' using errcode = '23514'; end if;
  if p_approved_quantity > v_return.requested_quantity then raise exception 'APPROVED_QUANTITY_EXCEEDS_REQUEST' using errcode = '23514'; end if;

  update public.order_item_returns
  set status = 'approved',
      approved_quantity = p_approved_quantity,
      approved_method = v_method,
      delivery_fee_responsibility = v_fee,
      admin_public_note = v_public_note,
      admin_internal_note = v_internal_note,
      reviewed_by_profile_id = v_admin.profile_id,
      reviewed_at = coalesce(reviewed_at, now()),
      approved_at = coalesce(approved_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_admin.profile_id, v_actor_role, 'admin_approve', v_key, v_fingerprint, v_return.id, v_return.status);

  perform public.return_workflow_audit(
    v_admin.profile_id,
    v_admin.admin_role,
    'return_approved',
    v_return.id,
    jsonb_build_object('status', v_return.status, 'approved_quantity', v_return.approved_quantity, 'approved_method', v_return.approved_method, 'delivery_fee_responsibility', v_return.delivery_fee_responsibility),
    'return_approved'
  );

  return query select v_return.id, v_return.status, v_return.approved_quantity, v_return.approved_method;
end;
$fn$;

create or replace function public.admin_reject_return(
  p_return_id uuid,
  p_public_reason text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_admin record;
  v_actor_role text;
  v_return public.order_item_returns%rowtype;
  v_public_reason text := public.return_workflow_safe_text(p_public_reason, true, 1200);
  v_internal_note text := public.return_workflow_safe_text(p_internal_note, false, 2000);
  v_fingerprint text;
begin
  select * into v_admin from public.current_dispute_support_admin();
  if v_admin.profile_id is null then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  v_actor_role := public.return_workflow_admin_actor_role(v_admin.admin_role);
  perform pg_advisory_xact_lock(hashtextextended('d7:return-review:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || v_public_reason || ':' || coalesce(v_internal_note, ''));

  select r.* into v_return
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_admin.profile_id and ra.action_type = 'admin_reject' and ra.idempotency_key = v_key;
  if found then
    if exists (select 1 from public.return_actions where return_id = p_return_id and actor_profile_id = v_admin.profile_id and action_type = 'admin_reject' and idempotency_key = v_key and request_fingerprint <> v_fingerprint) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status not in ('requested', 'under_review') then raise exception 'RETURN_NOT_REVIEWABLE' using errcode = '23514'; end if;

  update public.order_item_returns
  set status = 'rejected',
      admin_public_note = v_public_reason,
      admin_internal_note = v_internal_note,
      reviewed_by_profile_id = v_admin.profile_id,
      reviewed_at = coalesce(reviewed_at, now()),
      rejected_at = coalesce(rejected_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_admin.profile_id, v_actor_role, 'admin_reject', v_key, v_fingerprint, v_return.id, v_return.status);

  perform public.return_workflow_audit(v_admin.profile_id, v_admin.admin_role, 'return_rejected', v_return.id, jsonb_build_object('status', v_return.status), 'return_rejected');
  return query select v_return.id, v_return.status;
end;
$fn$;

create or replace function public.customer_mark_return_in_transit(
  p_return_id uuid,
  p_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_customer_id uuid := public.current_dispute_customer_id();
  v_note text := public.return_workflow_safe_text(p_note, false, 1200);
  v_return public.order_item_returns%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null or v_customer_id is null then raise exception 'CUSTOMER_REQUIRED' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('d7:return-customer:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || coalesce(v_note, ''));

  select r.* into v_return from public.return_actions ra join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_profile_id and ra.action_type = 'customer_in_transit' and ra.idempotency_key = v_key;
  if found then
    if exists (select 1 from public.return_actions where return_id = p_return_id and actor_profile_id = v_profile_id and action_type = 'customer_in_transit' and idempotency_key = v_key and request_fingerprint <> v_fingerprint) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and customer_profile_id = v_profile_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status <> 'approved' then raise exception 'RETURN_NOT_APPROVED' using errcode = '23514'; end if;
  if not public.return_workflow_is_physical_method(coalesce(v_return.approved_method, v_return.requested_method)) then
    raise exception 'RETURN_NOT_PHYSICAL' using errcode = '23514';
  end if;

  update public.order_item_returns
  set status = 'in_transit',
      customer_note = coalesce(v_note, customer_note),
      in_transit_at = coalesce(in_transit_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_profile_id, 'customer', 'customer_in_transit', v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_profile_id, 'customer', 'return_marked_in_transit', v_return.id, jsonb_build_object('status', v_return.status), 'return_marked_in_transit');
  return query select v_return.id, v_return.status;
end;
$fn$;

create or replace function public.supplier_confirm_return_received(
  p_return_id uuid,
  p_supplier_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_supplier_id uuid := public.current_dispute_supplier_id();
  v_note text := public.return_workflow_safe_text(p_supplier_note, false, 1200);
  v_return public.order_item_returns%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null or v_supplier_id is null then raise exception 'SUPPLIER_REQUIRED' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('d7:return-supplier:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || coalesce(v_note, ''));

  select r.* into v_return from public.return_actions ra join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_profile_id and ra.action_type = 'supplier_received' and ra.idempotency_key = v_key;
  if found then
    if exists (select 1 from public.return_actions where return_id = p_return_id and actor_profile_id = v_profile_id and action_type = 'supplier_received' and idempotency_key = v_key and request_fingerprint <> v_fingerprint) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and supplier_id = v_supplier_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status not in ('approved', 'in_transit') then raise exception 'RETURN_NOT_RECEIVABLE' using errcode = '23514'; end if;
  if not public.return_workflow_is_physical_method(coalesce(v_return.approved_method, v_return.requested_method)) then raise exception 'RETURN_NOT_PHYSICAL' using errcode = '23514'; end if;

  update public.order_item_returns
  set status = 'received',
      supplier_note = v_note,
      received_at = coalesce(received_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_profile_id, 'supplier', 'supplier_received', v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_profile_id, 'supplier_owner', 'return_received', v_return.id, jsonb_build_object('status', v_return.status), 'return_received');
  return query select v_return.id, v_return.status;
end;
$fn$;

create or replace function public.supplier_report_return_condition(
  p_return_id uuid,
  p_condition text,
  p_inventory_outcome text,
  p_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text, inspection_condition text, inventory_outcome text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_supplier_id uuid := public.current_dispute_supplier_id();
  v_condition text := lower(trim(coalesce(p_condition, '')));
  v_outcome text := lower(trim(coalesce(p_inventory_outcome, '')));
  v_note text := public.return_workflow_safe_text(p_note, false, 1200);
  v_return public.order_item_returns%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null or v_supplier_id is null then raise exception 'SUPPLIER_REQUIRED' using errcode = '42501'; end if;
  if not public.return_workflow_is_condition(v_condition) or v_condition = 'inspection_pending' then raise exception 'INVALID_RETURN_CONDITION' using errcode = '23514'; end if;
  if not public.return_workflow_is_inventory_outcome(v_outcome) or v_outcome = 'pending' then raise exception 'INVALID_INVENTORY_OUTCOME' using errcode = '23514'; end if;

  perform pg_advisory_xact_lock(hashtextextended('d7:return-supplier:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || v_condition || ':' || v_outcome || ':' || coalesce(v_note, ''));

  select r.* into v_return from public.return_actions ra join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_profile_id and ra.action_type = 'supplier_condition' and ra.idempotency_key = v_key;
  if found then
    if exists (select 1 from public.return_actions where return_id = p_return_id and actor_profile_id = v_profile_id and action_type = 'supplier_condition' and idempotency_key = v_key and request_fingerprint <> v_fingerprint) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status, v_return.inspection_condition, v_return.inventory_outcome;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and supplier_id = v_supplier_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status <> 'received' then raise exception 'RETURN_NOT_RECEIVED' using errcode = '23514'; end if;

  update public.order_item_returns
  set status = 'inspected',
      inspection_condition = v_condition,
      inventory_outcome = v_outcome,
      supplier_note = coalesce(v_note, supplier_note),
      inspected_at = coalesce(inspected_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_profile_id, 'supplier', 'supplier_condition', v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_profile_id, 'supplier_owner', 'returned_item_inspected', v_return.id, jsonb_build_object('status', v_return.status, 'inspection_condition', v_return.inspection_condition), 'returned_item_inspected');
  perform public.return_workflow_audit(v_profile_id, 'supplier_owner', 'return_inventory_outcome_recommended', v_return.id, jsonb_build_object('inventory_outcome', v_return.inventory_outcome), 'return_inventory_outcome_recommended');
  return query select v_return.id, v_return.status, v_return.inspection_condition, v_return.inventory_outcome;
end;
$fn$;

create or replace function public.return_workflow_admin_final(
  p_return_id uuid,
  p_next_status text,
  p_action_type text,
  p_audit_action text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_admin record;
  v_actor_role text;
  v_return public.order_item_returns%rowtype;
  v_public_note text := public.return_workflow_safe_text(p_public_note, false, 1200);
  v_internal_note text := public.return_workflow_safe_text(p_internal_note, false, 2000);
  v_fingerprint text;
begin
  select * into v_admin from public.current_dispute_support_admin();
  if v_admin.profile_id is null then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  v_actor_role := public.return_workflow_admin_actor_role(v_admin.admin_role);
  if p_next_status not in ('accepted', 'declined', 'completed') then raise exception 'INVALID_RETURN_STATUS' using errcode = '23514'; end if;
  if p_action_type not in ('admin_accept', 'admin_decline', 'admin_complete') then raise exception 'INVALID_RETURN_ACTION' using errcode = '23514'; end if;

  perform pg_advisory_xact_lock(hashtextextended('d7:return-final:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || p_next_status || ':' || coalesce(v_public_note, '') || ':' || coalesce(v_internal_note, ''));

  select r.* into v_return from public.return_actions ra join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_admin.profile_id and ra.action_type = p_action_type and ra.idempotency_key = v_key;
  if found then
    if exists (select 1 from public.return_actions where return_id = p_return_id and actor_profile_id = v_admin.profile_id and action_type = p_action_type and idempotency_key = v_key and request_fingerprint <> v_fingerprint) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;

  if p_next_status in ('accepted', 'declined') and v_return.status <> 'inspected' then
    raise exception 'RETURN_NOT_INSPECTED' using errcode = '23514';
  end if;
  if p_next_status = 'completed' and v_return.status not in ('accepted', 'declined', 'rejected', 'cancelled') then
    raise exception 'RETURN_NOT_COMPLETABLE' using errcode = '23514';
  end if;

  update public.order_item_returns
  set status = p_next_status,
      admin_public_note = coalesce(v_public_note, admin_public_note),
      admin_internal_note = coalesce(v_internal_note, admin_internal_note),
      accepted_at = case when p_next_status = 'accepted' then coalesce(accepted_at, now()) else accepted_at end,
      declined_at = case when p_next_status = 'declined' then coalesce(declined_at, now()) else declined_at end,
      completed_at = case when p_next_status = 'completed' then coalesce(completed_at, now()) else completed_at end,
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_admin.profile_id, v_actor_role, p_action_type, v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_admin.profile_id, v_admin.admin_role, p_audit_action, v_return.id, jsonb_build_object('status', v_return.status), p_audit_action);
  return query select v_return.id, v_return.status;
end;
$fn$;

create or replace function public.admin_accept_return(p_return_id uuid, p_public_note text, p_internal_note text, p_idempotency_key text)
returns table (return_id uuid, status text)
language sql
security definer
set search_path = public
as $fn$
  select * from public.return_workflow_admin_final(p_return_id, 'accepted', 'admin_accept', 'return_accepted', p_public_note, p_internal_note, p_idempotency_key);
$fn$;

create or replace function public.admin_decline_return(p_return_id uuid, p_public_note text, p_internal_note text, p_idempotency_key text)
returns table (return_id uuid, status text)
language sql
security definer
set search_path = public
as $fn$
  select * from public.return_workflow_admin_final(p_return_id, 'declined', 'admin_decline', 'return_declined', p_public_note, p_internal_note, p_idempotency_key);
$fn$;

create or replace function public.admin_complete_return(p_return_id uuid, p_public_note text, p_internal_note text, p_idempotency_key text)
returns table (return_id uuid, status text)
language sql
security definer
set search_path = public
as $fn$
  select * from public.return_workflow_admin_final(p_return_id, 'completed', 'admin_complete', 'return_completed', p_public_note, p_internal_note, p_idempotency_key);
$fn$;

create or replace function public.list_customer_returns_safe(p_limit integer default 20)
returns table (
  return_id uuid,
  dispute_id uuid,
  order_number text,
  product_name text,
  requested_quantity integer,
  approved_quantity integer,
  status text,
  requested_method text,
  approved_method text,
  delivery_fee_responsibility text,
  inspection_condition text,
  inventory_outcome text,
  admin_public_note text,
  requested_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    r.id,
    r.dispute_id,
    o.order_number,
    p.name,
    r.requested_quantity,
    r.approved_quantity,
    r.status,
    r.requested_method,
    r.approved_method,
    r.delivery_fee_responsibility,
    r.inspection_condition,
    r.inventory_outcome,
    r.admin_public_note,
    r.requested_at,
    r.updated_at
  from public.order_item_returns r
  join public.orders o on o.id = r.order_id
  join public.order_items oi on oi.id = r.order_item_id
  join public.products p on p.id = oi.product_id
  where r.customer_profile_id = public.current_profile_id()
    and public.current_dispute_customer_id() is not null
    and r.deleted_at is null
  order by r.created_at desc, r.id::text desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$fn$;

create or replace function public.get_customer_return_safe(p_return_id uuid)
returns table (
  return_id uuid,
  dispute_id uuid,
  order_number text,
  product_name text,
  requested_quantity integer,
  approved_quantity integer,
  status text,
  requested_method text,
  approved_method text,
  delivery_fee_responsibility text,
  inspection_condition text,
  inventory_outcome text,
  admin_public_note text,
  requested_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $fn$
  select *
  from public.list_customer_returns_safe(100) r
  where r.return_id = p_return_id;
$fn$;

create or replace function public.list_supplier_returns_safe(p_limit integer default 20)
returns table (
  return_id uuid,
  dispute_id uuid,
  order_number text,
  product_name text,
  requested_quantity integer,
  approved_quantity integer,
  status text,
  requested_method text,
  approved_method text,
  delivery_fee_responsibility text,
  inspection_condition text,
  inventory_outcome text,
  requested_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    r.id,
    r.dispute_id,
    o.order_number,
    p.name,
    r.requested_quantity,
    r.approved_quantity,
    r.status,
    r.requested_method,
    r.approved_method,
    r.delivery_fee_responsibility,
    r.inspection_condition,
    r.inventory_outcome,
    r.requested_at,
    r.updated_at
  from public.order_item_returns r
  join public.orders o on o.id = r.order_id
  join public.order_items oi on oi.id = r.order_item_id
  join public.products p on p.id = oi.product_id
  where r.supplier_id = public.current_dispute_supplier_id()
    and r.deleted_at is null
  order by r.created_at desc, r.id::text desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$fn$;

create or replace function public.get_supplier_return_safe(p_return_id uuid)
returns table (
  return_id uuid,
  dispute_id uuid,
  order_number text,
  product_name text,
  requested_quantity integer,
  approved_quantity integer,
  status text,
  requested_method text,
  approved_method text,
  delivery_fee_responsibility text,
  inspection_condition text,
  inventory_outcome text,
  requested_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $fn$
  select *
  from public.list_supplier_returns_safe(100) r
  where r.return_id = p_return_id;
$fn$;

create or replace function public.list_admin_returns_safe(p_status text default null, p_limit integer default 50)
returns table (
  return_id uuid,
  dispute_id uuid,
  order_id uuid,
  order_item_id uuid,
  supplier_id uuid,
  order_number text,
  product_name text,
  requested_quantity integer,
  approved_quantity integer,
  status text,
  requested_method text,
  approved_method text,
  delivery_fee_responsibility text,
  inspection_condition text,
  inventory_outcome text,
  customer_note text,
  admin_public_note text,
  supplier_note text,
  requested_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    r.id,
    r.dispute_id,
    r.order_id,
    r.order_item_id,
    r.supplier_id,
    o.order_number,
    p.name,
    r.requested_quantity,
    r.approved_quantity,
    r.status,
    r.requested_method,
    r.approved_method,
    r.delivery_fee_responsibility,
    r.inspection_condition,
    r.inventory_outcome,
    r.customer_note,
    r.admin_public_note,
    r.supplier_note,
    r.requested_at,
    r.updated_at
  from public.order_item_returns r
  join public.orders o on o.id = r.order_id
  join public.order_items oi on oi.id = r.order_item_id
  join public.products p on p.id = oi.product_id
  where exists (select 1 from public.current_dispute_support_admin())
    and r.deleted_at is null
    and (p_status is null or r.status = p_status)
  order by r.created_at desc, r.id::text desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
$fn$;

create or replace function public.get_admin_return_safe(p_return_id uuid)
returns table (
  return_id uuid,
  dispute_id uuid,
  order_id uuid,
  order_item_id uuid,
  supplier_id uuid,
  order_number text,
  product_name text,
  requested_quantity integer,
  approved_quantity integer,
  status text,
  requested_method text,
  approved_method text,
  delivery_fee_responsibility text,
  inspection_condition text,
  inventory_outcome text,
  customer_note text,
  admin_public_note text,
  supplier_note text,
  requested_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $fn$
  select *
  from public.list_admin_returns_safe(null, 200) r
  where r.return_id = p_return_id;
$fn$;

create or replace function public.get_reseller_return_impact_safe(p_return_id uuid)
returns table (
  return_id uuid,
  order_number text,
  product_name text,
  status text,
  impact_label text,
  safe_note text
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    r.id,
    o.order_number,
    p.name,
    r.status,
    case when r.status in ('requested', 'under_review', 'approved', 'in_transit', 'received', 'inspected', 'accepted') then 'future_commission_review_possible' else 'no_active_return_hold' end,
    'Return workflow is tracked separately from refund, commission, settlement, and withdrawal handling.'
  from public.order_item_returns r
  join public.orders o on o.id = r.order_id
  join public.order_items oi on oi.id = r.order_item_id
  join public.products p on p.id = oi.product_id
  where r.id = p_return_id
    and o.reseller_id = public.current_dispute_reseller_id()
    and r.deleted_at is null;
$fn$;

revoke all on function public.customer_request_item_return(uuid, integer, text, text, text) from public, anon, authenticated;
revoke all on function public.admin_approve_return(uuid, integer, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.admin_reject_return(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.customer_mark_return_in_transit(uuid, text, text) from public, anon, authenticated;
revoke all on function public.supplier_confirm_return_received(uuid, text, text) from public, anon, authenticated;
revoke all on function public.supplier_report_return_condition(uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.admin_accept_return(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.admin_decline_return(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.admin_complete_return(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.list_customer_returns_safe(integer) from public, anon, authenticated;
revoke all on function public.get_customer_return_safe(uuid) from public, anon, authenticated;
revoke all on function public.list_supplier_returns_safe(integer) from public, anon, authenticated;
revoke all on function public.get_supplier_return_safe(uuid) from public, anon, authenticated;
revoke all on function public.list_admin_returns_safe(text, integer) from public, anon, authenticated;
revoke all on function public.get_admin_return_safe(uuid) from public, anon, authenticated;
revoke all on function public.get_reseller_return_impact_safe(uuid) from public, anon, authenticated;

grant execute on function public.customer_request_item_return(uuid, integer, text, text, text) to authenticated;
grant execute on function public.admin_approve_return(uuid, integer, text, text, text, text, text) to authenticated;
grant execute on function public.admin_reject_return(uuid, text, text, text) to authenticated;
grant execute on function public.customer_mark_return_in_transit(uuid, text, text) to authenticated;
grant execute on function public.supplier_confirm_return_received(uuid, text, text) to authenticated;
grant execute on function public.supplier_report_return_condition(uuid, text, text, text, text) to authenticated;
grant execute on function public.admin_accept_return(uuid, text, text, text) to authenticated;
grant execute on function public.admin_decline_return(uuid, text, text, text) to authenticated;
grant execute on function public.admin_complete_return(uuid, text, text, text) to authenticated;
grant execute on function public.list_customer_returns_safe(integer) to authenticated;
grant execute on function public.get_customer_return_safe(uuid) to authenticated;
grant execute on function public.list_supplier_returns_safe(integer) to authenticated;
grant execute on function public.get_supplier_return_safe(uuid) to authenticated;
grant execute on function public.list_admin_returns_safe(text, integer) to authenticated;
grant execute on function public.get_admin_return_safe(uuid) to authenticated;
grant execute on function public.get_reseller_return_impact_safe(uuid) to authenticated;
