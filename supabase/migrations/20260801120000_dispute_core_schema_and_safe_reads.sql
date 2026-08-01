-- Disputes, Returns, and Refunds D2: core dispute schema and read-only safe RPCs.
-- Forward-only draft. No refund, return, finance-hold, settlement, commission,
-- withdrawal, payment, stock, reservation, evidence-upload, notification, or
-- provider side effects are introduced here.

create table if not exists public.order_disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  opened_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  opened_by_role text not null,
  dispute_category text not null,
  reason_code text not null,
  description text,
  requested_outcome text not null default 'information_only',
  status text not null default 'open',
  priority text not null default 'normal',
  assigned_admin_profile_id uuid references public.profiles(id) on delete set null,
  customer_action_required boolean not null default false,
  supplier_action_required boolean not null default false,
  finance_review_required boolean not null default false,
  return_review_required boolean not null default false,
  opened_at timestamptz not null default now(),
  first_response_at timestamptz,
  resolved_at timestamptz,
  closed_at timestamptz,
  resolution_code text,
  resolution_summary text,
  public_resolution_message text,
  internal_resolution_notes text,
  idempotency_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint order_disputes_opened_by_role_allowed check (
    opened_by_role in ('customer', 'supplier', 'reseller', 'support_staff', 'finance_staff', 'super_admin', 'system')
  ),
  constraint order_disputes_category_allowed check (
    dispute_category in ('pre_delivery', 'delivery', 'payment', 'post_completion', 'accounting', 'other')
  ),
  constraint order_disputes_reason_allowed check (
    reason_code in (
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
      'commission_missing',
      'settlement_discrepancy',
      'other'
    )
  ),
  constraint order_disputes_status_allowed check (
    status in (
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
  constraint order_disputes_requested_outcome_allowed check (
    requested_outcome in (
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
    )
  ),
  constraint order_disputes_priority_allowed check (priority in ('normal', 'high', 'urgent')),
  constraint order_disputes_resolution_allowed check (
    resolution_code is null
    or resolution_code in (
      'customer_favoured',
      'supplier_favoured',
      'partial_resolution',
      'accounting_correction_required',
      'return_process_required',
      'refund_review_required',
      'replacement_agreed',
      'redelivery_agreed',
      'no_action',
      'case_rejected',
      'case_cancelled'
    )
  ),
  constraint order_disputes_description_safe check (
    description is null
    or (
      length(trim(description)) between 1 and 1200
      and description !~ '<[^>]+>'
      and description !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)'
    )
  ),
  constraint order_disputes_resolution_summary_safe check (
    resolution_summary is null
    or (
      length(trim(resolution_summary)) <= 1200
      and resolution_summary !~ '<[^>]+>'
      and resolution_summary !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)'
    )
  ),
  constraint order_disputes_public_resolution_safe check (
    public_resolution_message is null
    or (
      length(trim(public_resolution_message)) <= 1200
      and public_resolution_message !~ '<[^>]+>'
      and public_resolution_message !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)'
    )
  ),
  constraint order_disputes_internal_notes_safe check (
    internal_resolution_notes is null
    or (
      length(trim(internal_resolution_notes)) <= 2000
      and internal_resolution_notes !~ '<[^>]+>'
      and internal_resolution_notes !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)'
    )
  ),
  constraint order_disputes_idempotency_key_safe check (
    idempotency_key is null
    or (
      length(trim(idempotency_key)) between 8 and 140
      and idempotency_key !~* '(password|secret|token|jwt|cookie)'
    )
  ),
  constraint order_disputes_resolution_requires_resolved_status check (
    resolution_code is null
    or status in ('resolved_customer', 'resolved_supplier', 'partially_resolved', 'rejected', 'cancelled', 'closed')
  ),
  constraint order_disputes_closed_at_matches_status check (
    closed_at is null or status = 'closed'
  )
);

create table if not exists public.dispute_messages (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  author_profile_id uuid references public.profiles(id) on delete set null,
  author_role text not null,
  message_type text not null default 'participant_response',
  body text,
  visibility text not null,
  is_system_message boolean not null default false,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  constraint dispute_messages_author_role_allowed check (
    author_role in ('customer', 'supplier', 'reseller', 'support_staff', 'finance_staff', 'super_admin', 'system')
  ),
  constraint dispute_messages_type_allowed check (
    message_type in ('participant_response', 'admin_request', 'public_admin_note', 'internal_admin_note', 'system_event')
  ),
  constraint dispute_messages_visibility_allowed check (
    visibility in ('customer_and_admin', 'supplier_and_admin', 'all_case_participants', 'admin_only', 'reseller_safe_summary')
  ),
  constraint dispute_messages_body_safe check (
    body is null
    or (
      length(trim(body)) between 1 and 2000
      and body !~ '<[^>]+>'
      and body !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)'
    )
  ),
  constraint dispute_messages_system_body check (
    is_system_message = false or message_type = 'system_event'
  )
);

create table if not exists public.dispute_status_history (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  previous_status text,
  new_status text not null,
  changed_by_profile_id uuid references public.profiles(id) on delete set null,
  changed_by_role text not null,
  reason_code text,
  public_note text,
  internal_note text,
  created_at timestamptz not null default now(),
  constraint dispute_status_history_previous_status_allowed check (
    previous_status is null
    or previous_status in (
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
  constraint dispute_status_history_new_status_allowed check (
    new_status in (
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
  constraint dispute_status_history_changed_by_role_allowed check (
    changed_by_role in ('customer', 'supplier', 'reseller', 'support_staff', 'finance_staff', 'super_admin', 'system')
  ),
  constraint dispute_status_history_reason_allowed check (
    reason_code is null
    or reason_code in (
      'customer_response',
      'supplier_response',
      'admin_request',
      'admin_review',
      'return_review',
      'refund_review',
      'resolution_recorded',
      'case_closed',
      'case_cancelled',
      'system_event'
    )
  ),
  constraint dispute_status_history_public_note_safe check (
    public_note is null
    or (
      length(trim(public_note)) <= 1200
      and public_note !~ '<[^>]+>'
      and public_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)'
    )
  ),
  constraint dispute_status_history_internal_note_safe check (
    internal_note is null
    or (
      length(trim(internal_note)) <= 2000
      and internal_note !~ '<[^>]+>'
      and internal_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin)'
    )
  )
);

create unique index if not exists order_disputes_opener_idempotency_unique
  on public.order_disputes(opened_by_profile_id, idempotency_key)
  where idempotency_key is not null and deleted_at is null;

create unique index if not exists order_disputes_active_reason_unique
  on public.order_disputes(order_id, opened_by_profile_id, reason_code)
  where deleted_at is null and status not in ('closed', 'cancelled', 'rejected');

create index if not exists order_disputes_order_created_idx
  on public.order_disputes(order_id, created_at desc);

create index if not exists order_disputes_opener_created_idx
  on public.order_disputes(opened_by_profile_id, created_at desc);

create index if not exists order_disputes_status_priority_created_idx
  on public.order_disputes(status, priority, created_at desc)
  where deleted_at is null;

create index if not exists order_disputes_assignment_created_idx
  on public.order_disputes(assigned_admin_profile_id, created_at desc)
  where deleted_at is null;

create index if not exists order_disputes_category_created_idx
  on public.order_disputes(dispute_category, created_at desc)
  where deleted_at is null;

create index if not exists dispute_messages_dispute_created_idx
  on public.dispute_messages(dispute_id, created_at asc)
  where deleted_at is null;

create index if not exists dispute_status_history_dispute_created_idx
  on public.dispute_status_history(dispute_id, created_at asc);

alter table public.order_disputes enable row level security;
alter table public.order_disputes force row level security;
alter table public.dispute_messages enable row level security;
alter table public.dispute_messages force row level security;
alter table public.dispute_status_history enable row level security;
alter table public.dispute_status_history force row level security;

revoke all on public.order_disputes from public, anon, authenticated;
revoke all on public.dispute_messages from public, anon, authenticated;
revoke all on public.dispute_status_history from public, anon, authenticated;

create or replace function public.current_dispute_admin_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  join public.admin_staff a on a.profile_id = p.id
  where p.id = public.current_profile_id()
    and p.account_status = 'active'
    and p.deleted_at is null
    and a.staff_status = 'active'
    and a.deleted_at is null
    and a.admin_role in ('support_staff', 'admin', 'super_admin')
  order by a.created_at asc, a.id::text asc
  limit 1;
$$;

create or replace function public.current_dispute_finance_admin_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  join public.admin_staff a on a.profile_id = p.id
  where p.id = public.current_profile_id()
    and p.account_status = 'active'
    and p.deleted_at is null
    and a.staff_status = 'active'
    and a.deleted_at is null
    and a.admin_role in ('finance_staff', 'super_admin')
  order by a.created_at asc, a.id::text asc
  limit 1;
$$;

create or replace function public.current_dispute_customer_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.id
  from public.customers c
  join public.profiles p on p.id = c.profile_id
  where p.id = public.current_profile_id()
    and p.primary_role = 'customer'
    and p.account_status = 'active'
    and p.deleted_at is null
    and c.customer_status = 'active'
    and c.deleted_at is null
    and not exists (
      select 1
      from public.admin_staff a
      where a.profile_id = p.id
        and a.staff_status = 'active'
        and a.deleted_at is null
    )
  order by c.created_at asc, c.id::text asc
  limit 1;
$$;

create or replace function public.current_dispute_supplier_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.suppliers s
  join public.profiles p on p.id = s.owner_profile_id
  where p.id = public.current_profile_id()
    and p.primary_role = 'supplier_owner'
    and p.account_status = 'active'
    and p.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and s.deleted_at is null
    and not exists (
      select 1
      from public.admin_staff a
      where a.profile_id = p.id
        and a.staff_status = 'active'
        and a.deleted_at is null
    )
  order by s.created_at asc, s.id::text asc
  limit 1;
$$;

create or replace function public.current_dispute_reseller_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select r.id
  from public.resellers r
  join public.profiles p on p.id = r.profile_id
  where p.id = public.current_profile_id()
    and p.primary_role = 'reseller'
    and p.account_status = 'active'
    and p.deleted_at is null
    and r.approval_status = 'approved'
    and r.deleted_at is null
    and not exists (
      select 1
      from public.admin_staff a
      where a.profile_id = p.id
        and a.staff_status = 'active'
        and a.deleted_at is null
    )
  order by r.created_at asc, r.id::text asc
  limit 1;
$$;

create or replace function public.dispute_next_action_label(
  p_status text,
  p_customer_action_required boolean,
  p_supplier_action_required boolean,
  p_finance_review_required boolean,
  p_return_review_required boolean
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_status = 'closed' then 'Case closed'
    when p_status in ('resolved_customer', 'resolved_supplier', 'partially_resolved') then 'Resolution recorded'
    when p_status = 'rejected' then 'Case rejected'
    when p_customer_action_required then 'Waiting for customer'
    when p_supplier_action_required then 'Waiting for supplier'
    when p_finance_review_required then 'Finance review required'
    when p_return_review_required then 'Return review required'
    when p_status = 'open' then 'New case awaiting review'
    when p_status = 'under_review' then 'Risellar is reviewing this case'
    else 'Review in progress'
  end;
$$;

create or replace function public.list_customer_disputes_safe(
  p_status text default null,
  p_limit integer default 20,
  p_cursor_opened_at timestamptz default null,
  p_cursor_dispute_id uuid default null
)
returns table (
  dispute_id uuid,
  safe_order_reference text,
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
    raise exception 'CUSTOMER_REQUIRED'
      using errcode = '42501';
  end if;

  if v_status is not null and v_status not in (
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
  ) then
    raise exception 'INVALID_STATUS_FILTER'
      using errcode = '23514';
  end if;

  return query
  select
    od.id as dispute_id,
    o.order_number as safe_order_reference,
    od.dispute_category as category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.customer_action_required,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    lm.body as safe_latest_message,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required) as safe_next_action
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
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

create or replace function public.get_customer_dispute_safe(p_dispute_id uuid)
returns table (
  dispute_id uuid,
  safe_order_reference text,
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
    raise exception 'DISPUTE_ID_REQUIRED'
      using errcode = '23514';
  end if;

  v_customer_id := public.current_dispute_customer_id();

  if v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED'
      using errcode = '42501';
  end if;

  return query
  select
    od.id as dispute_id,
    o.order_number as safe_order_reference,
    od.dispute_category as category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.priority,
    od.customer_action_required,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    od.public_resolution_message,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required) as safe_next_action,
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
    ), '[]'::jsonb) as messages,
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
    ), '[]'::jsonb) as status_history
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  where od.id = p_dispute_id
    and od.deleted_at is null
    and o.customer_id = v_customer_id;
end;
$fn$;

create or replace function public.list_supplier_disputes_safe(
  p_status text default null,
  p_limit integer default 20,
  p_cursor_opened_at timestamptz default null,
  p_cursor_dispute_id uuid default null
)
returns table (
  dispute_id uuid,
  safe_order_reference text,
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
    raise exception 'SUPPLIER_REQUIRED'
      using errcode = '42501';
  end if;

  if v_status is not null and v_status not in (
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
  ) then
    raise exception 'INVALID_STATUS_FILTER'
      using errcode = '23514';
  end if;

  return query
  select
    od.id as dispute_id,
    o.order_number as safe_order_reference,
    od.dispute_category as category,
    od.reason_code,
    od.status,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required) as safe_next_action
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  where exists (
      select 1
      from public.order_items oi
      where oi.order_id = o.id
        and oi.supplier_id = v_supplier_id
    )
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

create or replace function public.get_supplier_dispute_safe(p_dispute_id uuid)
returns table (
  dispute_id uuid,
  safe_order_reference text,
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
    raise exception 'DISPUTE_ID_REQUIRED'
      using errcode = '23514';
  end if;

  v_supplier_id := public.current_dispute_supplier_id();

  if v_supplier_id is null then
    raise exception 'SUPPLIER_REQUIRED'
      using errcode = '42501';
  end if;

  return query
  select
    od.id as dispute_id,
    o.order_number as safe_order_reference,
    od.dispute_category as category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.priority,
    od.supplier_action_required,
    od.opened_at,
    od.updated_at,
    string_agg(distinct p.name, ', ' order by p.name) as product_names,
    case
      when od.description is not null and od.opened_by_role in ('customer', 'support_staff', 'super_admin') then od.description
      else null
    end as safe_customer_claim,
    od.public_resolution_message,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, false, od.return_review_required) as safe_next_action,
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
    ), '[]'::jsonb) as messages,
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
    ), '[]'::jsonb) as status_history
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  join public.order_items oi on oi.order_id = o.id
  join public.products p on p.id = oi.product_id
  where od.id = p_dispute_id
    and od.deleted_at is null
    and oi.supplier_id = v_supplier_id
  group by od.id, o.order_number, od.dispute_category, od.reason_code, od.requested_outcome, od.status, od.priority, od.supplier_action_required, od.opened_at, od.updated_at, od.description, od.opened_by_role, od.public_resolution_message, od.customer_action_required, od.return_review_required;
end;
$fn$;

create or replace function public.get_reseller_dispute_impact_safe(p_order_id uuid default null, p_limit integer default 20)
returns table (
  safe_order_reference text,
  dispute_exists boolean,
  dispute_status text,
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
    raise exception 'RESELLER_REQUIRED'
      using errcode = '42501';
  end if;

  return query
  select
    o.order_number as safe_order_reference,
    (od.id is not null) as dispute_exists,
    od.status as dispute_status,
    case
      when od.id is null then 'none'
      when od.status in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'refund_review') then 'review_pending'
      when od.status in ('return_review') then 'future_hold_possible'
      when od.status in ('resolved_supplier', 'rejected', 'closed', 'cancelled') then 'resolved_no_effect'
      when od.status in ('resolved_customer', 'partially_resolved') then 'adjustment_required_later'
      else 'review_pending'
    end as commission_impact_state,
    od.opened_at,
    od.resolved_at,
    case
      when od.id is null then 'No dispute is linked to this order.'
      when od.status in ('resolved_customer', 'partially_resolved') then 'A dispute resolution may affect commission in a later finance phase.'
      when od.status in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'return_review', 'refund_review') then 'A dispute is under review. Commission handling remains controlled by finance rules.'
      else 'Dispute has no current reseller action.'
    end as safe_summary
  from public.orders o
  left join lateral (
    select d.id, d.status, d.opened_at, d.resolved_at
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

create or replace function public.list_admin_disputes_safe(
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
    raise exception 'DISPUTE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  if v_status is not null and v_status not in (
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
  ) then
    raise exception 'INVALID_STATUS_FILTER'
      using errcode = '23514';
  end if;

  if v_category is not null and v_category not in ('pre_delivery', 'delivery', 'payment', 'post_completion', 'accounting', 'other') then
    raise exception 'INVALID_CATEGORY_FILTER'
      using errcode = '23514';
  end if;

  if v_priority is not null and v_priority not in ('normal', 'high', 'urgent') then
    raise exception 'INVALID_PRIORITY_FILTER'
      using errcode = '23514';
  end if;

  return query
  select
    od.id as dispute_id,
    o.order_number as safe_order_reference,
    od.dispute_category as category,
    od.reason_code,
    od.requested_outcome,
    od.status,
    od.priority,
    (od.assigned_admin_profile_id = v_admin_profile_id) as assigned_to_current_admin,
    od.customer_action_required,
    od.supplier_action_required,
    od.finance_review_required,
    od.return_review_required,
    od.opened_by_role,
    od.opened_at,
    od.updated_at,
    public.dispute_next_action_label(od.status, od.customer_action_required, od.supplier_action_required, od.finance_review_required, od.return_review_required) as safe_next_action
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
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

create or replace function public.get_admin_dispute_safe(p_dispute_id uuid)
returns table (
  dispute_id uuid,
  safe_order_reference text,
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
    raise exception 'DISPUTE_ID_REQUIRED'
      using errcode = '23514';
  end if;

  v_admin_profile_id := public.current_dispute_admin_profile_id();
  v_finance_profile_id := public.current_dispute_finance_admin_profile_id();

  if v_admin_profile_id is null and v_finance_profile_id is null then
    raise exception 'DISPUTE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  return query
  select
    od.id as dispute_id,
    o.order_number as safe_order_reference,
    od.dispute_category as category,
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
    end as finance_context,
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
    ), '[]'::jsonb) as messages,
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
    ), '[]'::jsonb) as status_history
  from public.order_disputes od
  join public.orders o on o.id = od.order_id and o.deleted_at is null
  left join public.settlements st on st.order_id = o.id and st.deleted_at is null
  left join public.commissions cm on cm.order_id = o.id
  where od.id = p_dispute_id
    and od.deleted_at is null
  order by st.created_at desc nulls last, cm.created_at desc nulls last
  limit 1;
end;
$fn$;

revoke all on function public.current_dispute_admin_profile_id() from public, anon, authenticated;

revoke all on function public.current_dispute_finance_admin_profile_id() from public, anon, authenticated;

revoke all on function public.current_dispute_customer_id() from public, anon, authenticated;

revoke all on function public.current_dispute_supplier_id() from public, anon, authenticated;

revoke all on function public.current_dispute_reseller_id() from public, anon, authenticated;

revoke all on function public.dispute_next_action_label(text, boolean, boolean, boolean, boolean) from public, anon, authenticated;

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

comment on table public.order_disputes is
  'Core dispute case table for order-linked support investigations. D2 stores no refund amount, return shipment, finance hold, settlement mutation, commission mutation, withdrawal mutation, payment mutation, stock mutation, evidence file, or provider state.';

comment on table public.dispute_messages is
  'Append-only dispute message table. Participant messages and admin notes are separated by controlled visibility; direct browser table access is revoked.';

comment on table public.dispute_status_history is
  'Append-only dispute status history. Future mutation RPCs must write history in the same transaction as case status changes.';

comment on function public.list_customer_disputes_safe(text, integer, timestamptz, uuid) is
  'Customer-only read RPC. Resolves customer from authenticated profile and returns customer-safe dispute list fields only.';

comment on function public.get_customer_dispute_safe(uuid) is
  'Customer-only detail read RPC. Excludes admin-only notes, finance internals, supplier private messages, reseller commission, settlement, wallet, withdrawal, and evidence paths.';

comment on function public.list_supplier_disputes_safe(text, integer, timestamptz, uuid) is
  'Supplier-owner read RPC. Resolves supplier from authenticated profile and returns only disputes linked to that supplier through order_items.';

comment on function public.get_supplier_dispute_safe(uuid) is
  'Supplier-owner detail read RPC. Excludes customer auth metadata, unrelated address data, admin-only notes, reseller wallet details, settlement proof, and other supplier data.';

comment on function public.get_reseller_dispute_impact_safe(uuid, integer) is
  'Reseller-safe impact read. Returns only safe order reference, dispute status, and commission-impact state; no complaint text, evidence, settlement, refund, or private messages.';

comment on function public.list_admin_disputes_safe(text, text, text, boolean, boolean, integer, timestamptz, uuid) is
  'Support/admin dispute list read. Requires active support_staff/admin/super_admin admin_staff membership and returns no unrestricted finance details.';

comment on function public.get_admin_dispute_safe(uuid) is
  'Admin dispute detail read. Finance context is included only for active finance_staff/super_admin callers.';
