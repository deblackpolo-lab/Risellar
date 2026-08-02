-- D10: reseller liability, recovery, and future withdrawal allocation core.
-- Backend-only. No UI, provider collection, stock, order, refund, or notification
-- workflow is activated by this migration.

create table if not exists public.withdrawal_commission_allocations (
  id uuid primary key default gen_random_uuid(),
  withdrawal_id uuid not null references public.withdrawals(id) on delete restrict,
  commission_id uuid not null references public.commissions(id) on delete restrict,
  reseller_profile_id uuid not null references public.profiles(id) on delete restrict,
  allocated_amount numeric(12,2) not null,
  currency_code text not null,
  allocation_status text not null default 'reserved',
  allocated_at timestamptz not null default now(),
  released_at timestamptz,
  consumed_at timestamptz,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint withdrawal_commission_allocations_status_allowed
    check (allocation_status in ('reserved', 'consumed', 'released', 'disputed', 'cancelled')),
  constraint withdrawal_commission_allocations_amount_positive check (allocated_amount > 0),
  constraint withdrawal_commission_allocations_currency_safe
    check (currency_code = upper(trim(currency_code)) and length(currency_code) between 3 and 12),
  constraint withdrawal_commission_allocations_key_safe
    check (length(trim(idempotency_key)) between 12 and 160),
  constraint withdrawal_commission_allocations_terminal_timestamps check (
    (allocation_status = 'released' and released_at is not null)
    or (allocation_status = 'consumed' and consumed_at is not null)
    or (allocation_status not in ('released', 'consumed'))
  )
);

create table if not exists public.reseller_liabilities (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.order_disputes(id) on delete restrict,
  refund_id uuid references public.order_refunds(id) on delete restrict,
  finance_hold_id uuid references public.finance_holds(id) on delete restrict,
  finance_adjustment_id uuid references public.finance_adjustments(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid references public.order_items(id) on delete restrict,
  commission_id uuid references public.commissions(id) on delete restrict,
  reseller_profile_id uuid not null references public.profiles(id) on delete restrict,
  withdrawal_id uuid references public.withdrawals(id) on delete restrict,
  liability_type text not null,
  status text not null default 'approved',
  original_amount numeric(12,2) not null,
  outstanding_amount numeric(12,2) not null,
  recovered_amount numeric(12,2) not null default 0,
  currency_code text not null,
  source_finance_state text not null,
  recovery_policy text not null default 'no_automatic_recovery',
  approved_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  approved_at timestamptz not null default now(),
  resolved_by_profile_id uuid references public.profiles(id) on delete restrict,
  resolved_at timestamptz,
  public_note text,
  internal_note text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint reseller_liabilities_type_allowed check (
    liability_type in (
      'commission_recovery',
      'refund_responsibility',
      'duplicate_earning_correction',
      'accounting_correction',
      'withdrawal_overpayment_review'
    )
  ),
  constraint reseller_liabilities_status_allowed check (
    status in (
      'review_required',
      'approved',
      'recovery_active',
      'partially_recovered',
      'recovered',
      'waived',
      'cancelled'
    )
  ),
  constraint reseller_liabilities_policy_allowed check (
    recovery_policy in (
      'no_automatic_recovery',
      'hold_future_commission',
      'offset_future_earnings',
      'manual_repayment_required',
      'platform_absorbed',
      'waived'
    )
  ),
  constraint reseller_liabilities_amounts_safe check (
    original_amount > 0
    and outstanding_amount >= 0
    and recovered_amount >= 0
    and round(outstanding_amount + recovered_amount, 2) = round(original_amount, 2)
  ),
  constraint reseller_liabilities_currency_safe
    check (currency_code = upper(trim(currency_code)) and length(currency_code) between 3 and 12),
  constraint reseller_liabilities_key_safe check (length(trim(idempotency_key)) between 12 and 160),
  constraint reseller_liabilities_notes_safe check (
    (public_note is null or (length(public_note) <= 500 and public_note !~* '(pin|otp|password|secret|token|cvv|account number|momo|mobile money|bank)'))
    and (internal_note is null or (length(internal_note) <= 1000 and internal_note !~* '(pin|otp|password|secret|token|cvv|account number|momo|mobile money|bank)'))
  )
);

create table if not exists public.reseller_liability_recoveries (
  id uuid primary key default gen_random_uuid(),
  liability_id uuid not null references public.reseller_liabilities(id) on delete restrict,
  commission_id uuid references public.commissions(id) on delete restrict,
  withdrawal_id uuid references public.withdrawals(id) on delete restrict,
  recovery_type text not null,
  amount numeric(12,2) not null,
  currency_code text not null,
  status text not null default 'applied',
  approved_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  applied_by_profile_id uuid references public.profiles(id) on delete restrict,
  approved_at timestamptz not null default now(),
  applied_at timestamptz,
  reversed_by_recovery_id uuid references public.reseller_liability_recoveries(id) on delete restrict,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  constraint reseller_liability_recoveries_type_allowed check (
    recovery_type in (
      'future_commission_offset',
      'manual_repayment_record',
      'platform_absorption',
      'waiver',
      'correction_reversal'
    )
  ),
  constraint reseller_liability_recoveries_status_allowed
    check (status in ('proposed', 'approved', 'applied', 'cancelled', 'reversed')),
  constraint reseller_liability_recoveries_amount_positive check (amount > 0),
  constraint reseller_liability_recoveries_currency_safe
    check (currency_code = upper(trim(currency_code)) and length(currency_code) between 3 and 12),
  constraint reseller_liability_recoveries_key_safe check (length(trim(idempotency_key)) between 12 and 160)
);

alter table public.withdrawal_commission_allocations enable row level security;
alter table public.withdrawal_commission_allocations force row level security;
alter table public.reseller_liabilities enable row level security;
alter table public.reseller_liabilities force row level security;
alter table public.reseller_liability_recoveries enable row level security;
alter table public.reseller_liability_recoveries force row level security;

revoke all on public.withdrawal_commission_allocations from public, anon, authenticated;
revoke all on public.reseller_liabilities from public, anon, authenticated;
revoke all on public.reseller_liability_recoveries from public, anon, authenticated;

create unique index if not exists withdrawal_commission_allocations_key_unique
  on public.withdrawal_commission_allocations(withdrawal_id, commission_id, idempotency_key);

create unique index if not exists withdrawal_commission_allocations_active_commission_unique
  on public.withdrawal_commission_allocations(commission_id, withdrawal_id)
  where allocation_status in ('reserved', 'disputed');

create index if not exists withdrawal_commission_allocations_withdrawal_status_idx
  on public.withdrawal_commission_allocations(withdrawal_id, allocation_status, created_at desc);

create index if not exists withdrawal_commission_allocations_reseller_status_idx
  on public.withdrawal_commission_allocations(reseller_profile_id, allocation_status, created_at desc);

create unique index if not exists reseller_liabilities_idempotency_unique
  on public.reseller_liabilities(approved_by_profile_id, liability_type, idempotency_key)
  where deleted_at is null;

create unique index if not exists reseller_liabilities_active_commission_unique
  on public.reseller_liabilities(commission_id, liability_type)
  where deleted_at is null and status in ('review_required', 'approved', 'recovery_active', 'partially_recovered');

create index if not exists reseller_liabilities_reseller_status_idx
  on public.reseller_liabilities(reseller_profile_id, status, created_at desc)
  where deleted_at is null;

create unique index if not exists reseller_liability_recoveries_idempotency_unique
  on public.reseller_liability_recoveries(approved_by_profile_id, recovery_type, idempotency_key);

create index if not exists reseller_liability_recoveries_liability_status_idx
  on public.reseller_liability_recoveries(liability_id, status, created_at desc);

create or replace function public.finance_d10_validate_key(p_key text)
returns text
language plpgsql
immutable
set search_path = public
as $fn$
declare
  v_key text := nullif(trim(coalesce(p_key, '')), '');
begin
  if v_key is null or length(v_key) < 12 or length(v_key) > 160 then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = '22023';
  end if;
  return v_key;
end;
$fn$;

create or replace function public.finance_d10_validate_note(p_note text, p_max integer default 500)
returns text
language plpgsql
immutable
set search_path = public
as $fn$
declare
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if v_note is null then
    return null;
  end if;
  if length(v_note) > p_max or v_note ~* '(pin|otp|password|secret|token|cvv|account number|momo|mobile money|bank)' then
    raise exception 'INVALID_NOTE' using errcode = '22023';
  end if;
  return v_note;
end;
$fn$;

create or replace function public.finance_d10_assert_actor()
returns table(profile_id uuid, actor_role text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  return query select a.profile_id, a.actor_role from public.finance_d9_assert_actor() a;
end;
$fn$;

create or replace function public.finance_d10_commission_currency(p_commission_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select o.currency_code
  from public.commissions c
  join public.orders o on o.id = c.order_id
  where c.id = p_commission_id
  limit 1;
$$;

create or replace function public.finance_d10_active_commission_hold_amount(p_commission_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select round(coalesce(sum(fh.amount), 0), 2)
  from public.finance_holds fh
  where fh.commission_id = p_commission_id
    and fh.status = 'active'
    and fh.deleted_at is null
    and fh.hold_type in ('commission_availability_hold', 'reseller_liability_review', 'withdrawal_review_hold');
$$;

create or replace function public.finance_d10_commission_allocated_amount(p_commission_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select round(coalesce(sum(wca.allocated_amount), 0), 2)
  from public.withdrawal_commission_allocations wca
  where wca.commission_id = p_commission_id
    and wca.allocation_status in ('reserved', 'disputed', 'consumed');
$$;

create or replace function public.finance_d10_commission_offset_amount(p_commission_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select round(coalesce(sum(rlr.amount), 0), 2)
  from public.reseller_liability_recoveries rlr
  where rlr.commission_id = p_commission_id
    and rlr.recovery_type = 'future_commission_offset'
    and rlr.status = 'applied';
$$;

create or replace function public.finance_d10_commission_available_amount(p_commission_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    round(coalesce(c.commission_amount, 0), 2)
    - public.finance_d10_active_commission_hold_amount(c.id)
    - public.finance_d10_commission_allocated_amount(c.id)
    - public.finance_d10_commission_offset_amount(c.id),
    0
  )
  from public.commissions c
  where c.id = p_commission_id
    and c.commission_status = 'available';
$$;

create or replace function public.finance_d10_active_liability_outstanding_amount(p_reseller_profile_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select round(coalesce(sum(rl.outstanding_amount), 0), 2)
  from public.reseller_liabilities rl
  where rl.reseller_profile_id = p_reseller_profile_id
    and rl.deleted_at is null
    and rl.status in ('approved', 'recovery_active', 'partially_recovered')
    and rl.recovery_policy in ('offset_future_earnings', 'hold_future_commission');
$$;

create or replace function public.finance_d10_active_allocation_amount(p_reseller_profile_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select round(coalesce(sum(wca.allocated_amount), 0), 2)
  from public.withdrawal_commission_allocations wca
  where wca.reseller_profile_id = p_reseller_profile_id
    and wca.allocation_status in ('reserved', 'disputed');
$$;

create or replace function public.finance_d10_make_audit(
  p_actor_profile_id uuid,
  p_actor_role text,
  p_action text,
  p_target_entity_type text,
  p_target_entity_id uuid,
  p_after_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform public.finance_d9_make_audit(
    p_actor_profile_id,
    p_actor_role,
    p_action,
    p_target_entity_type,
    p_target_entity_id,
    null,
    p_after_data
  );
end;
$fn$;

create or replace function public.finance_d10_assert_liability_targets_immutable()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
  if old.dispute_id is distinct from new.dispute_id
    or old.refund_id is distinct from new.refund_id
    or old.finance_hold_id is distinct from new.finance_hold_id
    or old.finance_adjustment_id is distinct from new.finance_adjustment_id
    or old.order_id is distinct from new.order_id
    or old.order_item_id is distinct from new.order_item_id
    or old.commission_id is distinct from new.commission_id
    or old.reseller_profile_id is distinct from new.reseller_profile_id
    or old.withdrawal_id is distinct from new.withdrawal_id
    or old.liability_type is distinct from new.liability_type
    or old.original_amount is distinct from new.original_amount
    or old.currency_code is distinct from new.currency_code
    or old.source_finance_state is distinct from new.source_finance_state
    or old.approved_by_profile_id is distinct from new.approved_by_profile_id
    or old.idempotency_key is distinct from new.idempotency_key then
    raise exception 'LIABILITY_TARGET_IMMUTABLE' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists reseller_liabilities_targets_immutable on public.reseller_liabilities;
create trigger reseller_liabilities_targets_immutable
  before update on public.reseller_liabilities
  for each row execute function public.finance_d10_assert_liability_targets_immutable();

create or replace function public.finance_d10_assert_allocation_immutable()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
  if old.withdrawal_id is distinct from new.withdrawal_id
    or old.commission_id is distinct from new.commission_id
    or old.reseller_profile_id is distinct from new.reseller_profile_id
    or old.allocated_amount is distinct from new.allocated_amount
    or old.currency_code is distinct from new.currency_code
    or old.idempotency_key is distinct from new.idempotency_key then
    raise exception 'ALLOCATION_TARGET_IMMUTABLE' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists withdrawal_commission_allocations_immutable on public.withdrawal_commission_allocations;
create trigger withdrawal_commission_allocations_immutable
  before update on public.withdrawal_commission_allocations
  for each row execute function public.finance_d10_assert_allocation_immutable();

create or replace function public.finance_d10_block_disputed_allocation_payout()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if old.withdrawal_status is distinct from new.withdrawal_status
    and new.withdrawal_status = 'paid'
    and exists (
      select 1
      from public.withdrawal_commission_allocations wca
      where wca.withdrawal_id = new.id
        and wca.allocation_status = 'disputed'
    ) then
    raise exception 'WITHDRAWAL_BLOCKED_BY_DISPUTED_ALLOCATION' using errcode = '23514';
  end if;
  return new;
end;
$fn$;

drop trigger if exists withdrawal_disputed_allocation_payout_guard on public.withdrawals;
create trigger withdrawal_disputed_allocation_payout_guard
  before update of withdrawal_status on public.withdrawals
  for each row execute function public.finance_d10_block_disputed_allocation_payout();

revoke all on function public.finance_d10_validate_key(text) from public, anon, authenticated;
revoke all on function public.finance_d10_validate_note(text, integer) from public, anon, authenticated;
revoke all on function public.finance_d10_assert_actor() from public, anon, authenticated;
revoke all on function public.finance_d10_commission_currency(uuid) from public, anon, authenticated;
revoke all on function public.finance_d10_active_commission_hold_amount(uuid) from public, anon, authenticated;
revoke all on function public.finance_d10_commission_allocated_amount(uuid) from public, anon, authenticated;
revoke all on function public.finance_d10_commission_offset_amount(uuid) from public, anon, authenticated;
revoke all on function public.finance_d10_commission_available_amount(uuid) from public, anon, authenticated;
revoke all on function public.finance_d10_active_liability_outstanding_amount(uuid) from public, anon, authenticated;
revoke all on function public.finance_d10_active_allocation_amount(uuid) from public, anon, authenticated;
revoke all on function public.finance_d10_make_audit(uuid, text, text, text, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.finance_d10_assert_liability_targets_immutable() from public, anon, authenticated;
revoke all on function public.finance_d10_assert_allocation_immutable() from public, anon, authenticated;
revoke all on function public.finance_d10_block_disputed_allocation_payout() from public, anon, authenticated;

comment on table public.withdrawal_commission_allocations is
  'D10 future-only exact allocation between withdrawal requests and commission rows. Historical withdrawals are not guessed or backfilled.';
comment on table public.reseller_liabilities is
  'D10 reseller liability records for disputed/refunded commission recovery review. Paid withdrawals remain immutable and external collection is not automated.';
comment on table public.reseller_liability_recoveries is
  'D10 append-only liability recovery records for approved future offsets, waivers, platform absorption, and manual repayment records.';
