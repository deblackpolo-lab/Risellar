-- Disputes D5-A: supplier/item scoping foundation.
-- Forward-only. Adds explicit dispute targeting and repairs supplier safe reads.
-- Does not add supplier response mutations, admin mutations, returns, refunds,
-- finance holds, stock/reservation changes, notifications, or UI.

alter table public.order_disputes
  add column if not exists scope_type text not null default 'order',
  add column if not exists affected_supplier_id uuid references public.suppliers(id) on delete restrict,
  add column if not exists affected_order_item_id uuid references public.order_items(id) on delete restrict;

alter table public.order_disputes
  alter column scope_type drop default;

alter table public.order_disputes
  drop constraint if exists order_disputes_scope_type_allowed,
  add constraint order_disputes_scope_type_allowed
    check (scope_type in ('order', 'supplier', 'order_item'));

alter table public.order_disputes
  drop constraint if exists order_disputes_target_shape_valid,
  add constraint order_disputes_target_shape_valid
    check (
      (
        scope_type = 'order'
        and affected_supplier_id is null
        and affected_order_item_id is null
      )
      or (
        scope_type = 'supplier'
        and affected_supplier_id is not null
        and affected_order_item_id is null
      )
      or (
        scope_type = 'order_item'
        and affected_supplier_id is not null
        and affected_order_item_id is not null
      )
    );

create index if not exists order_disputes_target_created_idx
  on public.order_disputes(scope_type, affected_supplier_id, affected_order_item_id, created_at desc)
  where deleted_at is null;

drop index if exists order_disputes_active_reason_unique;

create unique index if not exists order_disputes_active_target_reason_unique
  on public.order_disputes(
    order_id,
    opened_by_profile_id,
    scope_type,
    coalesce(affected_supplier_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(affected_order_item_id, '00000000-0000-0000-0000-000000000000'::uuid),
    dispute_category,
    reason_code,
    requested_outcome
  )
  where deleted_at is null and status not in ('closed', 'cancelled', 'rejected');

create or replace function public.validate_order_dispute_target()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_item_supplier_id uuid;
  v_participates boolean;
begin
  if tg_op = 'UPDATE' then
    if old.order_id is distinct from new.order_id
      or old.opened_by_profile_id is distinct from new.opened_by_profile_id
      or old.opened_by_role is distinct from new.opened_by_role
      or old.scope_type is distinct from new.scope_type
      or old.affected_supplier_id is distinct from new.affected_supplier_id
      or old.affected_order_item_id is distinct from new.affected_order_item_id then
      raise exception 'DISPUTE_TARGET_IMMUTABLE' using errcode = '23514';
    end if;
  end if;

  if new.scope_type = 'order' then
    if new.affected_supplier_id is not null or new.affected_order_item_id is not null then
      raise exception 'INVALID_DISPUTE_TARGET' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.scope_type = 'supplier' then
    if new.affected_supplier_id is null or new.affected_order_item_id is not null then
      raise exception 'INVALID_DISPUTE_TARGET' using errcode = '23514';
    end if;

    select exists (
      select 1
      from public.order_items oi
      where oi.order_id = new.order_id
        and oi.supplier_id = new.affected_supplier_id
    )
    into v_participates;

    if not coalesce(v_participates, false) then
      raise exception 'DISPUTE_SUPPLIER_NOT_IN_ORDER' using errcode = '23514';
    end if;

    return new;
  end if;

  if new.scope_type = 'order_item' then
    if new.affected_supplier_id is null or new.affected_order_item_id is null then
      raise exception 'INVALID_DISPUTE_TARGET' using errcode = '23514';
    end if;

    select oi.supplier_id
    into v_item_supplier_id
    from public.order_items oi
    where oi.id = new.affected_order_item_id
      and oi.order_id = new.order_id;

    if v_item_supplier_id is null then
      raise exception 'DISPUTE_ITEM_NOT_IN_ORDER' using errcode = '23514';
    end if;

    if v_item_supplier_id <> new.affected_supplier_id then
      raise exception 'DISPUTE_SUPPLIER_ITEM_MISMATCH' using errcode = '23514';
    end if;

    return new;
  end if;

  raise exception 'INVALID_DISPUTE_SCOPE' using errcode = '23514';
end;
$fn$;

drop trigger if exists validate_order_dispute_target_before_write on public.order_disputes;
create trigger validate_order_dispute_target_before_write
  before insert or update on public.order_disputes
  for each row
  execute function public.validate_order_dispute_target();

create or replace function public.customer_dispute_reason_scope(
  p_reason_code text,
  p_order_item_id uuid,
  p_supplier_count integer
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if p_reason_code in (
    'wrong_item_received',
    'damaged_item_received',
    'incomplete_order',
    'item_not_as_described',
    'product_quality_issue',
    'return_requested',
    'refund_requested'
  ) then
    if p_order_item_id is null then
      raise exception 'ORDER_ITEM_REQUIRED_FOR_REASON' using errcode = '23514';
    end if;
    return 'order_item';
  end if;

  if p_reason_code in (
    'supplier_not_responding',
    'supplier_rejected_status_incorrect',
    'order_stuck_in_preparation',
    'customer_paid_not_reported',
    'supplier_reported_customer_disagrees'
  ) then
    if p_order_item_id is not null then
      return 'supplier';
    end if;

    if coalesce(p_supplier_count, 0) = 1 then
      return 'order';
    end if;

    raise exception 'ORDER_ITEM_REQUIRED_FOR_MULTI_SUPPLIER_REASON' using errcode = '23514';
  end if;

  if p_order_item_id is not null then
    raise exception 'ORDER_ITEM_NOT_ALLOWED_FOR_ORDER_SCOPE_REASON' using errcode = '23514';
  end if;

  return 'order';
end;
$fn$;

create or replace function public.customer_open_order_dispute(
  p_order_id uuid,
  p_order_item_id uuid,
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
  v_order_item record;
  v_supplier_count integer;
  v_scope_type text;
  v_affected_supplier_id uuid;
  v_affected_order_item_id uuid;
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

  if p_order_item_id is not null then
    select oi.id, oi.supplier_id
    into v_order_item
    from public.order_items oi
    where oi.id = p_order_item_id
      and oi.order_id = p_order_id;

    if not found then
      raise exception 'ORDER_ITEM_NOT_FOUND' using errcode = '42501';
    end if;
  end if;

  select count(distinct oi.supplier_id)
  into v_supplier_count
  from public.order_items oi
  where oi.order_id = p_order_id;

  v_scope_type := public.customer_dispute_reason_scope(v_reason, p_order_item_id, v_supplier_count);

  if v_scope_type = 'supplier' then
    v_affected_supplier_id := v_order_item.supplier_id;
    v_affected_order_item_id := null;
  elsif v_scope_type = 'order_item' then
    v_affected_supplier_id := v_order_item.supplier_id;
    v_affected_order_item_id := v_order_item.id;
  else
    v_affected_supplier_id := null;
    v_affected_order_item_id := null;
  end if;

  if not public.customer_dispute_reason_allowed_for_order_status(v_reason, v_order.order_status) then
    raise exception 'DISPUTE_NOT_ALLOWED_FOR_ORDER_STATE' using errcode = '23514';
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
    if v_existing.order_id <> p_order_id
      or v_existing.scope_type <> v_scope_type
      or v_existing.affected_supplier_id is distinct from v_affected_supplier_id
      or v_existing.affected_order_item_id is distinct from v_affected_order_item_id
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

  perform pg_advisory_xact_lock(hashtextextended(
    'customer_open_order_dispute:fingerprint:'
      || v_profile_id::text || ':'
      || p_order_id::text || ':'
      || v_scope_type || ':'
      || coalesce(v_affected_supplier_id::text, 'none') || ':'
      || coalesce(v_affected_order_item_id::text, 'none') || ':'
      || v_category || ':'
      || v_reason || ':'
      || v_outcome,
    0
  ));

  select *
  into v_existing
  from public.order_disputes od
  where od.order_id = p_order_id
    and od.opened_by_profile_id = v_profile_id
    and od.scope_type = v_scope_type
    and od.affected_supplier_id is not distinct from v_affected_supplier_id
    and od.affected_order_item_id is not distinct from v_affected_order_item_id
    and od.dispute_category = v_category
    and od.reason_code = v_reason
    and od.requested_outcome = v_outcome
    and od.deleted_at is null
    and od.status not in ('closed', 'cancelled', 'rejected')
  order by od.opened_at asc, od.id::text asc
  limit 1;

  if found then
    if coalesce(v_existing.description, '') = v_description then
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

  v_supplier_action_required := v_scope_type in ('supplier', 'order_item')
    and v_reason not in (
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
    scope_type,
    affected_supplier_id,
    affected_order_item_id,
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
    v_scope_type,
    v_affected_supplier_id,
    v_affected_order_item_id,
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
      'scope_type', v_scope_type,
      'target_supplier_present', v_affected_supplier_id is not null,
      'target_order_item_present', v_affected_order_item_id is not null,
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

drop function if exists public.list_customer_disputes_safe(text, integer, timestamptz, uuid);
create function public.list_customer_disputes_safe(
  p_status text default null,
  p_limit integer default 20,
  p_cursor_opened_at timestamptz default null,
  p_cursor_dispute_id uuid default null
)
returns table (
  dispute_id uuid,
  safe_order_reference text,
  scope_type text,
  affected_item_summary text,
  category text,
  reason_code text,
  requested_outcome text,
  status text,
  customer_action_required boolean,
  supplier_action_required boolean,
  opened_at timestamptz,
  updated_at timestamptz,
  safe_latest_message text,
  safe_next_action text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_customer_id uuid;
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  v_customer_id := public.current_dispute_customer_id();

  if v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  if v_status is not null and v_status not in (
    'open', 'awaiting_customer', 'awaiting_supplier', 'under_review',
    'return_review', 'refund_review', 'resolved_customer', 'resolved_supplier',
    'partially_resolved', 'rejected', 'cancelled', 'closed'
  ) then
    raise exception 'INVALID_STATUS_FILTER' using errcode = '23514';
  end if;

  return query
  select
    od.id,
    o.order_number,
    od.scope_type,
    case
      when od.scope_type = 'order_item' then coalesce(p.name, 'Order item')
      when od.scope_type = 'supplier' then 'Supplier-specific review'
      else 'Order-wide review'
    end,
    od.dispute_category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.customer_action_required,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    lm.body,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required)
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  left join public.order_items oi on oi.id = od.affected_order_item_id and oi.order_id = od.order_id
  left join public.products p on p.id = oi.product_id
  left join lateral (
    select dm.body
    from public.dispute_messages dm
    where dm.dispute_id = od.id
      and dm.deleted_at is null
      and dm.visibility in ('customer_and_admin', 'all_case_participants')
    order by dm.created_at desc, dm.id::text desc
    limit 1
  ) lm on true
  where o.customer_id = v_customer_id
    and od.deleted_at is null
    and (v_status is null or od.status = v_status)
    and (
      p_cursor_opened_at is null
      or od.opened_at < p_cursor_opened_at
      or (
        p_cursor_dispute_id is not null
        and od.opened_at = p_cursor_opened_at
        and od.id::text < p_cursor_dispute_id::text
      )
    )
  order by od.opened_at desc, od.id::text desc
  limit v_limit;
end;
$fn$;

drop function if exists public.get_customer_dispute_safe(uuid);
create function public.get_customer_dispute_safe(p_dispute_id uuid)
returns table (
  dispute_id uuid,
  safe_order_reference text,
  scope_type text,
  affected_item_summary text,
  category text,
  reason_code text,
  requested_outcome text,
  status text,
  priority text,
  customer_action_required boolean,
  supplier_action_required boolean,
  opened_at timestamptz,
  updated_at timestamptz,
  public_resolution_message text,
  safe_next_action text,
  messages jsonb,
  status_history jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_customer_id uuid;
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  v_customer_id := public.current_dispute_customer_id();

  if v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    od.id,
    o.order_number,
    od.scope_type,
    case
      when od.scope_type = 'order_item' then coalesce(p.name, 'Order item')
      when od.scope_type = 'supplier' then 'Supplier-specific review'
      else 'Order-wide review'
    end,
    od.dispute_category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.priority,
    od.customer_action_required,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    od.public_resolution_message,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'messageId', dm.id,
          'authorRole', dm.author_role,
          'messageType', dm.message_type,
          'body', dm.body,
          'createdAt', dm.created_at
        )
        order by dm.created_at asc, dm.id::text asc
      )
      from public.dispute_messages dm
      where dm.dispute_id = od.id
        and dm.deleted_at is null
        and dm.visibility in ('customer_and_admin', 'all_case_participants')
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'previousStatus', dsh.previous_status,
          'newStatus', dsh.new_status,
          'changedByRole', dsh.changed_by_role,
          'publicNote', dsh.public_note,
          'createdAt', dsh.created_at
        )
        order by dsh.created_at asc, dsh.id::text asc
      )
      from public.dispute_status_history dsh
      where dsh.dispute_id = od.id
    ), '[]'::jsonb)
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  left join public.order_items oi on oi.id = od.affected_order_item_id and oi.order_id = od.order_id
  left join public.products p on p.id = oi.product_id
  where od.id = p_dispute_id
    and od.deleted_at is null
    and o.customer_id = v_customer_id;
end;
$fn$;

drop function if exists public.list_supplier_disputes_safe(text, integer, timestamptz, uuid);
create function public.list_supplier_disputes_safe(
  p_status text default null,
  p_limit integer default 20,
  p_cursor_opened_at timestamptz default null,
  p_cursor_dispute_id uuid default null
)
returns table (
  dispute_id uuid,
  safe_order_reference text,
  scope_type text,
  affected_item_summary text,
  category text,
  reason_code text,
  status text,
  supplier_action_required boolean,
  opened_at timestamptz,
  updated_at timestamptz,
  safe_next_action text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_supplier_id uuid;
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  v_supplier_id := public.current_dispute_supplier_id();

  if v_supplier_id is null then
    raise exception 'SUPPLIER_REQUIRED' using errcode = '42501';
  end if;

  if v_status is not null and v_status not in (
    'open', 'awaiting_customer', 'awaiting_supplier', 'under_review',
    'return_review', 'refund_review', 'resolved_customer', 'resolved_supplier',
    'partially_resolved', 'rejected', 'cancelled', 'closed'
  ) then
    raise exception 'INVALID_STATUS_FILTER' using errcode = '23514';
  end if;

  return query
  select
    od.id,
    o.order_number,
    od.scope_type,
    case
      when od.scope_type = 'order_item' then coalesce(p.name, 'Order item')
      when od.scope_type = 'supplier' then 'Supplier-specific review'
      else 'Single-supplier order-wide review'
    end,
    od.dispute_category,
    od.reason_code,
    od.status,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required)
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  left join public.order_items target_item on target_item.id = od.affected_order_item_id and target_item.order_id = od.order_id
  left join public.products p on p.id = target_item.product_id
  where od.deleted_at is null
    and (
      od.affected_supplier_id = v_supplier_id
      or (
        od.scope_type = 'order'
        and (
          select count(distinct oi.supplier_id)
          from public.order_items oi
          where oi.order_id = od.order_id
        ) = 1
        and exists (
          select 1
          from public.order_items oi
          where oi.order_id = od.order_id
            and oi.supplier_id = v_supplier_id
        )
      )
    )
    and (v_status is null or od.status = v_status)
    and (
      p_cursor_opened_at is null
      or od.opened_at < p_cursor_opened_at
      or (
        p_cursor_dispute_id is not null
        and od.opened_at = p_cursor_opened_at
        and od.id::text < p_cursor_dispute_id::text
      )
    )
  order by od.opened_at desc, od.id::text desc
  limit v_limit;
end;
$fn$;

drop function if exists public.get_supplier_dispute_safe(uuid);
create function public.get_supplier_dispute_safe(p_dispute_id uuid)
returns table (
  dispute_id uuid,
  safe_order_reference text,
  scope_type text,
  affected_item_summary text,
  category text,
  reason_code text,
  requested_outcome text,
  status text,
  priority text,
  supplier_action_required boolean,
  opened_at timestamptz,
  updated_at timestamptz,
  product_names text,
  safe_customer_claim text,
  public_resolution_message text,
  safe_next_action text,
  messages jsonb,
  status_history jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_supplier_id uuid;
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  v_supplier_id := public.current_dispute_supplier_id();

  if v_supplier_id is null then
    raise exception 'SUPPLIER_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    od.id,
    o.order_number,
    od.scope_type,
    case
      when od.scope_type = 'order_item' then coalesce(target_product.name, 'Order item')
      when od.scope_type = 'supplier' then 'Supplier-specific review'
      else 'Single-supplier order-wide review'
    end,
    od.dispute_category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.priority,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    string_agg(distinct p.name, ', ' order by p.name),
    case
      when od.description is not null and od.opened_by_role in ('customer', 'support_staff', 'super_admin') then od.description
      else null
    end,
    od.public_resolution_message,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'messageId', dm.id,
          'authorRole', dm.author_role,
          'messageType', dm.message_type,
          'body', dm.body,
          'createdAt', dm.created_at
        )
        order by dm.created_at asc, dm.id::text asc
      )
      from public.dispute_messages dm
      where dm.dispute_id = od.id
        and dm.deleted_at is null
        and dm.visibility in ('supplier_and_admin', 'all_case_participants')
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'previousStatus', dsh.previous_status,
          'newStatus', dsh.new_status,
          'changedByRole', dsh.changed_by_role,
          'publicNote', dsh.public_note,
          'createdAt', dsh.created_at
        )
        order by dsh.created_at asc, dsh.id::text asc
      )
      from public.dispute_status_history dsh
      where dsh.dispute_id = od.id
    ), '[]'::jsonb)
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  left join public.order_items target_item on target_item.id = od.affected_order_item_id and target_item.order_id = od.order_id
  left join public.products target_product on target_product.id = target_item.product_id
  join public.order_items oi on oi.order_id = od.order_id
  join public.products p on p.id = oi.product_id
  where od.id = p_dispute_id
    and od.deleted_at is null
    and (
      od.affected_supplier_id = v_supplier_id
      or (
        od.scope_type = 'order'
        and (
          select count(distinct oi2.supplier_id)
          from public.order_items oi2
          where oi2.order_id = od.order_id
        ) = 1
        and exists (
          select 1
          from public.order_items oi3
          where oi3.order_id = od.order_id
            and oi3.supplier_id = v_supplier_id
        )
      )
    )
    and (
      od.scope_type <> 'order_item'
      or exists (
        select 1
        from public.order_items scoped_item
        where scoped_item.id = od.affected_order_item_id
          and scoped_item.order_id = od.order_id
          and scoped_item.supplier_id = v_supplier_id
      )
    )
    and (
      od.scope_type <> 'supplier'
      or exists (
        select 1
        from public.order_items scoped_supplier_item
        where scoped_supplier_item.order_id = od.order_id
          and scoped_supplier_item.supplier_id = v_supplier_id
      )
    )
  group by od.id, o.order_number, od.scope_type, target_product.name, od.dispute_category, od.reason_code, od.requested_outcome, od.status, od.priority, od.supplier_action_required, od.opened_at, od.updated_at, od.description, od.opened_by_role, od.public_resolution_message, od.customer_action_required, od.return_review_required;
end;
$fn$;

drop function if exists public.get_reseller_dispute_impact_safe(uuid, integer);
create function public.get_reseller_dispute_impact_safe(p_order_id uuid default null, p_limit integer default 20)
returns table (
  safe_order_reference text,
  dispute_exists boolean,
  dispute_status text,
  scope_type text,
  safe_target_summary text,
  commission_impact_state text,
  opened_at timestamptz,
  resolved_at timestamptz,
  safe_summary text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  v_reseller_id := public.current_dispute_reseller_id();

  if v_reseller_id is null then
    raise exception 'RESELLER_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    o.order_number,
    (od.id is not null),
    od.status,
    od.scope_type,
    case
      when od.id is null then null
      when od.scope_type = 'order_item' then 'Item-level review'
      when od.scope_type = 'supplier' then 'Supplier-level review'
      else 'Order-level review'
    end,
    case
      when od.id is null then 'none'
      when od.status in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'refund_review') then 'review_pending'
      when od.status in ('return_review') then 'future_hold_possible'
      when od.status in ('resolved_supplier', 'rejected', 'closed', 'cancelled') then 'resolved_no_effect'
      when od.status in ('resolved_customer', 'partially_resolved') then 'adjustment_required_later'
      else 'review_pending'
    end,
    od.opened_at,
    od.resolved_at,
    case
      when od.id is null then 'No dispute is linked to this order.'
      when od.status in ('resolved_customer', 'partially_resolved') then 'A dispute resolution may affect commission in a later finance phase.'
      when od.status in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'return_review', 'refund_review') then 'A dispute is under review. Commission handling remains controlled by finance rules.'
      else 'Dispute has no current reseller action.'
    end
  from public.orders o
  left join lateral (
    select d.id, d.status, d.scope_type, d.opened_at, d.resolved_at
    from public.order_disputes d
    where d.order_id = o.id
      and d.deleted_at is null
    order by d.opened_at desc, d.id::text desc
    limit 1
  ) od on true
  where o.reseller_id = v_reseller_id
    and o.deleted_at is null
    and (p_order_id is null or o.id = p_order_id)
  order by coalesce(od.opened_at, o.created_at) desc, o.id::text desc
  limit v_limit;
end;
$fn$;

drop function if exists public.list_admin_disputes_safe(text, text, text, boolean, boolean, integer, timestamptz, uuid);
create function public.list_admin_disputes_safe(
  p_status text default null,
  p_category text default null,
  p_priority text default null,
  p_assigned_only boolean default false,
  p_finance_review_required boolean default null,
  p_limit integer default 50,
  p_cursor_opened_at timestamptz default null,
  p_cursor_dispute_id uuid default null
)
returns table (
  dispute_id uuid,
  safe_order_reference text,
  scope_type text,
  safe_target_summary text,
  multi_supplier_order boolean,
  category text,
  reason_code text,
  requested_outcome text,
  status text,
  priority text,
  assigned_to_current_admin boolean,
  customer_action_required boolean,
  supplier_action_required boolean,
  finance_review_required boolean,
  return_review_required boolean,
  opened_by_role text,
  opened_at timestamptz,
  updated_at timestamptz,
  safe_next_action text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_category text := nullif(trim(coalesce(p_category, '')), '');
  v_priority text := nullif(trim(coalesce(p_priority, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  v_admin_profile_id := public.current_dispute_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'DISPUTE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  if v_status is not null and v_status not in (
    'open', 'awaiting_customer', 'awaiting_supplier', 'under_review',
    'return_review', 'refund_review', 'resolved_customer', 'resolved_supplier',
    'partially_resolved', 'rejected', 'cancelled', 'closed'
  ) then
    raise exception 'INVALID_STATUS_FILTER' using errcode = '23514';
  end if;

  if v_category is not null and v_category not in ('pre_delivery', 'delivery', 'payment', 'post_completion', 'accounting', 'other') then
    raise exception 'INVALID_CATEGORY_FILTER' using errcode = '23514';
  end if;

  if v_priority is not null and v_priority not in ('normal', 'high', 'urgent') then
    raise exception 'INVALID_PRIORITY_FILTER' using errcode = '23514';
  end if;

  return query
  select
    od.id,
    o.order_number,
    od.scope_type,
    case
      when od.scope_type = 'order_item' then coalesce(p.name, 'Affected item')
      when od.scope_type = 'supplier' then 'Affected supplier'
      else 'Order-wide'
    end,
    ((select count(distinct oi.supplier_id) from public.order_items oi where oi.order_id = od.order_id) > 1),
    od.dispute_category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.priority,
    (od.assigned_admin_profile_id = v_admin_profile_id),
    od.customer_action_required,
    od.supplier_action_required,
    od.finance_review_required,
    od.return_review_required,
    od.opened_by_role,
    od.opened_at,
    od.updated_at,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, od.finance_review_required, od.return_review_required)
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  left join public.order_items target_item on target_item.id = od.affected_order_item_id and target_item.order_id = od.order_id
  left join public.products p on p.id = target_item.product_id
  where od.deleted_at is null
    and (v_status is null or od.status = v_status)
    and (v_category is null or od.dispute_category = v_category)
    and (v_priority is null or od.priority = v_priority)
    and (p_assigned_only = false or od.assigned_admin_profile_id = v_admin_profile_id)
    and (p_finance_review_required is null or od.finance_review_required = p_finance_review_required)
    and (
      p_cursor_opened_at is null
      or od.opened_at < p_cursor_opened_at
      or (
        p_cursor_dispute_id is not null
        and od.opened_at = p_cursor_opened_at
        and od.id::text < p_cursor_dispute_id::text
      )
    )
  order by od.opened_at desc, od.id::text desc
  limit v_limit;
end;
$fn$;

drop function if exists public.get_admin_dispute_safe(uuid);
create function public.get_admin_dispute_safe(p_dispute_id uuid)
returns table (
  dispute_id uuid,
  safe_order_reference text,
  scope_type text,
  safe_target_summary text,
  multi_supplier_order boolean,
  category text,
  reason_code text,
  description text,
  requested_outcome text,
  status text,
  priority text,
  assigned_admin_profile_id uuid,
  customer_action_required boolean,
  supplier_action_required boolean,
  finance_review_required boolean,
  return_review_required boolean,
  opened_by_role text,
  opened_at timestamptz,
  updated_at timestamptz,
  resolution_code text,
  resolution_summary text,
  public_resolution_message text,
  internal_resolution_notes text,
  finance_context jsonb,
  messages jsonb,
  status_history jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
  v_finance_profile_id uuid;
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  v_admin_profile_id := public.current_dispute_admin_profile_id();
  v_finance_profile_id := public.current_dispute_finance_admin_profile_id();

  if v_admin_profile_id is null and v_finance_profile_id is null then
    raise exception 'DISPUTE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    od.id,
    o.order_number,
    od.scope_type,
    case
      when od.scope_type = 'order_item' then coalesce(p.name, 'Affected item')
      when od.scope_type = 'supplier' then 'Affected supplier'
      else 'Order-wide'
    end,
    ((select count(distinct oi.supplier_id) from public.order_items oi where oi.order_id = od.order_id) > 1),
    od.dispute_category,
    od.reason_code,
    od.description,
    od.requested_outcome,
    od.status,
    od.priority,
    od.assigned_admin_profile_id,
    od.customer_action_required,
    od.supplier_action_required,
    od.finance_review_required,
    od.return_review_required,
    od.opened_by_role,
    od.opened_at,
    od.updated_at,
    od.resolution_code,
    od.resolution_summary,
    od.public_resolution_message,
    od.internal_resolution_notes,
    case
      when v_finance_profile_id is null then jsonb_build_object('financeReviewVisible', false)
      else jsonb_build_object(
        'financeReviewVisible', true,
        'paymentCollectionStatus', o.payment_collection_status::text,
        'orderStatus', o.order_status::text,
        'settlementStatus', coalesce(st.settlement_status::text, 'none'),
        'commissionStatus', coalesce(cm.commission_status::text, 'none'),
        'withdrawalRisk', case when cm.commission_status in ('withdrawal_requested', 'paid') then 'review_required' else 'none' end
      )
    end,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'messageId', dm.id,
          'authorRole', dm.author_role,
          'messageType', dm.message_type,
          'visibility', dm.visibility,
          'body', dm.body,
          'createdAt', dm.created_at
        )
        order by dm.created_at asc, dm.id::text asc
      )
      from public.dispute_messages dm
      where dm.dispute_id = od.id
        and dm.deleted_at is null
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'previousStatus', dsh.previous_status,
          'newStatus', dsh.new_status,
          'changedByRole', dsh.changed_by_role,
          'reasonCode', dsh.reason_code,
          'publicNote', dsh.public_note,
          'internalNote', dsh.internal_note,
          'createdAt', dsh.created_at
        )
        order by dsh.created_at asc, dsh.id::text asc
      )
      from public.dispute_status_history dsh
      where dsh.dispute_id = od.id
    ), '[]'::jsonb)
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  left join public.order_items target_item on target_item.id = od.affected_order_item_id and target_item.order_id = od.order_id
  left join public.products p on p.id = target_item.product_id
  left join public.settlements st on st.order_id = o.id and st.deleted_at is null
  left join public.commissions cm on cm.order_id = o.id
  where od.id = p_dispute_id
    and od.deleted_at is null
  order by st.created_at desc nulls last, cm.created_at desc nulls last
  limit 1;
end;
$fn$;

revoke all on function public.validate_order_dispute_target() from public, anon, authenticated;
revoke all on function public.customer_dispute_reason_scope(text, uuid, integer) from public, anon, authenticated;

revoke all on function public.customer_open_order_dispute(uuid, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.customer_open_order_dispute(uuid, uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.customer_open_order_dispute(uuid, uuid, text, text, text, text, text) to authenticated;

revoke all on function public.list_customer_disputes_safe(text, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_customer_disputes_safe(text, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_customer_dispute_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_customer_dispute_safe(uuid) to authenticated;

revoke all on function public.list_supplier_disputes_safe(text, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_supplier_disputes_safe(text, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_supplier_dispute_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_supplier_dispute_safe(uuid) to authenticated;

revoke all on function public.get_reseller_dispute_impact_safe(uuid, integer) from public, anon, authenticated;
grant execute on function public.get_reseller_dispute_impact_safe(uuid, integer) to authenticated;

revoke all on function public.list_admin_disputes_safe(text, text, text, boolean, boolean, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_admin_disputes_safe(text, text, text, boolean, boolean, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_admin_dispute_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_admin_dispute_safe(uuid) to authenticated;

comment on column public.order_disputes.scope_type is
  'D5-A immutable dispute target scope: order, supplier, or order_item.';

comment on column public.order_disputes.affected_supplier_id is
  'D5-A immutable affected supplier target, derived server-side from order_items.supplier_id. Null for order-wide cases.';

comment on column public.order_disputes.affected_order_item_id is
  'D5-A immutable affected order item target, supplied by customer but validated against the customer-owned order and supplier snapshot.';

comment on function public.customer_open_order_dispute(uuid, uuid, text, text, text, text, text) is
  'D5-A customer-only audited dispute creation RPC. Customer supplies order and optional order item only; supplier target is derived from immutable order_items.supplier_id and target-aware idempotency/uniqueness is enforced.';

comment on function public.list_supplier_disputes_safe(text, integer, timestamptz, uuid) is
  'D5-A supplier-owner read RPC. Resolves supplier from authenticated profile and returns only explicitly targeted supplier/item cases plus single-supplier order-wide cases.';

comment on function public.get_supplier_dispute_safe(uuid) is
  'D5-A supplier-owner detail RPC. Blocks suppliers from seeing disputes merely because another item on the same order belongs to them.';
