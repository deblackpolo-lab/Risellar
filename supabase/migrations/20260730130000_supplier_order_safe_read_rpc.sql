-- Supplier Order Handling S2: supplier-safe order read RPC foundation.
-- Read-only forward migration. Does not accept/reject orders, release stock,
-- collect payment, create delivery records, create settlements, or release commissions.

create or replace function public.list_supplier_orders_safe(
  p_status text default null,
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_order_id uuid default null
)
returns table (
  order_id uuid,
  order_number text,
  created_at timestamptz,
  updated_at timestamptz,
  order_status public.order_status,
  order_status_label text,
  is_supplier_actionable boolean,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  supplier_amount_expected numeric,
  currency_code text,
  payment_method_label text,
  payment_status_label text,
  reservation_status_label text,
  reservation_expires_at timestamptz,
  recipient_name text,
  location_summary text,
  reseller_shop_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_supplier_id uuid;
  v_limit integer;
  v_status public.order_status;
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED'
      using errcode = '28000';
  end if;

  if exists (
    select 1
    from public.admin_staff a
    where a.profile_id = v_profile_id
      and a.staff_status = 'active'
      and a.deleted_at is null
  ) then
    raise exception 'SUPPLIER_REQUIRED'
      using errcode = '42501';
  end if;

  select s.id
  into v_supplier_id
  from public.suppliers s
  join public.profiles p on p.id = s.owner_profile_id
  where s.owner_profile_id = v_profile_id
    and p.primary_role = 'supplier_owner'
    and p.account_status = 'active'
    and p.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and s.deleted_at is null
  order by s.created_at asc, s.id::text asc
  limit 1;

  if v_supplier_id is null then
    raise exception 'SUPPLIER_REQUIRED'
      using errcode = '42501';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 50), 1), 100);

  if nullif(trim(coalesce(p_status, '')), '') is not null then
    begin
      v_status := trim(p_status)::public.order_status;
    exception when invalid_text_representation then
      raise exception 'INVALID_STATUS_FILTER'
        using errcode = '22P02';
    end;
  end if;

  return query
  select
    o.id as order_id,
    o.order_number,
    o.created_at,
    o.updated_at,
    o.order_status,
    case o.order_status
      when 'placed_pending_confirmation' then 'New order - confirm or reject'
      when 'supplier_preparing' then 'Preparing'
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
    (
      o.order_status = 'placed_pending_confirmation'
      and sr.reservation_status = 'reserved'
      and sr.expires_at > now()
    ) as is_supplier_actionable,
    coalesce(cd.product_name_snapshot, p.name) as product_name,
    coalesce(cd.product_slug_snapshot, p.slug) as product_slug,
    coalesce(cd.product_image_snapshot, '{}'::jsonb) as product_image_snapshot,
    oi.quantity,
    round(oi.supplier_base_price_snapshot_amount * oi.quantity, 2) as supplier_amount_expected,
    o.currency_code,
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
    end as payment_status_label,
    case sr.reservation_status
      when 'pending' then 'Reservation pending'
      when 'reserved' then 'Stock reserved'
      when 'committed' then 'Stock committed'
      when 'released' then 'Reservation released'
      when 'expired' then 'Reservation expired'
      when 'failed' then 'Reservation unavailable'
      else 'Reservation unavailable'
    end as reservation_status_label,
    sr.expires_at as reservation_expires_at,
    coalesce(
      nullif(o.delivery_address_snapshot ->> 'recipient_name', ''),
      nullif(o.customer_contact_snapshot ->> 'full_name', '')
    ) as recipient_name,
    nullif(concat_ws(
      ', ',
      nullif(o.delivery_address_snapshot ->> 'region', ''),
      nullif(o.delivery_address_snapshot ->> 'city', ''),
      nullif(o.delivery_address_snapshot ->> 'area', '')
    ), '') as location_summary,
    rs.display_name as reseller_shop_name
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.products p on p.id = oi.product_id
  left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
  left join public.stock_reservations sr on sr.order_id = o.id
    and sr.product_id = oi.product_id
    and sr.variant_id = oi.variant_id
    and sr.reseller_product_id = oi.reseller_product_id
  left join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  where oi.supplier_id = v_supplier_id
    and o.deleted_at is null
    and (v_status is null or o.order_status = v_status)
    and (
      p_cursor_created_at is null
      or o.created_at < p_cursor_created_at
      or (
        p_cursor_order_id is not null
        and o.created_at = p_cursor_created_at
        and o.id::text < p_cursor_order_id::text
      )
    )
  order by o.created_at desc, o.id::text desc
  limit v_limit;
end;
$$;

create or replace function public.get_supplier_order_safe(p_order_id uuid)
returns table (
  order_id uuid,
  order_number text,
  created_at timestamptz,
  updated_at timestamptz,
  order_status public.order_status,
  order_status_label text,
  is_supplier_actionable boolean,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  variant_sku text,
  variant_name text,
  quantity integer,
  supplier_amount_expected numeric,
  customer_total_amount numeric,
  currency_code text,
  payment_method_label text,
  payment_status_label text,
  delivery_status_label text,
  reservation_status_label text,
  reservation_expires_at timestamptz,
  reservation_quantity integer,
  recipient_name text,
  recipient_phone text,
  recipient_whatsapp text,
  delivery_address_snapshot jsonb,
  reseller_shop_name text,
  reseller_shop_slug text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_supplier_id uuid;
begin
  if p_order_id is null then
    return;
  end if;

  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED'
      using errcode = '28000';
  end if;

  if exists (
    select 1
    from public.admin_staff a
    where a.profile_id = v_profile_id
      and a.staff_status = 'active'
      and a.deleted_at is null
  ) then
    raise exception 'SUPPLIER_REQUIRED'
      using errcode = '42501';
  end if;

  select s.id
  into v_supplier_id
  from public.suppliers s
  join public.profiles p on p.id = s.owner_profile_id
  where s.owner_profile_id = v_profile_id
    and p.primary_role = 'supplier_owner'
    and p.account_status = 'active'
    and p.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and s.deleted_at is null
  order by s.created_at asc, s.id::text asc
  limit 1;

  if v_supplier_id is null then
    raise exception 'SUPPLIER_REQUIRED'
      using errcode = '42501';
  end if;

  return query
  select
    o.id as order_id,
    o.order_number,
    o.created_at,
    o.updated_at,
    o.order_status,
    case o.order_status
      when 'placed_pending_confirmation' then 'New order - confirm or reject'
      when 'supplier_preparing' then 'Preparing'
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
    (
      o.order_status = 'placed_pending_confirmation'
      and sr.reservation_status = 'reserved'
      and sr.expires_at > now()
    ) as is_supplier_actionable,
    coalesce(cd.product_name_snapshot, p.name) as product_name,
    coalesce(cd.product_slug_snapshot, p.slug) as product_slug,
    coalesce(cd.product_image_snapshot, '{}'::jsonb) as product_image_snapshot,
    pv.sku as variant_sku,
    pv.variant_name,
    oi.quantity,
    round(oi.supplier_base_price_snapshot_amount * oi.quantity, 2) as supplier_amount_expected,
    o.total_payable_amount as customer_total_amount,
    o.currency_code,
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
    end as payment_status_label,
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
    case sr.reservation_status
      when 'pending' then 'Reservation pending'
      when 'reserved' then 'Stock reserved'
      when 'committed' then 'Stock committed'
      when 'released' then 'Reservation released'
      when 'expired' then 'Reservation expired'
      when 'failed' then 'Reservation unavailable'
      else 'Reservation unavailable'
    end as reservation_status_label,
    sr.expires_at as reservation_expires_at,
    sr.quantity as reservation_quantity,
    coalesce(
      nullif(o.delivery_address_snapshot ->> 'recipient_name', ''),
      nullif(o.customer_contact_snapshot ->> 'full_name', '')
    ) as recipient_name,
    coalesce(
      nullif(o.delivery_address_snapshot ->> 'phone', ''),
      nullif(o.customer_contact_snapshot ->> 'phone', '')
    ) as recipient_phone,
    nullif(o.customer_contact_snapshot ->> 'whatsapp', '') as recipient_whatsapp,
    jsonb_strip_nulls(jsonb_build_object(
      'recipient_name', nullif(o.delivery_address_snapshot ->> 'recipient_name', ''),
      'phone', nullif(o.delivery_address_snapshot ->> 'phone', ''),
      'region', nullif(o.delivery_address_snapshot ->> 'region', ''),
      'city', nullif(o.delivery_address_snapshot ->> 'city', ''),
      'area', nullif(o.delivery_address_snapshot ->> 'area', ''),
      'street_address', nullif(o.delivery_address_snapshot ->> 'street_address', ''),
      'landmark', nullif(o.delivery_address_snapshot ->> 'landmark', ''),
      'ghana_post_gps', nullif(o.delivery_address_snapshot ->> 'ghana_post_gps', '')
    )) as delivery_address_snapshot,
    rs.display_name as reseller_shop_name,
    rs.shop_slug as reseller_shop_slug
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.products p on p.id = oi.product_id
  join public.product_variants pv on pv.id = oi.variant_id
  left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
  left join public.stock_reservations sr on sr.order_id = o.id
    and sr.product_id = oi.product_id
    and sr.variant_id = oi.variant_id
    and sr.reseller_product_id = oi.reseller_product_id
  left join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  where o.id = p_order_id
    and oi.supplier_id = v_supplier_id
    and o.deleted_at is null
  order by sr.created_at asc nulls last
  limit 1;
end;
$$;

revoke all on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) from public;
revoke all on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) from anon;
grant execute on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_supplier_order_safe(uuid) from public;
revoke all on function public.get_supplier_order_safe(uuid) from anon;
grant execute on function public.get_supplier_order_safe(uuid) to authenticated;

comment on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid)
  is 'Read-only supplier-owner order list boundary. Returns supplier-owned order summaries and safe fulfilment preview fields without exposing reseller margin, platform margin, commission, settlement, customer email, raw stock counts, or private admin data.';

comment on function public.get_supplier_order_safe(uuid)
  is 'Read-only supplier-owner order detail boundary. Returns one supplier-owned order fulfilment slice and safe operational fields without mutating order status, stock reservations, payment, delivery, settlement, commission, or withdrawal state.';
