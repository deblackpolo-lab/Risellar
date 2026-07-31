-- Delivery Arrangement Phase 1 runtime patch.
-- Fixes customer-safe order read enum label comparisons by casting enum values
-- to text before comparing label literals. Does not expose private supplier notes
-- or add delivery/payment/order/finance side effects.
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
  reservation_expires_at timestamptz,
  delivery_arrangement_method_label text,
  delivery_arrangement_fee_amount numeric,
  delivery_arrangement_currency_code text,
  delivery_arrangement_expected_date date,
  delivery_arrangement_time_window text,
  delivery_arrangement_courier_name text,
  delivery_arrangement_courier_phone text,
  delivery_arrangement_customer_instruction text,
  delivery_arranged_at timestamptz,
  delivery_arrangement_notice text
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
    case
      when o.order_status::text = 'placed_pending_confirmation' then 'Placed - waiting for supplier confirmation'
      when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed your order'
      when o.order_status::text = 'supplier_rejected' then 'Supplier could not fulfil this order'
      when o.order_status::text = 'supplier_preparing' then 'Supplier is preparing your order'
      when o.order_status::text = 'ready_for_delivery' then 'Your order is ready for delivery arrangement'
      when o.order_status::text = 'delivery_arranged' then 'Delivery arrangement confirmed'
      when o.order_status::text = 'ready_for_pickup_or_dispatch' then 'Ready for delivery'
      when o.order_status::text = 'out_for_delivery' then 'Out for delivery'
      when o.order_status::text = 'delivered_payment_pending' then 'Delivered - payment pending'
      when o.order_status::text = 'payment_collected' then 'Payment collected'
      when o.order_status::text = 'completed' then 'Completed'
      when o.order_status::text = 'cancelled' then 'Cancelled'
      when o.order_status::text = 'customer_refused' then 'Customer refused'
      when o.order_status::text = 'failed' then 'Failed'
      when o.order_status::text = 'disputed' then 'Disputed'
      else 'Order status unavailable'
    end as order_status_label,
    case o.customer_confirmation_status::text
      when 'not_required' then 'Customer confirmation not required'
      when 'pending' then 'Customer confirmation pending'
      when 'confirmed' then 'Customer confirmed'
      when 'refused' then 'Customer refused'
      when 'expired' then 'Customer confirmation expired'
      when 'cancelled' then 'Customer confirmation cancelled'
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
    case
      when o.order_status::text = 'delivery_arranged' then 'Delivery was arranged outside Risellar'
      when o.order_status::text = 'ready_for_delivery' then 'Delivery has not been arranged yet'
      when o.delivery_status = 'estimate_selected' then 'Delivery has not been arranged yet'
      when o.delivery_status = 'quote_pending' then 'Delivery quote pending'
      when o.delivery_status = 'quote_ready' then 'Delivery quote ready'
      when o.delivery_status = 'quote_approved' then 'Delivery quote approved'
      when o.delivery_status = 'quote_rejected' then 'Delivery quote rejected'
      when o.delivery_status = 'ready' then 'Delivery ready'
      when o.delivery_status = 'out_for_delivery' then 'Out for delivery'
      when o.delivery_status = 'delivered' then 'Delivered'
      when o.delivery_status = 'failed' then 'Delivery failed'
      when o.delivery_status = 'cancelled' then 'Delivery cancelled'
      else 'Delivery status unavailable'
    end as delivery_status_label,
    case o.delivery_quote_status::text
      when 'not_required' then 'Delivery quote not required'
      when 'pending' then 'Delivery quote pending'
      when 'quoted' then 'Delivery quote ready'
      when 'accepted' then 'Delivery quote accepted'
      when 'rejected' then 'Delivery quote rejected'
      when 'expired' then 'Delivery quote expired'
      when 'cancelled' then 'Delivery quote cancelled'
      else 'Delivery quote unavailable'
    end as delivery_quote_label,
    coalesce(cd.product_name_snapshot, p.name) as product_name,
    coalesce(cd.product_slug_snapshot, p.slug) as product_slug,
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
      when 'pending' then 'Stock reservation pending'
      when 'reserved' then 'Stock reserved for this order'
      when 'committed' then 'Stock committed'
      when 'released' then 'Stock reservation released'
      when 'expired' then 'Stock reservation expired'
      when 'failed' then 'Stock reservation unavailable'
      else 'Stock reservation unavailable'
    end as reservation_status_label,
    sr.expires_at as reservation_expires_at,
    public.delivery_arrangement_method_label(da.delivery_method) as delivery_arrangement_method_label,
    da.agreed_delivery_fee_amount as delivery_arrangement_fee_amount,
    da.currency_code as delivery_arrangement_currency_code,
    da.expected_delivery_date as delivery_arrangement_expected_date,
    da.expected_time_window as delivery_arrangement_time_window,
    da.courier_display_name as delivery_arrangement_courier_name,
    da.courier_phone as delivery_arrangement_courier_phone,
    da.customer_instruction as delivery_arrangement_customer_instruction,
    da.arranged_at as delivery_arranged_at,
    case
      when da.id is not null then 'You will pay according to the Pay on Delivery arrangement. Risellar has not collected the delivery fee.'
      else null
    end as delivery_arrangement_notice
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.products p on p.id = oi.product_id
  left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
  left join public.stock_reservations sr on sr.order_id = o.id
    and sr.product_id = oi.product_id
    and sr.variant_id = oi.variant_id
    and sr.reseller_product_id = oi.reseller_product_id
  left join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  left join public.delivery_arrangements da on da.order_id = o.id and da.deleted_at is null
  where o.id = p_order_id
    and o.customer_id = v_customer_id
    and o.deleted_at is null
  order by sr.created_at asc nulls last
  limit 1;
end;
$$;
comment on function public.get_customer_order_safe(uuid)
  is 'Customer-owned Pay on Delivery order read model including customer-safe delivery arrangement details. Enum labels are compared as text and supplier private arrangement notes remain excluded.';