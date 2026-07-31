-- Forward patch for Finance Visibility Phase 1 admin settlement history.
-- Qualifies order_item order_id references inside PL/pgSQL return contexts.

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
      oi.order_id as item_order_id,
      sum(oi.settlement_due_amount - oi.commission_amount) as platform_amount,
      sum(oi.commission_amount) as commission_amount
    from public.order_items oi
    group by oi.order_id
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
  left join item_totals it on it.item_order_id = o.id
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
