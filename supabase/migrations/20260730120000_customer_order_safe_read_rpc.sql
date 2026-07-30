create or replace function public.get_customer_order_safe(p_order_id uuid)
returns table (
  order_id uuid,
  order_number text,
  created_at timestamptz,
  updated_at timestamptz,
  order_status_label text,
  customer_confirmation_label text,
  payment_method_label text,
  payment_collection_label text,
  delivery_status_label text,
  delivery_quote_label text,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  total_payable_amount numeric,
  currency_code text,
  customer_contact_snapshot jsonb,
  delivery_address_snapshot jsonb,
  reseller_shop_name text,
  reseller_shop_slug text,
  reservation_status_label text,
  reservation_expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_customer_id uuid;
begin
  if p_order_id is null then
    return;
  end if;

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
  limit 1;

  if v_customer_id is null then
    return;
  end if;

  return query
  select
    o.id as order_id,
    o.order_number,
    o.created_at,
    o.updated_at,
    case o.order_status
      when 'placed_pending_confirmation' then 'Placed - waiting for supplier confirmation'
      when 'customer_confirmed' then 'Customer confirmed'
      when 'delivery_quote_pending' then 'Delivery quote pending'
      when 'delivery_quote_ready' then 'Delivery quote ready'
      when 'delivery_quote_approved' then 'Delivery quote approved'
      when 'supplier_preparing' then 'Supplier preparing'
      when 'ready_for_pickup_or_dispatch' then 'Ready for pickup or dispatch'
      when 'out_for_delivery' then 'Out for delivery'
      when 'delivered_payment_pending' then 'Delivered - payment pending'
      when 'payment_collected' then 'Payment collected'
      when 'completed' then 'Completed'
      when 'cancelled' then 'Cancelled'
      when 'customer_refused' then 'Customer refused delivery'
      when 'failed' then 'Failed'
      when 'disputed' then 'Disputed'
      else 'Order status unavailable'
    end as order_status_label,
    case o.customer_confirmation_status
      when 'pending' then 'Customer confirmation pending'
      when 'confirmed' then 'Customer confirmed'
      when 'expired' then 'Customer confirmation expired'
      when 'cancelled' then 'Customer confirmation cancelled'
      when 'manual_confirmed' then 'Confirmed by support'
      else 'Customer confirmation unavailable'
    end as customer_confirmation_label,
    case o.payment_method
      when 'pay_on_delivery' then 'Pay on Delivery'
      else 'Payment method unavailable'
    end as payment_method_label,
    case o.payment_collection_status
      when 'not_collected' then 'Payment not collected'
      when 'pending' then 'Payment pending'
      when 'collected' then 'Payment collected'
      when 'failed' then 'Payment failed'
      when 'refunded' then 'Payment refunded'
      when 'disputed' then 'Payment disputed'
      else 'Payment status unavailable'
    end as payment_collection_label,
    case o.delivery_status
      when 'estimate_selected' then 'Delivery not arranged yet'
      when 'quote_pending' then 'Delivery quote pending'
      when 'quote_ready' then 'Delivery quote ready'
      when 'quote_approved' then 'Delivery quote approved'
      when 'quote_rejected' then 'Delivery quote rejected'
      when 'ready' then 'Delivery ready'
      when 'out_for_delivery' then 'Out for delivery'
      when 'delivered' then 'Delivered'
      when 'failed' then 'Delivery failed'
      when 'cancelled' then 'Delivery cancelled'
      else 'Delivery status unavailable'
    end as delivery_status_label,
    case o.delivery_quote_status
      when 'pending' then 'Delivery fee not confirmed'
      when 'quoted' then 'Delivery fee quoted'
      when 'approved' then 'Delivery fee approved'
      when 'rejected' then 'Delivery fee rejected'
      when 'expired' then 'Delivery quote expired'
      when 'cancelled' then 'Delivery quote cancelled'
      else 'Delivery quote status unavailable'
    end as delivery_quote_label,
    cd.product_name_snapshot as product_name,
    cd.product_slug_snapshot as product_slug,
    coalesce(cd.product_image_snapshot, '{}'::jsonb) as product_image_snapshot,
    oi.quantity,
    oi.customer_product_price_snapshot_amount as final_customer_price_amount,
    oi.line_total_amount,
    o.total_payable_amount,
    o.currency_code,
    coalesce(o.customer_contact_snapshot, '{}'::jsonb) as customer_contact_snapshot,
    coalesce(o.delivery_address_snapshot, '{}'::jsonb) as delivery_address_snapshot,
    rs.display_name as reseller_shop_name,
    rs.shop_slug as reseller_shop_slug,
    case sr.reservation_status
      when 'reserved' then 'Stock reserved for this order'
      when 'pending' then 'Stock reservation pending'
      when 'released' then 'Stock reservation released'
      when 'committed' then 'Stock reservation committed'
      when 'expired' then 'Stock reservation expired'
      when 'cancelled' then 'Stock reservation cancelled'
      else 'Stock reservation unavailable'
    end as reservation_status_label,
    sr.expires_at as reservation_expires_at
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
  left join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  left join public.stock_reservations sr on sr.order_id = o.id
  where o.id = p_order_id
    and o.customer_id = v_customer_id
    and o.deleted_at is null
  order by sr.created_at asc nulls last
  limit 1;
end;
$$;

revoke all on function public.get_customer_order_safe(uuid) from public;
grant execute on function public.get_customer_order_safe(uuid) to authenticated;

comment on function public.get_customer_order_safe(uuid)
  is 'Customer-only read boundary for a single own order. Returns public/customer-safe labels, snapshots, totals, Pay on Delivery status, and reservation status without exposing supplier base price, margins, commissions, settlements, private contacts, risk data, or internal operational data.';
