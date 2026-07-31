-- Reseller Withdrawal Phase 1: safe request and admin manual payout RPC foundation.
-- This migration does not integrate any external payout provider and does not mutate orders,
-- stock reservations, supplier payouts, commissions amounts, settlements, payments, or delivery flows.

alter table public.resellers
  add column if not exists commission_pending_withdrawal_amount numeric(12,2) not null default 0,
  add column if not exists commission_withdrawn_amount numeric(12,2) not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'resellers_commission_pending_withdrawal_nonnegative'
      and conrelid = 'public.resellers'::regclass
  ) then
    alter table public.resellers
      add constraint resellers_commission_pending_withdrawal_nonnegative
      check (commission_pending_withdrawal_amount >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'resellers_commission_withdrawn_nonnegative'
      and conrelid = 'public.resellers'::regclass
  ) then
    alter table public.resellers
      add constraint resellers_commission_withdrawn_nonnegative
      check (commission_withdrawn_amount >= 0);
  end if;
end;
$$;

create table if not exists public.reseller_payout_accounts (
  id uuid primary key default gen_random_uuid(),
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  payout_method text not null default 'mobile_money',
  account_name text not null,
  mobile_money_network text,
  phone_number text,
  bank_name text,
  account_number text,
  is_default boolean not null default false,
  account_status public.account_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint reseller_payout_accounts_method_check check (payout_method in ('mobile_money', 'bank')),
  constraint reseller_payout_accounts_momo_network_check check (
    mobile_money_network is null
    or mobile_money_network in ('mtn_momo', 'telecel_cash', 'airteltigo_money')
  ),
  constraint reseller_payout_accounts_safe_phone_check check (phone_number is null or phone_number ~ '^[+0-9 ()-]{7,32}$'),
  constraint reseller_payout_accounts_no_secret_account_check check (
    coalesce(phone_number, '') !~* '(pin|otp|password|secret|token|cvv)'
    and coalesce(account_number, '') !~* '(pin|otp|password|secret|token|cvv)'
  )
);

alter table public.reseller_payout_accounts enable row level security;
alter table public.reseller_payout_accounts force row level security;

create index if not exists reseller_payout_accounts_reseller_status_idx
  on public.reseller_payout_accounts(reseller_id, account_status)
  where deleted_at is null;

create unique index if not exists reseller_payout_accounts_one_default_active_idx
  on public.reseller_payout_accounts(reseller_id)
  where is_default is true and account_status = 'active' and deleted_at is null;

drop policy if exists "reseller_payout_accounts_select_owner_or_finance" on public.reseller_payout_accounts;
create policy "reseller_payout_accounts_select_owner_or_finance"
  on public.reseller_payout_accounts for select
  using (
    public.is_reseller_owner(reseller_id)
    or public.current_finance_admin_profile_id() is not null
  );

alter table public.withdrawals
  add column if not exists payout_account_id uuid references public.reseller_payout_accounts(id) on delete restrict,
  add column if not exists currency_code text not null default 'GHS',
  add column if not exists request_reference text,
  add column if not exists request_idempotency_key text,
  add column if not exists paid_at timestamptz,
  add column if not exists payout_reference text,
  add column if not exists admin_private_note text,
  add column if not exists payout_idempotency_key text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'withdrawals_currency_code_check'
      and conrelid = 'public.withdrawals'::regclass
  ) then
    alter table public.withdrawals
      add constraint withdrawals_currency_code_check
      check (currency_code = 'GHS');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'withdrawals_reference_safe_check'
      and conrelid = 'public.withdrawals'::regclass
  ) then
    alter table public.withdrawals
      add constraint withdrawals_reference_safe_check
      check (
        coalesce(request_reference, '') !~* '(pin|otp|password|secret|token|cvv)'
        and coalesce(payout_reference, '') !~* '(pin|otp|password|secret|token|cvv)'
        and coalesce(admin_private_note, '') !~* '(pin|otp|password|secret|token|cvv)'
      );
  end if;
end;
$$;

create unique index if not exists withdrawals_request_idempotency_unique
  on public.withdrawals(request_idempotency_key)
  where request_idempotency_key is not null;

create unique index if not exists withdrawals_payout_idempotency_unique
  on public.withdrawals(payout_idempotency_key)
  where payout_idempotency_key is not null;

create unique index if not exists withdrawals_payout_reference_unique
  on public.withdrawals(payout_reference)
  where payout_reference is not null and withdrawal_status = 'paid';

create unique index if not exists withdrawals_one_pending_per_reseller_idx
  on public.withdrawals(reseller_id)
  where withdrawal_status = 'requested';

create index if not exists withdrawals_reseller_created_idx
  on public.withdrawals(reseller_id, created_at desc);

create or replace function public.mask_payout_value(p_value text)
returns text
language sql
immutable
as $$
  select case
    when nullif(trim(coalesce(p_value, '')), '') is null then null
    when length(regexp_replace(p_value, '\D', '', 'g')) <= 4 then repeat('*', greatest(length(p_value), 4))
    else concat('***', right(regexp_replace(p_value, '\D', '', 'g'), 4))
  end;
$$;

create or replace function public.reseller_withdrawal_minimum_amount()
returns numeric
language sql
immutable
as $$
  select 10.00::numeric;
$$;

create or replace function public.admin_can_manage_reseller_withdrawals()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_finance_admin_profile_id() is not null;
$$;

create or replace function public.reseller_upsert_payout_account(
  p_account_name text,
  p_mobile_money_network text,
  p_phone_number text,
  p_idempotency_key text default null
)
returns table (
  payout_account_id uuid,
  payout_method text,
  account_name text,
  mobile_money_network text,
  phone_number_masked text,
  is_default boolean,
  account_status text
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_account_id uuid;
  v_account_name text := nullif(trim(coalesce(p_account_name, '')), '');
  v_network text := nullif(trim(coalesce(p_mobile_money_network, '')), '');
  v_phone text := nullif(trim(coalesce(p_phone_number, '')), '');
begin
  v_reseller_id := public.current_verified_reseller_id();

  if v_account_name is null or length(v_account_name) > 120 then
    raise exception 'PAYOUT_ACCOUNT_REQUIRED' using errcode = '22023';
  end if;

  if v_network is null or v_network not in ('mtn_momo', 'telecel_cash', 'airteltigo_money') then
    raise exception 'PAYOUT_ACCOUNT_REQUIRED' using errcode = '22023';
  end if;

  if v_phone is null or length(v_phone) > 32 or v_phone !~ '^[+0-9 ()-]{7,32}$' then
    raise exception 'PAYOUT_ACCOUNT_REQUIRED' using errcode = '22023';
  end if;

  update public.reseller_payout_accounts
  set is_default = false,
      updated_at = now()
  where reseller_id = v_reseller_id
    and deleted_at is null
    and is_default is true;

  insert into public.reseller_payout_accounts(
    reseller_id,
    payout_method,
    account_name,
    mobile_money_network,
    phone_number,
    is_default,
    account_status
  )
  values (
    v_reseller_id,
    'mobile_money',
    v_account_name,
    v_network,
    v_phone,
    true,
    'active'
  )
  returning id into v_account_id;

  perform public.create_audit_log_entry(
    'reseller_payout_account_saved',
    'reseller_payout_accounts',
    v_account_id,
    'reseller_saved_withdrawal_account',
    null,
    jsonb_build_object(
      'reseller_id', v_reseller_id,
      'payout_method', 'mobile_money',
      'mobile_money_network', v_network,
      'phone_masked', public.mask_payout_value(v_phone),
      'idempotency_key_present', p_idempotency_key is not null
    )
  );

  return query
  select
    a.id,
    a.payout_method,
    a.account_name,
    a.mobile_money_network,
    public.mask_payout_value(a.phone_number),
    a.is_default,
    a.account_status::text
  from public.reseller_payout_accounts a
  where a.id = v_account_id;
end;
$fn$;

create or replace function public.list_reseller_payout_accounts_safe()
returns table (
  payout_account_id uuid,
  payout_method text,
  account_name text,
  mobile_money_network text,
  phone_number_masked text,
  is_default boolean,
  account_status text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
begin
  v_reseller_id := public.current_verified_reseller_id();

  return query
  select
    a.id,
    a.payout_method,
    a.account_name,
    a.mobile_money_network,
    public.mask_payout_value(a.phone_number),
    a.is_default,
    a.account_status::text
  from public.reseller_payout_accounts a
  where a.reseller_id = v_reseller_id
    and a.account_status = 'active'
    and a.deleted_at is null
  order by a.is_default desc, a.created_at desc;
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
begin
  v_reseller_id := public.current_verified_reseller_id();

  return query
  select
    r.id,
    'GHS'::text,
    r.commission_pending_amount,
    r.commission_available_amount,
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

create or replace function public.list_reseller_withdrawals_safe(p_limit integer default 25)
returns table (
  withdrawal_id uuid,
  request_reference text,
  requested_amount numeric,
  currency_code text,
  withdrawal_status text,
  payout_method text,
  payout_account_name text,
  payout_account_masked text,
  requested_at timestamptz,
  paid_at timestamptz,
  payout_reference_present boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
begin
  v_reseller_id := public.current_verified_reseller_id();

  return query
  select
    w.id,
    w.request_reference,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    coalesce(a.payout_method, w.provider),
    coalesce(a.account_name, w.account_name),
    coalesce(public.mask_payout_value(a.phone_number), w.account_number_masked),
    w.created_at,
    w.paid_at,
    w.payout_reference is not null
  from public.withdrawals w
  left join public.reseller_payout_accounts a on a.id = w.payout_account_id
  where w.reseller_id = v_reseller_id
  order by w.created_at desc
  limit greatest(1, least(coalesce(p_limit, 25), 50));
end;
$fn$;

create or replace function public.get_reseller_withdrawal_safe(p_withdrawal_id uuid)
returns table (
  withdrawal_id uuid,
  request_reference text,
  requested_amount numeric,
  currency_code text,
  withdrawal_status text,
  payout_method text,
  payout_account_name text,
  payout_account_masked text,
  requested_at timestamptz,
  paid_at timestamptz,
  payout_reference_present boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
begin
  v_reseller_id := public.current_verified_reseller_id();

  return query
  select *
  from public.list_reseller_withdrawals_safe(50) rw
  where rw.withdrawal_id = p_withdrawal_id;
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

  select *
  into v_existing
  from public.withdrawals
  where request_idempotency_key = v_key
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
      r.commission_available_amount,
      r.commission_pending_withdrawal_amount,
      r.commission_withdrawn_amount
    from public.withdrawals w
    join public.resellers r on r.id = w.reseller_id
    where w.id = v_existing.id;
    return;
  end if;

  select *
  into v_reseller
  from public.resellers
  where id = public.current_verified_reseller_id()
    and approval_status = 'approved'
    and payout_status = 'active'
    and deleted_at is null
  for update;

  if not found then
    raise exception 'RESELLER_REQUIRED' using errcode = '42501';
  end if;

  perform 1
  from public.withdrawals w
  where w.reseller_id = v_reseller.id
    and w.withdrawal_status = 'requested'
  for update;

  if found then
    raise exception 'WITHDRAWAL_ALREADY_PENDING' using errcode = '23505';
  end if;

  select *
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

  if v_reseller.commission_available_amount < v_amount then
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
    and r.commission_available_amount >= v_amount;

  if not found then
    raise exception 'INSUFFICIENT_AVAILABLE_BALANCE' using errcode = '22023';
  end if;

  update public.commissions c
  set commission_status = 'withdrawal_requested',
      withdrawal_id = v_withdrawal_id,
      updated_at = now()
  where c.reseller_id = v_reseller.id
    and c.commission_status = 'available'
    and c.withdrawal_id is null
    and c.available_at is not null
    and c.id in (
      select c2.id
      from public.commissions c2
      where c2.reseller_id = v_reseller.id
        and c2.commission_status = 'available'
        and c2.withdrawal_id is null
        and c2.available_at is not null
      order by c2.available_at asc, c2.id::text asc
    );

  perform public.create_audit_log_entry(
    'reseller_withdrawal_requested',
    'withdrawals',
    v_withdrawal_id,
    'reseller_reserved_available_commission',
    jsonb_build_object(
      'available_balance', v_reseller.commission_available_amount,
      'pending_withdrawal_balance', v_reseller.commission_pending_withdrawal_amount
    ),
    jsonb_build_object(
      'requested_amount', v_amount,
      'currency_code', 'GHS',
      'payout_account_masked', public.mask_payout_value(coalesce(v_account.phone_number, v_account.account_number)),
      'idempotency_key_present', true
    )
  );

  return query
  select
    w.id,
    w.request_reference,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    r.commission_available_amount,
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount
  from public.withdrawals w
  join public.resellers r on r.id = w.reseller_id
  where w.id = v_withdrawal_id;
end;
$fn$;

create or replace function public.list_admin_reseller_withdrawals_safe(
  p_status text default 'requested',
  p_limit integer default 50
)
returns table (
  withdrawal_id uuid,
  request_reference text,
  reseller_display_name text,
  reseller_email_masked text,
  requested_amount numeric,
  currency_code text,
  withdrawal_status text,
  payout_method text,
  payout_account_name text,
  payout_account_masked text,
  requested_at timestamptz,
  paid_at timestamptz,
  payout_reference_present boolean,
  can_mark_paid boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
begin
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    w.id,
    w.request_reference,
    coalesce(rs.display_name, p.full_name, 'Reseller'),
    case
      when p.email is null then null
      else concat(left(p.email, 2), '***@', split_part(p.email, '@', 2))
    end,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    coalesce(a.payout_method, w.provider),
    coalesce(a.account_name, w.account_name),
    coalesce(public.mask_payout_value(a.phone_number), w.account_number_masked),
    w.created_at,
    w.paid_at,
    w.payout_reference is not null,
    w.withdrawal_status = 'requested'
  from public.withdrawals w
  join public.resellers r on r.id = w.reseller_id
  join public.profiles p on p.id = r.profile_id
  left join public.reseller_shops rs on rs.reseller_id = r.id and rs.deleted_at is null
  left join public.reseller_payout_accounts a on a.id = w.payout_account_id
  where (p_status is null or w.withdrawal_status::text = p_status)
  order by w.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$fn$;

create or replace function public.get_admin_reseller_withdrawal_safe(p_withdrawal_id uuid)
returns table (
  withdrawal_id uuid,
  request_reference text,
  reseller_display_name text,
  reseller_email_masked text,
  requested_amount numeric,
  currency_code text,
  withdrawal_status text,
  payout_method text,
  payout_account_name text,
  payout_account_masked text,
  requested_at timestamptz,
  paid_at timestamptz,
  payout_reference_present boolean,
  can_mark_paid boolean,
  reseller_available_amount numeric,
  reseller_pending_withdrawal_amount numeric,
  reseller_withdrawn_amount numeric
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
begin
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  select
    w.id,
    w.request_reference,
    coalesce(rs.display_name, p.full_name, 'Reseller'),
    case
      when p.email is null then null
      else concat(left(p.email, 2), '***@', split_part(p.email, '@', 2))
    end,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    coalesce(a.payout_method, w.provider),
    coalesce(a.account_name, w.account_name),
    coalesce(public.mask_payout_value(a.phone_number), w.account_number_masked),
    w.created_at,
    w.paid_at,
    w.payout_reference is not null,
    w.withdrawal_status = 'requested',
    r.commission_available_amount,
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount
  from public.withdrawals w
  join public.resellers r on r.id = w.reseller_id
  join public.profiles p on p.id = r.profile_id
  left join public.reseller_shops rs on rs.reseller_id = r.id and rs.deleted_at is null
  left join public.reseller_payout_accounts a on a.id = w.payout_account_id
  where w.id = p_withdrawal_id;
end;
$fn$;

create or replace function public.admin_mark_reseller_withdrawal_paid(
  p_withdrawal_id uuid,
  p_payout_reference text,
  p_admin_note text default null,
  p_idempotency_key text default null
)
returns table (
  withdrawal_id uuid,
  request_reference text,
  requested_amount numeric,
  currency_code text,
  withdrawal_status text,
  paid_at timestamptz,
  pending_withdrawal_amount numeric,
  withdrawn_amount numeric
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
  v_withdrawal public.withdrawals%rowtype;
  v_reseller public.resellers%rowtype;
  v_reference text := nullif(trim(coalesce(p_payout_reference, '')), '');
  v_note text := nullif(trim(coalesce(p_admin_note, '')), '');
  v_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
begin
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  if p_withdrawal_id is null then
    raise exception 'WITHDRAWAL_NOT_FOUND' using errcode = '22023';
  end if;

  if v_reference is null or length(v_reference) > 100 then
    raise exception 'PAYOUT_REFERENCE_REQUIRED' using errcode = '22023';
  end if;

  if v_reference ~* '(pin|otp|password|secret|token|cvv)' then
    raise exception 'PAYOUT_REFERENCE_REQUIRED' using errcode = '22023';
  end if;

  if v_note is not null and (length(v_note) > 500 or v_note ~* '(pin|otp|password|secret|token|cvv)') then
    raise exception 'FIELD_TOO_LONG' using errcode = '22023';
  end if;

  if v_key is null or length(v_key) > 140 then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = '22023';
  end if;

  select *
  into v_withdrawal
  from public.withdrawals
  where id = p_withdrawal_id
  for update;

  if not found then
    raise exception 'WITHDRAWAL_NOT_FOUND' using errcode = '22023';
  end if;

  if v_withdrawal.withdrawal_status = 'paid' then
    if v_withdrawal.payout_idempotency_key = v_key
       and v_withdrawal.payout_reference = v_reference
       and coalesce(v_withdrawal.admin_private_note, '') = coalesce(v_note, '') then
      return query
      select
        w.id,
        w.request_reference,
        w.requested_amount,
        w.currency_code,
        w.withdrawal_status::text,
        w.paid_at,
        r.commission_pending_withdrawal_amount,
        r.commission_withdrawn_amount
      from public.withdrawals w
      join public.resellers r on r.id = w.reseller_id
      where w.id = p_withdrawal_id;
      return;
    end if;

    raise exception 'CONFLICTING_PAYOUT_RETRY' using errcode = '23505';
  end if;

  if v_withdrawal.withdrawal_status <> 'requested' then
    raise exception 'WITHDRAWAL_NOT_PENDING' using errcode = '22023';
  end if;

  if v_withdrawal.payout_idempotency_key is not null and v_withdrawal.payout_idempotency_key <> v_key then
    raise exception 'CONFLICTING_PAYOUT_RETRY' using errcode = '23505';
  end if;

  select *
  into v_reseller
  from public.resellers
  where id = v_withdrawal.reseller_id
  for update;

  if not found or v_reseller.commission_pending_withdrawal_amount < v_withdrawal.requested_amount then
    raise exception 'BALANCE_STATE_INCONSISTENT' using errcode = '22023';
  end if;

  update public.withdrawals
  set withdrawal_status = 'paid',
      approved_amount = requested_amount,
      approved_by_profile_id = v_admin_profile_id,
      paid_by_profile_id = v_admin_profile_id,
      paid_at = now(),
      payout_reference = v_reference,
      admin_private_note = v_note,
      payout_idempotency_key = v_key,
      updated_at = now()
  where id = p_withdrawal_id
    and withdrawal_status = 'requested';

  update public.resellers r
  set commission_pending_withdrawal_amount = r.commission_pending_withdrawal_amount - v_withdrawal.requested_amount,
      commission_withdrawn_amount = r.commission_withdrawn_amount + v_withdrawal.requested_amount,
      updated_at = now()
  where r.id = v_withdrawal.reseller_id
    and r.commission_pending_withdrawal_amount >= v_withdrawal.requested_amount;

  if not found then
    raise exception 'BALANCE_STATE_INCONSISTENT' using errcode = '22023';
  end if;

  update public.commissions c
  set commission_status = 'paid',
      updated_at = now()
  where c.withdrawal_id = p_withdrawal_id
    and c.commission_status = 'withdrawal_requested';

  perform public.create_audit_log_entry(
    'reseller_withdrawal_paid',
    'withdrawals',
    p_withdrawal_id,
    'finance_admin_recorded_manual_payout',
    jsonb_build_object(
      'pending_withdrawal_balance', v_reseller.commission_pending_withdrawal_amount,
      'withdrawn_balance', v_reseller.commission_withdrawn_amount
    ),
    jsonb_build_object(
      'requested_amount', v_withdrawal.requested_amount,
      'currency_code', v_withdrawal.currency_code,
      'payout_reference_present', true,
      'admin_note_present', v_note is not null,
      'idempotency_key_present', true
    )
  );

  return query
  select
    w.id,
    w.request_reference,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    w.paid_at,
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount
  from public.withdrawals w
  join public.resellers r on r.id = w.reseller_id
  where w.id = p_withdrawal_id;
end;
$fn$;

revoke all on function public.mask_payout_value(text) from public, anon, authenticated;
grant execute on function public.mask_payout_value(text) to authenticated;

revoke all on function public.reseller_withdrawal_minimum_amount() from public, anon, authenticated;
grant execute on function public.reseller_withdrawal_minimum_amount() to authenticated;

revoke all on function public.admin_can_manage_reseller_withdrawals() from public, anon, authenticated;
grant execute on function public.admin_can_manage_reseller_withdrawals() to authenticated;

revoke all on function public.reseller_upsert_payout_account(text, text, text, text) from public, anon, authenticated;
grant execute on function public.reseller_upsert_payout_account(text, text, text, text) to authenticated;

revoke all on function public.list_reseller_payout_accounts_safe() from public, anon, authenticated;
grant execute on function public.list_reseller_payout_accounts_safe() to authenticated;

revoke all on function public.get_reseller_wallet_safe() from public, anon, authenticated;
grant execute on function public.get_reseller_wallet_safe() to authenticated;

revoke all on function public.list_reseller_withdrawals_safe(integer) from public, anon, authenticated;
grant execute on function public.list_reseller_withdrawals_safe(integer) to authenticated;

revoke all on function public.get_reseller_withdrawal_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_reseller_withdrawal_safe(uuid) to authenticated;

revoke all on function public.reseller_request_withdrawal(numeric, uuid, text) from public, anon, authenticated;
grant execute on function public.reseller_request_withdrawal(numeric, uuid, text) to authenticated;

revoke all on function public.list_admin_reseller_withdrawals_safe(text, integer) from public, anon, authenticated;
grant execute on function public.list_admin_reseller_withdrawals_safe(text, integer) to authenticated;

revoke all on function public.get_admin_reseller_withdrawal_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_admin_reseller_withdrawal_safe(uuid) to authenticated;

revoke all on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) to authenticated;

comment on function public.reseller_request_withdrawal(numeric, uuid, text)
  is 'Reserves reseller available commission for a manual withdrawal request. Does not send money or call a payout provider.';

comment on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text)
  is 'Finance-staff-only manual payout recorder. Marks an already reserved reseller withdrawal paid after external manual payment.';
