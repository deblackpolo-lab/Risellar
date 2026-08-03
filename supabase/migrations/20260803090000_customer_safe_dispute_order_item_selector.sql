-- D13-B customer-safe order item selector for item-specific dispute reporting.
-- Read-only RPC. Does not mutate orders, disputes, stock, payments, delivery,
-- settlements, commissions, withdrawals, returns, refunds, or notifications.

create or replace function public.list_customer_order_items_for_dispute_safe(
  p_order_id uuid
)
returns table (
  order_item_id uuid,
  safe_item_name text,
  safe_variant_summary text,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  currency_code text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_customer_id uuid;
begin
  if p_order_id is null then
    return;
  end if;

  v_customer_id := public.current_dispute_customer_id();

  if v_customer_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.orders o
    where o.id = p_order_id
      and o.customer_id = v_customer_id
      and o.deleted_at is null
  ) then
    return;
  end if;

  return query
  select
    oi.id as order_item_id,
    coalesce(nullif(trim(p.name), ''), 'Order item') as safe_item_name,
    nullif(trim(coalesce(pv.variant_name, '')), '') as safe_variant_summary,
    oi.quantity,
    oi.customer_product_price_snapshot_amount as final_customer_price_amount,
    oi.line_total_amount,
    o.currency_code
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  left join public.products p on p.id = oi.product_id and p.deleted_at is null
  left join public.product_variants pv on pv.id = oi.variant_id and pv.deleted_at is null
  where o.id = p_order_id
    and o.customer_id = v_customer_id
    and o.deleted_at is null
  order by oi.created_at asc, oi.id::text asc
  limit 25;
end;
$fn$;

revoke all on function public.list_customer_order_items_for_dispute_safe(uuid) from public, anon, authenticated;
grant execute on function public.list_customer_order_items_for_dispute_safe(uuid) to authenticated;

comment on function public.list_customer_order_items_for_dispute_safe(uuid)
  is 'Customer-only safe item selector for item-specific disputes. Returns order item id, safe product/variant summary, quantity, customer price, line total, and currency for the caller owned order only. Does not expose supplier ids, supplier private data, margins, commissions, settlements, payout data, stock internals, or admin metadata.';
