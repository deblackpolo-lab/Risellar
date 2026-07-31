-- Admin Settlement Verification Phase: finance-only supplier settlement
-- verification for supplier-reported Pay on Delivery orders.
--
-- This migration keeps the transition server-side, audited, idempotent, and
-- scoped to active finance_staff or super_admin entries in admin_staff.

alter type public.payment_collection_status add value if not exists 'settlement_verified' after 'supplier_reported';

alter table public.orders
  add column if not exists completed_at timestamptz,
  add column if not exists completed_by_profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists settlement_verified_idempotency_key text;

alter table public.orders
  drop constraint if exists orders_settlement_verified_idempotency_key_check;

alter table public.orders
  add constraint orders_settlement_verified_idempotency_key_check
  check (settlement_verified_idempotency_key is null or length(trim(settlement_verified_idempotency_key)) between 1 and 140);

alter table public.settlements
  add column if not exists verification_idempotency_key text;

alter table public.settlements
  drop constraint if exists settlements_verification_idempotency_key_check,
  drop constraint if exists settlements_proof_reference_safe_check,
  drop constraint if exists settlements_review_notes_safe_check;

alter table public.settlements
  add constraint settlements_verification_idempotency_key_check
  check (verification_idempotency_key is null or length(trim(verification_idempotency_key)) between 1 and 140),
  add constraint settlements_proof_reference_safe_check
  check (proof_reference is null or (length(trim(proof_reference)) <= 100 and proof_reference !~* '(pin|password|secret|token|card|cvv|otp)')),
  add constraint settlements_review_notes_safe_check
  check (review_notes is null or (length(trim(review_notes)) <= 500 and review_notes !~* '(pin|password|secret|token|card|cvv|otp)'));

create unique index if not exists settlements_order_active_unique
  on public.settlements(order_id)
  where deleted_at is null;

create unique index if not exists settlements_verification_idempotency_unique
  on public.settlements(verification_idempotency_key)
  where verification_idempotency_key is not null and deleted_at is null;

create or replace function public.current_finance_admin_profile_id()
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

create or replace function public.admin_can_verify_supplier_settlements()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_finance_admin_profile_id() is not null;
$$;

create or replace function public.list_admin_pending_supplier_settlements(p_limit integer default 50)
returns table (
  order_id uuid,
  order_number text,
  supplier_business_name text,
  reseller_display_name text,
  customer_total_amount numeric,
  platform_amount_due numeric,
  reseller_commission_due numeric,
  total_settlement_due numeric,
  currency_code text,
  order_status text,
  payment_collection_status text,
  settlement_status text,
  commission_status text,
  supplier_reported_at timestamptz,
  settlement_created_at timestamptz
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
    raise exception 'FINANCE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  return query
  with commission_totals as (
    select
      cm.order_id,
      sum(cm.commission_amount) as commission_amount,
      min(cm.commission_status::text) as commission_status
    from public.commissions cm
    group by cm.order_id
  ),
  item_totals as (
    select
      oi.order_id,
      sum(oi.settlement_due_amount) as settlement_due_amount,
      sum(oi.commission_amount) as commission_amount
    from public.order_items oi
    group by oi.order_id
  )
  select
    o.id,
    o.order_number,
    s.business_name,
    rs.display_name,
    o.total_payable_amount,
    round(coalesce(it.settlement_due_amount, st.due_amount, 0) - coalesce(ct.commission_amount, it.commission_amount, 0), 2),
    round(coalesce(ct.commission_amount, it.commission_amount, 0), 2),
    st.due_amount,
    o.currency_code,
    o.order_status::text,
    o.payment_collection_status::text,
    st.settlement_status::text,
    ct.commission_status,
    spr.reported_at,
    st.created_at
  from public.settlements st
  join public.orders o on o.id = st.order_id and o.deleted_at is null
  join public.suppliers s on s.id = st.supplier_id and s.deleted_at is null
  join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  left join public.supplier_payment_reports spr on spr.order_id = o.id and spr.deleted_at is null
  left join commission_totals ct on ct.order_id = o.id
  left join item_totals it on it.order_id = o.id
  where st.deleted_at is null
    and st.settlement_status = 'due'
    and o.order_status::text = 'payment_reported'
    and o.payment_collection_status::text = 'supplier_reported'
  order by st.created_at asc, o.order_number asc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
end;
$fn$;

create or replace function public.get_admin_supplier_settlement_safe(p_order_id uuid)
returns table (
  order_id uuid,
  order_number text,
  supplier_business_name text,
  reseller_display_name text,
  customer_total_amount numeric,
  supplier_amount_expected numeric,
  platform_amount_due numeric,
  reseller_commission_due numeric,
  total_settlement_due numeric,
  currency_code text,
  order_status text,
  payment_collection_status text,
  settlement_status text,
  commission_status text,
  supplier_reported_at timestamptz,
  settlement_verified_at timestamptz,
  completed_at timestamptz,
  reservation_status text,
  settlement_reference_present boolean,
  admin_note_present boolean,
  can_verify boolean
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
    raise exception 'FINANCE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  if p_order_id is null then
    raise exception 'ORDER_NOT_FOUND'
      using errcode = '22023';
  end if;

  return query
  with item_totals as (
    select
      oi.order_id,
      sum(oi.supplier_base_price_snapshot_amount * oi.quantity) as supplier_amount,
      sum(oi.settlement_due_amount) as settlement_due_amount,
      sum(oi.commission_amount) as commission_amount
    from public.order_items oi
    where oi.order_id = p_order_id
    group by oi.order_id
  ),
  commission_totals as (
    select
      cm.order_id,
      sum(cm.commission_amount) as commission_amount,
      bool_and(cm.commission_status = 'awaiting_supplier_settlement') as all_locked,
      bool_and(cm.commission_status = 'available') as all_available,
      min(cm.commission_status::text) as commission_status
    from public.commissions cm
    where cm.order_id = p_order_id
    group by cm.order_id
  ),
  reservation_summary as (
    select
      sr.order_id,
      min(sr.reservation_status::text) as reservation_status
    from public.stock_reservations sr
    where sr.order_id = p_order_id
    group by sr.order_id
  )
  select
    o.id,
    o.order_number,
    s.business_name,
    rs.display_name,
    o.total_payable_amount,
    round(coalesce(it.supplier_amount, 0), 2),
    round(coalesce(it.settlement_due_amount, st.due_amount, 0) - coalesce(ct.commission_amount, it.commission_amount, 0), 2),
    round(coalesce(ct.commission_amount, it.commission_amount, 0), 2),
    st.due_amount,
    o.currency_code,
    o.order_status::text,
    o.payment_collection_status::text,
    st.settlement_status::text,
    ct.commission_status,
    spr.reported_at,
    st.verified_at,
    o.completed_at,
    rsrv.reservation_status,
    st.proof_reference is not null,
    st.review_notes is not null,
    (
      o.order_status::text = 'payment_reported'
      and o.payment_collection_status::text = 'supplier_reported'
      and st.settlement_status = 'due'
      and coalesce(ct.all_locked, false)
      and coalesce(rsrv.reservation_status, '') = 'committed'
    )
  from public.orders o
  join public.settlements st on st.order_id = o.id and st.deleted_at is null
  join public.suppliers s on s.id = st.supplier_id and s.deleted_at is null
  join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  left join public.supplier_payment_reports spr on spr.order_id = o.id and spr.deleted_at is null
  left join item_totals it on it.order_id = o.id
  left join commission_totals ct on ct.order_id = o.id
  left join reservation_summary rsrv on rsrv.order_id = o.id
  where o.id = p_order_id
    and o.deleted_at is null
  limit 1;
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
    raise exception 'FINANCE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  if p_order_id is null then
    raise exception 'ORDER_NOT_FOUND'
      using errcode = '22023';
  end if;

  v_idempotency_key := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_reference := nullif(trim(coalesce(p_settlement_reference, '')), '');
  v_admin_note := nullif(trim(coalesce(p_admin_note, '')), '');

  if v_idempotency_key is null or length(v_idempotency_key) > 140 then
    raise exception 'VALIDATION_ERROR'
      using errcode = '23514';
  end if;

  if v_reference is not null and (length(v_reference) > 100 or v_reference ~* '(pin|password|secret|token|card|cvv|otp)') then
    raise exception 'FIELD_TOO_LONG'
      using errcode = '23514';
  end if;

  if v_admin_note is not null and (length(v_admin_note) > 500 or v_admin_note ~* '(pin|password|secret|token|card|cvv|otp)') then
    raise exception 'FIELD_TOO_LONG'
      using errcode = '23514';
  end if;

  select *
  into v_order
  from public.orders o
  where o.id = p_order_id
    and o.deleted_at is null
  for update;

  if v_order.id is null then
    raise exception 'ORDER_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  select *
  into v_settlement
  from public.settlements st
  where st.order_id = p_order_id
    and st.deleted_at is null
  for update;

  if v_settlement.id is null then
    raise exception 'SETTLEMENT_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  if v_order.order_status = 'completed'
    or v_settlement.settlement_status = 'paid'
    or v_order.payment_collection_status::text = 'settlement_verified' then
    if v_settlement.verification_idempotency_key = v_idempotency_key
      and coalesce(v_settlement.proof_reference, '') is not distinct from coalesce(v_reference, '')
      and coalesce(v_settlement.review_notes, '') is not distinct from coalesce(v_admin_note, '') then
      return query select * from public.admin_verify_supplier_settlement_result(p_order_id);
      return;
    end if;

    raise exception 'CONFLICTING_RETRY'
      using errcode = '23505';
  end if;

  if v_order.order_status::text <> 'payment_reported' or v_order.payment_collection_status::text <> 'supplier_reported' then
    raise exception 'ORDER_NOT_PAYMENT_REPORTED'
      using errcode = '23514';
  end if;

  if v_settlement.settlement_status <> 'due' then
    raise exception 'SETTLEMENT_ALREADY_VERIFIED'
      using errcode = '23514';
  end if;

  select *
  into v_report
  from public.supplier_payment_reports spr
  where spr.order_id = p_order_id
    and spr.deleted_at is null
  order by spr.reported_at asc, spr.id::text asc
  limit 1
  for update;

  if v_report.id is null then
    raise exception 'PAYMENT_REPORT_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  if v_report.supplier_id <> v_settlement.supplier_id
    or v_report.currency_code <> v_order.currency_code
    or round(v_report.reported_amount, 2) <> round(v_order.total_payable_amount, 2) then
    raise exception 'CURRENCY_MISMATCH'
      using errcode = '23514';
  end if;

  select
    oi.supplier_id,
    sum(oi.supplier_base_price_snapshot_amount * oi.quantity),
    sum(oi.settlement_due_amount),
    sum(oi.commission_amount)
  into v_supplier_id, v_supplier_amount, v_settlement_due, v_commission_amount
  from public.order_items oi
  where oi.order_id = p_order_id
  group by oi.supplier_id;

  if v_supplier_id is null or v_supplier_id <> v_settlement.supplier_id then
    raise exception 'FINANCIAL_AMOUNT_MISMATCH'
      using errcode = '23514';
  end if;

  v_supplier_amount := round(coalesce(v_supplier_amount, 0), 2);
  v_settlement_due := round(coalesce(v_settlement_due, 0), 2);
  v_commission_amount := round(coalesce(v_commission_amount, 0), 2);
  v_platform_amount := round(v_settlement_due - v_commission_amount, 2);

  if round(v_supplier_amount + v_settlement_due, 2) <> round(v_order.total_payable_amount, 2)
    or round(v_settlement.due_amount, 2) <> v_settlement_due
    or v_platform_amount < 0 then
    raise exception 'FINANCIAL_AMOUNT_MISMATCH'
      using errcode = '23514';
  end if;

  select sr.reservation_status::text
  into v_reservation_status
  from public.stock_reservations sr
  where sr.order_id = p_order_id
  order by sr.created_at asc
  limit 1;

  if coalesce(v_reservation_status, '') <> 'committed' then
    raise exception 'STOCK_STATE_INCONSISTENT'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.withdrawals w
    join public.commissions cm on cm.withdrawal_id = w.id
    where cm.order_id = p_order_id
  ) then
    raise exception 'WITHDRAWAL_ALREADY_EXISTS'
      using errcode = '23514';
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
    raise exception 'COMMISSION_NOT_FOUND'
      using errcode = 'P0002';
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
    raise exception 'SETTLEMENT_ALREADY_VERIFIED'
      using errcode = '23514';
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
    raise exception 'COMMISSION_ALREADY_AVAILABLE'
      using errcode = '23514';
  end if;

  update public.resellers r
  set commission_available_amount = r.commission_available_amount + v_commission_amount,
      commission_pending_amount = greatest(r.commission_pending_amount - v_commission_amount, 0),
      updated_at = now()
  where r.id = v_reseller_id
    and r.deleted_at is null;

  if not found then
    raise exception 'COMMISSION_NOT_FOUND'
      using errcode = 'P0002';
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
    values
      (
        v_admin_profile_id,
        'finance_staff',
        'supplier_settlement_verified',
        'orders',
        p_order_id,
        jsonb_build_object('order_status', 'payment_reported', 'payment_collection_status', 'supplier_reported', 'settlement_status', 'due', 'commission_status', 'awaiting_supplier_settlement'),
        jsonb_build_object('order_status', 'completed', 'payment_collection_status', 'settlement_verified', 'settlement_status', 'paid', 'commission_status', 'available', 'reference_present', v_reference is not null, 'admin_note_present', v_admin_note is not null, 'idempotency_key_present', true),
        'Finance verified supplier settlement and unlocked reseller commission'
      ),
      (
        v_admin_profile_id,
        'finance_staff',
        'platform_amount_verified_received',
        'settlements',
        v_settlement.id,
        null,
        jsonb_build_object('platform_amount_due', v_platform_amount, 'currency_code', v_order.currency_code, 'settlement_status', 'paid'),
        'Risellar platform amount verified as received from supplier settlement'
      ),
      (
        v_admin_profile_id,
        'finance_staff',
        'reseller_commission_unlocked',
        'commissions',
        null,
        null,
        jsonb_build_object('order_id', p_order_id, 'commission_amount', v_commission_amount, 'currency_code', v_order.currency_code, 'commission_status', 'available'),
        'Reseller commission unlocked after supplier settlement verification'
      ),
      (
        v_admin_profile_id,
        'finance_staff',
        'reseller_available_balance_credited',
        'resellers',
        v_reseller_id,
        null,
        jsonb_build_object('order_id', p_order_id, 'credit_amount', v_commission_amount, 'currency_code', v_order.currency_code),
        'Reseller available balance credited after settlement verification'
      ),
      (
        v_admin_profile_id,
        'finance_staff',
        'order_completed',
        'orders',
        p_order_id,
        null,
        jsonb_build_object('order_status', 'completed', 'payment_collection_status', 'settlement_verified'),
        'Order completed after supplier settlement verification'
      );
  end if;

  return query select * from public.admin_verify_supplier_settlement_result(p_order_id);
end;
$fn$;

create or replace function public.admin_verify_supplier_settlement_result(p_order_id uuid)
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
language sql
stable
security definer
set search_path = public
as $$
  select
    o.id,
    o.order_number,
    o.order_status::text,
    o.payment_collection_status::text,
    st.settlement_status::text,
    min(cm.commission_status::text),
    r.commission_available_amount,
    st.verified_at,
    o.completed_at
  from public.orders o
  join public.settlements st on st.order_id = o.id and st.deleted_at is null
  join public.commissions cm on cm.order_id = o.id and cm.settlement_id = st.id
  join public.resellers r on r.id = o.reseller_id and r.deleted_at is null
  where o.id = p_order_id
    and o.deleted_at is null
  group by o.id, o.order_number, o.order_status, o.payment_collection_status, st.settlement_status, r.commission_available_amount, st.verified_at, o.completed_at;
$$;

revoke all on function public.current_finance_admin_profile_id() from public, anon, authenticated;
grant execute on function public.current_finance_admin_profile_id() to authenticated;

revoke all on function public.admin_can_verify_supplier_settlements() from public, anon, authenticated;
grant execute on function public.admin_can_verify_supplier_settlements() to authenticated;

revoke all on function public.list_admin_pending_supplier_settlements(integer) from public, anon, authenticated;
grant execute on function public.list_admin_pending_supplier_settlements(integer) to authenticated;

revoke all on function public.get_admin_supplier_settlement_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_admin_supplier_settlement_safe(uuid) to authenticated;

revoke all on function public.admin_verify_supplier_settlement(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.admin_verify_supplier_settlement(uuid, text, text, text) to authenticated;

revoke all on function public.admin_verify_supplier_settlement_result(uuid) from public, anon, authenticated;
grant execute on function public.admin_verify_supplier_settlement_result(uuid) to authenticated;

comment on function public.admin_verify_supplier_settlement(uuid, text, text, text)
  is 'Finance-only audited supplier settlement verification. Verifies pending supplier settlement, marks Pay on Delivery as settlement_verified, unlocks reseller commission exactly once, completes the order, and does not mutate stock or create withdrawals.';
