-- Real Dashboard Metrics Phase 1: role-scoped dashboard summaries.
-- Read-only safe RPCs. These functions do not create orders, payments, stock reservations,
-- delivery records, settlements, commissions, withdrawals, or audit rows.

create index if not exists orders_customer_status_created_dashboard_idx
  on public.orders(customer_id, order_status, created_at desc, id)
  where deleted_at is null;

create index if not exists orders_reseller_status_created_dashboard_idx
  on public.orders(reseller_id, order_status, created_at desc, id)
  where deleted_at is null;

create index if not exists order_items_supplier_order_dashboard_idx
  on public.order_items(supplier_id, order_id);

create or replace function public.dashboard_metrics_assert_date_range(p_date_from date, p_date_to date)
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

drop function if exists public.get_customer_dashboard_summary_safe();

create or replace function public.get_customer_dashboard_summary_safe()
returns table (
  active_orders_count bigint,
  completed_orders_count bigint,
  rejected_orders_count bigint,
  total_orders_count bigint,
  latest_active_order_id uuid,
  latest_active_order_number text,
  latest_active_product_name text,
  latest_active_status_label text,
  latest_active_total_payable_amount numeric,
  latest_active_currency_code text,
  latest_active_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
  v_customer_id uuid;
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  select c.id
  into v_customer_id
  from public.customers c
  join public.profiles p on p.id = c.profile_id
  where c.profile_id = v_profile_id
    and p.primary_role = 'customer'
    and p.account_status = 'active'
    and p.deleted_at is null
    and c.customer_status = 'active'
    and c.deleted_at is null
    and not exists (
      select 1
      from public.admin_staff a
      where a.profile_id = p.id
        and a.staff_status = 'active'
        and a.deleted_at is null
    )
  order by c.created_at asc, c.id::text asc
  limit 1;

  if v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  return query
  with own_orders as (
    select
      o.id,
      o.order_number,
      o.order_status::text as order_status,
      o.total_payable_amount,
      o.currency_code,
      o.created_at,
      coalesce(cd.product_name_snapshot, p.name) as product_name
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    join public.products p on p.id = oi.product_id
    left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
    where o.customer_id = v_customer_id
      and o.deleted_at is null
  ),
  counts as (
    select
      count(*) filter (where order_status not in ('completed', 'supplier_rejected', 'cancelled', 'customer_refused', 'failed', 'disputed')) as active_count,
      count(*) filter (where order_status = 'completed') as completed_count,
      count(*) filter (where order_status in ('supplier_rejected', 'cancelled', 'customer_refused', 'failed', 'disputed')) as rejected_count,
      count(*) as total_count
    from own_orders
  ),
  latest_active as (
    select *
    from own_orders
    where order_status not in ('completed', 'supplier_rejected', 'cancelled', 'customer_refused', 'failed', 'disputed')
    order by created_at desc, id::text desc
    limit 1
  )
  select
    coalesce(c.active_count, 0),
    coalesce(c.completed_count, 0),
    coalesce(c.rejected_count, 0),
    coalesce(c.total_count, 0),
    la.id,
    la.order_number,
    la.product_name,
    case
      when la.order_status = 'placed_pending_confirmation' then 'Placed - waiting for supplier confirmation'
      when la.order_status = 'supplier_confirmed' then 'Supplier confirmed your order'
      when la.order_status = 'supplier_preparing' then 'Supplier is preparing your order'
      when la.order_status = 'ready_for_delivery' then 'Your order is ready for delivery arrangement'
      when la.order_status = 'delivery_arranged' then 'Delivery arrangement confirmed'
      when la.order_status = 'out_for_delivery' then 'Your order is out for delivery'
      when la.order_status = 'delivered' then 'Your order has been delivered'
      when la.order_status = 'payment_reported' then 'Payment reported by supplier'
      else null
    end,
    la.total_payable_amount,
    la.currency_code,
    la.created_at
  from counts c
  left join latest_active la on true;
end;
$fn$;

drop function if exists public.get_reseller_dashboard_summary_safe(date, date);

create or replace function public.get_reseller_dashboard_summary_safe(
  p_date_from date default null,
  p_date_to date default null
)
returns table (
  currency_code text,
  locked_commission_amount numeric,
  available_balance_amount numeric,
  pending_withdrawal_amount numeric,
  withdrawn_amount numeric,
  attributed_orders_count bigint,
  completed_sales_count bigint,
  rejected_orders_count bigint,
  commission_earned_amount numeric,
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
  perform public.dashboard_metrics_assert_date_range(p_date_from, p_date_to);
  v_reseller_id := public.current_verified_reseller_id();

  return query
  with period_orders as (
    select
      o.currency_code as result_currency_code,
      count(*) as attributed_count,
      count(*) filter (where o.order_status::text = 'completed') as completed_count,
      count(*) filter (where o.order_status::text in ('supplier_rejected', 'cancelled', 'customer_refused', 'failed')) as rejected_count
    from public.orders o
    where o.reseller_id = v_reseller_id
      and o.deleted_at is null
      and (p_date_from is null or o.created_at >= p_date_from::timestamptz)
      and (p_date_to is null or o.created_at < (p_date_to + 1)::timestamptz)
    group by o.currency_code
  ),
  period_commissions as (
    select
      coalesce(o.currency_code, 'GHS') as result_currency_code,
      sum(c.commission_amount) as earned_amount
    from public.commissions c
    left join public.orders o on o.id = c.order_id and o.deleted_at is null
    where c.reseller_id = v_reseller_id
      and (p_date_from is null or c.created_at >= p_date_from::timestamptz)
      and (p_date_to is null or c.created_at < (p_date_to + 1)::timestamptz)
    group by coalesce(o.currency_code, 'GHS')
  ),
  currencies as (
    select result_currency_code from period_orders
    union select result_currency_code from period_commissions
    union select 'GHS'::text
  )
  select
    cur.result_currency_code,
    r.commission_pending_amount,
    r.commission_available_amount,
    r.commission_pending_withdrawal_amount,
    r.commission_withdrawn_amount,
    coalesce(po.attributed_count, 0),
    coalesce(po.completed_count, 0),
    coalesce(po.rejected_count, 0),
    round(coalesce(pc.earned_amount, 0), 2),
    p_date_from,
    p_date_to
  from public.resellers r
  cross join currencies cur
  left join period_orders po on po.result_currency_code = cur.result_currency_code
  left join period_commissions pc on pc.result_currency_code = cur.result_currency_code
  where r.id = v_reseller_id
    and r.deleted_at is null
  order by cur.result_currency_code;
end;
$fn$;

drop function if exists public.get_supplier_dashboard_summary_safe(date, date);

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
      o.currency_code,
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
      coalesce(currency_code, 'GHS') as result_currency_code,
      count(*) filter (where order_status = 'placed_pending_confirmation') as placed_pending_confirmation_count,
      count(*) filter (where order_status = 'supplier_confirmed') as supplier_confirmed_count,
      count(*) filter (where order_status = 'supplier_preparing') as supplier_preparing_count,
      count(*) filter (where order_status = 'ready_for_delivery') as ready_for_delivery_count,
      count(*) filter (where order_status = 'delivery_arranged') as delivery_arranged_count,
      count(*) filter (where order_status = 'out_for_delivery') as out_for_delivery_count,
      count(*) filter (where order_status = 'delivered') as delivered_count,
      count(*) filter (where order_status = 'payment_reported') as payment_reported_count,
      count(*) filter (where order_status = 'completed') as completed_count,
      count(*) filter (where order_status = 'supplier_rejected') as supplier_rejected_count
    from supplier_orders
    group by coalesce(currency_code, 'GHS')
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
      currency_code as result_currency_code,
      count(*) as count
    from supplier_orders
    where order_status = 'completed'
      and (p_date_from is null or coalesce(completed_at, created_at) >= p_date_from::timestamptz)
      and (p_date_to is null or coalesce(completed_at, created_at) < (p_date_to + 1)::timestamptz)
    group by currency_code
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

drop function if exists public.get_admin_dashboard_summary_safe(date, date);

create or replace function public.get_admin_dashboard_summary_safe(
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
  gross_completed_sales_amount numeric,
  reseller_commission_unlocked_amount numeric,
  withdrawals_paid_amount numeric,
  completed_orders_count bigint,
  active_supplier_count bigint,
  active_reseller_count bigint,
  orders_waiting_supplier_confirmation_count bigint,
  new_supplier_count bigint,
  new_reseller_count bigint,
  date_from date,
  date_to date
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.dashboard_metrics_assert_date_range(p_date_from, p_date_to);

  if not public.has_admin_role('finance_staff') then
    raise exception 'FINANCE_ADMIN_REQUIRED' using errcode = '42501';
  end if;

  return query
  with pending_settlements as (
    select o.currency_code as result_currency_code, sum(st.outstanding_amount) as amount, count(*) as count
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    where st.deleted_at is null
      and st.settlement_status in ('due', 'proof_submitted', 'verifying', 'partially_settled', 'overdue', 'disputed')
    group by o.currency_code
  ),
  pending_withdrawals as (
    select w.currency_code as result_currency_code, sum(w.requested_amount) as amount, count(*) as count
    from public.withdrawals w
    where w.withdrawal_status = 'requested'
    group by w.currency_code
  ),
  verified_platform as (
    select
      o.currency_code as result_currency_code,
      sum(greatest(oi.settlement_due_amount - oi.commission_amount, 0)) as platform_amount,
      sum(o.total_payable_amount) as gross_amount,
      count(distinct o.id) as completed_count
    from public.settlements st
    join public.orders o on o.id = st.order_id and o.deleted_at is null
    join public.order_items oi on oi.order_id = o.id
    where st.deleted_at is null
      and st.settlement_status = 'paid'
      and st.verified_at is not null
      and o.order_status::text = 'completed'
      and (p_date_from is null or st.verified_at >= p_date_from::timestamptz)
      and (p_date_to is null or st.verified_at < (p_date_to + 1)::timestamptz)
    group by o.currency_code
  ),
  commission_unlocked as (
    select
      o.currency_code as result_currency_code,
      sum(c.commission_amount) as amount
    from public.commissions c
    join public.orders o on o.id = c.order_id and o.deleted_at is null
    where c.commission_status in ('available', 'withdrawal_requested', 'paid')
      and c.available_at is not null
      and (p_date_from is null or c.available_at >= p_date_from::timestamptz)
      and (p_date_to is null or c.available_at < (p_date_to + 1)::timestamptz)
    group by o.currency_code
  ),
  paid_withdrawals as (
    select
      w.currency_code as result_currency_code,
      sum(coalesce(w.approved_amount, w.requested_amount)) as amount
    from public.withdrawals w
    where w.withdrawal_status = 'paid'
      and w.paid_at is not null
      and (p_date_from is null or w.paid_at >= p_date_from::timestamptz)
      and (p_date_to is null or w.paid_at < (p_date_to + 1)::timestamptz)
    group by w.currency_code
  ),
  currencies as (
    select result_currency_code from pending_settlements
    union select result_currency_code from pending_withdrawals
    union select result_currency_code from verified_platform
    union select result_currency_code from commission_unlocked
    union select result_currency_code from paid_withdrawals
    union select 'GHS'::text
  ),
  ops as (
    select
      (select count(*) from public.suppliers s where s.supplier_status = 'active' and s.verification_status = 'approved' and s.deleted_at is null) as active_supplier_count,
      (select count(*) from public.resellers r where r.approval_status = 'approved' and r.deleted_at is null) as active_reseller_count,
      (select count(*) from public.orders o where o.order_status::text = 'placed_pending_confirmation' and o.deleted_at is null) as waiting_count,
      (select count(*) from public.suppliers s where s.deleted_at is null and (p_date_from is null or s.created_at >= p_date_from::timestamptz) and (p_date_to is null or s.created_at < (p_date_to + 1)::timestamptz)) as new_supplier_count,
      (select count(*) from public.resellers r where r.deleted_at is null and (p_date_from is null or r.created_at >= p_date_from::timestamptz) and (p_date_to is null or r.created_at < (p_date_to + 1)::timestamptz)) as new_reseller_count
  )
  select
    cur.result_currency_code,
    round(coalesce(ps.amount, 0), 2),
    coalesce(ps.count, 0),
    round(coalesce(pw.amount, 0), 2),
    coalesce(pw.count, 0),
    round(coalesce(vp.platform_amount, 0), 2),
    round(coalesce(vp.gross_amount, 0), 2),
    round(coalesce(cu.amount, 0), 2),
    round(coalesce(paid.amount, 0), 2),
    coalesce(vp.completed_count, 0),
    ops.active_supplier_count,
    ops.active_reseller_count,
    ops.waiting_count,
    ops.new_supplier_count,
    ops.new_reseller_count,
    p_date_from,
    p_date_to
  from currencies cur
  cross join ops
  left join pending_settlements ps on ps.result_currency_code = cur.result_currency_code
  left join pending_withdrawals pw on pw.result_currency_code = cur.result_currency_code
  left join verified_platform vp on vp.result_currency_code = cur.result_currency_code
  left join commission_unlocked cu on cu.result_currency_code = cur.result_currency_code
  left join paid_withdrawals paid on paid.result_currency_code = cur.result_currency_code
  order by cur.result_currency_code;
end;
$fn$;

revoke all on function public.dashboard_metrics_assert_date_range(date, date) from public, anon, authenticated;
grant execute on function public.dashboard_metrics_assert_date_range(date, date) to authenticated;

revoke all on function public.get_customer_dashboard_summary_safe() from public, anon, authenticated;
grant execute on function public.get_customer_dashboard_summary_safe() to authenticated;

revoke all on function public.get_reseller_dashboard_summary_safe(date, date) from public, anon, authenticated;
grant execute on function public.get_reseller_dashboard_summary_safe(date, date) to authenticated;

revoke all on function public.get_supplier_dashboard_summary_safe(date, date) from public, anon, authenticated;
grant execute on function public.get_supplier_dashboard_summary_safe(date, date) to authenticated;

revoke all on function public.get_admin_dashboard_summary_safe(date, date) from public, anon, authenticated;
grant execute on function public.get_admin_dashboard_summary_safe(date, date) to authenticated;

comment on function public.get_customer_dashboard_summary_safe()
  is 'Read-only customer dashboard metrics scoped to the authenticated active customer profile.';
comment on function public.get_reseller_dashboard_summary_safe(date, date)
  is 'Read-only reseller dashboard metrics scoped to the authenticated approved reseller. Current wallet balances are not date-filtered; period metrics are date-filtered.';
comment on function public.get_supplier_dashboard_summary_safe(date, date)
  is 'Read-only supplier dashboard metrics scoped to the authenticated approved supplier owner. Current order and pending settlement values are not date-filtered; period metrics are date-filtered.';
comment on function public.get_admin_dashboard_summary_safe(date, date)
  is 'Read-only finance-admin dashboard metrics grouped by currency. Verified platform revenue is separate from gross completed sales.';
