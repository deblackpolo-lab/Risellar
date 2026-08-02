-- D10 forward fix: keep withdrawal allocation accounting auditable without
-- triggering transactional notification outbox rows, and tighten recovery
-- idempotency so a reused key cannot mask a different commission target.

create or replace function public.finance_d10_normalize_withdrawal_audit_action()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.target_entity_type = 'withdrawals'
    and new.action = 'reseller_withdrawal_requested'
    and coalesce(new.after_data ->> 'commission_allocation_model', '') = 'future_only'
  then
    new.action := 'reseller_withdrawal_requested_allocation_reserved';
  end if;

  return new;
end;
$fn$;

drop trigger if exists finance_d10_normalize_withdrawal_audit_action_trigger on public.audit_logs;
create trigger finance_d10_normalize_withdrawal_audit_action_trigger
before insert on public.audit_logs
for each row
execute function public.finance_d10_normalize_withdrawal_audit_action();

revoke all on function public.finance_d10_normalize_withdrawal_audit_action() from public, anon, authenticated;

create or replace function public.finance_apply_future_commission_offset(
  p_commission_id uuid,
  p_idempotency_key text
)
returns table (
  liability_id uuid,
  recovery_id uuid,
  commission_id uuid,
  amount numeric,
  outstanding_amount numeric,
  recovered_amount numeric,
  applied boolean
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_commission public.commissions%rowtype;
  v_order public.orders%rowtype;
  v_reseller_profile_id uuid;
  v_available numeric(12,2);
  v_liability public.reseller_liabilities%rowtype;
  v_amount numeric(12,2);
  v_recovery_id uuid;
  v_existing public.reseller_liability_recoveries%rowtype;
begin
  select * into v_actor from public.finance_d10_assert_actor();

  select * into v_commission
  from public.commissions c
  where c.id = p_commission_id
    and c.commission_status = 'available'
  for update;

  if not found then
    raise exception 'COMMISSION_NOT_AVAILABLE' using errcode = '22023';
  end if;

  select * into v_order from public.orders o where o.id = v_commission.order_id for update;

  select r.profile_id
  into v_reseller_profile_id
  from public.resellers r
  where r.id = v_commission.reseller_id
    and r.deleted_at is null
  for update;

  if v_reseller_profile_id is null then
    raise exception 'RESELLER_NOT_FOUND' using errcode = '22023';
  end if;

  select * into v_existing
  from public.reseller_liability_recoveries rlr
  where rlr.approved_by_profile_id = v_actor.profile_id
    and rlr.recovery_type = 'future_commission_offset'
    and rlr.idempotency_key = v_key
    and rlr.status = 'applied'
  for update;

  if found then
    if v_existing.commission_id is distinct from p_commission_id then
      raise exception 'CONFLICTING_RECOVERY_RETRY' using errcode = '23505';
    end if;

    select * into v_liability
    from public.reseller_liabilities rl
    where rl.id = v_existing.liability_id;

    return query
    select v_existing.liability_id, v_existing.id, v_existing.commission_id, v_existing.amount, v_liability.outstanding_amount, v_liability.recovered_amount, false;
    return;
  end if;

  v_available := public.finance_d10_commission_available_amount(v_commission.id);
  if v_available <= 0 then
    raise exception 'NO_OFFSETTABLE_COMMISSION_AMOUNT' using errcode = '23514';
  end if;

  select * into v_liability
  from public.reseller_liabilities rl
  where rl.reseller_profile_id = v_reseller_profile_id
    and rl.deleted_at is null
    and rl.status in ('approved', 'recovery_active', 'partially_recovered')
    and rl.recovery_policy = 'offset_future_earnings'
    and rl.currency_code = coalesce(v_order.currency_code, public.finance_d10_commission_currency(v_commission.id), 'GHS')
    and rl.outstanding_amount > 0
  order by rl.approved_at asc, rl.id::text asc
  limit 1
  for update;

  if not found then
    raise exception 'NO_ACTIVE_OFFSET_LIABILITY' using errcode = '22023';
  end if;

  v_amount := round(least(v_available, v_liability.outstanding_amount), 2);
  if v_amount <= 0 then
    raise exception 'INVALID_OFFSET_AMOUNT' using errcode = '23514';
  end if;

  insert into public.reseller_liability_recoveries(
    liability_id,
    commission_id,
    recovery_type,
    amount,
    currency_code,
    status,
    approved_by_profile_id,
    applied_by_profile_id,
    approved_at,
    applied_at,
    idempotency_key
  )
  values (
    v_liability.id,
    v_commission.id,
    'future_commission_offset',
    v_amount,
    v_liability.currency_code,
    'applied',
    v_actor.profile_id,
    v_actor.profile_id,
    now(),
    now(),
    v_key
  )
  returning id into v_recovery_id;

  update public.reseller_liabilities rl
  set recovered_amount = round(rl.recovered_amount + v_amount, 2),
      outstanding_amount = round(rl.outstanding_amount - v_amount, 2),
      status = case
        when round(rl.outstanding_amount - v_amount, 2) = 0 then 'recovered'
        else 'partially_recovered'
      end,
      resolved_by_profile_id = case when round(rl.outstanding_amount - v_amount, 2) = 0 then v_actor.profile_id else rl.resolved_by_profile_id end,
      resolved_at = case when round(rl.outstanding_amount - v_amount, 2) = 0 then now() else rl.resolved_at end,
      updated_at = now()
  where rl.id = v_liability.id
    and rl.outstanding_amount >= v_amount;

  if not found then
    raise exception 'LIABILITY_RECOVERY_OVERFLOW' using errcode = '23514';
  end if;

  perform public.finance_d10_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'reseller_liability_recovery_applied',
    'reseller_liability_recoveries',
    v_recovery_id,
    jsonb_build_object('amount', v_amount, 'currency_code', v_liability.currency_code, 'recovery_type', 'future_commission_offset')
  );

  return query
  select rl.id, v_recovery_id, v_commission.id, v_amount, rl.outstanding_amount, rl.recovered_amount, true
  from public.reseller_liabilities rl
  where rl.id = v_liability.id;
end;
$fn$;

revoke all on function public.finance_apply_future_commission_offset(uuid, text) from public, anon, authenticated;
grant execute on function public.finance_apply_future_commission_offset(uuid, text) to authenticated;

comment on function public.finance_d10_normalize_withdrawal_audit_action() is
  'D10: distinguishes future-only withdrawal allocation audit rows from legacy withdrawal-request notification events.';
