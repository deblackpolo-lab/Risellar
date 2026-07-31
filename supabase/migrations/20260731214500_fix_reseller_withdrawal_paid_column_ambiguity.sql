-- Forward fix for Reseller Withdrawal Phase 1.
-- Qualifies columns in admin_mark_reseller_withdrawal_paid to avoid PL/pgSQL output-column ambiguity.

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

revoke all on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) to authenticated;
