-- Customer Order History Phase 1: customer-safe order history and summary read RPCs.
-- Forward-only migration. These RPCs are read-only and do not create orders, payments,
-- stock reservations, delivery quotes, commissions, settlements, withdrawals, refunds,
-- cancellations, returns, disputes, or delivery/payment side effects.

drop function if exists public.list_customer_orders_safe(text, text, date, date, integer, timestamptz, uuid);

create or replace function public.list_customer_orders_safe(
  p_group text default null,
  p_search text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_limit integer default 20,
  p_cursor_created_at timestamptz default null,
  p_cursor_order_id uuid default null
)
returns table (
  order_id uuid,
  order_number text,
  created_at timestamptz,
  updated_at timestamptz,
  order_status_label text,
  order_status_group text,
  completed_at timestamptz,
  rejected_at timestamptz,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  total_payable_amount numeric,
  currency_code text,
  payment_method_label text,
  payment_collection_label text,
  delivery_status_label text,
  reseller_shop_name text,
  reseller_shop_slug text,
  detail_href text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
  v_customer_id uuid;
  v_group text := lower(nullif(trim(coalesce(p_group, '')), ''));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED'
      using errcode = '28000';
  end if;

  if v_group is not null and v_group not in ('all', 'active', 'completed', 'rejected') then
    raise exception 'INVALID_ORDER_GROUP'
      using errcode = '23514';
  end if;

  if v_search is not null and length(v_search) > 120 then
    raise exception 'SEARCH_TOO_LONG'
      using errcode = '23514';
  end if;

  if p_date_from is not null and p_date_to is not null and p_date_from > p_date_to then
    raise exception 'INVALID_DATE_RANGE'
      using errcode = '23514';
  end if;

  select c.id
  into v_customer_id
  from public.customers c
  join public.profiles p on p.id = c.profile_id
  where p.id = v_profile_id
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
    return;
  end if;

  return query
  with customer_orders as (
    select
      o.id,
      o.order_number,
      o.created_at,
      o.updated_at,
      o.order_status,
      o.payment_method,
      o.payment_collection_status,
      o.delivery_status,
      o.completed_at,
      o.supplier_rejected_at,
      coalesce(cd.product_name_snapshot, p.name) as product_name,
      coalesce(cd.product_slug_snapshot, p.slug) as product_slug,
      coalesce(cd.product_image_snapshot, '{}'::jsonb) as product_image_snapshot,
      oi.quantity,
      oi.customer_product_price_snapshot_amount,
      oi.line_total_amount,
      o.total_payable_amount,
      o.currency_code,
      rs.display_name as reseller_shop_name,
      rs.shop_slug as reseller_shop_slug,
      case
        when o.order_status::text = 'completed' then 'completed'
        when o.order_status::text in ('supplier_rejected', 'cancelled', 'customer_refused', 'failed', 'disputed') then 'rejected'
        else 'active'
      end as safe_group
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    join public.products p on p.id = oi.product_id
    left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
    left join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
    where o.customer_id = v_customer_id
      and o.deleted_at is null
  )
  select
    co.id as order_id,
    co.order_number,
    co.created_at,
    co.updated_at,
    case
      when co.order_status::text = 'placed_pending_confirmation' then 'Placed - waiting for supplier confirmation'
      when co.order_status::text = 'supplier_confirmed' then 'Supplier confirmed your order'
      when co.order_status::text = 'supplier_rejected' then 'Supplier could not fulfil this order'
      when co.order_status::text = 'supplier_preparing' then 'Supplier is preparing your order'
      when co.order_status::text = 'ready_for_delivery' then 'Your order is ready for delivery arrangement'
      when co.order_status::text = 'delivery_arranged' then 'Delivery arrangement confirmed'
      when co.order_status::text = 'out_for_delivery' then 'Your order is out for delivery'
      when co.order_status::text = 'delivered' then 'Your order has been delivered'
      when co.order_status::text = 'payment_reported' then 'Payment reported by supplier'
      when co.order_status::text = 'completed' then 'Completed'
      when co.order_status::text = 'cancelled' then 'Cancelled'
      when co.order_status::text = 'customer_refused' then 'Customer refused'
      when co.order_status::text = 'failed' then 'Failed'
      when co.order_status::text = 'disputed' then 'Disputed'
      else 'Order status unavailable'
    end as order_status_label,
    co.safe_group as order_status_group,
    co.completed_at,
    co.supplier_rejected_at as rejected_at,
    co.product_name,
    co.product_slug,
    co.product_image_snapshot,
    co.quantity,
    co.customer_product_price_snapshot_amount as final_customer_price_amount,
    co.line_total_amount,
    co.total_payable_amount,
    co.currency_code,
    case co.payment_method
      when 'pay_on_delivery' then 'Pay on Delivery'
      else 'Payment method unavailable'
    end as payment_method_label,
    case co.payment_collection_status::text
      when 'not_collected' then 'Payment not collected'
      when 'supplier_reported' then 'Payment reported by supplier'
      when 'pending' then 'Payment pending'
      when 'collected' then 'Payment collected'
      when 'failed' then 'Payment failed'
      when 'refunded' then 'Payment refunded'
      when 'disputed' then 'Payment disputed'
      when 'settlement_verified' then 'Payment verified for settlement'
      else 'Payment status unavailable'
    end as payment_collection_label,
    case
      when co.order_status::text = 'payment_reported' then 'Delivery completed - supplier reported receiving Pay on Delivery payment'
      when co.order_status::text = 'delivered' then 'Delivery completed - payment has not yet been confirmed in Risellar'
      when co.order_status::text = 'out_for_delivery' then 'Delivery has started outside Risellar'
      when co.order_status::text = 'delivery_arranged' then 'Delivery was arranged outside Risellar'
      when co.delivery_status = 'estimate_selected' then 'Delivery has not been arranged yet'
      when co.delivery_status = 'quote_pending' then 'Delivery quote pending'
      when co.delivery_status = 'quote_ready' then 'Delivery quote ready'
      when co.delivery_status = 'quote_approved' then 'Delivery quote approved'
      when co.delivery_status = 'quote_rejected' then 'Delivery quote rejected'
      when co.delivery_status = 'ready' then 'Delivery ready'
      when co.delivery_status = 'out_for_delivery' then 'Out for delivery'
      when co.delivery_status = 'delivered' then 'Delivered'
      when co.delivery_status = 'failed' then 'Delivery failed'
      when co.delivery_status = 'cancelled' then 'Delivery cancelled'
      else 'Delivery status unavailable'
    end as delivery_status_label,
    co.reseller_shop_name,
    co.reseller_shop_slug,
    '/customer/orders/' || co.id::text as detail_href
  from customer_orders co
  where (v_group is null or v_group = 'all' or co.safe_group = v_group)
    and (p_date_from is null or co.created_at >= p_date_from::timestamptz)
    and (p_date_to is null or co.created_at < (p_date_to + 1)::timestamptz)
    and (
      v_search is null
      or co.order_number ilike '%' || v_search || '%'
      or co.product_name ilike '%' || v_search || '%'
      or co.reseller_shop_name ilike '%' || v_search || '%'
    )
    and (
      p_cursor_created_at is null
      or co.created_at < p_cursor_created_at
      or (
        p_cursor_order_id is not null
        and co.created_at = p_cursor_created_at
        and co.id::text < p_cursor_order_id::text
      )
    )
  order by co.created_at desc, co.id::text desc
  limit v_limit;
end;
$fn$;

drop function if exists public.get_customer_order_summary_safe();

create or replace function public.get_customer_order_summary_safe()
returns table (
  total_order_count bigint,
  active_order_count bigint,
  completed_order_count bigint,
  rejected_order_count bigint,
  latest_order_created_at timestamptz,
  latest_order_number text,
  latest_order_status_label text,
  latest_total_payable_amount numeric,
  currency_code text
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
    raise exception 'AUTH_REQUIRED'
      using errcode = '28000';
  end if;

  select c.id
  into v_customer_id
  from public.customers c
  join public.profiles p on p.id = c.profile_id
  where p.id = v_profile_id
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
    return query select 0::bigint, 0::bigint, 0::bigint, 0::bigint, null::timestamptz, null::text, null::text, null::numeric, null::text;
    return;
  end if;

  return query
  with scoped_orders as (
    select
      o.id,
      o.order_number,
      o.created_at,
      o.total_payable_amount,
      o.currency_code,
      o.order_status,
      case
        when o.order_status::text = 'completed' then 'completed'
        when o.order_status::text in ('supplier_rejected', 'cancelled', 'customer_refused', 'failed', 'disputed') then 'rejected'
        else 'active'
      end as safe_group
    from public.orders o
    where o.customer_id = v_customer_id
      and o.deleted_at is null
  ),
  latest_order as (
    select *
    from scoped_orders
    order by created_at desc, id::text desc
    limit 1
  )
  select
    count(*)::bigint as total_order_count,
    count(*) filter (where so.safe_group = 'active')::bigint as active_order_count,
    count(*) filter (where so.safe_group = 'completed')::bigint as completed_order_count,
    count(*) filter (where so.safe_group = 'rejected')::bigint as rejected_order_count,
    lo.created_at as latest_order_created_at,
    lo.order_number as latest_order_number,
    case
      when lo.order_status::text = 'placed_pending_confirmation' then 'Placed - waiting for supplier confirmation'
      when lo.order_status::text = 'supplier_confirmed' then 'Supplier confirmed your order'
      when lo.order_status::text = 'supplier_rejected' then 'Supplier could not fulfil this order'
      when lo.order_status::text = 'supplier_preparing' then 'Supplier is preparing your order'
      when lo.order_status::text = 'ready_for_delivery' then 'Your order is ready for delivery arrangement'
      when lo.order_status::text = 'delivery_arranged' then 'Delivery arrangement confirmed'
      when lo.order_status::text = 'out_for_delivery' then 'Your order is out for delivery'
      when lo.order_status::text = 'delivered' then 'Your order has been delivered'
      when lo.order_status::text = 'payment_reported' then 'Payment reported by supplier'
      when lo.order_status::text = 'completed' then 'Completed'
      when lo.order_status::text = 'cancelled' then 'Cancelled'
      when lo.order_status::text = 'customer_refused' then 'Customer refused'
      when lo.order_status::text = 'failed' then 'Failed'
      when lo.order_status::text = 'disputed' then 'Disputed'
      else null
    end as latest_order_status_label,
    lo.total_payable_amount as latest_total_payable_amount,
    lo.currency_code
  from scoped_orders so
  left join latest_order lo on true
  group by lo.created_at, lo.order_number, lo.order_status, lo.total_payable_amount, lo.currency_code;
end;
$fn$;

revoke all on function public.list_customer_orders_safe(text, text, date, date, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_customer_orders_safe(text, text, date, date, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_customer_order_summary_safe() from public, anon, authenticated;
grant execute on function public.get_customer_order_summary_safe() to authenticated;

comment on function public.list_customer_orders_safe(text, text, date, date, integer, timestamptz, uuid)
  is 'Customer-only read RPC for order history. Resolves customer from the authenticated profile and exposes public/customer-safe order summary fields only.';

comment on function public.get_customer_order_summary_safe()
  is 'Customer-only read RPC for customer order dashboard counts. Does not expose internal IDs, margins, settlement, commission, stock, payment provider, or supplier private data.';
