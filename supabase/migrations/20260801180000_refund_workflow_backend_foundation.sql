-- Disputes, Returns, and Refunds D8: refund workflow backend foundation.
-- Backend-only, forward-only. Records manual refund obligations and verification.
-- Does not issue provider refunds, create finance holds, mutate settlements,
-- commissions, wallets, withdrawals, stock, reservations, orders, payments,
-- returns, notifications, or activate UI.

create table if not exists public.order_refunds (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  return_id uuid references public.order_item_returns(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid references public.order_items(id) on delete restrict,
  customer_profile_id uuid not null references public.profiles(id) on delete restrict,
  affected_supplier_id uuid references public.suppliers(id) on delete restrict,
  refund_type text not null,
  status text not null default 'awaiting_responsible_party',
  responsibility_code text not null,
  responsible_party_role text not null,
  approved_amount numeric(12,2) not null,
  currency_code text not null,
  item_amount_component numeric(12,2) not null default 0,
  delivery_fee_component numeric(12,2) not null default 0,
  goodwill_component numeric(12,2) not null default 0,
  approved_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  approved_at timestamptz not null default now(),
  reported_sent_by_profile_id uuid references public.profiles(id) on delete set null,
  reported_sent_at timestamptz,
  refund_method text,
  external_reference_masked text,
  sender_note text,
  customer_confirmation_status text not null default 'not_requested',
  customer_confirmed_at timestamptz,
  verified_by_profile_id uuid references public.profiles(id) on delete set null,
  verified_at timestamptz,
  rejected_by_profile_id uuid references public.profiles(id) on delete set null,
  rejected_at timestamptz,
  rejection_reason_public text,
  internal_notes text,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint order_refunds_type_allowed check (
    refund_type in ('full_refund', 'partial_refund', 'item_value_refund_only', 'delivery_fee_refund_only', 'goodwill_refund')
  ),
  constraint order_refunds_status_allowed check (
    status in (
      'approved',
      'awaiting_responsible_party',
      'reported_sent',
      'awaiting_customer_confirmation',
      'under_verification',
      'verified',
      'rejected',
      'failed_manual_payment',
      'cancelled',
      'completed'
    )
  ),
  constraint order_refunds_responsibility_allowed check (
    responsibility_code in (
      'supplier_responsible',
      'platform_responsible',
      'reseller_responsible',
      'delivery_partner_responsible',
      'shared_responsibility'
    )
  ),
  constraint order_refunds_party_role_allowed check (
    responsible_party_role in ('supplier', 'platform', 'reseller', 'delivery_partner', 'shared')
  ),
  constraint order_refunds_method_allowed check (
    refund_method is null
    or refund_method in ('cash', 'mobile_money', 'bank_transfer', 'original_manual_method', 'other_manual_method')
  ),
  constraint order_refunds_customer_confirmation_allowed check (
    customer_confirmation_status in ('not_requested', 'pending', 'confirmed_received', 'disputed_not_received', 'waived')
  ),
  constraint order_refunds_amounts_nonnegative check (
    item_amount_component >= 0
    and delivery_fee_component >= 0
    and goodwill_component >= 0
    and approved_amount > 0
    and approved_amount = item_amount_component + delivery_fee_component + goodwill_component
  ),
  constraint order_refunds_currency_safe check (currency_code = upper(trim(currency_code)) and length(trim(currency_code)) between 3 and 12),
  constraint order_refunds_reference_safe check (
    external_reference_masked is null
    or (
      length(trim(external_reference_masked)) between 2 and 80
      and external_reference_masked !~ '<[^>]+>'
      and external_reference_masked !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'
    )
  ),
  constraint order_refunds_notes_safe check (
    (sender_note is null or (length(trim(sender_note)) between 1 and 1200 and sender_note !~ '<[^>]+>' and sender_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
    and (rejection_reason_public is null or (length(trim(rejection_reason_public)) between 1 and 1200 and rejection_reason_public !~ '<[^>]+>' and rejection_reason_public !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
    and (internal_notes is null or (length(trim(internal_notes)) between 1 and 2000 and internal_notes !~ '<[^>]+>' and internal_notes !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
  ),
  constraint order_refunds_return_item_consistency check (
    return_id is null or order_item_id is not null
  ),
  constraint order_refunds_supplier_item_consistency check (
    (order_item_id is null and affected_supplier_id is null)
    or (order_item_id is not null and affected_supplier_id is not null)
  )
);

create table if not exists public.refund_actions (
  id uuid primary key default gen_random_uuid(),
  refund_id uuid references public.order_refunds(id) on delete restrict,
  dispute_id uuid references public.order_disputes(id) on delete restrict,
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  actor_role text not null,
  action_type text not null,
  idempotency_key text not null,
  request_fingerprint text not null,
  result_refund_id uuid references public.order_refunds(id) on delete restrict,
  result_status text,
  created_at timestamptz not null default now(),
  constraint refund_actions_target_scope check ((refund_id is null) <> (dispute_id is null)),
  constraint refund_actions_role_allowed check (actor_role in ('customer', 'supplier', 'finance_staff', 'super_admin')),
  constraint refund_actions_type_allowed check (
    action_type in (
      'approve_obligation',
      'supplier_report_sent',
      'platform_report_sent',
      'customer_confirm_received',
      'customer_dispute_not_received',
      'finance_verify',
      'finance_reject_report',
      'finance_complete',
      'finance_cancel'
    )
  ),
  constraint refund_actions_key_safe check (
    length(trim(idempotency_key)) between 8 and 140
    and idempotency_key !~* '(password|secret|token|jwt|cookie)'
  )
);

create unique index if not exists order_refunds_active_scope_idx
  on public.order_refunds(
    dispute_id,
    coalesce(order_item_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(return_id, '00000000-0000-0000-0000-000000000000'::uuid),
    refund_type,
    responsibility_code
  )
  where deleted_at is null
    and status in ('approved', 'awaiting_responsible_party', 'reported_sent', 'awaiting_customer_confirmation', 'under_verification');

create index if not exists order_refunds_customer_status_idx
  on public.order_refunds(customer_profile_id, status, created_at desc)
  where deleted_at is null;

create index if not exists order_refunds_supplier_status_idx
  on public.order_refunds(affected_supplier_id, status, created_at desc)
  where deleted_at is null and affected_supplier_id is not null;

create index if not exists order_refunds_dispute_idx
  on public.order_refunds(dispute_id, created_at desc)
  where deleted_at is null;

create unique index if not exists refund_actions_dispute_key_idx
  on public.refund_actions(dispute_id, actor_profile_id, action_type, idempotency_key)
  where dispute_id is not null;

create unique index if not exists refund_actions_refund_key_idx
  on public.refund_actions(refund_id, actor_profile_id, action_type, idempotency_key)
  where refund_id is not null;

alter table public.order_refunds enable row level security;
alter table public.order_refunds force row level security;
alter table public.refund_actions enable row level security;
alter table public.refund_actions force row level security;

revoke all on public.order_refunds from public, anon, authenticated;
revoke all on public.refund_actions from public, anon, authenticated;

create or replace function public.refund_workflow_assert_key(p_idempotency_key text)
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

create or replace function public.refund_workflow_safe_text(
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
    raise exception 'REFUND_TEXT_REQUIRED' using errcode = '23514';
  end if;

  if v_value is null then
    return null;
  end if;

  if length(v_value) > p_max_length
    or v_value ~ '<[^>]+>'
    or v_value ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)' then
    raise exception 'INVALID_REFUND_TEXT' using errcode = '23514';
  end if;

  return v_value;
end;
$fn$;

create or replace function public.refund_workflow_safe_reference(p_value text)
returns text
language plpgsql
stable
set search_path = public
as $fn$
declare
  v_value text := nullif(trim(coalesce(p_value, '')), '');
begin
  if v_value is null then
    return null;
  end if;

  if length(v_value) > 80
    or v_value ~ '<[^>]+>'
    or v_value ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'
    or v_value ~ '[0-9]{7,}' then
    raise exception 'INVALID_REFUND_REFERENCE' using errcode = '23514';
  end if;

  return v_value;
end;
$fn$;

create or replace function public.refund_workflow_current_finance_admin()
returns table (
  profile_id uuid,
  admin_role public.user_role
)
language sql
stable
security definer
set search_path = public
as $fn$
  select p.id, a.admin_role
  from public.profiles p
  join public.admin_staff a on a.profile_id = p.id
  where p.id = public.current_profile_id()
    and p.account_status = 'active'
    and p.deleted_at is null
    and a.staff_status = 'active'
    and a.deleted_at is null
    and a.admin_role in ('finance_staff', 'super_admin')
  order by
    case a.admin_role when 'finance_staff' then 1 when 'super_admin' then 2 else 9 end,
    a.created_at asc,
    a.id::text asc
  limit 1;
$fn$;

create or replace function public.refund_workflow_actor_role(p_admin_role public.user_role)
returns text
language sql
immutable
set search_path = public
as $fn$
  select case when p_admin_role = 'super_admin' then 'super_admin' else 'finance_staff' end;
$fn$;

create or replace function public.refund_workflow_is_type(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('full_refund', 'partial_refund', 'item_value_refund_only', 'delivery_fee_refund_only', 'goodwill_refund');
$fn$;

create or replace function public.refund_workflow_is_responsibility(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('supplier_responsible', 'platform_responsible', 'reseller_responsible', 'delivery_partner_responsible', 'shared_responsibility');
$fn$;

create or replace function public.refund_workflow_is_party_role(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('supplier', 'platform', 'reseller', 'delivery_partner', 'shared');
$fn$;

create or replace function public.refund_workflow_is_method(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_value in ('cash', 'mobile_money', 'bank_transfer', 'original_manual_method', 'other_manual_method');
$fn$;

create or replace function public.refund_workflow_responsibility_matches_role(p_responsibility text, p_role text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select (p_responsibility, p_role) in (
    ('supplier_responsible', 'supplier'),
    ('platform_responsible', 'platform'),
    ('reseller_responsible', 'reseller'),
    ('delivery_partner_responsible', 'delivery_partner'),
    ('shared_responsibility', 'shared')
  );
$fn$;

create or replace function public.refund_workflow_prevent_target_update()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
  if old.dispute_id is distinct from new.dispute_id
    or old.return_id is distinct from new.return_id
    or old.order_id is distinct from new.order_id
    or old.order_item_id is distinct from new.order_item_id
    or old.customer_profile_id is distinct from new.customer_profile_id
    or old.affected_supplier_id is distinct from new.affected_supplier_id
    or old.currency_code is distinct from new.currency_code
    or old.approved_amount is distinct from new.approved_amount
    or old.item_amount_component is distinct from new.item_amount_component
    or old.delivery_fee_component is distinct from new.delivery_fee_component
    or old.goodwill_component is distinct from new.goodwill_component
    or old.refund_type is distinct from new.refund_type
    or old.responsibility_code is distinct from new.responsibility_code
    or old.responsible_party_role is distinct from new.responsible_party_role then
    raise exception 'REFUND_TARGET_IMMUTABLE' using errcode = '23514';
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists order_refunds_prevent_target_update on public.order_refunds;
create trigger order_refunds_prevent_target_update
before update on public.order_refunds
for each row execute function public.refund_workflow_prevent_target_update();

create or replace function public.refund_workflow_audit(
  p_actor_profile_id uuid,
  p_actor_role public.user_role,
  p_action text,
  p_refund_id uuid,
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
    'order_refund',
    p_refund_id,
    coalesce(p_after_data, '{}'::jsonb) - 'sender_note' - 'internal_notes' - 'rejection_reason_public' - 'external_reference_masked',
    p_reason,
    now()
  );
end;
$fn$;

create or replace function public.refund_workflow_dispute_reason_allows_refund(p_reason_code text, p_requested_outcome text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_reason_code in (
    'wrong_item_received',
    'damaged_item_received',
    'incomplete_order',
    'item_not_as_described',
    'product_quality_issue',
    'customer_paid_not_reported',
    'supplier_reported_customer_disagrees',
    'duplicate_payment_claim',
    'wrong_amount_collected',
    'unauthorised_extra_charge',
    'return_requested',
    'refund_requested'
  )
  or p_requested_outcome in ('full_refund', 'partial_refund', 'delivery_fee_refund');
$fn$;

create or replace function public.refund_workflow_active_status(p_status text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_status in ('approved', 'awaiting_responsible_party', 'reported_sent', 'awaiting_customer_confirmation', 'under_verification');
$fn$;

create or replace function public.refund_workflow_terminal_status(p_status text)
returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_status in ('verified', 'rejected', 'failed_manual_payment', 'cancelled', 'completed');
$fn$;

create or replace function public.admin_approve_refund_obligation(
  p_dispute_id uuid,
  p_return_id uuid,
  p_refund_type text,
  p_item_quantity integer,
  p_item_amount_component numeric,
  p_delivery_fee_component numeric,
  p_goodwill_component numeric,
  p_responsibility_code text,
  p_responsible_party_role text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  refund_id uuid,
  status text,
  approved_amount numeric,
  currency_code text,
  responsible_party_role text,
  created boolean,
  approved_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_type text := lower(trim(coalesce(p_refund_type, '')));
  v_responsibility text := lower(trim(coalesce(p_responsibility_code, '')));
  v_party_role text := lower(trim(coalesce(p_responsible_party_role, '')));
  v_public_note text := public.refund_workflow_safe_text(p_public_note, v_type = 'partial_refund', 1200);
  v_internal_note text := public.refund_workflow_safe_text(p_internal_note, false, 2000);
  v_finance record;
  v_dispute public.order_disputes%rowtype;
  v_order public.orders%rowtype;
  v_item public.order_items%rowtype;
  v_return public.order_item_returns%rowtype;
  v_customer_profile_id uuid;
  v_item_max numeric(12,2) := 0;
  v_order_max numeric(12,2) := 0;
  v_delivery_max numeric(12,2) := 0;
  v_remaining numeric(12,2);
  v_approved_amount numeric(12,2);
  v_scope_item_id uuid;
  v_scope_supplier_id uuid;
  v_existing public.order_refunds%rowtype;
  v_refund public.order_refunds%rowtype;
  v_fingerprint text;
  v_old_status text;
begin
  select * into v_finance from public.refund_workflow_current_finance_admin();
  if v_finance.profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  if not public.refund_workflow_is_type(v_type) then
    raise exception 'INVALID_REFUND_TYPE' using errcode = '23514';
  end if;

  if not public.refund_workflow_is_responsibility(v_responsibility)
    or not public.refund_workflow_is_party_role(v_party_role)
    or not public.refund_workflow_responsibility_matches_role(v_responsibility, v_party_role) then
    raise exception 'INVALID_REFUND_RESPONSIBILITY' using errcode = '23514';
  end if;

  if coalesce(p_goodwill_component, 0) <> 0 or v_type = 'goodwill_refund' then
    raise exception 'GOODWILL_REFUNDS_DEFERRED' using errcode = '23514';
  end if;

  if coalesce(p_item_amount_component, 0) < 0 or coalesce(p_delivery_fee_component, 0) < 0 then
    raise exception 'INVALID_REFUND_AMOUNT' using errcode = '23514';
  end if;

  v_approved_amount := coalesce(p_item_amount_component, 0) + coalesce(p_delivery_fee_component, 0);
  if v_approved_amount <= 0 then
    raise exception 'INVALID_REFUND_AMOUNT' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('d8:refund-approval:' || p_dispute_id::text, 0));

  select * into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id and od.deleted_at is null
  for update;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.status in ('closed', 'cancelled', 'rejected') then
    raise exception 'DISPUTE_NOT_REFUND_ELIGIBLE' using errcode = '23514';
  end if;

  if not public.refund_workflow_dispute_reason_allows_refund(v_dispute.reason_code, v_dispute.requested_outcome) then
    raise exception 'DISPUTE_NOT_REFUND_ELIGIBLE' using errcode = '23514';
  end if;

  select * into v_order
  from public.orders o
  where o.id = v_dispute.order_id and o.deleted_at is null
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = '42501';
  end if;

  select c.profile_id into v_customer_profile_id
  from public.customers c
  where c.id = v_order.customer_id and c.deleted_at is null;

  if v_customer_profile_id is null then
    raise exception 'CUSTOMER_NOT_FOUND' using errcode = '42501';
  end if;

  if p_return_id is not null then
    select * into v_return
    from public.order_item_returns r
    where r.id = p_return_id and r.deleted_at is null
    for update;

    if not found
      or v_return.dispute_id <> v_dispute.id
      or v_return.order_id <> v_order.id
      or v_return.status not in ('accepted', 'completed') then
      raise exception 'RETURN_NOT_REFUND_ELIGIBLE' using errcode = '23514';
    end if;
  end if;

  if v_dispute.scope_type = 'order_item' or p_return_id is not null then
    v_scope_item_id := coalesce(v_return.order_item_id, v_dispute.affected_order_item_id);
    select * into v_item
    from public.order_items oi
    where oi.id = v_scope_item_id and oi.order_id = v_order.id
    for update;

    if not found then
      raise exception 'ORDER_ITEM_NOT_FOUND' using errcode = '42501';
    end if;

    v_scope_supplier_id := v_item.supplier_id;
    if p_item_quantity is null or p_item_quantity <= 0 or p_item_quantity > v_item.quantity then
      raise exception 'INVALID_REFUND_QUANTITY' using errcode = '23514';
    end if;

    v_item_max := round((v_item.line_total_amount / v_item.quantity) * p_item_quantity, 2);
  else
    if p_item_quantity is not null then
      raise exception 'ITEM_QUANTITY_NOT_ALLOWED' using errcode = '23514';
    end if;
    v_scope_item_id := null;
    v_scope_supplier_id := null;
  end if;

  v_order_max := coalesce(v_order.total_payable_amount, 0);
  v_delivery_max := case
    when v_order.final_delivery_amount is not null then v_order.final_delivery_amount
    else 0
  end;

  if v_type in ('item_value_refund_only', 'partial_refund') and v_scope_item_id is null and coalesce(p_item_amount_component, 0) > 0 then
    raise exception 'ITEM_SCOPE_REQUIRED' using errcode = '23514';
  end if;

  if v_type = 'item_value_refund_only' and coalesce(p_delivery_fee_component, 0) <> 0 then
    raise exception 'INVALID_REFUND_COMPONENTS' using errcode = '23514';
  end if;

  if v_type = 'delivery_fee_refund_only' and coalesce(p_item_amount_component, 0) <> 0 then
    raise exception 'INVALID_REFUND_COMPONENTS' using errcode = '23514';
  end if;

  if coalesce(p_item_amount_component, 0) > v_item_max then
    raise exception 'REFUND_AMOUNT_EXCEEDS_CAP' using errcode = '23514';
  end if;

  if coalesce(p_delivery_fee_component, 0) > v_delivery_max then
    raise exception 'REFUND_AMOUNT_EXCEEDS_CAP' using errcode = '23514';
  end if;

  if v_approved_amount > v_order_max then
    raise exception 'REFUND_AMOUNT_EXCEEDS_CAP' using errcode = '23514';
  end if;

  v_remaining := v_order_max - coalesce((
    select sum(r.approved_amount)
    from public.order_refunds r
    where r.order_id = v_order.id
      and r.deleted_at is null
      and r.status in ('approved', 'awaiting_responsible_party', 'reported_sent', 'awaiting_customer_confirmation', 'under_verification', 'verified', 'completed')
  ), 0);

  if v_approved_amount > v_remaining then
    raise exception 'REFUND_AMOUNT_EXCEEDS_REMAINING_CAP' using errcode = '23514';
  end if;

  v_fingerprint := md5(jsonb_build_object(
    'dispute_id', p_dispute_id,
    'return_id', p_return_id,
    'refund_type', v_type,
    'item_quantity', p_item_quantity,
    'item_amount_component', coalesce(p_item_amount_component, 0),
    'delivery_fee_component', coalesce(p_delivery_fee_component, 0),
    'goodwill_component', 0,
    'responsibility_code', v_responsibility,
    'responsible_party_role', v_party_role,
    'public_note', v_public_note,
    'internal_note_present', v_internal_note is not null
  )::text);

  select r.*
  into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.dispute_id = p_dispute_id
    and a.actor_profile_id = v_finance.profile_id
    and a.action_type = 'approve_obligation'
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.dispute_id = p_dispute_id
        and a.actor_profile_id = v_finance.profile_id
        and a.action_type = 'approve_obligation'
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    refund_id := v_existing.id;
    status := v_existing.status;
    approved_amount := v_existing.approved_amount;
    currency_code := v_existing.currency_code;
    responsible_party_role := v_existing.responsible_party_role;
    created := false;
    approved_at := v_existing.approved_at;
    return next;
    return;
  end if;

  if exists (
    select 1
    from public.order_refunds r
    where r.dispute_id = p_dispute_id
      and r.order_item_id is not distinct from v_scope_item_id
      and r.return_id is not distinct from p_return_id
      and r.refund_type = v_type
      and r.responsibility_code = v_responsibility
      and r.deleted_at is null
      and public.refund_workflow_active_status(r.status)
  ) then
    raise exception 'ACTIVE_REFUND_EXISTS' using errcode = '23505';
  end if;

  insert into public.order_refunds(
    dispute_id,
    return_id,
    order_id,
    order_item_id,
    customer_profile_id,
    affected_supplier_id,
    refund_type,
    status,
    responsibility_code,
    responsible_party_role,
    approved_amount,
    currency_code,
    item_amount_component,
    delivery_fee_component,
    goodwill_component,
    approved_by_profile_id,
    approved_at,
    customer_confirmation_status,
    internal_notes
  )
  values (
    p_dispute_id,
    p_return_id,
    v_order.id,
    v_scope_item_id,
    v_customer_profile_id,
    v_scope_supplier_id,
    v_type,
    'awaiting_responsible_party',
    v_responsibility,
    v_party_role,
    v_approved_amount,
    v_order.currency_code,
    coalesce(p_item_amount_component, 0),
    coalesce(p_delivery_fee_component, 0),
    0,
    v_finance.profile_id,
    now(),
    'not_requested',
    v_internal_note
  )
  returning * into v_refund;

  v_old_status := v_dispute.status;
  if v_dispute.status in ('open', 'awaiting_customer', 'awaiting_supplier', 'under_review', 'return_review') then
    update public.order_disputes
    set status = 'refund_review',
        finance_review_required = true,
        customer_action_required = false,
        supplier_action_required = false,
        updated_at = now()
    where id = v_dispute.id;

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
      v_dispute.id,
      v_old_status,
      'refund_review',
      v_finance.profile_id,
      public.refund_workflow_actor_role(v_finance.admin_role),
      'refund_review',
      now()
    )
    on conflict do nothing;
  else
    update public.order_disputes
    set finance_review_required = true,
        updated_at = now()
    where id = v_dispute.id;
  end if;

  perform public.refund_workflow_audit(
    v_finance.profile_id,
    v_finance.admin_role,
    'refund_obligation_approved',
    v_refund.id,
    jsonb_build_object(
      'dispute_id', v_refund.dispute_id,
      'order_id', v_refund.order_id,
      'order_item_present', v_refund.order_item_id is not null,
      'return_present', v_refund.return_id is not null,
      'refund_type', v_refund.refund_type,
      'responsibility_code', v_refund.responsibility_code,
      'responsible_party_role', v_refund.responsible_party_role,
      'approved_amount', v_refund.approved_amount,
      'currency_code', v_refund.currency_code,
      'status', v_refund.status
    ),
    v_public_note
  );

  insert into public.refund_actions(
    refund_id,
    dispute_id,
    actor_profile_id,
    actor_role,
    action_type,
    idempotency_key,
    request_fingerprint,
    result_refund_id,
    result_status
  )
  values (
    null,
    p_dispute_id,
    v_finance.profile_id,
    public.refund_workflow_actor_role(v_finance.admin_role),
    'approve_obligation',
    v_key,
    v_fingerprint,
    v_refund.id,
    v_refund.status
  );

  refund_id := v_refund.id;
  status := v_refund.status;
  approved_amount := v_refund.approved_amount;
  currency_code := v_refund.currency_code;
  responsible_party_role := v_refund.responsible_party_role;
  created := true;
  approved_at := v_refund.approved_at;
  return next;
end;
$fn$;

create or replace function public.supplier_report_refund_sent(
  p_refund_id uuid,
  p_refund_method text,
  p_external_reference_masked text,
  p_note text,
  p_idempotency_key text
)
returns table (refund_id uuid, status text, reported_sent_at timestamptz)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_supplier_id uuid := public.current_dispute_supplier_id();
  v_profile_id uuid := public.current_profile_id();
  v_method text := lower(trim(coalesce(p_refund_method, '')));
  v_reference text := public.refund_workflow_safe_reference(p_external_reference_masked);
  v_note text := public.refund_workflow_safe_text(p_note, false, 1200);
  v_refund public.order_refunds%rowtype;
  v_existing public.order_refunds%rowtype;
  v_fingerprint text;
begin
  if v_supplier_id is null or v_profile_id is null then
    raise exception 'SUPPLIER_REQUIRED' using errcode = '42501';
  end if;
  if not public.refund_workflow_is_method(v_method) then
    raise exception 'INVALID_REFUND_METHOD' using errcode = '23514';
  end if;

  select * into v_refund
  from public.order_refunds r
  where r.id = p_refund_id and r.deleted_at is null
  for update;

  if not found
    or v_refund.responsibility_code <> 'supplier_responsible'
    or v_refund.responsible_party_role <> 'supplier'
    or v_refund.affected_supplier_id <> v_supplier_id then
    raise exception 'REFUND_NOT_FOUND' using errcode = '42501';
  end if;

  v_fingerprint := md5(jsonb_build_object('refund_id', p_refund_id, 'method', v_method, 'reference_present', v_reference is not null, 'note_present', v_note is not null)::text);

  select r.* into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.refund_id = p_refund_id
    and a.actor_profile_id = v_profile_id
    and a.action_type = 'supplier_report_sent'
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.refund_id = p_refund_id
        and a.actor_profile_id = v_profile_id
        and a.action_type = 'supplier_report_sent'
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    refund_id := v_existing.id;
    status := v_existing.status;
    reported_sent_at := v_existing.reported_sent_at;
    return next;
    return;
  end if;

  if v_refund.status not in ('awaiting_responsible_party', 'approved') then
    raise exception 'REFUND_REPORT_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_refunds
  set status = 'reported_sent',
      reported_sent_by_profile_id = v_profile_id,
      reported_sent_at = now(),
      refund_method = v_method,
      external_reference_masked = v_reference,
      sender_note = v_note,
      customer_confirmation_status = 'pending',
      updated_at = now()
  where id = v_refund.id
  returning * into v_refund;

  perform public.refund_workflow_audit(
    v_profile_id,
    'supplier_owner',
    'refund_reported_sent',
    v_refund.id,
    jsonb_build_object('status', v_refund.status, 'refund_method', v_method, 'reference_present', v_reference is not null),
    null
  );

  insert into public.refund_actions(refund_id, dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_refund_id, result_status)
  values (v_refund.id, null, v_profile_id, 'supplier', 'supplier_report_sent', v_key, v_fingerprint, v_refund.id, v_refund.status);

  refund_id := v_refund.id;
  status := v_refund.status;
  reported_sent_at := v_refund.reported_sent_at;
  return next;
end;
$fn$;

create or replace function public.admin_report_platform_refund_sent(
  p_refund_id uuid,
  p_refund_method text,
  p_external_reference_masked text,
  p_note text,
  p_idempotency_key text
)
returns table (refund_id uuid, status text, reported_sent_at timestamptz)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_finance record;
  v_method text := lower(trim(coalesce(p_refund_method, '')));
  v_reference text := public.refund_workflow_safe_reference(p_external_reference_masked);
  v_note text := public.refund_workflow_safe_text(p_note, false, 1200);
  v_refund public.order_refunds%rowtype;
  v_existing public.order_refunds%rowtype;
  v_fingerprint text;
begin
  select * into v_finance from public.refund_workflow_current_finance_admin();
  if v_finance.profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;
  if not public.refund_workflow_is_method(v_method) then
    raise exception 'INVALID_REFUND_METHOD' using errcode = '23514';
  end if;

  select * into v_refund
  from public.order_refunds r
  where r.id = p_refund_id and r.deleted_at is null
  for update;

  if not found
    or v_refund.responsibility_code <> 'platform_responsible'
    or v_refund.responsible_party_role <> 'platform' then
    raise exception 'REFUND_NOT_FOUND' using errcode = '42501';
  end if;

  v_fingerprint := md5(jsonb_build_object('refund_id', p_refund_id, 'method', v_method, 'reference_present', v_reference is not null, 'note_present', v_note is not null)::text);

  select r.* into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.refund_id = p_refund_id
    and a.actor_profile_id = v_finance.profile_id
    and a.action_type = 'platform_report_sent'
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.refund_id = p_refund_id
        and a.actor_profile_id = v_finance.profile_id
        and a.action_type = 'platform_report_sent'
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    refund_id := v_existing.id;
    status := v_existing.status;
    reported_sent_at := v_existing.reported_sent_at;
    return next;
    return;
  end if;

  if v_refund.status not in ('awaiting_responsible_party', 'approved') then
    raise exception 'REFUND_REPORT_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_refunds
  set status = 'reported_sent',
      reported_sent_by_profile_id = v_finance.profile_id,
      reported_sent_at = now(),
      refund_method = v_method,
      external_reference_masked = v_reference,
      sender_note = v_note,
      customer_confirmation_status = 'pending',
      updated_at = now()
  where id = v_refund.id
  returning * into v_refund;

  perform public.refund_workflow_audit(
    v_finance.profile_id,
    v_finance.admin_role,
    'refund_reported_sent',
    v_refund.id,
    jsonb_build_object('status', v_refund.status, 'refund_method', v_method, 'reference_present', v_reference is not null),
    null
  );

  insert into public.refund_actions(refund_id, dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_refund_id, result_status)
  values (v_refund.id, null, v_finance.profile_id, public.refund_workflow_actor_role(v_finance.admin_role), 'platform_report_sent', v_key, v_fingerprint, v_refund.id, v_refund.status);

  refund_id := v_refund.id;
  status := v_refund.status;
  reported_sent_at := v_refund.reported_sent_at;
  return next;
end;
$fn$;

create or replace function public.customer_confirm_refund_received(
  p_refund_id uuid,
  p_received boolean,
  p_note text,
  p_idempotency_key text
)
returns table (refund_id uuid, status text, customer_confirmation_status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_note text := public.refund_workflow_safe_text(p_note, false, 1200);
  v_action text;
  v_refund public.order_refunds%rowtype;
  v_existing public.order_refunds%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  select * into v_refund
  from public.order_refunds r
  where r.id = p_refund_id
    and r.customer_profile_id = v_profile_id
    and r.deleted_at is null
  for update;

  if not found then
    raise exception 'REFUND_NOT_FOUND' using errcode = '42501';
  end if;

  if v_refund.status not in ('reported_sent', 'awaiting_customer_confirmation') then
    raise exception 'CUSTOMER_CONFIRMATION_NOT_ALLOWED' using errcode = '23514';
  end if;

  v_action := case when p_received then 'customer_confirm_received' else 'customer_dispute_not_received' end;
  v_fingerprint := md5(jsonb_build_object('refund_id', p_refund_id, 'received', p_received, 'note_present', v_note is not null)::text);

  select r.* into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.refund_id = p_refund_id
    and a.actor_profile_id = v_profile_id
    and a.action_type = v_action
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.refund_id = p_refund_id
        and a.actor_profile_id = v_profile_id
        and a.action_type = v_action
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    refund_id := v_existing.id;
    status := v_existing.status;
    customer_confirmation_status := v_existing.customer_confirmation_status;
    return next;
    return;
  end if;

  update public.order_refunds
  set status = 'under_verification',
      customer_confirmation_status = case when p_received then 'confirmed_received' else 'disputed_not_received' end,
      customer_confirmed_at = case when p_received then now() else null end,
      updated_at = now()
  where id = v_refund.id
  returning * into v_refund;

  perform public.refund_workflow_audit(
    v_profile_id,
    'customer',
    case when p_received then 'refund_customer_confirmed_received' else 'refund_customer_disputed_not_received' end,
    v_refund.id,
    jsonb_build_object('status', v_refund.status, 'customer_confirmation_status', v_refund.customer_confirmation_status),
    null
  );

  insert into public.refund_actions(refund_id, dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_refund_id, result_status)
  values (v_refund.id, null, v_profile_id, 'customer', v_action, v_key, v_fingerprint, v_refund.id, v_refund.status);

  refund_id := v_refund.id;
  status := v_refund.status;
  customer_confirmation_status := v_refund.customer_confirmation_status;
  return next;
end;
$fn$;

create or replace function public.admin_verify_refund_report(
  p_refund_id uuid,
  p_internal_note text,
  p_idempotency_key text
)
returns table (refund_id uuid, status text, verified_at timestamptz)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_finance record;
  v_note text := public.refund_workflow_safe_text(p_internal_note, false, 2000);
  v_refund public.order_refunds%rowtype;
  v_existing public.order_refunds%rowtype;
  v_fingerprint text;
begin
  select * into v_finance from public.refund_workflow_current_finance_admin();
  if v_finance.profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  select * into v_refund
  from public.order_refunds r
  where r.id = p_refund_id and r.deleted_at is null
  for update;

  if not found then
    raise exception 'REFUND_NOT_FOUND' using errcode = '42501';
  end if;

  v_fingerprint := md5(jsonb_build_object('refund_id', p_refund_id, 'note_present', v_note is not null)::text);

  select r.* into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.refund_id = p_refund_id
    and a.actor_profile_id = v_finance.profile_id
    and a.action_type = 'finance_verify'
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.refund_id = p_refund_id
        and a.actor_profile_id = v_finance.profile_id
        and a.action_type = 'finance_verify'
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    refund_id := v_existing.id;
    status := v_existing.status;
    verified_at := v_existing.verified_at;
    return next;
    return;
  end if;

  if v_refund.status not in ('reported_sent', 'under_verification') then
    raise exception 'REFUND_VERIFY_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_refunds
  set status = 'verified',
      verified_by_profile_id = v_finance.profile_id,
      verified_at = now(),
      internal_notes = coalesce(v_note, internal_notes),
      updated_at = now()
  where id = v_refund.id
  returning * into v_refund;

  perform public.refund_workflow_audit(
    v_finance.profile_id,
    v_finance.admin_role,
    'refund_verified',
    v_refund.id,
    jsonb_build_object('status', v_refund.status, 'approved_amount', v_refund.approved_amount, 'currency_code', v_refund.currency_code),
    null
  );

  insert into public.refund_actions(refund_id, dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_refund_id, result_status)
  values (v_refund.id, null, v_finance.profile_id, public.refund_workflow_actor_role(v_finance.admin_role), 'finance_verify', v_key, v_fingerprint, v_refund.id, v_refund.status);

  refund_id := v_refund.id;
  status := v_refund.status;
  verified_at := v_refund.verified_at;
  return next;
end;
$fn$;

create or replace function public.admin_reject_refund_report(
  p_refund_id uuid,
  p_public_reason text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (refund_id uuid, status text, rejected_at timestamptz)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_finance record;
  v_public_reason text := public.refund_workflow_safe_text(p_public_reason, true, 1200);
  v_internal_note text := public.refund_workflow_safe_text(p_internal_note, false, 2000);
  v_refund public.order_refunds%rowtype;
  v_existing public.order_refunds%rowtype;
  v_fingerprint text;
begin
  select * into v_finance from public.refund_workflow_current_finance_admin();
  if v_finance.profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  select * into v_refund
  from public.order_refunds r
  where r.id = p_refund_id and r.deleted_at is null
  for update;

  if not found then
    raise exception 'REFUND_NOT_FOUND' using errcode = '42501';
  end if;

  v_fingerprint := md5(jsonb_build_object('refund_id', p_refund_id, 'public_reason', v_public_reason, 'internal_note_present', v_internal_note is not null)::text);

  select r.* into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.refund_id = p_refund_id
    and a.actor_profile_id = v_finance.profile_id
    and a.action_type = 'finance_reject_report'
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.refund_id = p_refund_id
        and a.actor_profile_id = v_finance.profile_id
        and a.action_type = 'finance_reject_report'
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    refund_id := v_existing.id;
    status := v_existing.status;
    rejected_at := v_existing.rejected_at;
    return next;
    return;
  end if;

  if v_refund.status not in ('reported_sent', 'under_verification') then
    raise exception 'REFUND_REPORT_REJECT_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_refunds
  set status = 'rejected',
      rejected_by_profile_id = v_finance.profile_id,
      rejected_at = now(),
      rejection_reason_public = v_public_reason,
      internal_notes = coalesce(v_internal_note, internal_notes),
      updated_at = now()
  where id = v_refund.id
  returning * into v_refund;

  perform public.refund_workflow_audit(
    v_finance.profile_id,
    v_finance.admin_role,
    'refund_report_rejected',
    v_refund.id,
    jsonb_build_object('status', v_refund.status),
    v_public_reason
  );

  insert into public.refund_actions(refund_id, dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_refund_id, result_status)
  values (v_refund.id, null, v_finance.profile_id, public.refund_workflow_actor_role(v_finance.admin_role), 'finance_reject_report', v_key, v_fingerprint, v_refund.id, v_refund.status);

  refund_id := v_refund.id;
  status := v_refund.status;
  rejected_at := v_refund.rejected_at;
  return next;
end;
$fn$;

create or replace function public.admin_complete_refund(
  p_refund_id uuid,
  p_internal_note text,
  p_idempotency_key text
)
returns table (refund_id uuid, status text, completed_at timestamptz)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_finance record;
  v_note text := public.refund_workflow_safe_text(p_internal_note, false, 2000);
  v_refund public.order_refunds%rowtype;
  v_existing public.order_refunds%rowtype;
  v_fingerprint text;
begin
  select * into v_finance from public.refund_workflow_current_finance_admin();
  if v_finance.profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  select * into v_refund
  from public.order_refunds r
  where r.id = p_refund_id and r.deleted_at is null
  for update;

  if not found then
    raise exception 'REFUND_NOT_FOUND' using errcode = '42501';
  end if;

  v_fingerprint := md5(jsonb_build_object('refund_id', p_refund_id, 'note_present', v_note is not null)::text);

  select r.* into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.refund_id = p_refund_id
    and a.actor_profile_id = v_finance.profile_id
    and a.action_type = 'finance_complete'
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.refund_id = p_refund_id
        and a.actor_profile_id = v_finance.profile_id
        and a.action_type = 'finance_complete'
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    refund_id := v_existing.id;
    status := v_existing.status;
    completed_at := v_existing.completed_at;
    return next;
    return;
  end if;

  if v_refund.status <> 'verified' then
    raise exception 'REFUND_COMPLETE_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_refunds
  set status = 'completed',
      completed_at = now(),
      internal_notes = coalesce(v_note, internal_notes),
      updated_at = now()
  where id = v_refund.id
  returning * into v_refund;

  perform public.refund_workflow_audit(
    v_finance.profile_id,
    v_finance.admin_role,
    'refund_completed',
    v_refund.id,
    jsonb_build_object('status', v_refund.status, 'approved_amount', v_refund.approved_amount, 'currency_code', v_refund.currency_code),
    null
  );

  insert into public.refund_actions(refund_id, dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_refund_id, result_status)
  values (v_refund.id, null, v_finance.profile_id, public.refund_workflow_actor_role(v_finance.admin_role), 'finance_complete', v_key, v_fingerprint, v_refund.id, v_refund.status);

  refund_id := v_refund.id;
  status := v_refund.status;
  completed_at := v_refund.completed_at;
  return next;
end;
$fn$;

create or replace function public.list_customer_refunds_safe(p_limit integer default 50)
returns table (
  refund_id uuid,
  dispute_id uuid,
  order_number text,
  refund_type text,
  status text,
  approved_amount numeric,
  currency_code text,
  responsible_party_role text,
  customer_confirmation_status text,
  approved_at timestamptz,
  reported_sent_at timestamptz,
  verified_at timestamptz,
  completed_at timestamptz
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
    r.refund_type,
    r.status,
    r.approved_amount,
    r.currency_code,
    r.responsible_party_role,
    r.customer_confirmation_status,
    r.approved_at,
    r.reported_sent_at,
    r.verified_at,
    r.completed_at
  from public.order_refunds r
  join public.orders o on o.id = r.order_id
  where r.customer_profile_id = public.current_profile_id()
    and r.deleted_at is null
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$fn$;

create or replace function public.get_customer_refund_safe(p_refund_id uuid)
returns table (
  refund_id uuid,
  dispute_id uuid,
  order_number text,
  refund_type text,
  status text,
  approved_amount numeric,
  currency_code text,
  responsible_party_role text,
  customer_confirmation_status text,
  refund_method text,
  external_reference_present boolean,
  rejection_reason_public text,
  approved_at timestamptz,
  reported_sent_at timestamptz,
  verified_at timestamptz,
  completed_at timestamptz
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
    r.refund_type,
    r.status,
    r.approved_amount,
    r.currency_code,
    r.responsible_party_role,
    r.customer_confirmation_status,
    r.refund_method,
    r.external_reference_masked is not null,
    r.rejection_reason_public,
    r.approved_at,
    r.reported_sent_at,
    r.verified_at,
    r.completed_at
  from public.order_refunds r
  join public.orders o on o.id = r.order_id
  where r.id = p_refund_id
    and r.customer_profile_id = public.current_profile_id()
    and r.deleted_at is null;
$fn$;

create or replace function public.list_supplier_refunds_safe(p_limit integer default 50)
returns table (
  refund_id uuid,
  dispute_id uuid,
  order_number text,
  refund_type text,
  status text,
  approved_amount numeric,
  currency_code text,
  refund_method text,
  customer_confirmation_status text,
  approved_at timestamptz,
  reported_sent_at timestamptz,
  verified_at timestamptz
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
    r.refund_type,
    r.status,
    r.approved_amount,
    r.currency_code,
    r.refund_method,
    r.customer_confirmation_status,
    r.approved_at,
    r.reported_sent_at,
    r.verified_at
  from public.order_refunds r
  join public.orders o on o.id = r.order_id
  where r.affected_supplier_id = public.current_dispute_supplier_id()
    and r.responsible_party_role = 'supplier'
    and r.deleted_at is null
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$fn$;

create or replace function public.get_supplier_refund_safe(p_refund_id uuid)
returns table (
  refund_id uuid,
  dispute_id uuid,
  order_number text,
  refund_type text,
  status text,
  approved_amount numeric,
  currency_code text,
  refund_method text,
  external_reference_present boolean,
  customer_confirmation_status text,
  approved_at timestamptz,
  reported_sent_at timestamptz,
  verified_at timestamptz
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
    r.refund_type,
    r.status,
    r.approved_amount,
    r.currency_code,
    r.refund_method,
    r.external_reference_masked is not null,
    r.customer_confirmation_status,
    r.approved_at,
    r.reported_sent_at,
    r.verified_at
  from public.order_refunds r
  join public.orders o on o.id = r.order_id
  where r.id = p_refund_id
    and r.affected_supplier_id = public.current_dispute_supplier_id()
    and r.responsible_party_role = 'supplier'
    and r.deleted_at is null;
$fn$;

create or replace function public.get_reseller_refund_impact_safe(p_refund_id uuid)
returns table (
  refund_id uuid,
  order_number text,
  status text,
  impact_label text
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    r.id,
    o.order_number,
    r.status,
    case
      when r.responsible_party_role = 'reseller' then 'Refund may require future reseller accounting review'
      else 'Refund recorded without reseller wallet mutation'
    end
  from public.order_refunds r
  join public.orders o on o.id = r.order_id
  where r.id = p_refund_id
    and o.reseller_id = public.current_dispute_reseller_id()
    and r.deleted_at is null;
$fn$;

create or replace function public.list_support_refunds_safe(p_limit integer default 50)
returns table (
  refund_id uuid,
  dispute_id uuid,
  order_number text,
  refund_type text,
  status text,
  approved_amount numeric,
  currency_code text,
  responsibility_code text,
  responsible_party_role text,
  customer_confirmation_status text,
  approved_at timestamptz,
  reported_sent_at timestamptz,
  verified_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin record;
begin
  select * into v_admin from public.current_dispute_support_admin();
  if v_admin.profile_id is null then
    raise exception 'SUPPORT_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    r.id,
    r.dispute_id,
    o.order_number,
    r.refund_type,
    r.status,
    r.approved_amount,
    r.currency_code,
    r.responsibility_code,
    r.responsible_party_role,
    r.customer_confirmation_status,
    r.approved_at,
    r.reported_sent_at,
    r.verified_at
  from public.order_refunds r
  join public.orders o on o.id = r.order_id
  where r.deleted_at is null
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$fn$;

create or replace function public.list_finance_refunds_safe(p_limit integer default 50)
returns table (
  refund_id uuid,
  dispute_id uuid,
  order_number text,
  refund_type text,
  status text,
  approved_amount numeric,
  currency_code text,
  item_amount_component numeric,
  delivery_fee_component numeric,
  goodwill_component numeric,
  responsibility_code text,
  responsible_party_role text,
  refund_method text,
  external_reference_masked text,
  customer_confirmation_status text,
  approved_at timestamptz,
  reported_sent_at timestamptz,
  verified_at timestamptz,
  completed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_finance record;
begin
  select * into v_finance from public.refund_workflow_current_finance_admin();
  if v_finance.profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    r.id,
    r.dispute_id,
    o.order_number,
    r.refund_type,
    r.status,
    r.approved_amount,
    r.currency_code,
    r.item_amount_component,
    r.delivery_fee_component,
    r.goodwill_component,
    r.responsibility_code,
    r.responsible_party_role,
    r.refund_method,
    r.external_reference_masked,
    r.customer_confirmation_status,
    r.approved_at,
    r.reported_sent_at,
    r.verified_at,
    r.completed_at
  from public.order_refunds r
  join public.orders o on o.id = r.order_id
  where r.deleted_at is null
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$fn$;

comment on table public.order_refunds is
  'D8 manual refund obligation table. It records approved obligations and manual verification only; it does not execute provider refunds or mutate settlements, commissions, wallets, withdrawals, orders, payments, stock, returns, or notifications.';

comment on table public.refund_actions is
  'D8 refund idempotency/action table. Browser roles have no direct table access.';

revoke all on function public.refund_workflow_assert_key(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_safe_text(text, boolean, integer) from public, anon, authenticated;
revoke all on function public.refund_workflow_safe_reference(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_current_finance_admin() from public, anon, authenticated;
revoke all on function public.refund_workflow_actor_role(public.user_role) from public, anon, authenticated;
revoke all on function public.refund_workflow_is_type(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_is_responsibility(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_is_party_role(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_is_method(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_responsibility_matches_role(text, text) from public, anon, authenticated;
revoke all on function public.refund_workflow_prevent_target_update() from public, anon, authenticated;
revoke all on function public.refund_workflow_audit(uuid, public.user_role, text, uuid, jsonb, text) from public, anon, authenticated;
revoke all on function public.refund_workflow_dispute_reason_allows_refund(text, text) from public, anon, authenticated;
revoke all on function public.refund_workflow_active_status(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_terminal_status(text) from public, anon, authenticated;

grant execute on function public.admin_approve_refund_obligation(uuid, uuid, text, integer, numeric, numeric, numeric, text, text, text, text, text) to authenticated;
grant execute on function public.supplier_report_refund_sent(uuid, text, text, text, text) to authenticated;
grant execute on function public.admin_report_platform_refund_sent(uuid, text, text, text, text) to authenticated;
grant execute on function public.customer_confirm_refund_received(uuid, boolean, text, text) to authenticated;
grant execute on function public.admin_verify_refund_report(uuid, text, text) to authenticated;
grant execute on function public.admin_reject_refund_report(uuid, text, text, text) to authenticated;
grant execute on function public.admin_complete_refund(uuid, text, text) to authenticated;
grant execute on function public.list_customer_refunds_safe(integer) to authenticated;
grant execute on function public.get_customer_refund_safe(uuid) to authenticated;
grant execute on function public.list_supplier_refunds_safe(integer) to authenticated;
grant execute on function public.get_supplier_refund_safe(uuid) to authenticated;
grant execute on function public.get_reseller_refund_impact_safe(uuid) to authenticated;
grant execute on function public.list_support_refunds_safe(integer) to authenticated;
grant execute on function public.list_finance_refunds_safe(integer) to authenticated;
