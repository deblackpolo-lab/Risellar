-- Supplier Fulfilment Phase 3: supplier marks a preparing POD order ready for delivery arrangement.
-- Forward-only migration. No delivery, payment, stock-commit, settlement, commission, withdrawal, refund, or cancellation side effects.

alter type public.order_status add value if not exists 'ready_for_delivery' after 'supplier_preparing';

alter table public.orders
  add column if not exists ready_for_delivery_at timestamptz,
  add column if not exists ready_for_delivery_by_profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists ready_for_delivery_idempotency_key text;

create index if not exists idx_orders_ready_for_delivery_at
  on public.orders(ready_for_delivery_at)
  where ready_for_delivery_at is not null and deleted_at is null;

create or replace function public.supplier_mark_ready_for_delivery(
  p_order_id uuid,
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
  reseller_shop_slug text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_actor_role public.user_role;
  v_supplier_id uuid;
  v_order public.orders%rowtype;
  v_item record;
  v_reservation public.stock_reservations%rowtype;
  v_variant public.product_variants%rowtype;
  v_idempotency_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_transitioned boolean := false;
begin
  if p_order_id is null then
    raise exception 'ORDER_ID_REQUIRED'
      using errcode = '23514';
  end if;

  if v_idempotency_key is not null and length(v_idempotency_key) > 120 then
    raise exception 'INVALID_IDEMPOTENCY_KEY'
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

  perform 1
  from public.order_items oi
  where oi.order_id = p_order_id
  order by oi.id
  for update;

  select
    count(*)::integer as item_count,
    count(distinct oi.supplier_id)::integer as supplier_count,
    min(oi.supplier_id::text)::uuid as supplier_id,
    min(oi.product_id::text)::uuid as product_id,
    min(oi.variant_id::text)::uuid as variant_id,
    min(oi.reseller_product_id::text)::uuid as reseller_product_id
  into v_item
  from public.order_items oi
  where oi.order_id = p_order_id;

  if v_item.item_count <> 1 or v_item.supplier_count <> 1 then
    raise exception 'ORDER_NOT_ACTIONABLE'
      using errcode = '23514';
  end if;

  if v_item.supplier_id <> v_supplier_id then
    raise exception 'ORDER_NOT_FOUND'
      using errcode = '42501';
  end if;

  if v_order.order_status::text = 'ready_for_delivery' then
    return query select * from public.get_supplier_order_safe(p_order_id);
    return;
  end if;

  if v_order.order_status::text = 'supplier_rejected' then
    raise exception 'ALREADY_REJECTED'
      using errcode = '23514';
  end if;

  if v_order.order_status::text = 'placed_pending_confirmation' then
    raise exception 'ORDER_NOT_ACTIONABLE'
      using errcode = '23514';
  end if;

  if v_order.order_status::text = 'supplier_confirmed' then
    raise exception 'ORDER_NOT_PREPARING'
      using errcode = '23514';
  end if;

  if v_order.order_status::text <> 'supplier_preparing' then
    raise exception 'ORDER_NOT_ACTIONABLE'
      using errcode = '23514';
  end if;

  if v_order.supplier_preparing_at is null then
    raise exception 'PREPARATION_NOT_STARTED'
      using errcode = '23514';
  end if;

  if v_order.payment_collection_status <> 'not_collected' then
    raise exception 'ORDER_NOT_ACTIONABLE'
      using errcode = '23514';
  end if;

  select *
  into v_reservation
  from public.stock_reservations sr
  where sr.order_id = p_order_id
    and sr.product_id = v_item.product_id
    and sr.variant_id = v_item.variant_id
    and sr.reseller_product_id = v_item.reseller_product_id
  order by sr.created_at asc, sr.id::text asc
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

  select *
  into v_variant
  from public.product_variants pv
  where pv.id = v_reservation.variant_id
    and pv.product_id = v_reservation.product_id
  for update;

  if v_variant.id is null then
    raise exception 'VARIANT_REQUIRED'
      using errcode = '23514';
  end if;

  update public.orders o
  set order_status = 'ready_for_delivery'::text::public.order_status,
      ready_for_delivery_at = coalesce(o.ready_for_delivery_at, now()),
      ready_for_delivery_by_profile_id = coalesce(o.ready_for_delivery_by_profile_id, v_profile_id),
      ready_for_delivery_idempotency_key = coalesce(o.ready_for_delivery_idempotency_key, v_idempotency_key),
      updated_at = now()
  where o.id = p_order_id
    and o.order_status::text = 'supplier_preparing'
  returning true into v_transitioned;

  if v_transitioned then
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
      'supplier_order_ready_for_delivery',
      'orders',
      p_order_id,
      jsonb_build_object('order_status', v_order.order_status::text),
      jsonb_build_object(
        'order_status',
        'ready_for_delivery',
        'supplier_id',
        v_supplier_id,
        'reservation_status',
        v_reservation.reservation_status::text,
        'idempotency_key_present',
        v_idempotency_key is not null
      ),
      'Supplier marked order ready for delivery arrangement; reservation, stock, payment, delivery, and finance state preserved'
    );
  end if;

  return query select * from public.get_supplier_order_safe(p_order_id);
end;
$$;

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
    case
      when o.order_status::text = 'placed_pending_confirmation' then 'New order - confirm or reject'
      when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed'
      when o.order_status::text = 'supplier_rejected' then 'Rejected - stock released'
      when o.order_status::text = 'supplier_preparing' then 'Preparing order'
      when o.order_status::text = 'ready_for_delivery' then 'Ready for delivery'
      when o.order_status::text = 'ready_for_pickup_or_dispatch' then 'Ready for pickup or dispatch'
      when o.order_status::text = 'out_for_delivery' then 'Out for delivery'
      when o.order_status::text = 'delivered_payment_pending' then 'Delivered - payment pending'
      when o.order_status::text = 'payment_collected' then 'Payment collected'
      when o.order_status::text = 'completed' then 'Completed'
      when o.order_status::text = 'cancelled' then 'Cancelled'
      when o.order_status::text = 'customer_refused' then 'Customer refused delivery'
      when o.order_status::text = 'failed' then 'Failed'
      when o.order_status::text = 'disputed' then 'Disputed'
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
    case
      when o.order_status::text = 'placed_pending_confirmation' then 'New order - confirm or reject'
      when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed'
      when o.order_status::text = 'supplier_rejected' then 'Rejected - stock released'
      when o.order_status::text = 'supplier_preparing' then 'Preparing order'
      when o.order_status::text = 'ready_for_delivery' then 'Ready for delivery'
      when o.order_status::text = 'ready_for_pickup_or_dispatch' then 'Ready for pickup or dispatch'
      when o.order_status::text = 'out_for_delivery' then 'Out for delivery'
      when o.order_status::text = 'delivered_payment_pending' then 'Delivered - payment pending'
      when o.order_status::text = 'payment_collected' then 'Payment collected'
      when o.order_status::text = 'completed' then 'Completed'
      when o.order_status::text = 'cancelled' then 'Cancelled'
      when o.order_status::text = 'customer_refused' then 'Customer refused delivery'
      when o.order_status::text = 'failed' then 'Failed'
      when o.order_status::text = 'disputed' then 'Disputed'
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
    case o.delivery_status
      when 'estimate_selected' then 'Delivery has not been arranged yet'
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
    coalesce(
      nullif(o.delivery_address_snapshot ->> 'whatsapp', ''),
      nullif(o.customer_contact_snapshot ->> 'whatsapp', '')
    ) as recipient_whatsapp,
    coalesce(o.delivery_address_snapshot, '{}'::jsonb) as delivery_address_snapshot,
    rs.display_name as reseller_shop_name,
    rs.shop_slug as reseller_shop_slug
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
  where o.id = p_order_id
    and oi.supplier_id = v_supplier_id
    and o.deleted_at is null
  order by sr.created_at asc nulls last
  limit 1;
end;
$$;

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
    case
      when o.order_status::text = 'placed_pending_confirmation' then 'Placed - waiting for supplier confirmation'
      when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed your order'
      when o.order_status::text = 'supplier_rejected' then 'Supplier could not fulfil this order'
      when o.order_status::text = 'supplier_preparing' then 'Supplier is preparing your order'
      when o.order_status::text = 'ready_for_delivery' then 'Your order is ready for delivery arrangement'
      when o.order_status::text = 'customer_confirmed' then 'Customer confirmed'
      when o.order_status::text = 'delivery_quote_pending' then 'Delivery quote pending'
      when o.order_status::text = 'delivery_quote_ready' then 'Delivery quote ready'
      when o.order_status::text = 'delivery_quote_approved' then 'Delivery quote approved'
      when o.order_status::text = 'ready_for_delivery' then 'Ready for delivery'
      when o.order_status::text = 'ready_for_pickup_or_dispatch' then 'Ready for pickup or dispatch'
      when o.order_status::text = 'out_for_delivery' then 'Out for delivery'
      when o.order_status::text = 'delivered_payment_pending' then 'Delivered - payment pending'
      when o.order_status::text = 'payment_collected' then 'Payment collected'
      when o.order_status::text = 'completed' then 'Completed'
      when o.order_status::text = 'cancelled' then 'Cancelled'
      when o.order_status::text = 'customer_refused' then 'Customer refused delivery'
      when o.order_status::text = 'failed' then 'Failed'
      when o.order_status::text = 'disputed' then 'Disputed'
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
      when 'estimate_selected' then 'Delivery has not been arranged yet'
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
      when 'failed' then 'Stock reservation failed'
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


revoke all on function public.supplier_mark_ready_for_delivery(uuid, text) from public;
revoke all on function public.supplier_mark_ready_for_delivery(uuid, text) from anon;
grant execute on function public.supplier_mark_ready_for_delivery(uuid, text) to authenticated;

revoke all on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) from public;
revoke all on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) from anon;
grant execute on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_supplier_order_safe(uuid) from public;
revoke all on function public.get_supplier_order_safe(uuid) from anon;
grant execute on function public.get_supplier_order_safe(uuid) to authenticated;

revoke all on function public.get_customer_order_safe(uuid) from public;
revoke all on function public.get_customer_order_safe(uuid) from anon;
grant execute on function public.get_customer_order_safe(uuid) to authenticated;

comment on function public.supplier_mark_ready_for_delivery(uuid, text)
  is 'Supplier-owner audited ready-for-delivery boundary. Emits supplier_order_ready_for_delivery once, resolves supplier from the authenticated profile, locks order/item/reservation rows, preserves reservation, stock, payment, delivery, and finance state, and returns the existing supplier-safe order detail shape.';
