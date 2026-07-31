-- Forward safety patch for Reseller Withdrawal Phase 1.
-- The Phase 1 withdrawal balance model moves stored reseller wallet totals and
-- audit events only. It must not broadly mutate individual commission rows
-- before a dedicated withdrawal-items allocation model exists.

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
  from public.resellers r
  where r.id = public.current_verified_reseller_id()
    and r.approval_status = 'approved'
    and r.payout_status = 'active'
    and r.deleted_at is null
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
      'idempotency_key_present', true,
      'commission_row_allocation_deferred', true
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
  from public.withdrawals w
  where w.id = p_withdrawal_id
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
  from public.resellers r
  where r.id = v_withdrawal.reseller_id
  for update;

  if not found or v_reseller.commission_pending_withdrawal_amount < v_withdrawal.requested_amount then
    raise exception 'BALANCE_STATE_INCONSISTENT' using errcode = '22023';
  end if;

  update public.withdrawals w
  set withdrawal_status = 'paid',
      approved_amount = w.requested_amount,
      approved_by_profile_id = v_admin_profile_id,
      paid_by_profile_id = v_admin_profile_id,
      paid_at = now(),
      payout_reference = v_reference,
      admin_private_note = v_note,
      payout_idempotency_key = v_key,
      updated_at = now()
  where w.id = p_withdrawal_id
    and w.withdrawal_status = 'requested';

  update public.resellers r
  set commission_pending_withdrawal_amount = r.commission_pending_withdrawal_amount - v_withdrawal.requested_amount,
      commission_withdrawn_amount = r.commission_withdrawn_amount + v_withdrawal.requested_amount,
      updated_at = now()
  where r.id = v_withdrawal.reseller_id
    and r.commission_pending_withdrawal_amount >= v_withdrawal.requested_amount;

  if not found then
    raise exception 'BALANCE_STATE_INCONSISTENT' using errcode = '22023';
  end if;

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
      'idempotency_key_present', true,
      'commission_row_allocation_deferred', true
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

revoke all on function public.reseller_request_withdrawal(numeric, uuid, text) from public, anon, authenticated;
grant execute on function public.reseller_request_withdrawal(numeric, uuid, text) to authenticated;

revoke all on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) to authenticated;
