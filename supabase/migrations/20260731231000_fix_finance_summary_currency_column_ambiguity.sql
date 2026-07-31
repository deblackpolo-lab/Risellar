-- Forward patch for Finance Visibility Phase 1.
-- PL/pgSQL output column names are variables, so currency CTE references must
-- be qualified to avoid runtime ambiguity.

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
    union
    select pw.result_currency_code from period_withdrawals pw
    union
    select 'GHS'::text
  )
  select
    cur.result_currency_code,
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
  left join period_commissions pc on pc.result_currency_code = cur.result_currency_code
  left join period_withdrawals pw on pw.result_currency_code = cur.result_currency_code
  where r.id = v_reseller_id
    and r.deleted_at is null
  order by cur.result_currency_code;
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
      o.currency_code as result_currency_code,
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
      spr.currency_code as result_currency_code,
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
      o.currency_code as result_currency_code,
      sum(st.paid_amount) as verified_amount,
      count(distinct st.order_id) as completed_count,
      sum(coalesce(oi.platform_amount, 0)) as platform_amount,
      sum(coalesce(oi.commission_amount, 0)) as commission_amount
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    left join (
      select oi_inner.order_id, sum(oi_inner.settlement_due_amount - oi_inner.commission_amount) as platform_amount, sum(oi_inner.commission_amount) as commission_amount
      from public.order_items oi_inner
      group by oi_inner.order_id
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
    select ps.result_currency_code from pending_settlements ps
    union select r.result_currency_code from reported r
    union select paid.result_currency_code from paid_settlements paid
    union select 'GHS'::text
  )
  select
    cur.result_currency_code,
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
  left join pending_settlements ps on ps.result_currency_code = cur.result_currency_code
  left join reported r on r.result_currency_code = cur.result_currency_code
  left join paid_settlements paid on paid.result_currency_code = cur.result_currency_code
  order by cur.result_currency_code;
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
    select o.currency_code as result_currency_code, sum(st.outstanding_amount) as amount, count(*) as count
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    where st.deleted_at is null
      and st.settlement_status in ('due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue')
    group by o.currency_code
  ),
  pending_withdrawals as (
    select w.currency_code as result_currency_code, sum(w.requested_amount) as amount, count(*) as count
    from public.withdrawals w
    where w.withdrawal_status = 'requested'
    group by w.currency_code
  ),
  verified_settlements as (
    select
      o.currency_code as result_currency_code,
      sum(st.paid_amount) as settlement_total,
      count(distinct st.order_id) as completed_count,
      sum(o.total_payable_amount) as gross_sales,
      sum(coalesce(oi.platform_amount, 0)) as platform_amount,
      sum(coalesce(oi.commission_amount, 0)) as commission_amount
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    left join (
      select oi_inner.order_id, sum(oi_inner.settlement_due_amount - oi_inner.commission_amount) as platform_amount, sum(oi_inner.commission_amount) as commission_amount
      from public.order_items oi_inner
      group by oi_inner.order_id
    ) oi on oi.order_id = st.order_id
    where st.deleted_at is null
      and st.settlement_status = 'paid'
      and st.verified_at is not null
      and (p_date_from is null or st.verified_at >= p_date_from::timestamptz)
      and (p_date_to is null or st.verified_at < (p_date_to + 1)::timestamptz)
    group by o.currency_code
  ),
  paid_withdrawals as (
    select w.currency_code as result_currency_code, sum(coalesce(w.approved_amount, w.requested_amount)) as amount
    from public.withdrawals w
    where w.withdrawal_status = 'paid'
      and w.paid_at is not null
      and (p_date_from is null or w.paid_at >= p_date_from::timestamptz)
      and (p_date_to is null or w.paid_at < (p_date_to + 1)::timestamptz)
    group by w.currency_code
  ),
  currencies as (
    select ps.result_currency_code from pending_settlements ps
    union select pw.result_currency_code from pending_withdrawals pw
    union select vs.result_currency_code from verified_settlements vs
    union select wp.result_currency_code from paid_withdrawals wp
    union select 'GHS'::text
  )
  select
    cur.result_currency_code,
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
  left join pending_settlements ps on ps.result_currency_code = cur.result_currency_code
  left join pending_withdrawals pw on pw.result_currency_code = cur.result_currency_code
  left join verified_settlements vs on vs.result_currency_code = cur.result_currency_code
  left join paid_withdrawals wp on wp.result_currency_code = cur.result_currency_code
  order by cur.result_currency_code;
end;
$fn$;
