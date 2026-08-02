-- D10: finance-only reseller liability/recovery RPCs and future withdrawal allocation integration.
-- Historical withdrawals remain unallocated unless a future allocation row proves attribution.

create or replace function public.finance_d10_liability_source_state(p_commission public.commissions)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_withdrawal_status text;
begin
  select w.withdrawal_status::text
  into v_withdrawal_status
  from public.withdrawal_commission_allocations wca
  join public.withdrawals w on w.id = wca.withdrawal_id
  where wca.commission_id = p_commission.id
    and wca.allocation_status in ('reserved', 'disputed', 'consumed')
  order by wca.created_at desc, wca.id::text desc
  limit 1;

  if v_withdrawal_status = 'paid' then
    return 'withdrawal_paid';
  end if;
  if v_withdrawal_status = 'requested' then
    return 'withdrawal_requested';
  end if;
  if p_commission.commission_status = 'available' then
    return 'commission_available';
  end if;
  if p_commission.commission_status in ('awaiting_supplier_settlement', 'held', 'disputed') then
    return 'commission_locked';
  end if;
  if p_commission.commission_status = 'paid' then
    return 'historical_paid_unallocated';
  end if;

  return 'review_required';
end;
$fn$;

create or replace function public.finance_d10_proven_withdrawal_for_commission(p_commission_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select wca.withdrawal_id
  from public.withdrawal_commission_allocations wca
  join public.withdrawals w on w.id = wca.withdrawal_id
  where wca.commission_id = p_commission_id
    and wca.allocation_status in ('reserved', 'disputed', 'consumed')
    and w.withdrawal_status in ('requested', 'paid')
  order by
    case when w.withdrawal_status = 'paid' then 1 else 0 end desc,
    wca.created_at desc,
    wca.id::text desc
  limit 1;
$$;

create or replace function public.finance_approve_reseller_liability(
  p_dispute_id uuid,
  p_refund_id uuid,
  p_commission_id uuid,
  p_liability_type text,
  p_recovery_policy text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  liability_id uuid,
  status text,
  recovery_policy text,
  original_amount numeric,
  outstanding_amount numeric,
  recovered_amount numeric,
  currency_code text,
  source_finance_state text,
  created boolean
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_type text := nullif(trim(coalesce(p_liability_type, '')), '');
  v_policy text := coalesce(nullif(trim(coalesce(p_recovery_policy, '')), ''), 'no_automatic_recovery');
  v_public_note text := public.finance_d10_validate_note(p_public_note, 500);
  v_internal_note text := public.finance_d10_validate_note(p_internal_note, 1000);
  v_commission public.commissions%rowtype;
  v_dispute public.order_disputes%rowtype;
  v_refund public.order_refunds%rowtype;
  v_order public.orders%rowtype;
  v_item public.order_items%rowtype;
  v_reseller_profile_id uuid;
  v_amount numeric(12,2);
  v_currency text;
  v_source_state text;
  v_withdrawal_id uuid;
  v_existing public.reseller_liabilities%rowtype;
  v_id uuid;
  v_fingerprint text;
begin
  select * into v_actor from public.finance_d10_assert_actor();

  if v_type not in ('commission_recovery', 'refund_responsibility', 'duplicate_earning_correction', 'accounting_correction', 'withdrawal_overpayment_review') then
    raise exception 'INVALID_LIABILITY_TYPE' using errcode = '22023';
  end if;

  if v_policy not in ('no_automatic_recovery', 'hold_future_commission', 'offset_future_earnings', 'manual_repayment_required', 'platform_absorbed', 'waived') then
    raise exception 'INVALID_RECOVERY_POLICY' using errcode = '22023';
  end if;

  if v_policy in ('manual_repayment_required', 'offset_future_earnings') then
    -- D10 records approval only. External collection is not implemented, and
    -- future offset must be explicitly enabled through its own RPC.
    v_policy := 'no_automatic_recovery';
  end if;

  select * into v_commission
  from public.commissions c
  where c.id = p_commission_id
  for update;

  if not found then
    raise exception 'COMMISSION_NOT_FOUND' using errcode = '22023';
  end if;

  select * into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
  for update;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '22023';
  end if;

  if p_refund_id is not null then
    select * into v_refund
    from public.order_refunds rf
    where rf.id = p_refund_id
      and rf.deleted_at is null
    for update;

    if not found then
      raise exception 'REFUND_NOT_FOUND' using errcode = '22023';
    end if;
  end if;

  select * into v_order
  from public.orders o
  where o.id = v_commission.order_id
    and o.deleted_at is null
  for update;

  if not found or v_dispute.order_id <> v_order.id then
    raise exception 'LIABILITY_SCOPE_MISMATCH' using errcode = '23514';
  end if;

  select * into v_item
  from public.order_items oi
  where oi.id = v_commission.order_item_id
    and oi.order_id = v_order.id
  for update;

  if not found then
    raise exception 'ORDER_ITEM_NOT_FOUND' using errcode = '22023';
  end if;

  if p_refund_id is not null and v_refund.order_id <> v_order.id then
    raise exception 'REFUND_SCOPE_MISMATCH' using errcode = '23514';
  end if;

  select r.profile_id
  into v_reseller_profile_id
  from public.resellers r
  where r.id = v_commission.reseller_id
    and r.deleted_at is null
  for update;

  if v_reseller_profile_id is null then
    raise exception 'RESELLER_NOT_FOUND' using errcode = '22023';
  end if;

  v_amount := round(least(v_commission.commission_amount, coalesce(v_item.commission_amount, v_commission.commission_amount)), 2);
  if v_amount <= 0 then
    raise exception 'INVALID_LIABILITY_AMOUNT' using errcode = '23514';
  end if;

  v_currency := coalesce(v_order.currency_code, public.finance_d10_commission_currency(v_commission.id), 'GHS');
  v_source_state := public.finance_d10_liability_source_state(v_commission);
  v_withdrawal_id := public.finance_d10_proven_withdrawal_for_commission(v_commission.id);

  if v_source_state = 'historical_paid_unallocated' then
    v_withdrawal_id := null;
  end if;

  v_fingerprint := md5(jsonb_build_object(
    'dispute_id', p_dispute_id,
    'refund_id', p_refund_id,
    'commission_id', p_commission_id,
    'liability_type', v_type,
    'recovery_policy', v_policy,
    'amount', v_amount,
    'currency_code', v_currency
  )::text);

  select * into v_existing
  from public.reseller_liabilities rl
  where rl.approved_by_profile_id = v_actor.profile_id
    and rl.liability_type = v_type
    and rl.idempotency_key = v_key
    and rl.deleted_at is null
  for update;

  if found then
    if v_existing.dispute_id <> p_dispute_id
      or v_existing.refund_id is distinct from p_refund_id
      or v_existing.commission_id is distinct from p_commission_id
      or v_existing.original_amount <> v_amount
      or v_existing.currency_code <> v_currency then
      raise exception 'CONFLICTING_LIABILITY_RETRY' using errcode = '23505';
    end if;

    return query
    select
      v_existing.id,
      v_existing.status,
      v_existing.recovery_policy,
      v_existing.original_amount,
      v_existing.outstanding_amount,
      v_existing.recovered_amount,
      v_existing.currency_code,
      v_existing.source_finance_state,
      false;
    return;
  end if;

  if exists (
    select 1
    from public.reseller_liabilities rl
    where rl.commission_id = v_commission.id
      and rl.liability_type = v_type
      and rl.deleted_at is null
      and rl.status in ('review_required', 'approved', 'recovery_active', 'partially_recovered')
  ) then
    raise exception 'ACTIVE_LIABILITY_EXISTS' using errcode = '23505';
  end if;

  insert into public.reseller_liabilities(
    dispute_id,
    refund_id,
    order_id,
    order_item_id,
    commission_id,
    reseller_profile_id,
    withdrawal_id,
    liability_type,
    status,
    original_amount,
    outstanding_amount,
    recovered_amount,
    currency_code,
    source_finance_state,
    recovery_policy,
    approved_by_profile_id,
    public_note,
    internal_note,
    idempotency_key
  )
  values (
    p_dispute_id,
    p_refund_id,
    v_order.id,
    v_item.id,
    v_commission.id,
    v_reseller_profile_id,
    v_withdrawal_id,
    v_type,
    case when v_source_state in ('historical_paid_unallocated', 'review_required') then 'review_required' else 'approved' end,
    v_amount,
    v_amount,
    0,
    v_currency,
    v_source_state,
    v_policy,
    v_actor.profile_id,
    v_public_note,
    v_internal_note,
    v_key
  )
  returning id into v_id;

  perform public.finance_d10_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    case when v_source_state in ('historical_paid_unallocated', 'review_required') then 'reseller_liability_review_created' else 'reseller_liability_approved' end,
    'reseller_liabilities',
    v_id,
    jsonb_build_object(
      'liability_type', v_type,
      'amount', v_amount,
      'currency_code', v_currency,
      'source_finance_state', v_source_state,
      'recovery_policy', v_policy,
      'request_fingerprint', v_fingerprint
    )
  );

  return query
  select
    rl.id,
    rl.status,
    rl.recovery_policy,
    rl.original_amount,
    rl.outstanding_amount,
    rl.recovered_amount,
    rl.currency_code,
    rl.source_finance_state,
    true
  from public.reseller_liabilities rl
  where rl.id = v_id;
end;
$fn$;

create or replace function public.finance_enable_future_earnings_offset(
  p_liability_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (
  liability_id uuid,
  status text,
  recovery_policy text,
  outstanding_amount numeric,
  recovered_amount numeric,
  currency_code text,
  updated boolean
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_public_note text := public.finance_d10_validate_note(p_public_note, 500);
  v_internal_note text := public.finance_d10_validate_note(p_internal_note, 1000);
  v_liability public.reseller_liabilities%rowtype;
begin
  select * into v_actor from public.finance_d10_assert_actor();

  select * into v_liability
  from public.reseller_liabilities rl
  where rl.id = p_liability_id
    and rl.deleted_at is null
  for update;

  if not found then
    raise exception 'LIABILITY_NOT_FOUND' using errcode = '22023';
  end if;

  if v_liability.status not in ('approved', 'review_required', 'recovery_active', 'partially_recovered') then
    raise exception 'LIABILITY_NOT_OFFSET_ELIGIBLE' using errcode = '23514';
  end if;

  if v_liability.outstanding_amount <= 0 then
    raise exception 'LIABILITY_ALREADY_RESOLVED' using errcode = '23514';
  end if;

  if v_liability.recovery_policy = 'offset_future_earnings' then
    return query
    select rl.id, rl.status, rl.recovery_policy, rl.outstanding_amount, rl.recovered_amount, rl.currency_code, false
    from public.reseller_liabilities rl
    where rl.id = p_liability_id;
    return;
  end if;

  if exists (
    select 1
    from public.finance_actions fa
    where fa.actor_profile_id = v_actor.profile_id
      and fa.action_type = 'reseller_future_earnings_offset_enabled'
      and fa.target_entity_type = 'reseller_liabilities'
      and fa.target_entity_id = p_liability_id
      and fa.idempotency_key = v_key
  ) then
    return query
    select rl.id, rl.status, rl.recovery_policy, rl.outstanding_amount, rl.recovered_amount, rl.currency_code, false
    from public.reseller_liabilities rl
    where rl.id = p_liability_id;
    return;
  end if;

  update public.reseller_liabilities rl
  set recovery_policy = 'offset_future_earnings',
      status = case when rl.status = 'review_required' then 'approved' else rl.status end,
      public_note = coalesce(v_public_note, rl.public_note),
      internal_note = coalesce(v_internal_note, rl.internal_note),
      updated_at = now()
  where rl.id = p_liability_id;

  insert into public.finance_actions(
    actor_profile_id,
    actor_role,
    action_type,
    target_entity_type,
    target_entity_id,
    idempotency_key,
    request_fingerprint,
    result_status
  )
  values (
    v_actor.profile_id,
    v_actor.actor_role,
    'reseller_future_earnings_offset_enabled',
    'reseller_liabilities',
    p_liability_id,
    v_key,
    md5(jsonb_build_object('liability_id', p_liability_id, 'policy', 'offset_future_earnings')::text),
    'enabled'
  );

  perform public.finance_d10_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'reseller_future_earnings_offset_enabled',
    'reseller_liabilities',
    p_liability_id,
    jsonb_build_object('recovery_policy', 'offset_future_earnings', 'idempotency_key_present', true)
  );

  return query
  select rl.id, rl.status, rl.recovery_policy, rl.outstanding_amount, rl.recovered_amount, rl.currency_code, true
  from public.reseller_liabilities rl
  where rl.id = p_liability_id;
end;
$fn$;

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
    select * into v_liability from public.reseller_liabilities rl where rl.id = v_existing.liability_id;
    return query select v_existing.liability_id, v_existing.id, v_existing.commission_id, v_existing.amount, v_liability.outstanding_amount, v_liability.recovered_amount, false;
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

create or replace function public.finance_waive_reseller_liability(
  p_liability_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table(liability_id uuid, status text, outstanding_amount numeric, recovered_amount numeric, applied boolean)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_note text := public.finance_d10_validate_note(p_public_note, 500);
  v_internal text := public.finance_d10_validate_note(p_internal_note, 1000);
  v_liability public.reseller_liabilities%rowtype;
  v_recovery_id uuid;
begin
  select * into v_actor from public.finance_d10_assert_actor();

  select * into v_liability
  from public.reseller_liabilities rl
  where rl.id = p_liability_id
    and rl.deleted_at is null
  for update;

  if not found then
    raise exception 'LIABILITY_NOT_FOUND' using errcode = '22023';
  end if;

  if v_liability.status in ('waived', 'cancelled', 'recovered') then
    return query select v_liability.id, v_liability.status, v_liability.outstanding_amount, v_liability.recovered_amount, false;
    return;
  end if;

  insert into public.reseller_liability_recoveries(
    liability_id,
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
    'waiver',
    v_liability.outstanding_amount,
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
  set status = 'waived',
      recovery_policy = 'waived',
      public_note = coalesce(v_note, rl.public_note),
      internal_note = coalesce(v_internal, rl.internal_note),
      resolved_by_profile_id = v_actor.profile_id,
      resolved_at = now(),
      updated_at = now()
  where rl.id = v_liability.id;

  perform public.finance_d10_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'reseller_liability_waived',
    'reseller_liabilities',
    v_liability.id,
    jsonb_build_object('amount', v_liability.outstanding_amount, 'currency_code', v_liability.currency_code)
  );

  return query
  select rl.id, rl.status, rl.outstanding_amount, rl.recovered_amount, true
  from public.reseller_liabilities rl
  where rl.id = v_liability.id;
end;
$fn$;

create or replace function public.finance_absorb_reseller_liability(
  p_liability_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table(liability_id uuid, status text, recovery_policy text, outstanding_amount numeric, recovered_amount numeric, applied boolean)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_note text := public.finance_d10_validate_note(p_public_note, 500);
  v_internal text := public.finance_d10_validate_note(p_internal_note, 1000);
  v_liability public.reseller_liabilities%rowtype;
  v_recovery_id uuid;
begin
  select * into v_actor from public.finance_d10_assert_actor();

  select * into v_liability
  from public.reseller_liabilities rl
  where rl.id = p_liability_id
    and rl.deleted_at is null
  for update;

  if not found then
    raise exception 'LIABILITY_NOT_FOUND' using errcode = '22023';
  end if;

  if v_liability.status in ('waived', 'cancelled', 'recovered') then
    return query select v_liability.id, v_liability.status, v_liability.recovery_policy, v_liability.outstanding_amount, v_liability.recovered_amount, false;
    return;
  end if;

  insert into public.reseller_liability_recoveries(
    liability_id,
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
    'platform_absorption',
    v_liability.outstanding_amount,
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
  set status = 'recovered',
      recovery_policy = 'platform_absorbed',
      recovered_amount = rl.original_amount,
      outstanding_amount = 0,
      public_note = coalesce(v_note, rl.public_note),
      internal_note = coalesce(v_internal, rl.internal_note),
      resolved_by_profile_id = v_actor.profile_id,
      resolved_at = now(),
      updated_at = now()
  where rl.id = v_liability.id;

  perform public.finance_d10_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'reseller_liability_platform_absorbed',
    'reseller_liabilities',
    v_liability.id,
    jsonb_build_object('amount', v_liability.outstanding_amount, 'currency_code', v_liability.currency_code)
  );

  return query
  select rl.id, rl.status, rl.recovery_policy, rl.outstanding_amount, rl.recovered_amount, true
  from public.reseller_liabilities rl
  where rl.id = v_liability.id;
end;
$fn$;

create or replace function public.finance_mark_withdrawal_allocation_disputed(
  p_allocation_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table(allocation_id uuid, withdrawal_id uuid, commission_id uuid, allocation_status text, updated boolean)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_allocation public.withdrawal_commission_allocations%rowtype;
begin
  select * into v_actor from public.finance_d10_assert_actor();

  select * into v_allocation
  from public.withdrawal_commission_allocations wca
  where wca.id = p_allocation_id
  for update;

  if not found then
    raise exception 'ALLOCATION_NOT_FOUND' using errcode = '22023';
  end if;

  if v_allocation.allocation_status = 'consumed' then
    raise exception 'CONSUMED_ALLOCATION_IMMUTABLE' using errcode = '23514';
  end if;

  if v_allocation.allocation_status = 'disputed' then
    return query select v_allocation.id, v_allocation.withdrawal_id, v_allocation.commission_id, v_allocation.allocation_status, false;
    return;
  end if;

  update public.withdrawal_commission_allocations wca
  set allocation_status = 'disputed',
      updated_at = now()
  where wca.id = p_allocation_id
    and wca.allocation_status = 'reserved';

  if not found then
    raise exception 'ALLOCATION_NOT_RESERVED' using errcode = '23514';
  end if;

  perform public.finance_d10_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'withdrawal_allocation_disputed',
    'withdrawal_commission_allocations',
    p_allocation_id,
    jsonb_build_object('idempotency_key_present', true)
  );

  return query
  select wca.id, wca.withdrawal_id, wca.commission_id, wca.allocation_status, true
  from public.withdrawal_commission_allocations wca
  where wca.id = p_allocation_id;
end;
$fn$;

create or replace function public.finance_release_withdrawal_allocation(
  p_allocation_id uuid,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table(allocation_id uuid, withdrawal_id uuid, commission_id uuid, allocation_status text, updated boolean)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_allocation public.withdrawal_commission_allocations%rowtype;
  v_withdrawal public.withdrawals%rowtype;
begin
  select * into v_actor from public.finance_d10_assert_actor();

  select * into v_allocation
  from public.withdrawal_commission_allocations wca
  where wca.id = p_allocation_id
  for update;

  if not found then
    raise exception 'ALLOCATION_NOT_FOUND' using errcode = '22023';
  end if;

  select * into v_withdrawal
  from public.withdrawals w
  where w.id = v_allocation.withdrawal_id
  for update;

  if v_withdrawal.withdrawal_status = 'paid' or v_allocation.allocation_status = 'consumed' then
    raise exception 'CONSUMED_ALLOCATION_IMMUTABLE' using errcode = '23514';
  end if;

  if v_allocation.allocation_status = 'released' then
    return query select v_allocation.id, v_allocation.withdrawal_id, v_allocation.commission_id, v_allocation.allocation_status, false;
    return;
  end if;

  update public.withdrawal_commission_allocations wca
  set allocation_status = 'released',
      released_at = now(),
      updated_at = now()
  where wca.id = p_allocation_id
    and wca.allocation_status in ('reserved', 'disputed');

  if not found then
    raise exception 'ALLOCATION_NOT_RELEASABLE' using errcode = '23514';
  end if;

  perform public.finance_d10_make_audit(
    v_actor.profile_id,
    v_actor.actor_role,
    'withdrawal_allocation_released',
    'withdrawal_commission_allocations',
    p_allocation_id,
    jsonb_build_object('idempotency_key_present', true)
  );

  return query
  select wca.id, wca.withdrawal_id, wca.commission_id, wca.allocation_status, true
  from public.withdrawal_commission_allocations wca
  where wca.id = p_allocation_id;
end;
$fn$;

create or replace function public.get_reseller_liability_impact_safe()
returns table (
  active_liability_count bigint,
  outstanding_amount numeric,
  recovered_amount numeric,
  active_allocation_amount numeric,
  currency_code text,
  recovery_status text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_profile_id uuid;
begin
  v_reseller_id := public.current_verified_reseller_id();
  select r.profile_id into v_profile_id from public.resellers r where r.id = v_reseller_id;

  return query
  select
    count(rl.id)::bigint,
    round(coalesce(sum(rl.outstanding_amount), 0), 2),
    round(coalesce(sum(rl.recovered_amount), 0), 2),
    public.finance_d10_active_allocation_amount(v_profile_id),
    coalesce(min(rl.currency_code), 'GHS'),
    case when count(rl.id) > 0 then 'finance_review' else 'clear' end
  from public.reseller_liabilities rl
  where rl.reseller_profile_id = v_profile_id
    and rl.deleted_at is null
    and rl.status in ('review_required', 'approved', 'recovery_active', 'partially_recovered');
end;
$fn$;

create or replace function public.list_reseller_liabilities_safe(p_status text default null, p_limit integer default 50)
returns table (
  liability_id uuid,
  liability_type text,
  status text,
  outstanding_amount numeric,
  recovered_amount numeric,
  currency_code text,
  source_finance_state text,
  recovery_policy text,
  public_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_profile_id uuid;
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  v_reseller_id := public.current_verified_reseller_id();
  select r.profile_id into v_profile_id from public.resellers r where r.id = v_reseller_id;

  return query
  select
    rl.id,
    rl.liability_type,
    rl.status,
    rl.outstanding_amount,
    rl.recovered_amount,
    rl.currency_code,
    rl.source_finance_state,
    rl.recovery_policy,
    rl.public_note,
    rl.created_at
  from public.reseller_liabilities rl
  where rl.reseller_profile_id = v_profile_id
    and rl.deleted_at is null
    and (p_status is null or rl.status = p_status)
  order by rl.created_at desc, rl.id desc
  limit v_limit;
end;
$fn$;

create or replace function public.list_finance_reseller_liabilities_safe(p_status text default null, p_limit integer default 50)
returns table (
  liability_id uuid,
  liability_type text,
  status text,
  original_amount numeric,
  outstanding_amount numeric,
  recovered_amount numeric,
  currency_code text,
  source_finance_state text,
  recovery_policy text,
  has_internal_note boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_actor record;
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  select * into v_actor from public.finance_d10_assert_actor();

  return query
  select
    rl.id,
    rl.liability_type,
    rl.status,
    rl.original_amount,
    rl.outstanding_amount,
    rl.recovered_amount,
    rl.currency_code,
    rl.source_finance_state,
    rl.recovery_policy,
    rl.internal_note is not null,
    rl.created_at
  from public.reseller_liabilities rl
  where rl.deleted_at is null
    and (p_status is null or rl.status = p_status)
  order by rl.created_at desc, rl.id desc
  limit v_limit;
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
  v_held_amount numeric(12,2);
  v_offset_hold_amount numeric(12,2);
begin
  v_reseller_id := public.current_verified_reseller_id();
  select r.profile_id into v_reseller_profile_id from public.resellers r where r.id = v_reseller_id;
  v_held_amount := public.finance_d9_active_reseller_hold_amount(v_reseller_profile_id);
  v_offset_hold_amount := public.finance_d10_active_liability_outstanding_amount(v_reseller_profile_id);

  return query
  select
    r.id,
    'GHS'::text,
    r.commission_pending_amount,
    greatest(r.commission_available_amount - v_held_amount - v_offset_hold_amount, 0),
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount,
    public.reseller_withdrawal_minimum_amount(),
    exists (
      select 1 from public.withdrawals w
      where w.reseller_id = r.id
        and w.withdrawal_status = 'requested'
    )
  from public.resellers r
  where r.id = v_reseller_id
    and r.deleted_at is null;
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
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_amount numeric(12,2) := round(coalesce(p_amount, 0), 2);
  v_held_amount numeric(12,2);
  v_liability_hold_amount numeric(12,2);
  v_remaining numeric(12,2);
  v_allocate numeric(12,2);
  v_commission record;
  v_allocated_total numeric(12,2) := 0;
begin
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
      greatest(r.commission_available_amount - public.finance_d9_active_reseller_hold_amount(r.profile_id) - public.finance_d10_active_liability_outstanding_amount(r.profile_id), 0),
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
  v_liability_hold_amount := public.finance_d10_active_liability_outstanding_amount(v_reseller.profile_id);

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

  if greatest(v_reseller.commission_available_amount - v_held_amount - v_liability_hold_amount, 0) < v_amount then
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

  v_remaining := v_amount;

  for v_commission in
    select
      c.id,
      public.finance_d10_commission_available_amount(c.id) as available_amount,
      c.available_at,
      c.created_at
    from public.commissions c
    where c.reseller_id = v_reseller.id
      and c.commission_status = 'available'
    order by coalesce(c.available_at, c.created_at) asc, c.id::text asc
    for update
  loop
    exit when v_remaining <= 0;
    v_allocate := round(least(v_remaining, coalesce(v_commission.available_amount, 0)), 2);
    if v_allocate <= 0 then
      continue;
    end if;

    insert into public.withdrawal_commission_allocations(
      withdrawal_id,
      commission_id,
      reseller_profile_id,
      allocated_amount,
      currency_code,
      allocation_status,
      idempotency_key
    )
    values (
      v_withdrawal_id,
      v_commission.id,
      v_reseller.profile_id,
      v_allocate,
      'GHS',
      'reserved',
      v_key || ':' || left(v_commission.id::text, 12)
    );

    v_allocated_total := round(v_allocated_total + v_allocate, 2);
    v_remaining := round(v_remaining - v_allocate, 2);
  end loop;

  if v_allocated_total <> v_amount then
    raise exception 'ALLOCATION_INSUFFICIENT' using errcode = '23514';
  end if;

  update public.resellers r
  set commission_available_amount = r.commission_available_amount - v_amount,
      commission_pending_withdrawal_amount = r.commission_pending_withdrawal_amount + v_amount,
      updated_at = now()
  where r.id = v_reseller.id
    and r.commission_available_amount >= v_amount
    and greatest(r.commission_available_amount - v_held_amount - v_liability_hold_amount, 0) >= v_amount;

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
      'active_hold_amount', v_held_amount,
      'active_liability_hold_amount', v_liability_hold_amount
    ),
    jsonb_build_object(
      'requested_amount', v_amount,
      'currency_code', 'GHS',
      'payout_account_masked', public.mask_payout_value(coalesce(v_account.phone_number, v_account.account_number)),
      'idempotency_key_present', true,
      'commission_allocation_model', 'future_only',
      'allocation_total', v_allocated_total,
      'active_holds_respected', true
    )
  );

  perform public.finance_d10_make_audit(
    public.current_profile_id(),
    'reseller',
    'withdrawal_commission_allocated',
    'withdrawals',
    v_withdrawal_id,
    jsonb_build_object('allocation_total', v_allocated_total, 'currency_code', 'GHS')
  );

  return query
  select
    w.id,
    w.request_reference,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    greatest(r.commission_available_amount - public.finance_d9_active_reseller_hold_amount(r.profile_id) - public.finance_d10_active_liability_outstanding_amount(r.profile_id), 0),
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
  v_key text := public.finance_d10_validate_key(p_idempotency_key);
  v_allocation_total numeric(12,2);
begin
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  if p_withdrawal_id is null then
    raise exception 'WITHDRAWAL_NOT_FOUND' using errcode = '22023';
  end if;

  if v_reference is null or length(v_reference) > 100 or v_reference ~* '(pin|otp|password|secret|token|cvv)' then
    raise exception 'PAYOUT_REFERENCE_REQUIRED' using errcode = '22023';
  end if;

  if v_note is not null and (length(v_note) > 500 or v_note ~* '(pin|otp|password|secret|token|cvv)') then
    raise exception 'FIELD_TOO_LONG' using errcode = '22023';
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

  if exists (
    select 1
    from public.withdrawal_commission_allocations wca
    where wca.withdrawal_id = p_withdrawal_id
      and wca.allocation_status = 'disputed'
  ) then
    raise exception 'WITHDRAWAL_BLOCKED_BY_DISPUTED_ALLOCATION' using errcode = '23514';
  end if;

  select round(coalesce(sum(wca.allocated_amount), 0), 2)
  into v_allocation_total
  from public.withdrawal_commission_allocations wca
  where wca.withdrawal_id = p_withdrawal_id
    and wca.allocation_status = 'reserved';

  if v_allocation_total <> v_withdrawal.requested_amount then
    raise exception 'WITHDRAWAL_ALLOCATION_INCOMPLETE' using errcode = '23514';
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

  update public.withdrawal_commission_allocations wca
  set allocation_status = 'consumed',
      consumed_at = now(),
      updated_at = now()
  where wca.withdrawal_id = p_withdrawal_id
    and wca.allocation_status = 'reserved';

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
      'allocation_total_consumed', v_allocation_total
    )
  );

  perform public.finance_d10_make_audit(
    v_admin_profile_id,
    'finance_staff',
    'withdrawal_allocations_consumed',
    'withdrawals',
    p_withdrawal_id,
    jsonb_build_object('allocation_total', v_allocation_total, 'currency_code', v_withdrawal.currency_code)
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

revoke all on function public.finance_d10_liability_source_state(public.commissions) from public, anon, authenticated;
revoke all on function public.finance_d10_proven_withdrawal_for_commission(uuid) from public, anon, authenticated;
revoke all on function public.finance_approve_reseller_liability(uuid, uuid, uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_approve_reseller_liability(uuid, uuid, uuid, text, text, text, text, text) to authenticated;
revoke all on function public.finance_enable_future_earnings_offset(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_enable_future_earnings_offset(uuid, text, text, text) to authenticated;
revoke all on function public.finance_apply_future_commission_offset(uuid, text) from public, anon, authenticated;
grant execute on function public.finance_apply_future_commission_offset(uuid, text) to authenticated;
revoke all on function public.finance_waive_reseller_liability(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_waive_reseller_liability(uuid, text, text, text) to authenticated;
revoke all on function public.finance_absorb_reseller_liability(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_absorb_reseller_liability(uuid, text, text, text) to authenticated;
revoke all on function public.finance_mark_withdrawal_allocation_disputed(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_mark_withdrawal_allocation_disputed(uuid, text, text, text) to authenticated;
revoke all on function public.finance_release_withdrawal_allocation(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finance_release_withdrawal_allocation(uuid, text, text, text) to authenticated;
revoke all on function public.get_reseller_liability_impact_safe() from public, anon, authenticated;
grant execute on function public.get_reseller_liability_impact_safe() to authenticated;
revoke all on function public.list_reseller_liabilities_safe(text, integer) from public, anon, authenticated;
grant execute on function public.list_reseller_liabilities_safe(text, integer) to authenticated;
revoke all on function public.list_finance_reseller_liabilities_safe(text, integer) from public, anon, authenticated;
grant execute on function public.list_finance_reseller_liabilities_safe(text, integer) to authenticated;
revoke all on function public.get_reseller_wallet_safe() from public, anon, authenticated;
grant execute on function public.get_reseller_wallet_safe() to authenticated;
revoke all on function public.reseller_request_withdrawal(numeric, uuid, text) from public, anon, authenticated;
grant execute on function public.reseller_request_withdrawal(numeric, uuid, text) to authenticated;
revoke all on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_mark_reseller_withdrawal_paid(uuid, text, text, text) to authenticated;

comment on function public.finance_approve_reseller_liability(uuid, uuid, uuid, text, text, text, text, text)
  is 'D10 finance-only audited reseller liability approval. Amount, currency, reseller, order, and withdrawal proof are derived server-side.';
comment on function public.finance_enable_future_earnings_offset(uuid, text, text, text)
  is 'D10 finance-only explicit future earnings offset enablement. No immediate deduction or provider collection is performed.';
