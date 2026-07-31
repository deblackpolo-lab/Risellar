-- Fix supplier dashboard metrics currency ambiguity.
-- Forward patch only because 20260731234500_real_dashboard_metrics_safe_read_rpcs.sql was applied to DEVELOPMENT.

create or replace function public.get_supplier_dashboard_summary_safe(
  p_date_from date default null,
  p_date_to date default null
)
returns table (
  currency_code text,
  placed_pending_confirmation_count bigint,
  supplier_confirmed_count bigint,
  supplier_preparing_count bigint,
  ready_for_delivery_count bigint,
  delivery_arranged_count bigint,
  out_for_delivery_count bigint,
  delivered_count bigint,
  payment_reported_count bigint,
  completed_count bigint,
  supplier_rejected_count bigint,
  pending_settlement_amount numeric,
  pending_settlement_count bigint,
  customer_payments_reported_amount numeric,
  verified_settlement_amount numeric,
  completed_orders_count bigint,
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
  perform public.dashboard_metrics_assert_date_range(p_date_from, p_date_to);
  v_supplier_id := public.current_verified_supplier_owner_id();

  return query
  with supplier_orders as (
    select distinct
      o.id,
      o.order_status::text as order_status,
      o.currency_code as order_currency_code,
      o.total_payable_amount,
      o.completed_at,
      o.created_at
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    where oi.supplier_id = v_supplier_id
      and o.deleted_at is null
  ),
  status_counts as (
    select
      coalesce(so.order_currency_code, 'GHS') as result_currency_code,
      count(*) filter (where so.order_status = 'placed_pending_confirmation') as placed_pending_confirmation_count,
      count(*) filter (where so.order_status = 'supplier_confirmed') as supplier_confirmed_count,
      count(*) filter (where so.order_status = 'supplier_preparing') as supplier_preparing_count,
      count(*) filter (where so.order_status = 'ready_for_delivery') as ready_for_delivery_count,
      count(*) filter (where so.order_status = 'delivery_arranged') as delivery_arranged_count,
      count(*) filter (where so.order_status = 'out_for_delivery') as out_for_delivery_count,
      count(*) filter (where so.order_status = 'delivered') as delivered_count,
      count(*) filter (where so.order_status = 'payment_reported') as payment_reported_count,
      count(*) filter (where so.order_status = 'completed') as completed_count,
      count(*) filter (where so.order_status = 'supplier_rejected') as supplier_rejected_count
    from supplier_orders so
    group by coalesce(so.order_currency_code, 'GHS')
  ),
  pending_settlements as (
    select
      o.currency_code as result_currency_code,
      sum(st.outstanding_amount) as amount,
      count(*) as count
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    where st.supplier_id = v_supplier_id
      and st.deleted_at is null
      and st.settlement_status in ('due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue', 'disputed')
    group by o.currency_code
  ),
  reported_payments as (
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
  verified_settlements as (
    select
      o.currency_code as result_currency_code,
      sum(st.due_amount) as amount
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    where st.supplier_id = v_supplier_id
      and st.deleted_at is null
      and st.settlement_status = 'paid'
      and st.verified_at is not null
      and (p_date_from is null or st.verified_at >= p_date_from::timestamptz)
      and (p_date_to is null or st.verified_at < (p_date_to + 1)::timestamptz)
    group by o.currency_code
  ),
  completed_period as (
    select
      so.order_currency_code as result_currency_code,
      count(*) as count
    from supplier_orders so
    where so.order_status = 'completed'
      and (p_date_from is null or coalesce(so.completed_at, so.created_at) >= p_date_from::timestamptz)
      and (p_date_to is null or coalesce(so.completed_at, so.created_at) < (p_date_to + 1)::timestamptz)
    group by so.order_currency_code
  ),
  currencies as (
    select result_currency_code from status_counts
    union select result_currency_code from pending_settlements
    union select result_currency_code from reported_payments
    union select result_currency_code from verified_settlements
    union select result_currency_code from completed_period
    union select 'GHS'::text
  )
  select
    cur.result_currency_code,
    coalesce(sc.placed_pending_confirmation_count, 0),
    coalesce(sc.supplier_confirmed_count, 0),
    coalesce(sc.supplier_preparing_count, 0),
    coalesce(sc.ready_for_delivery_count, 0),
    coalesce(sc.delivery_arranged_count, 0),
    coalesce(sc.out_for_delivery_count, 0),
    coalesce(sc.delivered_count, 0),
    coalesce(sc.payment_reported_count, 0),
    coalesce(sc.completed_count, 0),
    coalesce(sc.supplier_rejected_count, 0),
    round(coalesce(ps.amount, 0), 2),
    coalesce(ps.count, 0),
    round(coalesce(rp.amount, 0), 2),
    round(coalesce(vs.amount, 0), 2),
    coalesce(cp.count, 0),
    p_date_from,
    p_date_to
  from currencies cur
  left join status_counts sc on sc.result_currency_code = cur.result_currency_code
  left join pending_settlements ps on ps.result_currency_code = cur.result_currency_code
  left join reported_payments rp on rp.result_currency_code = cur.result_currency_code
  left join verified_settlements vs on vs.result_currency_code = cur.result_currency_code
  left join completed_period cp on cp.result_currency_code = cur.result_currency_code
  order by cur.result_currency_code;
end;
$fn$;

comment on function public.get_supplier_dashboard_summary_safe(date, date)
  is 'Read-only supplier dashboard metrics scoped to the authenticated approved supplier owner. Current order and pending settlement values are not date-filtered; period metrics are date-filtered. Currency references are UUID-safe and PL/pgSQL variable-safe.';
