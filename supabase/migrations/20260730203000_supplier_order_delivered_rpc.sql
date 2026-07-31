-- Delivery Phase 3: supplier marks an out-for-delivery Pay on Delivery order delivered.
-- Delivered records logistics completion only. Payment remains not_collected;
-- stock reservation, stock counts, commission, settlement, withdrawal, refund,
-- cancellation, proof-of-delivery media, GPS, tracking, and provider/rider effects
-- remain deferred.

alter type public.order_status add value if not exists 'delivered' after 'out_for_delivery';

alter table public.orders
  add column if not exists delivered_at timestamptz,
  add column if not exists delivered_by_profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists delivered_idempotency_key text,
  add column if not exists delivery_confirmation_note text;

create index if not exists idx_orders_delivered_at
  on public.orders(delivered_at)
  where delivered_at is not null and deleted_at is null;
drop function if exists public.get_supplier_order_safe(uuid);

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
  reseller_shop_slug text,
  delivery_arrangement_method text,
  delivery_arrangement_method_label text,
  delivery_arrangement_fee_amount numeric,
  delivery_arrangement_currency_code text,
  delivery_arrangement_expected_date date,
  delivery_arrangement_time_window text,
  delivery_arrangement_courier_name text,
  delivery_arrangement_courier_phone text,
  delivery_arrangement_customer_instruction text,
  delivery_arrangement_supplier_private_note text,
  delivery_arranged_at timestamptz,
  out_for_delivery_at timestamptz,
  dispatch_reference text,
  customer_dispatch_instruction text,
  delivered_at timestamptz,
  delivery_confirmation_note text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
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
    case
      when o.order_status::text = 'placed_pending_confirmation' then 'New order - confirm or reject'
      when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed'
      when o.order_status::text = 'supplier_rejected' then 'Rejected - stock released'
      when o.order_status::text = 'supplier_preparing' then 'Preparing order'
      when o.order_status::text = 'ready_for_delivery' then 'Ready for delivery'
      when o.order_status::text = 'delivery_arranged' then 'Delivery arranged'
      when o.order_status::text = 'out_for_delivery' then 'Out for delivery'
      when o.order_status::text = 'delivered' then 'Delivered'
      else 'Order status unavailable'
    end as order_status_label,
    (
      o.order_status::text = 'placed_pending_confirmation'
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
    case
      when o.order_status::text = 'delivered' then 'Delivered - payment not confirmed'
      when o.order_status::text = 'out_for_delivery' then 'Out for delivery - payment not collected'
      when o.order_status::text = 'delivery_arranged' then 'Delivery arrangement recorded outside Risellar'
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
    coalesce(nullif(o.delivery_address_snapshot ->> 'recipient_name', ''), nullif(o.customer_contact_snapshot ->> 'full_name', '')) as recipient_name,
    coalesce(nullif(o.delivery_address_snapshot ->> 'phone', ''), nullif(o.customer_contact_snapshot ->> 'phone', '')) as recipient_phone,
    coalesce(nullif(o.delivery_address_snapshot ->> 'whatsapp', ''), nullif(o.customer_contact_snapshot ->> 'whatsapp', '')) as recipient_whatsapp,
    coalesce(o.delivery_address_snapshot, '{}'::jsonb) as delivery_address_snapshot,
    rs.display_name as reseller_shop_name,
    rs.shop_slug as reseller_shop_slug,
    da.delivery_method as delivery_arrangement_method,
    public.delivery_arrangement_method_label(da.delivery_method) as delivery_arrangement_method_label,
    da.agreed_delivery_fee_amount as delivery_arrangement_fee_amount,
    da.currency_code as delivery_arrangement_currency_code,
    da.expected_delivery_date as delivery_arrangement_expected_date,
    da.expected_time_window as delivery_arrangement_time_window,
    da.courier_display_name as delivery_arrangement_courier_name,
    da.courier_phone as delivery_arrangement_courier_phone,
    da.customer_instruction as delivery_arrangement_customer_instruction,
    da.supplier_private_note as delivery_arrangement_supplier_private_note,
    da.arranged_at as delivery_arranged_at,
    o.out_for_delivery_at,
    o.dispatch_reference,
    o.customer_dispatch_instruction,
    o.delivered_at,
    o.delivery_confirmation_note
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.products p on p.id = oi.product_id
  left join public.product_variants pv on pv.id = oi.variant_id
  left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
  left join public.stock_reservations sr on sr.order_id = o.id
    and sr.product_id = oi.product_id
    and sr.variant_id = oi.variant_id
    and sr.reseller_product_id = oi.reseller_product_id
  left join public.reseller_shops rs on rs.id = o.shop_id and rs.deleted_at is null
  left join public.delivery_arrangements da on da.order_id = o.id and da.deleted_at is null
  where o.id = p_order_id
    and oi.supplier_id = v_supplier_id
    and o.deleted_at is null
  order by sr.created_at asc nulls last
  limit 1;
end;
$fn$;


create or replace function public.supplier_mark_order_delivered(
  p_order_id uuid,
  p_delivery_confirmation_note text default null,
  p_idempotency_key text default null
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
  reseller_shop_slug text,
  delivery_arrangement_method text,
  delivery_arrangement_method_label text,
  delivery_arrangement_fee_amount numeric,
  delivery_arrangement_currency_code text,
  delivery_arrangement_expected_date date,
  delivery_arrangement_time_window text,
  delivery_arrangement_courier_name text,
  delivery_arrangement_courier_phone text,
  delivery_arrangement_customer_instruction text,
  delivery_arrangement_supplier_private_note text,
  delivery_arranged_at timestamptz,
  out_for_delivery_at timestamptz,
  dispatch_reference text,
  customer_dispatch_instruction text,
  delivered_at timestamptz,
  delivery_confirmation_note text
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
  v_actor_role public.user_role;
  v_supplier_id uuid;
  v_order public.orders%rowtype;
  v_item record;
  v_reservation public.stock_reservations%rowtype;
  v_arrangement public.delivery_arrangements%rowtype;
  v_delivery_confirmation_note text := nullif(trim(coalesce(p_delivery_confirmation_note, '')), '');
  v_idempotency_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_existing_audit_count integer;
begin
  if p_order_id is null then
    raise exception 'ORDER_ID_REQUIRED'
      using errcode = '23514';
  end if;

  if v_idempotency_key is not null and length(v_idempotency_key) > 140 then
    raise exception 'INVALID_IDEMPOTENCY_KEY'
      using errcode = '23514';
  end if;

  if length(coalesce(v_delivery_confirmation_note, '')) > 300 then
    raise exception 'FIELD_TOO_LONG'
      using errcode = '23514';
  end if;

  if coalesce(v_delivery_confirmation_note, '') ~ '<[^>]+>' then
    raise exception 'INVALID_DELIVERY_NOTE'
      using errcode = '23514';
  end if;

  if coalesce(v_delivery_confirmation_note, '') ~* '(payment collected|cash collected|paid in full|id card|national id|passport|gps|latitude|longitude|live tracking)' then
    raise exception 'INVALID_DELIVERY_NOTE'
      using errcode = '23514';
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

  select p.primary_role, s.id
  into v_actor_role, v_supplier_id
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

  select *
  into v_order
  from public.orders o
  where o.id = p_order_id
    and o.deleted_at is null
  for update;

  if v_order.id is null then
    raise exception 'ORDER_NOT_FOUND'
      using errcode = '42501';
  end if;

  select
    count(*)::integer as item_count,
    count(distinct oi.supplier_id)::integer as supplier_count,
    min(oi.supplier_id::text)::uuid as supplier_id
  into v_item
  from public.order_items oi
  where oi.order_id = p_order_id;

  if coalesce(v_item.item_count, 0) = 0 or coalesce(v_item.supplier_count, 0) <> 1 then
    raise exception 'ORDER_NOT_FOUND'
      using errcode = '42501';
  end if;

  if v_item.supplier_id is distinct from v_supplier_id then
    raise exception 'ORDER_NOT_OWNED'
      using errcode = '42501';
  end if;

  if v_order.order_status::text = 'delivered' then
    if v_order.delivered_idempotency_key is not distinct from v_idempotency_key
      and v_order.delivery_confirmation_note is not distinct from v_delivery_confirmation_note then
      return query select * from public.get_supplier_order_safe(p_order_id);
      return;
    end if;

    raise exception 'CONFLICTING_RETRY'
      using errcode = '23505';
  end if;

  if v_order.order_status::text <> 'out_for_delivery' then
    raise exception 'ORDER_NOT_OUT_FOR_DELIVERY'
      using errcode = '23514';
  end if;

  if v_order.out_for_delivery_at is null then
    raise exception 'DISPATCH_NOT_RECORDED'
      using errcode = '23514';
  end if;

  select *
  into v_arrangement
  from public.delivery_arrangements da
  where da.order_id = p_order_id
    and da.supplier_id = v_supplier_id
    and da.deleted_at is null
  for update;

  if v_arrangement.id is null then
    raise exception 'DELIVERY_ARRANGEMENT_NOT_FOUND'
      using errcode = '23514';
  end if;

  select *
  into v_reservation
  from public.stock_reservations sr
  where sr.order_id = p_order_id
  order by sr.created_at asc
  limit 1
  for update;

  if v_reservation.id is null then
    raise exception 'RESERVATION_NOT_FOUND'
      using errcode = '23514';
  end if;

  if v_reservation.reservation_status <> 'reserved' then
    raise exception 'RESERVATION_NOT_ACTIVE'
      using errcode = '23514';
  end if;

  if v_reservation.expires_at <= now() then
    raise exception 'RESERVATION_EXPIRED'
      using errcode = '23514';
  end if;

  if v_order.payment_collection_status <> 'not_collected' then
    raise exception 'ORDER_NOT_ACTIONABLE'
      using errcode = '23514';
  end if;

  update public.orders o
  set order_status = 'delivered'::text::public.order_status,
      delivery_status = 'delivered'::public.delivery_status,
      delivered_at = coalesce(o.delivered_at, now()),
      delivered_by_profile_id = coalesce(o.delivered_by_profile_id, v_profile_id),
      delivered_idempotency_key = coalesce(o.delivered_idempotency_key, v_idempotency_key),
      delivery_confirmation_note = coalesce(o.delivery_confirmation_note, v_delivery_confirmation_note),
      updated_at = now()
  where o.id = p_order_id;

  select count(*)::integer
  into v_existing_audit_count
  from public.audit_logs al
  where al.target_entity_type = 'orders'
    and al.target_entity_id = p_order_id
    and al.action = 'supplier_order_delivered';

  if coalesce(v_existing_audit_count, 0) = 0 then
    insert into public.audit_logs(
      actor_profile_id,
      actor_role,
      action,
      target_entity_type,
      target_entity_id,
      before_data,
      after_data,
      reason
    )
    values (
      v_profile_id,
      v_actor_role,
      'supplier_order_delivered',
      'orders',
      p_order_id,
      jsonb_build_object('order_status', v_order.order_status::text, 'delivery_status', v_order.delivery_status::text),
      jsonb_build_object(
        'order_status', 'delivered',
        'delivery_status', 'delivered',
        'delivery_arrangement_recorded', true,
        'dispatch_recorded', true,
        'delivery_confirmation_note_present', v_delivery_confirmation_note is not null,
        'idempotency_key_present', v_idempotency_key is not null
      ),
      'Supplier marked Pay on Delivery order delivered outside Risellar; payment remains unconfirmed'
    );
  end if;

  return query select * from public.get_supplier_order_safe(p_order_id);
end;
$fn$;

comment on function public.supplier_mark_order_delivered(uuid, text, text)
  is 'Supplier-owner audited delivered boundary for out_for_delivery Pay on Delivery orders. Records delivery completion only while preserving reservation, stock, payment, and commercial snapshots.';
drop function if exists public.get_customer_order_safe(uuid);

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
  delivery_arrangement_notice text,
  out_for_delivery_at timestamptz,
  customer_dispatch_instruction text,
  dispatch_notice text,
  delivered_at timestamptz,
  delivered_notice text
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
      when o.order_status::text = 'out_for_delivery' then 'Your order is out for delivery'
      when o.order_status::text = 'delivered' then 'Your order has been delivered'
      else 'Order status unavailable'
    end as order_status_label,
    case o.customer_confirmation_status::text
      when 'not_required' then 'Customer confirmation not required'
      when 'pending' then 'Customer confirmation pending'
      when 'confirmed' then 'Customer confirmed'
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
      when o.order_status::text = 'delivered' then 'Delivery completed - payment has not yet been confirmed in Risellar'
      when o.order_status::text = 'out_for_delivery' then 'Delivery has started outside Risellar'
      when o.order_status::text = 'delivery_arranged' then 'Delivery was arranged outside Risellar'
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
      when 'approved' then 'Delivery quote approved'
      when 'rejected' then 'Delivery quote rejected'
      when 'expired' then 'Delivery quote expired'
      else 'Delivery fee not confirmed'
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
    end as delivery_arrangement_notice,
    o.out_for_delivery_at,
    o.customer_dispatch_instruction,
    case
      when o.order_status::text = 'out_for_delivery' then 'Risellar has not collected the order or delivery fee. Please pay according to the Pay on Delivery arrangement.'
      else null
    end as dispatch_notice,
    o.delivered_at,
    case
      when o.order_status::text = 'delivered' then 'Delivery completed. Payment has not yet been confirmed in Risellar. Risellar has not collected or confirmed the order payment.'
      else null
    end as delivered_notice
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
$fn$;


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
as $fn$
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
    case
      when o.order_status::text = 'placed_pending_confirmation' then 'New order - confirm or reject'
      when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed'
      when o.order_status::text = 'supplier_rejected' then 'Rejected - stock released'
      when o.order_status::text = 'supplier_preparing' then 'Preparing order'
      when o.order_status::text = 'ready_for_delivery' then 'Ready for delivery'
      when o.order_status::text = 'delivery_arranged' then 'Delivery arranged'
      when o.order_status::text = 'out_for_delivery' then 'Out for delivery'
      when o.order_status::text = 'delivered' then 'Delivered'
      else 'Order status unavailable'
    end as order_status_label,
    (
      o.order_status::text = 'placed_pending_confirmation'
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
$fn$;


revoke all on function public.supplier_mark_order_delivered(uuid, text, text) from public, anon, authenticated;
grant execute on function public.supplier_mark_order_delivered(uuid, text, text) to authenticated;

comment on column public.orders.delivered_at
  is 'Manual delivered timestamp recorded by supplier after out_for_delivery. Does not imply payment collection, order completion, stock commit, commission release, settlement, withdrawal, proof upload, GPS, or tracking.';
comment on column public.orders.delivery_confirmation_note
  is 'Optional supplier-only internal delivery confirmation note. Not exposed by customer-safe order reads.';
