-- Finance Visibility Phase 1: read-only finance summaries and history.
-- These RPCs expose role-scoped, public-safe finance dashboard data only.
-- Money movement remains in the existing audited settlement and withdrawal RPCs.

create index if not exists commissions_reseller_status_created_idx
  on public.commissions(reseller_id, commission_status, created_at desc, id)
  where commission_amount >= 0;

create index if not exists settlements_supplier_status_created_idx
  on public.settlements(supplier_id, settlement_status, created_at desc, id)
  where deleted_at is null;

create index if not exists withdrawals_reseller_status_created_idx
  on public.withdrawals(reseller_id, withdrawal_status, created_at desc, id);

create index if not exists supplier_payment_reports_supplier_reported_idx
  on public.supplier_payment_reports(supplier_id, reported_at desc, id)
  where deleted_at is null;

create or replace function public.finance_history_clamped_limit(p_limit integer, p_default integer default 50)
returns integer
language sql
immutable
security definer
set search_path = public
as $$
  select greatest(1, least(coalesce(p_limit, p_default), 100));
$$;

create or replace function public.finance_history_assert_date_range(p_date_from date, p_date_to date)
returns void
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if p_date_from is not null and p_date_to is not null and p_date_from > p_date_to then
    raise exception 'INVALID_DATE_RANGE' using errcode = '22023';
  end if;
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
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_reseller_id := public.current_verified_reseller_id();

  return query
  with period_commissions as (
    select
      coalesce(o.currency_code, 'GHS') as currency_code,
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
      w.currency_code,
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
    select currency_code from period_commissions
    union
    select currency_code from period_withdrawals
    union
    select 'GHS'::text
  )
  select
    cur.currency_code,
    r.commission_pending_amount,
    r.commission_available_amount,
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
  left join period_commissions pc on pc.currency_code = cur.currency_code
  left join period_withdrawals pw on pw.currency_code = cur.currency_code
  where r.id = v_reseller_id
    and r.deleted_at is null
  order by cur.currency_code;
end;
$fn$;

create or replace function public.list_reseller_earnings_history_safe(
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  commission_id uuid,
  order_number text,
  product_name text,
  quantity integer,
  reseller_shop_name text,
  commission_amount numeric,
  currency_code text,
  commission_status text,
  earned_at timestamptz,
  available_at timestamptz,
  withdrawal_reference text,
  withdrawal_status text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_limit integer;
  v_commission_status public.commission_status;
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_reseller_id := public.current_verified_reseller_id();
  v_limit := public.finance_history_clamped_limit(p_limit, 50);

  if p_status is not null then
    if p_status = 'locked' then
      v_commission_status := 'awaiting_supplier_settlement';
    elsif p_status = 'available' then
      v_commission_status := 'available';
    elsif p_status = 'pending_withdrawal' then
      v_commission_status := 'withdrawal_requested';
    elsif p_status = 'withdrawn' then
      v_commission_status := 'paid';
    else
      raise exception 'INVALID_STATUS_FILTER' using errcode = '22023';
    end if;
  end if;

  return query
  select
    c.id,
    o.order_number,
    p.name,
    oi.quantity,
    rs.display_name,
    c.commission_amount,
    o.currency_code,
    c.commission_status::text,
    c.created_at,
    c.available_at,
    w.request_reference,
    w.withdrawal_status::text
  from public.commissions c
  join public.orders o on o.id = c.order_id and o.deleted_at is null
  join public.order_items oi on oi.id = c.order_item_id
  join public.products p on p.id = oi.product_id and p.deleted_at is null
  join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  left join public.withdrawals w on w.id = c.withdrawal_id
  where c.reseller_id = v_reseller_id
    and (v_commission_status is null or c.commission_status = v_commission_status)
    and (p_date_from is null or c.created_at >= p_date_from::timestamptz)
    and (p_date_to is null or c.created_at < (p_date_to + 1)::timestamptz)
    and (
      p_cursor_created_at is null
      or (c.created_at, c.id::text) < (p_cursor_created_at, coalesce(p_cursor_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)::text)
    )
  order by c.created_at desc, c.id::text desc
  limit v_limit;
end;
$fn$;

create or replace function public.list_reseller_withdrawal_history_safe(
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
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
  v_limit integer;
  v_status public.withdrawal_status;
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_reseller_id := public.current_verified_reseller_id();
  v_limit := public.finance_history_clamped_limit(p_limit, 50);

  if p_status is not null then
    if p_status = 'pending' then
      v_status := 'requested';
    elsif p_status in ('paid', 'rejected', 'cancelled') then
      v_status := p_status::public.withdrawal_status;
    else
      raise exception 'INVALID_STATUS_FILTER' using errcode = '22023';
    end if;
  end if;

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
    and (v_status is null or w.withdrawal_status = v_status)
    and (p_date_from is null or coalesce(w.paid_at, w.created_at) >= p_date_from::timestamptz)
    and (p_date_to is null or coalesce(w.paid_at, w.created_at) < (p_date_to + 1)::timestamptz)
    and (
      p_cursor_created_at is null
      or (w.created_at, w.id::text) < (p_cursor_created_at, coalesce(p_cursor_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)::text)
    )
  order by w.created_at desc, w.id::text desc
  limit v_limit;
end;
$fn$;

create or replace function public.get_supplier_finance_summary_safe(
  p_date_from date default null,
  p_date_to date default null
)
returns table (
  currency_code text,
  pending_settlement_amount numeric,
  pending_settlement_count bigint,
  customer_payments_reported_amount numeric,
  verified_settlement_amount numeric,
  completed_order_count bigint,
  platform_amount_settled numeric,
  reseller_commission_settled numeric,
  date_from date,
  date_to date
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_supplier_id uuid;
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_supplier_id := public.current_verified_supplier_owner_id();

  return query
  with pending_settlements as (
    select
      o.currency_code,
      sum(st.outstanding_amount) as amount,
      count(*) as count
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    where st.supplier_id = v_supplier_id
      and st.deleted_at is null
      and st.settlement_status in ('due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue')
    group by o.currency_code
  ),
  reported as (
    select
      spr.currency_code,
      sum(spr.reported_amount) as amount
    from public.supplier_payment_reports spr
    where spr.supplier_id = v_supplier_id
      and spr.deleted_at is null
      and (p_date_from is null or spr.reported_at >= p_date_from::timestamptz)
      and (p_date_to is null or spr.reported_at < (p_date_to + 1)::timestamptz)
    group by spr.currency_code
  ),
  paid_settlements as (
    select
      o.currency_code,
      sum(st.paid_amount) as verified_amount,
      count(distinct st.order_id) as completed_count,
      sum(coalesce(oi.platform_amount, 0)) as platform_amount,
      sum(coalesce(oi.commission_amount, 0)) as commission_amount
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    left join (
      select order_id, sum(settlement_due_amount - commission_amount) as platform_amount, sum(commission_amount) as commission_amount
      from public.order_items
      group by order_id
    ) oi on oi.order_id = st.order_id
    where st.supplier_id = v_supplier_id
      and st.deleted_at is null
      and st.settlement_status = 'paid'
      and st.verified_at is not null
      and (p_date_from is null or st.verified_at >= p_date_from::timestamptz)
      and (p_date_to is null or st.verified_at < (p_date_to + 1)::timestamptz)
    group by o.currency_code
  ),
  currencies as (
    select currency_code from pending_settlements
    union select currency_code from reported
    union select currency_code from paid_settlements
    union select 'GHS'::text
  )
  select
    cur.currency_code,
    round(coalesce(ps.amount, 0), 2),
    coalesce(ps.count, 0),
    round(coalesce(r.amount, 0), 2),
    round(coalesce(paid.verified_amount, 0), 2),
    coalesce(paid.completed_count, 0),
    round(coalesce(paid.platform_amount, 0), 2),
    round(coalesce(paid.commission_amount, 0), 2),
    p_date_from,
    p_date_to
  from currencies cur
  left join pending_settlements ps on ps.currency_code = cur.currency_code
  left join reported r on r.currency_code = cur.currency_code
  left join paid_settlements paid on paid.currency_code = cur.currency_code
  order by cur.currency_code;
end;
$fn$;

create or replace function public.list_supplier_settlement_history_safe(
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  settlement_id uuid,
  order_id uuid,
  order_number text,
  customer_total_amount numeric,
  supplier_amount numeric,
  platform_amount_due numeric,
  reseller_commission_due numeric,
  total_settlement_due numeric,
  currency_code text,
  settlement_status text,
  payment_reported_at timestamptz,
  settlement_created_at timestamptz,
  settlement_verified_at timestamptz,
  order_status text,
  settlement_reference_present boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_supplier_id uuid;
  v_limit integer;
  v_statuses public.settlement_status[];
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_supplier_id := public.current_verified_supplier_owner_id();
  v_limit := public.finance_history_clamped_limit(p_limit, 50);

  if p_status is null then
    v_statuses := null;
  elsif p_status = 'pending' then
    v_statuses := array['due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue']::public.settlement_status[];
  elsif p_status in ('paid', 'verified') then
    v_statuses := array['paid']::public.settlement_status[];
  else
    raise exception 'INVALID_STATUS_FILTER' using errcode = '22023';
  end if;

  return query
  with item_totals as (
    select
      oi.order_id,
      sum(oi.supplier_base_price_snapshot_amount * oi.quantity) as supplier_amount,
      sum(oi.settlement_due_amount - oi.commission_amount) as platform_amount,
      sum(oi.commission_amount) as commission_amount
    from public.order_items oi
    group by oi.order_id
  )
  select
    st.id,
    o.id,
    o.order_number,
    o.total_payable_amount,
    round(coalesce(it.supplier_amount, 0), 2),
    round(coalesce(it.platform_amount, 0), 2),
    round(coalesce(it.commission_amount, 0), 2),
    st.due_amount,
    o.currency_code,
    st.settlement_status::text,
    spr.reported_at,
    st.created_at,
    st.verified_at,
    o.order_status::text,
    st.proof_reference is not null
  from public.settlements st
  join public.orders o on o.id = st.order_id and o.deleted_at is null
  left join public.supplier_payment_reports spr on spr.order_id = o.id and spr.deleted_at is null
  left join item_totals it on it.order_id = o.id
  where st.supplier_id = v_supplier_id
    and st.deleted_at is null
    and (v_statuses is null or st.settlement_status = any(v_statuses))
    and (p_date_from is null or coalesce(st.verified_at, spr.reported_at, st.created_at) >= p_date_from::timestamptz)
    and (p_date_to is null or coalesce(st.verified_at, spr.reported_at, st.created_at) < (p_date_to + 1)::timestamptz)
    and (
      p_cursor_created_at is null
      or (st.created_at, st.id::text) < (p_cursor_created_at, coalesce(p_cursor_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)::text)
    )
  order by st.created_at desc, st.id::text desc
  limit v_limit;
end;
$fn$;

create or replace function public.get_admin_finance_summary_safe(
  p_date_from date default null,
  p_date_to date default null
)
returns table (
  currency_code text,
  pending_supplier_settlement_amount numeric,
  pending_supplier_settlement_count bigint,
  pending_reseller_withdrawal_amount numeric,
  pending_reseller_withdrawal_count bigint,
  verified_platform_revenue_amount numeric,
  verified_supplier_settlement_total numeric,
  reseller_commission_unlocked_amount numeric,
  reseller_withdrawal_paid_amount numeric,
  gross_completed_sales_amount numeric,
  completed_order_count bigint,
  date_from date,
  date_to date
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  with pending_settlements as (
    select o.currency_code, sum(st.outstanding_amount) as amount, count(*) as count
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    where st.deleted_at is null
      and st.settlement_status in ('due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue')
    group by o.currency_code
  ),
  pending_withdrawals as (
    select w.currency_code, sum(w.requested_amount) as amount, count(*) as count
    from public.withdrawals w
    where w.withdrawal_status = 'requested'
    group by w.currency_code
  ),
  verified_settlements as (
    select
      o.currency_code,
      sum(st.paid_amount) as settlement_total,
      count(distinct st.order_id) as completed_count,
      sum(o.total_payable_amount) as gross_sales,
      sum(coalesce(oi.platform_amount, 0)) as platform_amount,
      sum(coalesce(oi.commission_amount, 0)) as commission_amount
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    left join (
      select order_id, sum(settlement_due_amount - commission_amount) as platform_amount, sum(commission_amount) as commission_amount
      from public.order_items
      group by order_id
    ) oi on oi.order_id = st.order_id
    where st.deleted_at is null
      and st.settlement_status = 'paid'
      and st.verified_at is not null
      and (p_date_from is null or st.verified_at >= p_date_from::timestamptz)
      and (p_date_to is null or st.verified_at < (p_date_to + 1)::timestamptz)
    group by o.currency_code
  ),
  paid_withdrawals as (
    select w.currency_code, sum(coalesce(w.approved_amount, w.requested_amount)) as amount
    from public.withdrawals w
    where w.withdrawal_status = 'paid'
      and w.paid_at is not null
      and (p_date_from is null or w.paid_at >= p_date_from::timestamptz)
      and (p_date_to is null or w.paid_at < (p_date_to + 1)::timestamptz)
    group by w.currency_code
  ),
  currencies as (
    select currency_code from pending_settlements
    union select currency_code from pending_withdrawals
    union select currency_code from verified_settlements
    union select currency_code from paid_withdrawals
    union select 'GHS'::text
  )
  select
    cur.currency_code,
    round(coalesce(ps.amount, 0), 2),
    coalesce(ps.count, 0),
    round(coalesce(pw.amount, 0), 2),
    coalesce(pw.count, 0),
    round(coalesce(vs.platform_amount, 0), 2),
    round(coalesce(vs.settlement_total, 0), 2),
    round(coalesce(vs.commission_amount, 0), 2),
    round(coalesce(wp.amount, 0), 2),
    round(coalesce(vs.gross_sales, 0), 2),
    coalesce(vs.completed_count, 0),
    p_date_from,
    p_date_to
  from currencies cur
  left join pending_settlements ps on ps.currency_code = cur.currency_code
  left join pending_withdrawals pw on pw.currency_code = cur.currency_code
  left join verified_settlements vs on vs.currency_code = cur.currency_code
  left join paid_withdrawals wp on wp.currency_code = cur.currency_code
  order by cur.currency_code;
end;
$fn$;

create or replace function public.list_admin_settlement_history_safe(
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  settlement_id uuid,
  order_id uuid,
  order_number text,
  supplier_business_name text,
  reseller_display_name text,
  customer_total_amount numeric,
  platform_amount numeric,
  reseller_commission_amount numeric,
  total_settlement_amount numeric,
  currency_code text,
  settlement_status text,
  supplier_reported_at timestamptz,
  settlement_verified_at timestamptz,
  order_status text,
  finance_actor_present boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
  v_limit integer;
  v_statuses public.settlement_status[];
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  v_limit := public.finance_history_clamped_limit(p_limit, 50);

  if p_status is null then
    v_statuses := null;
  elsif p_status = 'pending' then
    v_statuses := array['due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue']::public.settlement_status[];
  elsif p_status in ('paid', 'verified') then
    v_statuses := array['paid']::public.settlement_status[];
  else
    raise exception 'INVALID_STATUS_FILTER' using errcode = '22023';
  end if;

  return query
  with item_totals as (
    select
      order_id,
      sum(settlement_due_amount - commission_amount) as platform_amount,
      sum(commission_amount) as commission_amount
    from public.order_items
    group by order_id
  )
  select
    st.id,
    o.id,
    o.order_number,
    s.business_name,
    rs.display_name,
    o.total_payable_amount,
    round(coalesce(it.platform_amount, 0), 2),
    round(coalesce(it.commission_amount, 0), 2),
    st.due_amount,
    o.currency_code,
    st.settlement_status::text,
    spr.reported_at,
    st.verified_at,
    o.order_status::text,
    st.verified_by_profile_id is not null
  from public.settlements st
  join public.orders o on o.id = st.order_id and o.deleted_at is null
  join public.suppliers s on s.id = st.supplier_id and s.deleted_at is null
  join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  left join public.supplier_payment_reports spr on spr.order_id = o.id and spr.deleted_at is null
  left join item_totals it on it.order_id = o.id
  where st.deleted_at is null
    and (v_statuses is null or st.settlement_status = any(v_statuses))
    and (p_date_from is null or coalesce(st.verified_at, spr.reported_at, st.created_at) >= p_date_from::timestamptz)
    and (p_date_to is null or coalesce(st.verified_at, spr.reported_at, st.created_at) < (p_date_to + 1)::timestamptz)
    and (
      p_cursor_created_at is null
      or (st.created_at, st.id::text) < (p_cursor_created_at, coalesce(p_cursor_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)::text)
    )
  order by st.created_at desc, st.id::text desc
  limit v_limit;
end;
$fn$;

create or replace function public.list_admin_withdrawal_history_safe(
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
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
  finance_actor_present boolean
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_admin_profile_id uuid;
  v_limit integer;
  v_status public.withdrawal_status;
begin
  perform public.finance_history_assert_date_range(p_date_from, p_date_to);
  v_admin_profile_id := public.current_finance_admin_profile_id();

  if v_admin_profile_id is null then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  v_limit := public.finance_history_clamped_limit(p_limit, 50);

  if p_status is not null then
    if p_status = 'pending' then
      v_status := 'requested';
    elsif p_status in ('paid', 'rejected', 'cancelled') then
      v_status := p_status::public.withdrawal_status;
    else
      raise exception 'INVALID_STATUS_FILTER' using errcode = '22023';
    end if;
  end if;

  return query
  select
    w.id,
    w.request_reference,
    coalesce(rs.display_name, p.full_name, 'Reseller'),
    case when p.email is null then null else concat(left(p.email, 2), '***@', split_part(p.email, '@', 2)) end,
    w.requested_amount,
    w.currency_code,
    w.withdrawal_status::text,
    coalesce(a.payout_method, w.provider),
    coalesce(a.account_name, w.account_name),
    coalesce(public.mask_payout_value(a.phone_number), w.account_number_masked),
    w.created_at,
    w.paid_at,
    w.payout_reference is not null,
    w.paid_by_profile_id is not null or w.approved_by_profile_id is not null
  from public.withdrawals w
  join public.resellers r on r.id = w.reseller_id
  join public.profiles p on p.id = r.profile_id
  left join public.reseller_shops rs on rs.reseller_id = r.id and rs.deleted_at is null
  left join public.reseller_payout_accounts a on a.id = w.payout_account_id
  where (v_status is null or w.withdrawal_status = v_status)
    and (p_date_from is null or coalesce(w.paid_at, w.created_at) >= p_date_from::timestamptz)
    and (p_date_to is null or coalesce(w.paid_at, w.created_at) < (p_date_to + 1)::timestamptz)
    and (
      p_cursor_created_at is null
      or (w.created_at, w.id::text) < (p_cursor_created_at, coalesce(p_cursor_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)::text)
    )
  order by w.created_at desc, w.id::text desc
  limit v_limit;
end;
$fn$;

revoke all on function public.finance_history_clamped_limit(integer, integer) from public, anon, authenticated;
revoke all on function public.finance_history_assert_date_range(date, date) from public, anon, authenticated;

revoke all on function public.get_reseller_finance_summary_safe(date, date) from public, anon, authenticated;
grant execute on function public.get_reseller_finance_summary_safe(date, date) to authenticated;

revoke all on function public.list_reseller_earnings_history_safe(text, date, date, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_reseller_earnings_history_safe(text, date, date, integer, timestamptz, uuid) to authenticated;

revoke all on function public.list_reseller_withdrawal_history_safe(text, date, date, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_reseller_withdrawal_history_safe(text, date, date, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_supplier_finance_summary_safe(date, date) from public, anon, authenticated;
grant execute on function public.get_supplier_finance_summary_safe(date, date) to authenticated;

revoke all on function public.list_supplier_settlement_history_safe(text, date, date, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_supplier_settlement_history_safe(text, date, date, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_admin_finance_summary_safe(date, date) from public, anon, authenticated;
grant execute on function public.get_admin_finance_summary_safe(date, date) to authenticated;

revoke all on function public.list_admin_settlement_history_safe(text, date, date, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_admin_settlement_history_safe(text, date, date, integer, timestamptz, uuid) to authenticated;

revoke all on function public.list_admin_withdrawal_history_safe(text, date, date, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_admin_withdrawal_history_safe(text, date, date, integer, timestamptz, uuid) to authenticated;

comment on function public.get_reseller_finance_summary_safe(date, date)
  is 'Read-only reseller finance summary. Current wallet balances are lifetime/current state; period activity uses explicit business timestamps.';
comment on function public.list_reseller_earnings_history_safe(text, date, date, integer, timestamptz, uuid)
  is 'Read-only reseller-owned earnings history. Does not fabricate per-commission withdrawal allocation.';
comment on function public.get_supplier_finance_summary_safe(date, date)
  is 'Read-only supplier-owned finance summary for payment reports and settlement obligations.';
comment on function public.get_admin_finance_summary_safe(date, date)
  is 'Finance-admin-only read summary. Verified platform revenue comes only from paid supplier settlements.';
