-- Disputes, Returns, and Refunds D9: finance holds, settlement controls,
-- commission hold projections, and append-only accounting adjustments.
-- Backend-only, forward-only. No UI, provider payouts/refunds, stock,
-- reservation, notification, order-status, payment-status, settlement history
-- rewrite, commission history rewrite, wallet negative-balance, or paid
-- withdrawal reversal is introduced here.

create table if not exists public.finance_holds (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  refund_id uuid references public.order_refunds(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid references public.order_items(id) on delete restrict,
  supplier_id uuid references public.suppliers(id) on delete restrict,
  reseller_profile_id uuid references public.profiles(id) on delete restrict,
  commission_id uuid references public.commissions(id) on delete restrict,
  settlement_id uuid references public.settlements(id) on delete restrict,
  hold_type text not null,
  status text not null default 'active',
  amount numeric(12,2) not null,
  currency_code text not null,
  reason_code text not null,
  source_finance_state text not null,
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  released_by_profile_id uuid references public.profiles(id) on delete set null,
  released_at timestamptz,
  applied_by_profile_id uuid references public.profiles(id) on delete set null,
  applied_at timestamptz,
  cancelled_by_profile_id uuid references public.profiles(id) on delete set null,
  cancelled_at timestamptz,
  public_note text,
  internal_note text,
  idempotency_key text not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint finance_holds_type_allowed check (
    hold_type in (
      'settlement_verification_block',
      'commission_availability_hold',
      'refund_accounting_hold',
      'supplier_liability_hold',
      'platform_liability_hold',
      'reseller_liability_review',
      'withdrawal_review_hold'
    )
  ),
  constraint finance_holds_status_allowed check (status in ('active', 'released', 'applied', 'cancelled', 'expired')),
  constraint finance_holds_source_state_allowed check (
    source_finance_state in (
      'pre_payment_report',
      'payment_reported',
      'settlement_pending',
      'settlement_verified',
      'commission_locked',
      'commission_available',
      'withdrawal_pending',
      'withdrawal_paid'
    )
  ),
  constraint finance_holds_reason_allowed check (
    reason_code in (
      'active_dispute',
      'approved_refund',
      'refund_verified',
      'supplier_responsible',
      'platform_responsible',
      'reseller_responsibility_review',
      'accounting_inconsistency',
      'manual_finance_review'
    )
  ),
  constraint finance_holds_amount_nonnegative check (amount >= 0),
  constraint finance_holds_monetary_amount_positive check (
    (
      hold_type in ('reseller_liability_review', 'withdrawal_review_hold')
      and amount >= 0
    )
    or amount > 0
  ),
  constraint finance_holds_currency_safe check (currency_code = upper(trim(currency_code)) and length(trim(currency_code)) between 3 and 12),
  constraint finance_holds_key_safe check (
    length(trim(idempotency_key)) between 8 and 140
    and idempotency_key !~* '(password|secret|token|jwt|cookie)'
  ),
  constraint finance_holds_notes_safe check (
    (public_note is null or (length(trim(public_note)) between 1 and 1200 and public_note !~ '<[^>]+>' and public_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
    and (internal_note is null or (length(trim(internal_note)) between 1 and 2000 and internal_note !~ '<[^>]+>' and internal_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
  ),
  constraint finance_holds_terminal_actor_timestamp check (
    (status <> 'released' or (released_by_profile_id is not null and released_at is not null))
    and (status <> 'applied' or (applied_by_profile_id is not null and applied_at is not null))
    and (status <> 'cancelled' or (cancelled_by_profile_id is not null and cancelled_at is not null))
  )
);

create table if not exists public.finance_adjustments (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  refund_id uuid references public.order_refunds(id) on delete restrict,
  finance_hold_id uuid references public.finance_holds(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid references public.order_items(id) on delete restrict,
  settlement_id uuid references public.settlements(id) on delete restrict,
  commission_id uuid references public.commissions(id) on delete restrict,
  reseller_profile_id uuid references public.profiles(id) on delete restrict,
  supplier_id uuid references public.suppliers(id) on delete restrict,
  adjustment_type text not null,
  direction text not null,
  amount numeric(12,2) not null,
  currency_code text not null,
  status text not null default 'approved',
  reason_code text not null,
  approved_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  approved_at timestamptz not null default now(),
  applied_by_profile_id uuid references public.profiles(id) on delete set null,
  applied_at timestamptz,
  reversed_by_adjustment_id uuid references public.finance_adjustments(id) on delete set null,
  public_note text,
  internal_note text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  constraint finance_adjustments_type_allowed check (
    adjustment_type in (
      'settlement_reduction',
      'platform_revenue_reversal',
      'commission_hold',
      'commission_reduction',
      'supplier_liability',
      'platform_liability',
      'reseller_liability_review',
      'manual_accounting_correction'
    )
  ),
  constraint finance_adjustments_direction_allowed check (direction in ('debit', 'credit', 'hold', 'release')),
  constraint finance_adjustments_status_allowed check (status in ('proposed', 'approved', 'applied', 'cancelled', 'reversed')),
  constraint finance_adjustments_reason_allowed check (
    reason_code in (
      'active_dispute',
      'approved_refund',
      'refund_verified',
      'supplier_responsible',
      'platform_responsible',
      'reseller_responsibility_review',
      'accounting_inconsistency',
      'manual_finance_review'
    )
  ),
  constraint finance_adjustments_amount_nonnegative check (amount >= 0),
  constraint finance_adjustments_currency_safe check (currency_code = upper(trim(currency_code)) and length(trim(currency_code)) between 3 and 12),
  constraint finance_adjustments_key_safe check (
    length(trim(idempotency_key)) between 8 and 140
    and idempotency_key !~* '(password|secret|token|jwt|cookie)'
  ),
  constraint finance_adjustments_notes_safe check (
    (public_note is null or (length(trim(public_note)) between 1 and 1200 and public_note !~ '<[^>]+>' and public_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
    and (internal_note is null or (length(trim(internal_note)) between 1 and 2000 and internal_note !~ '<[^>]+>' and internal_note !~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)'))
  )
);

create table if not exists public.finance_actions (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  actor_role text not null,
  action_type text not null,
  target_entity_type text not null,
  target_entity_id uuid not null,
  idempotency_key text not null,
  request_fingerprint text not null,
  result_hold_id uuid references public.finance_holds(id) on delete restrict,
  result_adjustment_id uuid references public.finance_adjustments(id) on delete restrict,
  result_status text,
  created_at timestamptz not null default now(),
  constraint finance_actions_role_allowed check (actor_role in ('finance_staff', 'super_admin')),
  constraint finance_actions_key_safe check (
    length(trim(idempotency_key)) between 8 and 140
    and idempotency_key !~* '(password|secret|token|jwt|cookie)'
  )
);

alter table public.finance_holds enable row level security;
alter table public.finance_holds force row level security;
alter table public.finance_adjustments enable row level security;
alter table public.finance_adjustments force row level security;
alter table public.finance_actions enable row level security;
alter table public.finance_actions force row level security;

revoke all on public.finance_holds from public, anon, authenticated;
revoke all on public.finance_adjustments from public, anon, authenticated;
revoke all on public.finance_actions from public, anon, authenticated;

create unique index if not exists finance_holds_active_scope_unique
  on public.finance_holds(
    dispute_id,
    hold_type,
    coalesce(refund_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(order_item_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(commission_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(settlement_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status = 'active' and deleted_at is null;

create unique index if not exists finance_holds_idempotency_unique
  on public.finance_holds(created_by_profile_id, hold_type, idempotency_key)
  where deleted_at is null;

create unique index if not exists finance_adjustments_idempotency_unique
  on public.finance_adjustments(approved_by_profile_id, adjustment_type, idempotency_key);

create unique index if not exists finance_adjustments_active_liability_unique
  on public.finance_adjustments(
    coalesce(refund_id, '00000000-0000-0000-0000-000000000000'::uuid),
    adjustment_type,
    coalesce(supplier_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(reseller_profile_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status in ('proposed', 'approved', 'applied');

create unique index if not exists finance_actions_idempotency_unique
  on public.finance_actions(actor_profile_id, action_type, target_entity_type, target_entity_id, idempotency_key);

create index if not exists finance_holds_order_status_idx
  on public.finance_holds(order_id, status, created_at desc)
  where deleted_at is null;

create index if not exists finance_holds_reseller_status_idx
  on public.finance_holds(reseller_profile_id, status, created_at desc)
  where reseller_profile_id is not null and deleted_at is null;

create index if not exists finance_holds_supplier_status_idx
  on public.finance_holds(supplier_id, status, created_at desc)
  where supplier_id is not null and deleted_at is null;

create index if not exists finance_adjustments_order_status_idx
  on public.finance_adjustments(order_id, status, created_at desc);

create or replace function public.finance_d9_actor_role(p_profile_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select a.admin_role::text
  from public.admin_staff a
  join public.profiles p on p.id = a.profile_id
  where a.profile_id = p_profile_id
    and p.account_status = 'active'
    and p.deleted_at is null
    and a.staff_status = 'active'
    and a.deleted_at is null
    and a.admin_role in ('finance_staff', 'super_admin')
  order by case a.admin_role when 'super_admin' then 1 else 2 end, a.created_at asc, a.id::text asc
  limit 1;
$$;

create or replace function public.finance_d9_assert_actor()
returns table(profile_id uuid, actor_role text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
  v_role text;
begin
  v_profile_id := public.current_finance_admin_profile_id();
  if v_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  v_role := public.finance_d9_actor_role(v_profile_id);
  if v_role is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query select v_profile_id, v_role;
end;
$fn$;

create or replace function public.finance_d9_validate_note(p_value text, p_required boolean default false, p_max integer default 1200)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_value text := nullif(trim(coalesce(p_value, '')), '');
begin
  if p_required and v_value is null then
    raise exception 'VALIDATION_ERROR' using errcode = '23514';
  end if;
  if v_value is not null and (length(v_value) > p_max or v_value ~ '<[^>]+>' or v_value ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|bank account|mobile money)') then
    raise exception 'FIELD_TOO_LONG' using errcode = '23514';
  end if;
  return v_value;
end;
$fn$;

create or replace function public.finance_d9_validate_key(p_value text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_key text := nullif(trim(coalesce(p_value, '')), '');
begin
  if v_key is null or length(v_key) < 8 or length(v_key) > 140 or v_key ~* '(password|secret|token|jwt|cookie)' then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = '22023';
  end if;
  return v_key;
end;
$fn$;

create or replace function public.finance_d9_source_state(
  p_order public.orders,
  p_settlement public.settlements,
  p_commission public.commissions
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if p_commission.id is not null and p_commission.withdrawal_id is not null then
    if exists (select 1 from public.withdrawals w where w.id = p_commission.withdrawal_id and w.withdrawal_status = 'paid') then
      return 'withdrawal_paid';
    end if;
    return 'withdrawal_pending';
  end if;

  if p_commission.id is not null and p_commission.commission_status = 'available' then
    return 'commission_available';
  end if;

  if p_commission.id is not null and p_commission.commission_status in ('awaiting_supplier_settlement', 'held', 'disputed') then
    return 'commission_locked';
  end if;

  if p_settlement.id is not null and p_settlement.settlement_status = 'paid' then
    return 'settlement_verified';
  end if;

  if p_settlement.id is not null and p_settlement.settlement_status in ('due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue') then
    return 'settlement_pending';
  end if;

  if p_order.payment_collection_status::text in ('supplier_reported', 'settlement_verified') then
    return 'payment_reported';
  end if;

  return 'pre_payment_report';
end;
$fn$;

create or replace function public.finance_d9_active_reseller_hold_amount(p_reseller_profile_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select round(coalesce(sum(fh.amount), 0), 2)
  from public.finance_holds fh
  where fh.reseller_profile_id = p_reseller_profile_id
    and fh.status = 'active'
    and fh.deleted_at is null
    and fh.hold_type in ('commission_availability_hold', 'reseller_liability_review', 'withdrawal_review_hold');
$$;

create or replace function public.finance_d9_settlement_has_review_blocker(p_settlement_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with target_settlement as (
    select st.id, st.order_id, st.supplier_id
    from public.settlements st
    where st.id = p_settlement_id
      and st.deleted_at is null
  )
  select exists (
    select 1
    from target_settlement ts
    join public.finance_holds fh on fh.deleted_at is null
      and fh.status = 'active'
      and (
        fh.settlement_id = ts.id
        or (fh.order_id = ts.order_id and (fh.supplier_id is null or fh.supplier_id = ts.supplier_id))
      )
      and fh.hold_type in (
        'settlement_verification_block',
        'refund_accounting_hold',
        'supplier_liability_hold',
        'platform_liability_hold'
      )
  )
  or exists (
    select 1
    from target_settlement ts
    join public.order_disputes od on od.order_id = ts.order_id
      and od.deleted_at is null
      and od.status not in ('closed', 'cancelled', 'rejected')
      and (od.finance_review_required or od.requested_outcome in ('full_refund', 'partial_refund', 'delivery_fee_refund', 'accounting_correction'))
      and (
        od.affected_supplier_id is null
        or od.affected_supplier_id = ts.supplier_id
      )
  )
  or exists (
    select 1
    from target_settlement ts
    join public.order_refunds rf on rf.order_id = ts.order_id
      and rf.deleted_at is null
      and rf.status in ('approved', 'awaiting_responsible_party', 'reported_sent', 'awaiting_customer_confirmation', 'under_verification', 'verified')
      and (
        rf.affected_supplier_id is null
        or rf.affected_supplier_id = ts.supplier_id
      )
  );
$$;

create or replace function public.finance_d9_hold_context(
  p_dispute_id uuid,
  p_refund_id uuid default null,
  p_commission_id uuid default null,
  p_settlement_id uuid default null
)
returns table (
  dispute_id uuid,
  refund_id uuid,
  order_id uuid,
  order_item_id uuid,
  supplier_id uuid,
  reseller_profile_id uuid,
  commission_id uuid,
  settlement_id uuid,
  amount_from_refund numeric,
  amount_from_commission numeric,
  amount_from_settlement numeric,
  currency_code text,
  source_finance_state text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_dispute public.order_disputes%rowtype;
  v_refund public.order_refunds%rowtype;
  v_order public.orders%rowtype;
  v_item public.order_items%rowtype;
  v_settlement public.settlements%rowtype;
  v_commission public.commissions%rowtype;
  v_reseller_profile_id uuid;
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '22023';
  end if;

  select od.* into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null;

  if v_dispute.id is null then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = 'P0002';
  end if;

  if p_refund_id is not null then
    select rf.* into v_refund
    from public.order_refunds rf
    where rf.id = p_refund_id
      and rf.dispute_id = p_dispute_id
      and rf.deleted_at is null;
    if v_refund.id is null then
      raise exception 'REFUND_NOT_FOUND' using errcode = 'P0002';
    end if;
  end if;

  select o.* into v_order
  from public.orders o
  where o.id = coalesce(v_refund.order_id, v_dispute.order_id)
    and o.deleted_at is null;

  if v_order.id is null then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;

  if coalesce(v_refund.order_item_id, v_dispute.affected_order_item_id) is not null then
    select oi.* into v_item
    from public.order_items oi
    where oi.id = coalesce(v_refund.order_item_id, v_dispute.affected_order_item_id)
      and oi.order_id = v_order.id;
  end if;

  if p_commission_id is not null then
    select cm.* into v_commission
    from public.commissions cm
    where cm.id = p_commission_id
      and cm.order_id = v_order.id;
    if v_commission.id is null then
      raise exception 'COMMISSION_NOT_FOUND' using errcode = 'P0002';
    end if;
  elsif v_item.id is not null then
    select cm.* into v_commission
    from public.commissions cm
    where cm.order_item_id = v_item.id
      and cm.order_id = v_order.id
    order by cm.created_at asc, cm.id::text asc
    limit 1;
  else
    select cm.* into v_commission
    from public.commissions cm
    where cm.order_id = v_order.id
    order by cm.created_at asc, cm.id::text asc
    limit 1;
  end if;

  if p_settlement_id is not null then
    select st.* into v_settlement
    from public.settlements st
    where st.id = p_settlement_id
      and st.order_id = v_order.id
      and st.deleted_at is null;
    if v_settlement.id is null then
      raise exception 'SETTLEMENT_NOT_FOUND' using errcode = 'P0002';
    end if;
  elsif coalesce(v_refund.affected_supplier_id, v_dispute.affected_supplier_id, v_item.supplier_id) is not null then
    select st.* into v_settlement
    from public.settlements st
    where st.order_id = v_order.id
      and st.deleted_at is null
      and (
        coalesce(v_refund.affected_supplier_id, v_dispute.affected_supplier_id, v_item.supplier_id) is null
        or st.supplier_id = coalesce(v_refund.affected_supplier_id, v_dispute.affected_supplier_id, v_item.supplier_id)
      )
    order by st.created_at asc, st.id::text asc
    limit 1;
  end if;

  select r.profile_id
  into v_reseller_profile_id
  from public.resellers r
  where r.id = coalesce(v_commission.reseller_id, v_order.reseller_id)
    and r.deleted_at is null;

  return query
  select
    v_dispute.id,
    v_refund.id,
    v_order.id,
    coalesce(v_refund.order_item_id, v_dispute.affected_order_item_id, v_item.id),
    coalesce(v_refund.affected_supplier_id, v_dispute.affected_supplier_id, v_item.supplier_id, v_settlement.supplier_id),
    v_reseller_profile_id,
    v_commission.id,
    v_settlement.id,
    round(coalesce(v_refund.approved_amount, 0), 2),
    round(coalesce(v_commission.commission_amount, 0), 2),
    round(coalesce(v_settlement.outstanding_amount, v_settlement.due_amount, 0), 2),
    v_order.currency_code,
    public.finance_d9_source_state(v_order, v_settlement, v_commission);
end;
$fn$;

create or replace function public.finance_d9_make_audit(
  p_actor_profile_id uuid,
  p_actor_role text,
  p_action text,
  p_target_entity_type text,
  p_target_entity_id uuid,
  p_before jsonb,
  p_after jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $fn$
begin
  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    before_data,
    after_data,
    reason
  )
  values (
    p_actor_profile_id,
    p_actor_role,
    p_action,
    p_target_entity_type,
    p_target_entity_id,
    p_before,
    p_after,
    null
  );
end;
$fn$;

create or replace function public.finance_d9_assert_hold_immutable()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'UPDATE' then
    if old.dispute_id is distinct from new.dispute_id
      or old.refund_id is distinct from new.refund_id
      or old.order_id is distinct from new.order_id
      or old.order_item_id is distinct from new.order_item_id
      or old.supplier_id is distinct from new.supplier_id
      or old.reseller_profile_id is distinct from new.reseller_profile_id
      or old.commission_id is distinct from new.commission_id
      or old.settlement_id is distinct from new.settlement_id
      or old.hold_type is distinct from new.hold_type
      or old.amount is distinct from new.amount
      or old.currency_code is distinct from new.currency_code
      or old.reason_code is distinct from new.reason_code
      or old.source_finance_state is distinct from new.source_finance_state
      or old.created_by_profile_id is distinct from new.created_by_profile_id
      or old.idempotency_key is distinct from new.idempotency_key then
      raise exception 'FINANCE_HOLD_TARGET_IMMUTABLE' using errcode = '23514';
    end if;
    new.updated_at := now();
  end if;
  return new;
end;
$fn$;

drop trigger if exists finance_holds_immutable_fields on public.finance_holds;
create trigger finance_holds_immutable_fields
  before update on public.finance_holds
  for each row execute function public.finance_d9_assert_hold_immutable();

create or replace function public.finance_d9_block_withdrawal_paid_under_hold()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if old.withdrawal_status is distinct from new.withdrawal_status
    and new.withdrawal_status = 'paid' then
    if exists (
      select 1
      from public.resellers r
      join public.finance_holds fh on fh.reseller_profile_id = r.profile_id
      where r.id = new.reseller_id
        and r.deleted_at is null
        and fh.deleted_at is null
        and fh.status = 'active'
        and fh.hold_type in ('withdrawal_review_hold', 'reseller_liability_review')
    ) then
      raise exception 'WITHDRAWAL_REVIEW_REQUIRED' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$fn$;

drop trigger if exists finance_d9_withdrawal_paid_hold_guard on public.withdrawals;
create trigger finance_d9_withdrawal_paid_hold_guard
  before update of withdrawal_status on public.withdrawals
  for each row execute function public.finance_d9_block_withdrawal_paid_under_hold();

create or replace function public.finance_create_dispute_hold(
  p_dispute_id uuid,
  p_refund_id uuid,
  p_hold_type text,
  p_reason_code text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  hold_id uuid,
  hold_type text,
  status text,
  amount numeric,
  currency_code text,
  source_finance_state text,
  created boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text;
  v_public_note text;
  v_internal_note text;
  v_context record;
  v_amount numeric(12,2);
  v_fingerprint text;
  v_action public.finance_actions%rowtype;
  v_hold_id uuid;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_key := public.finance_d9_validate_key(p_idempotency_key);
  v_public_note := public.finance_d9_validate_note(p_public_note, false, 1200);
  v_internal_note := public.finance_d9_validate_note(p_internal_note, false, 2000);

  if p_hold_type not in (
    'settlement_verification_block',
    'commission_availability_hold',
    'refund_accounting_hold',
    'supplier_liability_hold',
    'platform_liability_hold',
    'reseller_liability_review',
    'withdrawal_review_hold'
  ) then
    raise exception 'INVALID_HOLD_TYPE' using errcode = '23514';
  end if;

  if p_reason_code not in (
    'active_dispute',
    'approved_refund',
    'refund_verified',
    'supplier_responsible',
    'platform_responsible',
    'reseller_responsibility_review',
    'accounting_inconsistency',
    'manual_finance_review'
  ) then
    raise exception 'INVALID_REASON_CODE' using errcode = '23514';
  end if;

  select c.* into v_context from public.finance_d9_hold_context(p_dispute_id, p_refund_id, null, null) c;

  if v_context.settlement_id is not null then
    perform 1 from public.settlements st where st.id = v_context.settlement_id for update;
  end if;
  if v_context.commission_id is not null then
    perform 1 from public.commissions cm where cm.id = v_context.commission_id for update;
  end if;
  if v_context.reseller_profile_id is not null then
    perform 1 from public.resellers r where r.profile_id = v_context.reseller_profile_id for update;
  end if;

  v_amount := case
    when p_hold_type = 'commission_availability_hold' then least(nullif(v_context.amount_from_refund, 0), nullif(v_context.amount_from_commission, 0))
    when p_hold_type in ('supplier_liability_hold', 'platform_liability_hold', 'refund_accounting_hold') then v_context.amount_from_refund
    when p_hold_type = 'settlement_verification_block' then greatest(v_context.amount_from_refund, v_context.amount_from_settlement)
    when p_hold_type in ('reseller_liability_review', 'withdrawal_review_hold') then coalesce(nullif(v_context.amount_from_commission, 0), v_context.amount_from_refund, 0)
    else 0
  end;
  v_amount := round(coalesce(v_amount, 0), 2);

  if p_hold_type in ('commission_availability_hold') and v_context.commission_id is null then
    raise exception 'COMMISSION_NOT_FOUND' using errcode = 'P0002';
  end if;

  if p_hold_type = 'settlement_verification_block' and v_context.source_finance_state = 'settlement_verified' then
    raise exception 'SETTLEMENT_ALREADY_VERIFIED' using errcode = '23514';
  end if;

  if p_hold_type in ('supplier_liability_hold', 'platform_liability_hold', 'refund_accounting_hold') and coalesce(p_refund_id, '00000000-0000-0000-0000-000000000000'::uuid) = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'REFUND_REQUIRED' using errcode = '23514';
  end if;

  if p_hold_type not in ('reseller_liability_review', 'withdrawal_review_hold') and v_amount <= 0 then
    raise exception 'ATTRIBUTABLE_AMOUNT_REQUIRED' using errcode = '23514';
  end if;

  if p_hold_type = 'commission_availability_hold' and v_amount > v_context.amount_from_commission then
    raise exception 'HOLD_AMOUNT_EXCEEDS_ATTRIBUTABLE_AMOUNT' using errcode = '23514';
  end if;

  v_fingerprint := md5(concat_ws('|', p_dispute_id::text, coalesce(p_refund_id::text, ''), p_hold_type, p_reason_code, coalesce(v_public_note, ''), coalesce(v_internal_note, ''), v_amount::text, v_context.order_id::text, coalesce(v_context.commission_id::text, ''), coalesce(v_context.settlement_id::text, '')));

  select fa.* into v_action
  from public.finance_actions fa
  where fa.actor_profile_id = v_actor.profile_id
    and fa.action_type = 'finance_hold_created'
    and fa.target_entity_type = 'order_disputes'
    and fa.target_entity_id = p_dispute_id
    and fa.idempotency_key = v_key
  for update;

  if v_action.id is not null then
    if v_action.request_fingerprint <> v_fingerprint then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;
    return query
    select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, fh.source_finance_state, false
    from public.finance_holds fh
    where fh.id = v_action.result_hold_id;
    return;
  end if;

  if exists (
    select 1
    from public.finance_holds fh
    where fh.dispute_id = p_dispute_id
      and fh.hold_type = p_hold_type
      and fh.status = 'active'
      and fh.deleted_at is null
      and fh.refund_id is not distinct from p_refund_id
      and fh.order_item_id is not distinct from v_context.order_item_id
      and fh.commission_id is not distinct from v_context.commission_id
      and fh.settlement_id is not distinct from v_context.settlement_id
  ) then
    raise exception 'ACTIVE_HOLD_EXISTS' using errcode = '23505';
  end if;

  insert into public.finance_holds(
    dispute_id,
    refund_id,
    order_id,
    order_item_id,
    supplier_id,
    reseller_profile_id,
    commission_id,
    settlement_id,
    hold_type,
    status,
    amount,
    currency_code,
    reason_code,
    source_finance_state,
    created_by_profile_id,
    public_note,
    internal_note,
    idempotency_key
  )
  values (
    p_dispute_id,
    p_refund_id,
    v_context.order_id,
    v_context.order_item_id,
    v_context.supplier_id,
    v_context.reseller_profile_id,
    v_context.commission_id,
    v_context.settlement_id,
    p_hold_type,
    'active',
    v_amount,
    v_context.currency_code,
    p_reason_code,
    v_context.source_finance_state,
    v_actor.profile_id,
    v_public_note,
    v_internal_note,
    v_key
  )
  returning id into v_hold_id;

  insert into public.finance_actions(
    actor_profile_id,
    actor_role,
    action_type,
    target_entity_type,
    target_entity_id,
    idempotency_key,
    request_fingerprint,
    result_hold_id,
    result_status
  )
  values (
    v_actor.profile_id,
    v_actor.actor_role,
    'finance_hold_created',
    'order_disputes',
    p_dispute_id,
    v_key,
    v_fingerprint,
    v_hold_id,
    'active'
  );

  perform public.finance_d9_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'finance_hold_created',
    'finance_holds',
    v_hold_id,
    null,
    jsonb_build_object(
      'hold_type', p_hold_type,
      'status', 'active',
      'amount', v_amount,
      'currency_code', v_context.currency_code,
      'reason_code', p_reason_code,
      'source_finance_state', v_context.source_finance_state,
      'public_note_present', v_public_note is not null,
      'internal_note_present', v_internal_note is not null
    )
  );

  return query
  select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, fh.source_finance_state, true
  from public.finance_holds fh
  where fh.id = v_hold_id;
end;
$fn$;

create or replace function public.finance_release_dispute_hold(
  p_hold_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  hold_id uuid,
  hold_type text,
  status text,
  amount numeric,
  currency_code text,
  released boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text;
  v_public_note text;
  v_internal_note text;
  v_hold public.finance_holds%rowtype;
  v_fingerprint text;
  v_action public.finance_actions%rowtype;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_key := public.finance_d9_validate_key(p_idempotency_key);
  v_public_note := public.finance_d9_validate_note(p_public_note, false, 1200);
  v_internal_note := public.finance_d9_validate_note(p_internal_note, false, 2000);

  select fh.* into v_hold
  from public.finance_holds fh
  where fh.id = p_hold_id
    and fh.deleted_at is null
  for update;

  if v_hold.id is null then
    raise exception 'HOLD_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_fingerprint := md5(concat_ws('|', p_hold_id::text, coalesce(v_public_note, ''), coalesce(v_internal_note, ''), 'release'));

  select fa.* into v_action
  from public.finance_actions fa
  where fa.actor_profile_id = v_actor.profile_id
    and fa.action_type = 'finance_hold_released'
    and fa.target_entity_type = 'finance_holds'
    and fa.target_entity_id = p_hold_id
    and fa.idempotency_key = v_key
  for update;

  if v_action.id is not null then
    if v_action.request_fingerprint <> v_fingerprint then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;
    return query select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, false from public.finance_holds fh where fh.id = p_hold_id;
    return;
  end if;

  if v_hold.status <> 'active' then
    raise exception 'HOLD_NOT_ACTIVE' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.order_disputes od
    where od.id = v_hold.dispute_id
      and od.deleted_at is null
      and od.status not in ('closed', 'cancelled', 'rejected')
      and od.finance_review_required
  ) then
    raise exception 'HOLD_BLOCKER_UNRESOLVED' using errcode = '23514';
  end if;

  update public.finance_holds fh
  set status = 'released',
      released_by_profile_id = v_actor.profile_id,
      released_at = now(),
      public_note = coalesce(fh.public_note, v_public_note),
      internal_note = coalesce(fh.internal_note, v_internal_note)
  where fh.id = p_hold_id;

  insert into public.finance_actions(actor_profile_id, actor_role, action_type, target_entity_type, target_entity_id, idempotency_key, request_fingerprint, result_hold_id, result_status)
  values (v_actor.profile_id, v_actor.actor_role, 'finance_hold_released', 'finance_holds', p_hold_id, v_key, v_fingerprint, p_hold_id, 'released');

  perform public.finance_d9_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'finance_hold_released',
    'finance_holds',
    p_hold_id,
    jsonb_build_object('status', 'active'),
    jsonb_build_object('status', 'released', 'public_note_present', v_public_note is not null, 'internal_note_present', v_internal_note is not null)
  );

  return query select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, true from public.finance_holds fh where fh.id = p_hold_id;
end;
$fn$;

create or replace function public.finance_cancel_dispute_hold(
  p_hold_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  hold_id uuid,
  hold_type text,
  status text,
  amount numeric,
  currency_code text,
  cancelled boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text;
  v_public_note text;
  v_internal_note text;
  v_hold public.finance_holds%rowtype;
  v_fingerprint text;
  v_action public.finance_actions%rowtype;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_key := public.finance_d9_validate_key(p_idempotency_key);
  v_public_note := public.finance_d9_validate_note(p_public_note, false, 1200);
  v_internal_note := public.finance_d9_validate_note(p_internal_note, false, 2000);

  select fh.* into v_hold
  from public.finance_holds fh
  where fh.id = p_hold_id
    and fh.deleted_at is null
  for update;

  if v_hold.id is null then
    raise exception 'HOLD_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_fingerprint := md5(concat_ws('|', p_hold_id::text, coalesce(v_public_note, ''), coalesce(v_internal_note, ''), 'cancel'));

  select fa.* into v_action
  from public.finance_actions fa
  where fa.actor_profile_id = v_actor.profile_id
    and fa.action_type = 'finance_hold_cancelled'
    and fa.target_entity_type = 'finance_holds'
    and fa.target_entity_id = p_hold_id
    and fa.idempotency_key = v_key
  for update;

  if v_action.id is not null then
    if v_action.request_fingerprint <> v_fingerprint then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;
    return query select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, false from public.finance_holds fh where fh.id = p_hold_id;
    return;
  end if;

  if v_hold.status <> 'active' then
    raise exception 'HOLD_NOT_ACTIVE' using errcode = '23514';
  end if;

  update public.finance_holds fh
  set status = 'cancelled',
      cancelled_by_profile_id = v_actor.profile_id,
      cancelled_at = now(),
      public_note = coalesce(fh.public_note, v_public_note),
      internal_note = coalesce(fh.internal_note, v_internal_note)
  where fh.id = p_hold_id;

  insert into public.finance_actions(actor_profile_id, actor_role, action_type, target_entity_type, target_entity_id, idempotency_key, request_fingerprint, result_hold_id, result_status)
  values (v_actor.profile_id, v_actor.actor_role, 'finance_hold_cancelled', 'finance_holds', p_hold_id, v_key, v_fingerprint, p_hold_id, 'cancelled');

  perform public.finance_d9_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'finance_hold_cancelled',
    'finance_holds',
    p_hold_id,
    jsonb_build_object('status', 'active'),
    jsonb_build_object('status', 'cancelled', 'public_note_present', v_public_note is not null, 'internal_note_present', v_internal_note is not null)
  );

  return query select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, true from public.finance_holds fh where fh.id = p_hold_id;
end;
$fn$;

create or replace function public.finance_review_disputed_settlement(
  p_settlement_id uuid,
  p_decision text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  settlement_id uuid,
  decision text,
  adjustment_id uuid,
  adjustment_status text,
  amount numeric,
  currency_code text
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text;
  v_public_note text;
  v_internal_note text;
  v_settlement public.settlements%rowtype;
  v_order public.orders%rowtype;
  v_dispute_id uuid;
  v_refund public.order_refunds%rowtype;
  v_commission public.commissions%rowtype;
  v_adjustment_id uuid;
  v_adjustment_type text;
  v_direction text;
  v_status text;
  v_amount numeric(12,2);
  v_reason text;
  v_fingerprint text;
  v_action public.finance_actions%rowtype;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_key := public.finance_d9_validate_key(p_idempotency_key);
  v_public_note := public.finance_d9_validate_note(p_public_note, false, 1200);
  v_internal_note := public.finance_d9_validate_note(p_internal_note, false, 2000);

  if p_decision not in ('keep_blocked', 'allow_verification', 'create_supplier_liability', 'create_platform_liability', 'require_manual_accounting_review') then
    raise exception 'INVALID_SETTLEMENT_REVIEW_DECISION' using errcode = '23514';
  end if;

  select st.* into v_settlement
  from public.settlements st
  where st.id = p_settlement_id
    and st.deleted_at is null
  for update;

  if v_settlement.id is null then
    raise exception 'SETTLEMENT_NOT_FOUND' using errcode = 'P0002';
  end if;

  select o.* into v_order from public.orders o where o.id = v_settlement.order_id and o.deleted_at is null;

  select od.id into v_dispute_id
  from public.order_disputes od
  where od.order_id = v_settlement.order_id
    and od.deleted_at is null
    and (od.affected_supplier_id is null or od.affected_supplier_id = v_settlement.supplier_id)
  order by od.created_at desc, od.id::text desc
  limit 1;

  if v_dispute_id is null then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = 'P0002';
  end if;

  select rf.* into v_refund
  from public.order_refunds rf
  where rf.dispute_id = v_dispute_id
    and rf.deleted_at is null
  order by rf.created_at desc, rf.id::text desc
  limit 1;

  select cm.* into v_commission
  from public.commissions cm
  where cm.settlement_id = v_settlement.id
  order by cm.created_at asc, cm.id::text asc
  limit 1;

  v_fingerprint := md5(concat_ws('|', p_settlement_id::text, p_decision, coalesce(v_public_note, ''), coalesce(v_internal_note, '')));

  select fa.* into v_action
  from public.finance_actions fa
  where fa.actor_profile_id = v_actor.profile_id
    and fa.action_type = 'disputed_settlement_reviewed'
    and fa.target_entity_type = 'settlements'
    and fa.target_entity_id = p_settlement_id
    and fa.idempotency_key = v_key
  for update;

  if v_action.id is not null then
    if v_action.request_fingerprint <> v_fingerprint then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;
    return query
    select p_settlement_id, p_decision, fa.id, fa.status, fa.amount, fa.currency_code
    from public.finance_adjustments fa
    where fa.id = v_action.result_adjustment_id
    union all
    select p_settlement_id, p_decision, null::uuid, null::text, 0::numeric, v_order.currency_code
    where v_action.result_adjustment_id is null
    limit 1;
    return;
  end if;

  if p_decision = 'allow_verification' and public.finance_d9_settlement_has_review_blocker(p_settlement_id) then
    raise exception 'SETTLEMENT_REVIEW_REQUIRED' using errcode = '23514';
  end if;

  if p_decision in ('create_supplier_liability', 'create_platform_liability') and v_refund.id is null then
    raise exception 'REFUND_REQUIRED' using errcode = '23514';
  end if;

  if p_decision = 'create_supplier_liability' then
    v_adjustment_type := 'supplier_liability';
    v_direction := 'debit';
    v_status := 'approved';
    v_amount := v_refund.approved_amount;
    v_reason := 'supplier_responsible';
  elsif p_decision = 'create_platform_liability' then
    v_adjustment_type := 'platform_liability';
    v_direction := 'debit';
    v_status := 'approved';
    v_amount := v_refund.approved_amount;
    v_reason := 'platform_responsible';
  elsif p_decision = 'require_manual_accounting_review' then
    v_adjustment_type := 'manual_accounting_correction';
    v_direction := 'hold';
    v_status := 'proposed';
    v_amount := 0;
    v_reason := 'manual_finance_review';
  else
    v_amount := 0;
  end if;

  if v_adjustment_type is not null then
    insert into public.finance_adjustments(
      dispute_id,
      refund_id,
      order_id,
      order_item_id,
      settlement_id,
      commission_id,
      reseller_profile_id,
      supplier_id,
      adjustment_type,
      direction,
      amount,
      currency_code,
      status,
      reason_code,
      approved_by_profile_id,
      public_note,
      internal_note,
      idempotency_key
    )
    values (
      v_dispute_id,
      v_refund.id,
      v_settlement.order_id,
      v_refund.order_item_id,
      v_settlement.id,
      v_commission.id,
      (select r.profile_id from public.resellers r where r.id = coalesce(v_commission.reseller_id, v_order.reseller_id)),
      v_settlement.supplier_id,
      v_adjustment_type,
      v_direction,
      v_amount,
      v_order.currency_code,
      v_status,
      v_reason,
      v_actor.profile_id,
      v_public_note,
      v_internal_note,
      v_key
    )
    returning id into v_adjustment_id;
  end if;

  insert into public.finance_actions(actor_profile_id, actor_role, action_type, target_entity_type, target_entity_id, idempotency_key, request_fingerprint, result_adjustment_id, result_status)
  values (v_actor.profile_id, v_actor.actor_role, 'disputed_settlement_reviewed', 'settlements', p_settlement_id, v_key, v_fingerprint, v_adjustment_id, p_decision);

  perform public.finance_d9_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'disputed_settlement_reviewed',
    'settlements',
    p_settlement_id,
    null,
    jsonb_build_object(
      'decision', p_decision,
      'adjustment_created', v_adjustment_id is not null,
      'public_note_present', v_public_note is not null,
      'internal_note_present', v_internal_note is not null
    )
  );

  if p_decision = 'create_supplier_liability' then
    perform public.finance_d9_make_audit(v_actor.profile_id, v_actor.actor_role, 'supplier_liability_created', 'finance_adjustments', v_adjustment_id, null, jsonb_build_object('amount', v_amount, 'currency_code', v_order.currency_code));
  elsif p_decision = 'create_platform_liability' then
    perform public.finance_d9_make_audit(v_actor.profile_id, v_actor.actor_role, 'platform_liability_created', 'finance_adjustments', v_adjustment_id, null, jsonb_build_object('amount', v_amount, 'currency_code', v_order.currency_code));
  end if;

  return query select p_settlement_id, p_decision, v_adjustment_id, v_status, v_amount, v_order.currency_code;
end;
$fn$;

create or replace function public.finance_hold_reseller_commission(
  p_commission_id uuid,
  p_dispute_id uuid,
  p_refund_id uuid,
  p_reason_code text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  hold_id uuid,
  hold_type text,
  status text,
  amount numeric,
  currency_code text,
  source_finance_state text,
  created boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text;
  v_public_note text;
  v_internal_note text;
  v_context record;
  v_commission public.commissions%rowtype;
  v_amount numeric(12,2);
  v_fingerprint text;
  v_action public.finance_actions%rowtype;
  v_hold_id uuid;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_key := public.finance_d9_validate_key(p_idempotency_key);
  v_public_note := public.finance_d9_validate_note(p_public_note, false, 1200);
  v_internal_note := public.finance_d9_validate_note(p_internal_note, false, 2000);

  if p_reason_code not in ('active_dispute', 'approved_refund', 'refund_verified', 'reseller_responsibility_review', 'accounting_inconsistency', 'manual_finance_review') then
    raise exception 'INVALID_REASON_CODE' using errcode = '23514';
  end if;

  select c.* into v_context from public.finance_d9_hold_context(p_dispute_id, p_refund_id, p_commission_id, null) c;

  select cm.* into v_commission
  from public.commissions cm
  where cm.id = p_commission_id
  for update;

  if v_commission.id is null then
    raise exception 'COMMISSION_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform 1 from public.resellers r where r.profile_id = v_context.reseller_profile_id for update;

  if v_commission.commission_status not in ('awaiting_supplier_settlement', 'available', 'held', 'disputed') then
    raise exception 'COMMISSION_NOT_HOLDABLE' using errcode = '23514';
  end if;

  if v_commission.withdrawal_id is not null then
    raise exception 'WITHDRAWAL_REVIEW_REQUIRED' using errcode = '23514';
  end if;

  v_amount := round(coalesce(nullif(least(greatest(v_context.amount_from_refund, 0), v_context.amount_from_commission), 0), v_context.amount_from_commission), 2);

  if v_amount <= 0 or v_amount > v_context.amount_from_commission then
    raise exception 'HOLD_AMOUNT_EXCEEDS_ATTRIBUTABLE_AMOUNT' using errcode = '23514';
  end if;

  v_fingerprint := md5(concat_ws('|', p_commission_id::text, p_dispute_id::text, coalesce(p_refund_id::text, ''), p_reason_code, coalesce(v_public_note, ''), coalesce(v_internal_note, ''), v_amount::text));

  select fa.* into v_action
  from public.finance_actions fa
  where fa.actor_profile_id = v_actor.profile_id
    and fa.action_type = 'commission_hold_created'
    and fa.target_entity_type = 'commissions'
    and fa.target_entity_id = p_commission_id
    and fa.idempotency_key = v_key
  for update;

  if v_action.id is not null then
    if v_action.request_fingerprint <> v_fingerprint then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;
    return query select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, fh.source_finance_state, false from public.finance_holds fh where fh.id = v_action.result_hold_id;
    return;
  end if;

  if exists (
    select 1 from public.finance_holds fh
    where fh.commission_id = p_commission_id
      and fh.hold_type = 'commission_availability_hold'
      and fh.status = 'active'
      and fh.deleted_at is null
  ) then
    raise exception 'ACTIVE_HOLD_EXISTS' using errcode = '23505';
  end if;

  insert into public.finance_holds(
    dispute_id,
    refund_id,
    order_id,
    order_item_id,
    supplier_id,
    reseller_profile_id,
    commission_id,
    settlement_id,
    hold_type,
    status,
    amount,
    currency_code,
    reason_code,
    source_finance_state,
    created_by_profile_id,
    public_note,
    internal_note,
    idempotency_key
  )
  values (
    p_dispute_id,
    p_refund_id,
    v_context.order_id,
    v_context.order_item_id,
    v_context.supplier_id,
    v_context.reseller_profile_id,
    p_commission_id,
    v_context.settlement_id,
    'commission_availability_hold',
    'active',
    v_amount,
    v_context.currency_code,
    p_reason_code,
    v_context.source_finance_state,
    v_actor.profile_id,
    v_public_note,
    v_internal_note,
    v_key
  )
  returning id into v_hold_id;

  insert into public.finance_actions(actor_profile_id, actor_role, action_type, target_entity_type, target_entity_id, idempotency_key, request_fingerprint, result_hold_id, result_status)
  values (v_actor.profile_id, v_actor.actor_role, 'commission_hold_created', 'commissions', p_commission_id, v_key, v_fingerprint, v_hold_id, 'active');

  perform public.finance_d9_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'commission_hold_created',
    'finance_holds',
    v_hold_id,
    null,
    jsonb_build_object('hold_type', 'commission_availability_hold', 'amount', v_amount, 'currency_code', v_context.currency_code, 'commission_status_preserved', v_commission.commission_status::text)
  );

  return query select fh.id, fh.hold_type, fh.status, fh.amount, fh.currency_code, fh.source_finance_state, true from public.finance_holds fh where fh.id = v_hold_id;
end;
$fn$;

create or replace function public.finance_apply_adjustment(
  p_adjustment_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  adjustment_id uuid,
  adjustment_type text,
  status text,
  amount numeric,
  currency_code text,
  applied boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text;
  v_public_note text;
  v_internal_note text;
  v_adjustment public.finance_adjustments%rowtype;
  v_fingerprint text;
  v_action public.finance_actions%rowtype;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_key := public.finance_d9_validate_key(p_idempotency_key);
  v_public_note := public.finance_d9_validate_note(p_public_note, false, 1200);
  v_internal_note := public.finance_d9_validate_note(p_internal_note, false, 2000);

  select fa.* into v_adjustment
  from public.finance_adjustments fa
  where fa.id = p_adjustment_id
  for update;

  if v_adjustment.id is null then
    raise exception 'ADJUSTMENT_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_fingerprint := md5(concat_ws('|', p_adjustment_id::text, coalesce(v_public_note, ''), coalesce(v_internal_note, ''), 'apply'));

  select fa.* into v_action
  from public.finance_actions fa
  where fa.actor_profile_id = v_actor.profile_id
    and fa.action_type = 'finance_adjustment_applied'
    and fa.target_entity_type = 'finance_adjustments'
    and fa.target_entity_id = p_adjustment_id
    and fa.idempotency_key = v_key
  for update;

  if v_action.id is not null then
    if v_action.request_fingerprint <> v_fingerprint then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;
    return query select fa.id, fa.adjustment_type, fa.status, fa.amount, fa.currency_code, false from public.finance_adjustments fa where fa.id = p_adjustment_id;
    return;
  end if;

  if v_adjustment.status not in ('proposed', 'approved') then
    raise exception 'ADJUSTMENT_NOT_APPLYABLE' using errcode = '23514';
  end if;

  if v_adjustment.adjustment_type in ('settlement_reduction', 'platform_revenue_reversal', 'commission_reduction', 'supplier_liability', 'platform_liability') then
    raise exception 'ADJUSTMENT_APPLY_DEFERRED' using errcode = '23514';
  end if;

  update public.finance_adjustments fa
  set status = 'applied',
      applied_by_profile_id = v_actor.profile_id,
      applied_at = now(),
      public_note = coalesce(fa.public_note, v_public_note),
      internal_note = coalesce(fa.internal_note, v_internal_note)
  where fa.id = p_adjustment_id;

  insert into public.finance_actions(actor_profile_id, actor_role, action_type, target_entity_type, target_entity_id, idempotency_key, request_fingerprint, result_adjustment_id, result_status)
  values (v_actor.profile_id, v_actor.actor_role, 'finance_adjustment_applied', 'finance_adjustments', p_adjustment_id, v_key, v_fingerprint, p_adjustment_id, 'applied');

  perform public.finance_d9_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'finance_adjustment_applied',
    'finance_adjustments',
    p_adjustment_id,
    jsonb_build_object('status', v_adjustment.status),
    jsonb_build_object('status', 'applied', 'public_note_present', v_public_note is not null, 'internal_note_present', v_internal_note is not null)
  );

  return query select fa.id, fa.adjustment_type, fa.status, fa.amount, fa.currency_code, true from public.finance_adjustments fa where fa.id = p_adjustment_id;
end;
$fn$;

create or replace function public.finance_cancel_adjustment(
  p_adjustment_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  adjustment_id uuid,
  adjustment_type text,
  status text,
  amount numeric,
  currency_code text,
  cancelled boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text;
  v_public_note text;
  v_internal_note text;
  v_adjustment public.finance_adjustments%rowtype;
  v_fingerprint text;
  v_action public.finance_actions%rowtype;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_key := public.finance_d9_validate_key(p_idempotency_key);
  v_public_note := public.finance_d9_validate_note(p_public_note, false, 1200);
  v_internal_note := public.finance_d9_validate_note(p_internal_note, false, 2000);

  select fa.* into v_adjustment
  from public.finance_adjustments fa
  where fa.id = p_adjustment_id
  for update;

  if v_adjustment.id is null then
    raise exception 'ADJUSTMENT_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_fingerprint := md5(concat_ws('|', p_adjustment_id::text, coalesce(v_public_note, ''), coalesce(v_internal_note, ''), 'cancel'));

  select fa.* into v_action
  from public.finance_actions fa
  where fa.actor_profile_id = v_actor.profile_id
    and fa.action_type = 'finance_adjustment_cancelled'
    and fa.target_entity_type = 'finance_adjustments'
    and fa.target_entity_id = p_adjustment_id
    and fa.idempotency_key = v_key
  for update;

  if v_action.id is not null then
    if v_action.request_fingerprint <> v_fingerprint then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;
    return query select fa.id, fa.adjustment_type, fa.status, fa.amount, fa.currency_code, false from public.finance_adjustments fa where fa.id = p_adjustment_id;
    return;
  end if;

  if v_adjustment.status not in ('proposed', 'approved') then
    raise exception 'ADJUSTMENT_NOT_CANCELLABLE' using errcode = '23514';
  end if;

  update public.finance_adjustments fa
  set status = 'cancelled',
      public_note = coalesce(fa.public_note, v_public_note),
      internal_note = coalesce(fa.internal_note, v_internal_note)
  where fa.id = p_adjustment_id;

  insert into public.finance_actions(actor_profile_id, actor_role, action_type, target_entity_type, target_entity_id, idempotency_key, request_fingerprint, result_adjustment_id, result_status)
  values (v_actor.profile_id, v_actor.actor_role, 'finance_adjustment_cancelled', 'finance_adjustments', p_adjustment_id, v_key, v_fingerprint, p_adjustment_id, 'cancelled');

  perform public.finance_d9_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'finance_adjustment_cancelled',
    'finance_adjustments',
    p_adjustment_id,
    jsonb_build_object('status', v_adjustment.status),
    jsonb_build_object('status', 'cancelled', 'public_note_present', v_public_note is not null, 'internal_note_present', v_internal_note is not null)
  );

  return query select fa.id, fa.adjustment_type, fa.status, fa.amount, fa.currency_code, true from public.finance_adjustments fa where fa.id = p_adjustment_id;
end;
$fn$;

create or replace function public.finance_release_reseller_commission_hold(
  p_hold_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  hold_id uuid,
  hold_type text,
  status text,
  amount numeric,
  currency_code text,
  released boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
begin
  if not exists (
    select 1 from public.finance_holds fh
    where fh.id = p_hold_id
      and fh.hold_type = 'commission_availability_hold'
      and fh.deleted_at is null
  ) then
    raise exception 'HOLD_NOT_FOUND' using errcode = 'P0002';
  end if;

  return query
  select r.hold_id, r.hold_type, r.status, r.amount, r.currency_code, r.released
  from public.finance_release_dispute_hold(p_hold_id, p_public_note, p_internal_note, p_idempotency_key) r;
end;
$fn$;

create or replace function public.list_finance_holds_safe(p_status text default null, p_limit integer default 50)
returns table (
  hold_id uuid,
  dispute_id uuid,
  refund_id uuid,
  order_id uuid,
  hold_type text,
  status text,
  amount numeric,
  currency_code text,
  reason_code text,
  source_finance_state text,
  public_note text,
  internal_note text,
  created_at timestamptz,
  terminal_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_limit integer;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_limit := greatest(1, least(coalesce(p_limit, 50), 100));

  if p_status is not null and p_status not in ('active', 'released', 'applied', 'cancelled', 'expired') then
    raise exception 'INVALID_STATUS_FILTER' using errcode = '22023';
  end if;

  return query
  select fh.id, fh.dispute_id, fh.refund_id, fh.order_id, fh.hold_type, fh.status, fh.amount, fh.currency_code, fh.reason_code, fh.source_finance_state, fh.public_note, fh.internal_note, fh.created_at, coalesce(fh.released_at, fh.applied_at, fh.cancelled_at)
  from public.finance_holds fh
  where fh.deleted_at is null
    and (p_status is null or fh.status = p_status)
  order by fh.created_at desc, fh.id::text desc
  limit v_limit;
end;
$fn$;

create or replace function public.get_finance_hold_safe(p_hold_id uuid)
returns table (
  hold_id uuid,
  dispute_id uuid,
  refund_id uuid,
  order_id uuid,
  order_item_id uuid,
  supplier_id uuid,
  reseller_profile_present boolean,
  commission_id uuid,
  settlement_id uuid,
  hold_type text,
  status text,
  amount numeric,
  currency_code text,
  reason_code text,
  source_finance_state text,
  public_note text,
  internal_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_actor record;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;

  return query
  select fh.id, fh.dispute_id, fh.refund_id, fh.order_id, fh.order_item_id, fh.supplier_id, fh.reseller_profile_id is not null, fh.commission_id, fh.settlement_id, fh.hold_type, fh.status, fh.amount, fh.currency_code, fh.reason_code, fh.source_finance_state, fh.public_note, fh.internal_note, fh.created_at
  from public.finance_holds fh
  where fh.id = p_hold_id
    and fh.deleted_at is null;
end;
$fn$;

create or replace function public.list_finance_adjustments_safe(p_status text default null, p_limit integer default 50)
returns table (
  adjustment_id uuid,
  dispute_id uuid,
  refund_id uuid,
  order_id uuid,
  adjustment_type text,
  direction text,
  amount numeric,
  currency_code text,
  status text,
  reason_code text,
  public_note text,
  internal_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_limit integer;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;
  v_limit := greatest(1, least(coalesce(p_limit, 50), 100));

  if p_status is not null and p_status not in ('proposed', 'approved', 'applied', 'cancelled', 'reversed') then
    raise exception 'INVALID_STATUS_FILTER' using errcode = '22023';
  end if;

  return query
  select fa.id, fa.dispute_id, fa.refund_id, fa.order_id, fa.adjustment_type, fa.direction, fa.amount, fa.currency_code, fa.status, fa.reason_code, fa.public_note, fa.internal_note, fa.created_at
  from public.finance_adjustments fa
  where p_status is null or fa.status = p_status
  order by fa.created_at desc, fa.id::text desc
  limit v_limit;
end;
$fn$;

create or replace function public.get_finance_adjustment_safe(p_adjustment_id uuid)
returns table (
  adjustment_id uuid,
  dispute_id uuid,
  refund_id uuid,
  finance_hold_id uuid,
  order_id uuid,
  settlement_id uuid,
  commission_id uuid,
  supplier_id uuid,
  reseller_profile_present boolean,
  adjustment_type text,
  direction text,
  amount numeric,
  currency_code text,
  status text,
  reason_code text,
  public_note text,
  internal_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_actor record;
begin
  select a.profile_id, a.actor_role into v_actor from public.finance_d9_assert_actor() a;

  return query
  select fa.id, fa.dispute_id, fa.refund_id, fa.finance_hold_id, fa.order_id, fa.settlement_id, fa.commission_id, fa.supplier_id, fa.reseller_profile_id is not null, fa.adjustment_type, fa.direction, fa.amount, fa.currency_code, fa.status, fa.reason_code, fa.public_note, fa.internal_note, fa.created_at
  from public.finance_adjustments fa
  where fa.id = p_adjustment_id;
end;
$fn$;

create or replace function public.get_reseller_finance_hold_impact_safe()
returns table (
  active_hold_count bigint,
  held_amount numeric,
  currency_code text,
  review_status text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_reseller_profile_id uuid;
begin
  v_reseller_id := public.current_verified_reseller_id();
  select r.profile_id into v_reseller_profile_id from public.resellers r where r.id = v_reseller_id;

  return query
  select
    count(*)::bigint,
    round(coalesce(sum(fh.amount), 0), 2),
    coalesce(min(fh.currency_code), 'GHS'),
    case when count(*) filter (where fh.status = 'active') > 0 then 'review_required' else 'clear' end
  from public.finance_holds fh
  where fh.reseller_profile_id = v_reseller_profile_id
    and fh.deleted_at is null
    and fh.status = 'active';
end;
$fn$;

create or replace function public.list_supplier_liabilities_safe(p_limit integer default 50)
returns table (
  adjustment_id uuid,
  order_id uuid,
  amount numeric,
  currency_code text,
  status text,
  reason_code text,
  public_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_supplier_id uuid;
  v_limit integer;
begin
  v_supplier_id := public.current_verified_supplier_owner_id();
  v_limit := greatest(1, least(coalesce(p_limit, 50), 100));

  return query
  select fa.id, fa.order_id, fa.amount, fa.currency_code, fa.status, fa.reason_code, fa.public_note, fa.created_at
  from public.finance_adjustments fa
  where fa.supplier_id = v_supplier_id
    and fa.adjustment_type = 'supplier_liability'
  order by fa.created_at desc, fa.id::text desc
  limit v_limit;
end;
$fn$;

create or replace function public.get_supplier_liability_safe(p_adjustment_id uuid)
returns table (
  adjustment_id uuid,
  order_id uuid,
  amount numeric,
  currency_code text,
  status text,
  reason_code text,
  public_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_supplier_id uuid;
begin
  v_supplier_id := public.current_verified_supplier_owner_id();

  return query
  select fa.id, fa.order_id, fa.amount, fa.currency_code, fa.status, fa.reason_code, fa.public_note, fa.created_at
  from public.finance_adjustments fa
  where fa.id = p_adjustment_id
    and fa.supplier_id = v_supplier_id
    and fa.adjustment_type = 'supplier_liability';
end;
$fn$;

create or replace function public.get_dispute_finance_review_summary_safe(p_dispute_id uuid)
returns table (
  dispute_id uuid,
  finance_review_required boolean,
  active_hold_count bigint,
  active_hold_amount numeric,
  currency_code text,
  has_supplier_liability boolean,
  has_platform_liability boolean,
  has_reseller_review boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_support record;
  v_is_allowed boolean := false;
begin
  if public.current_finance_admin_profile_id() is not null then
    v_is_allowed := true;
  else
    select c.profile_id, c.admin_role into v_support from public.current_dispute_support_admin() c;
    v_is_allowed := v_support.profile_id is not null;
  end if;

  if not v_is_allowed then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    od.id,
    od.finance_review_required or exists (select 1 from public.finance_holds fh where fh.dispute_id = od.id and fh.status = 'active' and fh.deleted_at is null),
    count(fh.id)::bigint,
    round(coalesce(sum(fh.amount) filter (where fh.status = 'active'), 0), 2),
    coalesce(min(fh.currency_code), 'GHS'),
    exists (select 1 from public.finance_adjustments fa where fa.dispute_id = od.id and fa.adjustment_type = 'supplier_liability'),
    exists (select 1 from public.finance_adjustments fa where fa.dispute_id = od.id and fa.adjustment_type = 'platform_liability'),
    exists (select 1 from public.finance_holds rh where rh.dispute_id = od.id and rh.hold_type = 'reseller_liability_review' and rh.status = 'active')
  from public.order_disputes od
  left join public.finance_holds fh on fh.dispute_id = od.id and fh.deleted_at is null
  where od.id = p_dispute_id
    and od.deleted_at is null
  group by od.id, od.finance_review_required;
end;
$fn$;

create or replace function public.get_reseller_wallet_safe()
returns table (
  reseller_id uuid,
  currency_code text,
  locked_commission_amount numeric,
  available_balance_amount numeric,
  pending_withdrawal_amount numeric,
  withdrawn_amount numeric,
  minimum_withdrawal_amount numeric,
  has_pending_withdrawal boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_reseller_profile_id uuid;
  v_held_amount numeric;
begin
  v_reseller_id := public.current_verified_reseller_id();
  select r.profile_id into v_reseller_profile_id from public.resellers r where r.id = v_reseller_id;
  v_held_amount := public.finance_d9_active_reseller_hold_amount(v_reseller_profile_id);

  return query
  select
    r.id,
    'GHS'::text,
    r.commission_pending_amount,
    greatest(r.commission_available_amount - v_held_amount, 0),
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount,
    public.reseller_withdrawal_minimum_amount(),
    exists (
      select 1
      from public.withdrawals w
      where w.reseller_id = r.id
        and w.withdrawal_status = 'requested'
    )
  from public.resellers r
  where r.id = v_reseller_id
    and r.deleted_at is null;
end;
$fn$;

create or replace function public.get_reseller_finance_summary_safe(
  p_date_from date default null,
  p_date_to date default null
)
returns table (
  currency_code text,
  locked_commission_amount numeric,
  available_balance_amount numeric,
  pending_withdrawal_amount numeric,
  withdrawn_amount numeric,
  period_commission_earned_amount numeric,
  period_available_commission_amount numeric,
  period_withdrawal_requested_amount numeric,
  period_withdrawal_paid_amount numeric,
  completed_sales_count bigint,
  date_from date,
  date_to date
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_reseller_profile_id uuid;
  v_held_amount numeric;
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_reseller_id := public.current_verified_reseller_id();
  select r.profile_id into v_reseller_profile_id from public.resellers r where r.id = v_reseller_id;
  v_held_amount := public.finance_d9_active_reseller_hold_amount(v_reseller_profile_id);

  return query
  with period_commissions as (
    select
      coalesce(o.currency_code, 'GHS') as result_currency_code,
      sum(c.commission_amount) filter (
        where (p_date_from is null or c.created_at >= p_date_from::timestamptz)
          and (p_date_to is null or c.created_at < (p_date_to + 1)::timestamptz)
      ) as earned_amount,
      sum(c.commission_amount) filter (
        where c.commission_status in ('available', 'withdrawal_requested', 'paid')
          and c.available_at is not null
          and (p_date_from is null or c.available_at >= p_date_from::timestamptz)
          and (p_date_to is null or c.available_at < (p_date_to + 1)::timestamptz)
      ) as available_amount,
      count(distinct c.order_id) filter (
        where o.order_status::text = 'completed'
          and (p_date_from is null or coalesce(o.completed_at, c.available_at, c.created_at) >= p_date_from::timestamptz)
          and (p_date_to is null or coalesce(o.completed_at, c.available_at, c.created_at) < (p_date_to + 1)::timestamptz)
      ) as completed_sales_count
    from public.commissions c
    left join public.orders o on o.id = c.order_id and o.deleted_at is null
    where c.reseller_id = v_reseller_id
    group by coalesce(o.currency_code, 'GHS')
  ),
  period_withdrawals as (
    select
      w.currency_code as result_currency_code,
      sum(w.requested_amount) filter (
        where w.withdrawal_status = 'requested'
          and (p_date_from is null or w.created_at >= p_date_from::timestamptz)
          and (p_date_to is null or w.created_at < (p_date_to + 1)::timestamptz)
      ) as requested_amount,
      sum(coalesce(w.approved_amount, w.requested_amount)) filter (
        where w.withdrawal_status = 'paid'
          and w.paid_at is not null
          and (p_date_from is null or w.paid_at >= p_date_from::timestamptz)
          and (p_date_to is null or w.paid_at < (p_date_to + 1)::timestamptz)
      ) as paid_amount
    from public.withdrawals w
    where w.reseller_id = v_reseller_id
    group by w.currency_code
  ),
  currencies as (
    select pc.result_currency_code from period_commissions pc
    union select pw.result_currency_code from period_withdrawals pw
    union select 'GHS'::text
  )
  select
    cur.result_currency_code,
    r.commission_pending_amount,
    greatest(r.commission_available_amount - v_held_amount, 0),
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount,
    round(coalesce(pc.earned_amount, 0), 2),
    round(coalesce(pc.available_amount, 0), 2),
    round(coalesce(pw.requested_amount, 0), 2),
    round(coalesce(pw.paid_amount, 0), 2),
    coalesce(pc.completed_sales_count, 0),
    p_date_from,
    p_date_to
  from public.resellers r
  cross join currencies cur
  left join period_commissions pc on pc.result_currency_code = cur.result_currency_code
  left join period_withdrawals pw on pw.result_currency_code = cur.result_currency_code
  where r.id = v_reseller_id
    and r.deleted_at is null
  order by cur.result_currency_code;
end;
$fn$;

create or replace function public.reseller_request_withdrawal(
  p_amount numeric,
  p_payout_account_id uuid,
  p_idempotency_key text default null
)
returns table (
  withdrawal_id uuid,
  request_reference text,
  requested_amount numeric,
  currency_code text,
  withdrawal_status text,
  available_balance_amount numeric,
  pending_withdrawal_amount numeric,
  withdrawn_amount numeric
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_reseller public.resellers%rowtype;
  v_account public.reseller_payout_accounts%rowtype;
  v_existing public.withdrawals%rowtype;
  v_withdrawal_id uuid;
  v_reference text;
  v_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_amount numeric(12,2) := round(coalesce(p_amount, 0), 2);
  v_held_amount numeric(12,2);
begin
  if v_key is null or length(v_key) > 140 then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = '22023';
  end if;

  if v_amount <= 0 then
    raise exception 'INVALID_AMOUNT' using errcode = '22023';
  end if;

  if v_amount < public.reseller_withdrawal_minimum_amount() then
    raise exception 'BELOW_MINIMUM' using errcode = '22023';
  end if;

  select w.*
  into v_existing
  from public.withdrawals w
  where w.request_idempotency_key = v_key
  for update;

  if found then
    if v_existing.requested_amount <> v_amount
       or v_existing.payout_account_id is distinct from p_payout_account_id then
      raise exception 'CONFLICTING_RETRY' using errcode = '23505';
    end if;

    return query
    select
      w.id,
      w.request_reference,
      w.requested_amount,
      w.currency_code,
      w.withdrawal_status::text,
      greatest(r.commission_available_amount - public.finance_d9_active_reseller_hold_amount(r.profile_id), 0),
      r.commission_pending_withdrawal_amount,
      r.commission_withdrawn_amount
    from public.withdrawals w
    join public.resellers r on r.id = w.reseller_id
    where w.id = v_existing.id;
    return;
  end if;

  select r.*
  into v_reseller
  from public.resellers r
  where r.id = public.current_verified_reseller_id()
    and r.approval_status = 'approved'
    and r.payout_status = 'active'
    and r.deleted_at is null
  for update;

  if not found then
    raise exception 'RESELLER_REQUIRED' using errcode = '42501';
  end if;

  v_held_amount := public.finance_d9_active_reseller_hold_amount(v_reseller.profile_id);

  if exists (
    select 1
    from public.order_disputes od
    join public.orders o on o.id = od.order_id
    where o.reseller_id = v_reseller.id
      and o.deleted_at is null
      and od.deleted_at is null
      and od.status not in ('closed', 'cancelled', 'rejected')
      and (
        od.finance_review_required
        or od.requested_outcome in ('full_refund', 'partial_refund', 'delivery_fee_refund', 'accounting_correction')
      )
  )
  or exists (
    select 1
    from public.order_refunds rf
    join public.orders o on o.id = rf.order_id
    where o.reseller_id = v_reseller.id
      and o.deleted_at is null
      and rf.deleted_at is null
      and rf.status in ('approved', 'awaiting_responsible_party', 'reported_sent', 'awaiting_customer_confirmation', 'under_verification', 'verified')
      and rf.responsibility_code in ('reseller_responsible', 'shared_responsibility')
  ) then
    raise exception 'WITHDRAWAL_REVIEW_REQUIRED' using errcode = '23514';
  end if;

  perform 1
  from public.withdrawals w
  where w.reseller_id = v_reseller.id
    and w.withdrawal_status = 'requested'
  for update;

  if found then
    raise exception 'WITHDRAWAL_ALREADY_PENDING' using errcode = '23505';
  end if;

  select a.*
  into v_account
  from public.reseller_payout_accounts a
  where a.id = p_payout_account_id
    and a.reseller_id = v_reseller.id
    and a.account_status = 'active'
    and a.deleted_at is null
  for update;

  if not found then
    raise exception 'PAYOUT_ACCOUNT_NOT_FOUND' using errcode = '22023';
  end if;

  if greatest(v_reseller.commission_available_amount - v_held_amount, 0) < v_amount then
    raise exception 'INSUFFICIENT_AVAILABLE_BALANCE' using errcode = '22023';
  end if;

  v_reference := concat('WD-', upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)));

  insert into public.withdrawals(
    reseller_id,
    requested_amount,
    approved_amount,
    withdrawal_status,
    provider,
    account_name,
    account_number_masked,
    payout_account_id,
    currency_code,
    request_reference,
    request_idempotency_key,
    requested_by_profile_id
  )
  values (
    v_reseller.id,
    v_amount,
    null,
    'requested',
    v_account.payout_method,
    v_account.account_name,
    public.mask_payout_value(coalesce(v_account.phone_number, v_account.account_number)),
    v_account.id,
    'GHS',
    v_reference,
    v_key,
    public.current_profile_id()
  )
  returning id into v_withdrawal_id;

  update public.resellers r
  set commission_available_amount = r.commission_available_amount - v_amount,
      commission_pending_withdrawal_amount = r.commission_pending_withdrawal_amount + v_amount,
      updated_at = now()
  where r.id = v_reseller.id
    and r.commission_available_amount >= v_amount
    and greatest(r.commission_available_amount - v_held_amount, 0) >= v_amount;

  if not found then
    raise exception 'INSUFFICIENT_AVAILABLE_BALANCE' using errcode = '22023';
  end if;

  perform public.create_audit_log_entry(
    'reseller_withdrawal_requested',
    'withdrawals',
    v_withdrawal_id,
    'reseller_reserved_available_commission',
    jsonb_build_object(
      'available_balance', v_reseller.commission_available_amount,
      'pending_withdrawal_balance', v_reseller.commission_pending_withdrawal_amount,
      'active_hold_amount', v_held_amount
    ),
    jsonb_build_object(
      'requested_amount', v_amount,
      'currency_code', 'GHS',
      'payout_account_masked', public.mask_payout_value(coalesce(v_account.phone_number, v_account.account_number)),
      'idempotency_key_present', true,
      'commission_row_allocation_deferred', true,
      'active_holds_respected', true
    )
  );

  return query
  select
    w.id,
    w.request_reference,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    greatest(r.commission_available_amount - public.finance_d9_active_reseller_hold_amount(r.profile_id), 0),
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount
  from public.withdrawals w
  join public.resellers r on r.id = w.reseller_id
  where w.id = v_withdrawal_id;
end;
$fn$;

create or replace function public.admin_verify_supplier_settlement(
  p_order_id uuid,
  p_settlement_reference text default null,
  p_admin_note text default null,
  p_idempotency_key text default null
)
returns table (
  order_id uuid,
  order_number text,
  order_status text,
  payment_collection_status text,
  settlement_status text,
  commission_status text,
  reseller_available_amount numeric,
  settlement_verified_at timestamptz,
  completed_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
  v_order public.orders%rowtype;
  v_settlement public.settlements%rowtype;
  v_report public.supplier_payment_reports%rowtype;
  v_reservation_status text;
  v_supplier_id uuid;
  v_reseller_id uuid;
  v_supplier_amount numeric;
  v_settlement_due numeric;
  v_commission_amount numeric;
  v_platform_amount numeric;
  v_idempotency_key text;
  v_reference text;
  v_admin_note text;
  v_existing_audit_count integer;
begin
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  if p_order_id is null then
    raise exception 'ORDER_NOT_FOUND' using errcode = '22023';
  end if;

  v_idempotency_key := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_reference := nullif(trim(coalesce(p_settlement_reference, '')), '');
  v_admin_note := nullif(trim(coalesce(p_admin_note, '')), '');

  if v_idempotency_key is null or length(v_idempotency_key) > 140 then
    raise exception 'VALIDATION_ERROR' using errcode = '23514';
  end if;

  if v_reference is not null and (length(v_reference) > 100 or v_reference ~* '(pin|password|secret|token|card|cvv|otp)') then
    raise exception 'FIELD_TOO_LONG' using errcode = '23514';
  end if;

  if v_admin_note is not null and (length(v_admin_note) > 500 or v_admin_note ~* '(pin|password|secret|token|card|cvv|otp)') then
    raise exception 'FIELD_TOO_LONG' using errcode = '23514';
  end if;

  select o.* into v_order
  from public.orders o
  where o.id = p_order_id
    and o.deleted_at is null
  for update;

  if v_order.id is null then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;

  select st.* into v_settlement
  from public.settlements st
  where st.order_id = p_order_id
    and st.deleted_at is null
  for update;

  if v_settlement.id is null then
    raise exception 'SETTLEMENT_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_order.order_status = 'completed'
    or v_settlement.settlement_status = 'paid'
    or v_order.payment_collection_status::text = 'settlement_verified' then
    if v_settlement.verification_idempotency_key = v_idempotency_key
      and coalesce(v_settlement.proof_reference, '') is not distinct from coalesce(v_reference, '')
      and coalesce(v_settlement.review_notes, '') is not distinct from coalesce(v_admin_note, '') then
      return query select r.order_id, r.order_number, r.order_status, r.payment_collection_status, r.settlement_status, r.commission_status, r.reseller_available_amount, r.settlement_verified_at, r.completed_at from public.admin_verify_supplier_settlement_result(p_order_id) r;
      return;
    end if;
    raise exception 'CONFLICTING_RETRY' using errcode = '23505';
  end if;

  if public.finance_d9_settlement_has_review_blocker(v_settlement.id) then
    raise exception 'SETTLEMENT_REVIEW_REQUIRED' using errcode = '23514';
  end if;

  if v_order.order_status::text <> 'payment_reported' or v_order.payment_collection_status::text <> 'supplier_reported' then
    raise exception 'ORDER_NOT_PAYMENT_REPORTED' using errcode = '23514';
  end if;

  if v_settlement.settlement_status <> 'due' then
    raise exception 'SETTLEMENT_ALREADY_VERIFIED' using errcode = '23514';
  end if;

  select spr.* into v_report
  from public.supplier_payment_reports spr
  where spr.order_id = p_order_id
    and spr.deleted_at is null
  order by spr.reported_at asc, spr.id::text asc
  limit 1
  for update;

  if v_report.id is null then
    raise exception 'PAYMENT_REPORT_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_report.supplier_id <> v_settlement.supplier_id
    or v_report.currency_code <> v_order.currency_code
    or round(v_report.reported_amount, 2) <> round(v_order.total_payable_amount, 2) then
    raise exception 'CURRENCY_MISMATCH' using errcode = '23514';
  end if;

  select oi.supplier_id, sum(oi.supplier_base_price_snapshot_amount * oi.quantity), sum(oi.settlement_due_amount), sum(oi.commission_amount)
  into v_supplier_id, v_supplier_amount, v_settlement_due, v_commission_amount
  from public.order_items oi
  where oi.order_id = p_order_id
  group by oi.supplier_id;

  if v_supplier_id is null or v_supplier_id <> v_settlement.supplier_id then
    raise exception 'FINANCIAL_AMOUNT_MISMATCH' using errcode = '23514';
  end if;

  v_supplier_amount := round(coalesce(v_supplier_amount, 0), 2);
  v_settlement_due := round(coalesce(v_settlement_due, 0), 2);
  v_commission_amount := round(coalesce(v_commission_amount, 0), 2);
  v_platform_amount := round(v_settlement_due - v_commission_amount, 2);

  if round(v_supplier_amount + v_settlement_due, 2) <> round(v_order.total_payable_amount, 2)
    or round(v_settlement.due_amount, 2) <> v_settlement_due
    or v_platform_amount < 0 then
    raise exception 'FINANCIAL_AMOUNT_MISMATCH' using errcode = '23514';
  end if;

  select sr.reservation_status::text
  into v_reservation_status
  from public.stock_reservations sr
  where sr.order_id = p_order_id
  order by sr.created_at asc
  limit 1;

  if coalesce(v_reservation_status, '') <> 'committed' then
    raise exception 'STOCK_STATE_INCONSISTENT' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.withdrawals w
    join public.commissions cm on cm.withdrawal_id = w.id
    where cm.order_id = p_order_id
  ) then
    raise exception 'WITHDRAWAL_ALREADY_EXISTS' using errcode = '23514';
  end if;

  select cm.reseller_id
  into v_reseller_id
  from public.commissions cm
  where cm.order_id = p_order_id
    and cm.settlement_id = v_settlement.id
    and cm.commission_status = 'awaiting_supplier_settlement'
    and cm.withdrawal_id is null
  order by cm.created_at asc, cm.id::text asc
  limit 1;

  select sum(cm.commission_amount)
  into v_commission_amount
  from public.commissions cm
  where cm.order_id = p_order_id
    and cm.settlement_id = v_settlement.id
    and cm.commission_status = 'awaiting_supplier_settlement'
    and cm.withdrawal_id is null
    and cm.reseller_id = v_reseller_id;

  if v_reseller_id is null or round(coalesce(v_commission_amount, 0), 2) <> round(v_settlement_due - v_platform_amount, 2) then
    raise exception 'COMMISSION_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.settlements st
  set settlement_status = 'paid',
      paid_amount = st.due_amount,
      outstanding_amount = 0,
      verified_at = coalesce(st.verified_at, now()),
      verified_by_profile_id = coalesce(st.verified_by_profile_id, v_admin_profile_id),
      reviewed_by_profile_id = coalesce(st.reviewed_by_profile_id, v_admin_profile_id),
      proof_reference = coalesce(st.proof_reference, v_reference),
      review_notes = coalesce(st.review_notes, v_admin_note),
      verification_idempotency_key = coalesce(st.verification_idempotency_key, v_idempotency_key),
      updated_at = now()
  where st.id = v_settlement.id
    and st.settlement_status = 'due'
    and st.verified_at is null;

  if not found then
    raise exception 'SETTLEMENT_ALREADY_VERIFIED' using errcode = '23514';
  end if;

  update public.commissions cm
  set commission_status = 'available',
      available_at = coalesce(cm.available_at, now()),
      held_reason = null,
      updated_at = now()
  where cm.order_id = p_order_id
    and cm.settlement_id = v_settlement.id
    and cm.commission_status = 'awaiting_supplier_settlement'
    and cm.withdrawal_id is null;

  if not found then
    raise exception 'COMMISSION_ALREADY_AVAILABLE' using errcode = '23514';
  end if;

  update public.resellers r
  set commission_available_amount = r.commission_available_amount + v_commission_amount,
      commission_pending_amount = greatest(r.commission_pending_amount - v_commission_amount, 0),
      updated_at = now()
  where r.id = v_reseller_id
    and r.deleted_at is null;

  if not found then
    raise exception 'COMMISSION_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.orders o
  set order_status = 'completed',
      payment_collection_status = 'settlement_verified'::text::public.payment_collection_status,
      completed_at = coalesce(o.completed_at, now()),
      completed_by_profile_id = coalesce(o.completed_by_profile_id, v_admin_profile_id),
      settlement_verified_idempotency_key = coalesce(o.settlement_verified_idempotency_key, v_idempotency_key),
      updated_at = now()
  where o.id = p_order_id;

  select count(*)::integer
  into v_existing_audit_count
  from public.audit_logs al
  where al.target_entity_type = 'orders'
    and al.target_entity_id = p_order_id
    and al.action = 'supplier_settlement_verified';

  if coalesce(v_existing_audit_count, 0) = 0 then
    insert into public.audit_logs(actor_profile_id, actor_role, action, target_entity_type, target_entity_id, before_data, after_data, reason)
    values
      (v_admin_profile_id, 'finance_staff', 'supplier_settlement_verified', 'orders', p_order_id, jsonb_build_object('order_status', 'payment_reported', 'payment_collection_status', 'supplier_reported', 'settlement_status', 'due', 'commission_status', 'awaiting_supplier_settlement'), jsonb_build_object('order_status', 'completed', 'payment_collection_status', 'settlement_verified', 'settlement_status', 'paid', 'commission_status', 'available', 'reference_present', v_reference is not null, 'admin_note_present', v_admin_note is not null, 'idempotency_key_present', true), 'Finance verified supplier settlement and unlocked reseller commission'),
      (v_admin_profile_id, 'finance_staff', 'platform_amount_verified_received', 'settlements', v_settlement.id, null, jsonb_build_object('platform_amount_due', v_platform_amount, 'currency_code', v_order.currency_code, 'settlement_status', 'paid'), 'Risellar platform amount verified as received from supplier settlement'),
      (v_admin_profile_id, 'finance_staff', 'reseller_commission_unlocked', 'commissions', null, null, jsonb_build_object('order_id', p_order_id, 'commission_amount', v_commission_amount, 'currency_code', v_order.currency_code, 'commission_status', 'available'), 'Reseller commission unlocked after supplier settlement verification'),
      (v_admin_profile_id, 'finance_staff', 'reseller_available_balance_credited', 'resellers', v_reseller_id, null, jsonb_build_object('order_id', p_order_id, 'credit_amount', v_commission_amount, 'currency_code', v_order.currency_code), 'Reseller available balance credited after settlement verification'),
      (v_admin_profile_id, 'finance_staff', 'order_completed', 'orders', p_order_id, null, jsonb_build_object('order_status', 'completed', 'payment_collection_status', 'settlement_verified'), 'Order completed after supplier settlement verification');
  end if;

  return query select r.order_id, r.order_number, r.order_status, r.payment_collection_status, r.settlement_status, r.commission_status, r.reseller_available_amount, r.settlement_verified_at, r.completed_at from public.admin_verify_supplier_settlement_result(p_order_id) r;
end;
$fn$;

revoke all on function public.finance_d9_actor_role(uuid) from public, anon, authenticated;
revoke all on function public.finance_d9_assert_actor() from public, anon, authenticated;
revoke all on function public.finance_d9_validate_note(text, boolean, integer) from public, anon, authenticated;
revoke all on function public.finance_d9_validate_key(text) from public, anon, authenticated;
revoke all on function public.finance_d9_source_state(public.orders, public.settlements, public.commissions) from public, anon, authenticated;
revoke all on function public.finance_d9_active_reseller_hold_amount(uuid) from public, anon, authenticated;
revoke all on function public.finance_d9_settlement_has_review_blocker(uuid) from public, anon, authenticated;
revoke all on function public.finance_d9_hold_context(uuid, uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.finance_d9_make_audit(uuid, text, text, text, uuid, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.finance_d9_assert_hold_immutable() from public, anon, authenticated;
revoke all on function public.finance_d9_block_withdrawal_paid_under_hold() from public, anon, authenticated;

revoke all on function public.finance_create_dispute_hold(uuid, uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_create_dispute_hold(uuid, uuid, text, text, text, text, text) to authenticated;
revoke all on function public.finance_release_dispute_hold(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_release_dispute_hold(uuid, text, text, text) to authenticated;
revoke all on function public.finance_cancel_dispute_hold(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_cancel_dispute_hold(uuid, text, text, text) to authenticated;
revoke all on function public.finance_review_disputed_settlement(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_review_disputed_settlement(uuid, text, text, text, text) to authenticated;
revoke all on function public.finance_hold_reseller_commission(uuid, uuid, uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_hold_reseller_commission(uuid, uuid, uuid, text, text, text, text) to authenticated;
revoke all on function public.finance_release_reseller_commission_hold(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_release_reseller_commission_hold(uuid, text, text, text) to authenticated;
revoke all on function public.finance_apply_adjustment(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_apply_adjustment(uuid, text, text, text) to authenticated;
revoke all on function public.finance_cancel_adjustment(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_cancel_adjustment(uuid, text, text, text) to authenticated;

revoke all on function public.list_finance_holds_safe(text, integer) from public, anon, authenticated;
grant execute on function public.list_finance_holds_safe(text, integer) to authenticated;
revoke all on function public.get_finance_hold_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_finance_hold_safe(uuid) to authenticated;
revoke all on function public.list_finance_adjustments_safe(text, integer) from public, anon, authenticated;
grant execute on function public.list_finance_adjustments_safe(text, integer) to authenticated;
revoke all on function public.get_finance_adjustment_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_finance_adjustment_safe(uuid) to authenticated;
revoke all on function public.get_reseller_finance_hold_impact_safe() from public, anon, authenticated;
grant execute on function public.get_reseller_finance_hold_impact_safe() to authenticated;
revoke all on function public.list_supplier_liabilities_safe(integer) from public, anon, authenticated;
grant execute on function public.list_supplier_liabilities_safe(integer) to authenticated;
revoke all on function public.get_supplier_liability_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_supplier_liability_safe(uuid) to authenticated;
revoke all on function public.get_dispute_finance_review_summary_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_dispute_finance_review_summary_safe(uuid) to authenticated;

comment on table public.finance_holds is 'D9 non-destructive finance holds for disputes/refunds. Direct browser role table access is revoked; mutations use narrow audited RPCs.';
comment on table public.finance_adjustments is 'D9 append-only accounting adjustment/liability records. Historical settlement, commission, wallet, and withdrawal records are not rewritten.';
comment on function public.finance_create_dispute_hold(uuid, uuid, text, text, text, text, text) is 'D9 finance-only hold creation. Derives targets, amount, and currency server-side; does not mutate business finance history.';
comment on function public.admin_verify_supplier_settlement(uuid, text, text, text) is 'Finance-only audited supplier settlement verification with D9 active dispute/refund/finance hold blocking before any settlement, commission, wallet, order, or payment mutation.';
