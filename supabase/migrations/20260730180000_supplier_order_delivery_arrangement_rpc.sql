-- Delivery Arrangement Phase 1.
-- Records a manual supplier/customer delivery arrangement only.
-- No provider booking, live tracking, payment collection, stock commit, commission, settlement, withdrawal, refund, or cancellation side effects.

alter type public.order_status add value if not exists 'delivery_arranged' after 'ready_for_delivery';

alter table public.orders
  add column if not exists delivery_arranged_at timestamptz,
  add column if not exists delivery_arranged_by_profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists delivery_arrangement_idempotency_key text;

create table if not exists public.delivery_arrangements (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  delivery_method text not null,
  agreed_delivery_fee_amount numeric,
  currency_code text not null,
  expected_delivery_date date,
  expected_time_window text,
  courier_display_name text,
  courier_phone text,
  customer_instruction text,
  supplier_private_note text,
  arranged_by_profile_id uuid references public.profiles(id) on delete set null,
  idempotency_key text,
  arranged_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint delivery_arrangements_method_check check (
    delivery_method in (
      'supplier_rider',
      'third_party_courier',
      'ride_hailing',
      'customer_pickup',
      'manually_arranged',
      'other'
    )
  ),
  constraint delivery_arrangements_fee_check check (agreed_delivery_fee_amount is null or agreed_delivery_fee_amount >= 0),
  constraint delivery_arrangements_currency_check check (length(trim(currency_code)) between 3 and 12),
  constraint delivery_arrangements_expected_window_check check (expected_time_window is null or length(expected_time_window) <= 100),
  constraint delivery_arrangements_courier_name_check check (courier_display_name is null or length(courier_display_name) <= 100),
  constraint delivery_arrangements_courier_phone_check check (courier_phone is null or length(courier_phone) <= 32),
  constraint delivery_arrangements_customer_instruction_check check (customer_instruction is null or length(customer_instruction) <= 500),
  constraint delivery_arrangements_private_note_check check (supplier_private_note is null or length(supplier_private_note) <= 500),
  constraint delivery_arrangements_idempotency_key_check check (idempotency_key is null or length(idempotency_key) <= 140)
);

alter table public.delivery_arrangements enable row level security;

create index if not exists idx_delivery_arrangements_supplier
  on public.delivery_arrangements(supplier_id, arranged_at desc)
  where deleted_at is null;

create index if not exists idx_orders_delivery_arranged_at
  on public.orders(delivery_arranged_at)
  where delivery_arranged_at is not null and deleted_at is null;

create or replace function public.delivery_arrangement_method_label(p_delivery_method text)
returns text
language sql
stable
set search_path = public
as $$
  select case p_delivery_method
    when 'supplier_rider' then 'Supplier''s rider'
    when 'third_party_courier' then 'Third-party courier'
    when 'ride_hailing' then 'Ride-hailing delivery'
    when 'customer_pickup' then 'Customer pickup'
    when 'manually_arranged' then 'Manually arranged delivery'
    when 'other' then 'Other agreed arrangement'
    else 'Delivery arrangement unavailable'
  end;
$$;

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
  delivery_arranged_at timestamptz
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
      when o.order_status::text = 'delivery_arranged' then 'Delivery arranged'
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
    case
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
    da.arranged_at as delivery_arranged_at
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
$$;

create or replace function public.supplier_arrange_order_delivery(
  p_order_id uuid,
  p_delivery_method text,
  p_agreed_delivery_fee_amount numeric default null,
  p_expected_delivery_date date default null,
  p_expected_time_window text default null,
  p_courier_display_name text default null,
  p_courier_phone text default null,
  p_customer_instruction text default null,
  p_supplier_private_note text default null,
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
  delivery_arranged_at timestamptz
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
  v_delivery_method text := nullif(trim(coalesce(p_delivery_method, '')), '');
  v_expected_time_window text := nullif(trim(coalesce(p_expected_time_window, '')), '');
  v_courier_display_name text := nullif(trim(coalesce(p_courier_display_name, '')), '');
  v_courier_phone text := nullif(regexp_replace(trim(coalesce(p_courier_phone, '')), '\s+', ' ', 'g'), '');
  v_customer_instruction text := nullif(trim(coalesce(p_customer_instruction, '')), '');
  v_supplier_private_note text := nullif(trim(coalesce(p_supplier_private_note, '')), '');
  v_idempotency_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_existing public.delivery_arrangements%rowtype;
  v_inserted_id uuid;
begin
  if p_order_id is null then
    raise exception 'ORDER_ID_REQUIRED'
      using errcode = '23514';
  end if;

  if v_idempotency_key is not null and length(v_idempotency_key) > 140 then
    raise exception 'INVALID_IDEMPOTENCY_KEY'
      using errcode = '23514';
  end if;

  if v_delivery_method not in ('supplier_rider', 'third_party_courier', 'ride_hailing', 'customer_pickup', 'manually_arranged', 'other') then
    raise exception 'INVALID_DELIVERY_METHOD'
      using errcode = '23514';
  end if;

  if p_agreed_delivery_fee_amount is not null and p_agreed_delivery_fee_amount < 0 then
    raise exception 'INVALID_DELIVERY_FEE'
      using errcode = '23514';
  end if;

  if p_agreed_delivery_fee_amount is not null and p_agreed_delivery_fee_amount > 5000 then
    raise exception 'DELIVERY_FEE_TOO_HIGH'
      using errcode = '23514';
  end if;

  if p_expected_delivery_date is not null and p_expected_delivery_date < current_date then
    raise exception 'EXPECTED_DATE_IN_PAST'
      using errcode = '23514';
  end if;

  if length(coalesce(v_expected_time_window, '')) > 100
    or length(coalesce(v_courier_display_name, '')) > 100
    or length(coalesce(v_customer_instruction, '')) > 500
    or length(coalesce(v_supplier_private_note, '')) > 500 then
    raise exception 'FIELD_TOO_LONG'
      using errcode = '23514';
  end if;

  if v_courier_phone is not null and (length(v_courier_phone) > 32 or v_courier_phone !~ '^[0-9+() -]{7,32}$') then
    raise exception 'INVALID_COURIER_PHONE'
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

  select count(distinct oi.supplier_id) as supplier_count, min(oi.supplier_id::text)::uuid as supplier_id
  into v_item
  from public.order_items oi
  where oi.order_id = p_order_id;

  if v_item.supplier_count is distinct from 1 or v_item.supplier_id is distinct from v_supplier_id then
    raise exception 'ORDER_NOT_OWNED'
      using errcode = '42501';
  end if;

  select *
  into v_existing
  from public.delivery_arrangements da
  where da.order_id = p_order_id
    and da.deleted_at is null
  for update;

  if v_existing.id is not null then
    if v_existing.delivery_method = v_delivery_method
      and v_existing.idempotency_key is not distinct from v_idempotency_key
      and v_existing.agreed_delivery_fee_amount is not distinct from p_agreed_delivery_fee_amount
      and v_existing.expected_delivery_date is not distinct from p_expected_delivery_date
      and v_existing.expected_time_window is not distinct from v_expected_time_window
      and v_existing.courier_display_name is not distinct from v_courier_display_name
      and v_existing.courier_phone is not distinct from v_courier_phone
      and v_existing.customer_instruction is not distinct from v_customer_instruction
      and v_existing.supplier_private_note is not distinct from v_supplier_private_note then
      return query select * from public.get_supplier_order_safe(p_order_id);
      return;
    end if;

    raise exception 'CONFLICTING_RETRY'
      using errcode = '23505';
  end if;

  if v_order.order_status::text = 'delivery_arranged' then
    raise exception 'ALREADY_ARRANGED'
      using errcode = '23505';
  end if;

  if v_order.order_status::text <> 'ready_for_delivery' then
    raise exception 'ORDER_NOT_READY'
      using errcode = '23514';
  end if;

  if v_order.ready_for_delivery_at is null then
    raise exception 'ORDER_NOT_READY'
      using errcode = '23514';
  end if;

  if v_order.payment_collection_status::text <> 'not_collected' then
    raise exception 'ORDER_NOT_ACTIONABLE'
      using errcode = '23514';
  end if;

  select sr.*
  into v_reservation
  from public.stock_reservations sr
  join public.order_items oi on oi.order_id = p_order_id
    and oi.product_id = sr.product_id
    and oi.variant_id = sr.variant_id
    and oi.reseller_product_id = sr.reseller_product_id
  where sr.order_id = p_order_id
  order by sr.created_at asc
  limit 1
  for update;

  if v_reservation.id is null then
    raise exception 'RESERVATION_NOT_FOUND'
      using errcode = '23514';
  end if;

  if v_reservation.reservation_status::text <> 'reserved' then
    raise exception 'RESERVATION_NOT_ACTIVE'
      using errcode = '23514';
  end if;

  if v_reservation.expires_at <= now() then
    raise exception 'RESERVATION_EXPIRED'
      using errcode = '23514';
  end if;

  insert into public.delivery_arrangements(
    order_id,
    supplier_id,
    delivery_method,
    agreed_delivery_fee_amount,
    currency_code,
    expected_delivery_date,
    expected_time_window,
    courier_display_name,
    courier_phone,
    customer_instruction,
    supplier_private_note,
    arranged_by_profile_id,
    idempotency_key
  )
  values (
    p_order_id,
    v_supplier_id,
    v_delivery_method,
    p_agreed_delivery_fee_amount,
    v_order.currency_code,
    p_expected_delivery_date,
    v_expected_time_window,
    v_courier_display_name,
    v_courier_phone,
    v_customer_instruction,
    v_supplier_private_note,
    v_profile_id,
    v_idempotency_key
  )
  on conflict (order_id) do nothing
  returning id into v_inserted_id;

  if v_inserted_id is null then
    raise exception 'CONFLICTING_RETRY'
      using errcode = '23505';
  end if;

  update public.orders o
  set order_status = 'delivery_arranged'::text::public.order_status,
      delivery_arranged_at = coalesce(o.delivery_arranged_at, now()),
      delivery_arranged_by_profile_id = coalesce(o.delivery_arranged_by_profile_id, v_profile_id),
      delivery_arrangement_idempotency_key = coalesce(o.delivery_arrangement_idempotency_key, v_idempotency_key),
      updated_at = now()
  where o.id = p_order_id;

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
    'supplier_order_delivery_arranged',
    'orders',
    p_order_id,
    jsonb_build_object('order_status', v_order.order_status::text),
    jsonb_build_object(
      'order_status',
      'delivery_arranged',
      'delivery_method',
      v_delivery_method,
      'fee_recorded',
      p_agreed_delivery_fee_amount is not null,
      'supplier_id',
      v_supplier_id,
      'idempotency_key_present',
      v_idempotency_key is not null
    ),
    'Supplier recorded manual delivery arrangement outside Risellar'
  );

  return query select * from public.get_supplier_order_safe(p_order_id);
end;
$$;

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
    case o.customer_confirmation_status
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
    case o.delivery_quote_status
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

revoke all on function public.delivery_arrangement_method_label(text) from public;
revoke all on function public.delivery_arrangement_method_label(text) from anon;
grant execute on function public.delivery_arrangement_method_label(text) to authenticated;

revoke all on function public.supplier_arrange_order_delivery(uuid, text, numeric, date, text, text, text, text, text, text) from public;
revoke all on function public.supplier_arrange_order_delivery(uuid, text, numeric, date, text, text, text, text, text, text) from anon;
grant execute on function public.supplier_arrange_order_delivery(uuid, text, numeric, date, text, text, text, text, text, text) to authenticated;

revoke all on function public.get_supplier_order_safe(uuid) from public;
revoke all on function public.get_supplier_order_safe(uuid) from anon;
grant execute on function public.get_supplier_order_safe(uuid) to authenticated;

revoke all on function public.get_customer_order_safe(uuid) from public;
revoke all on function public.get_customer_order_safe(uuid) from anon;
grant execute on function public.get_customer_order_safe(uuid) to authenticated;

comment on table public.delivery_arrangements
  is 'Manual supplier-recorded delivery arrangement. Informational only; no delivery provider, payment, tracking, stock, commission, settlement, or withdrawal side effects.';

comment on function public.supplier_arrange_order_delivery(uuid, text, numeric, date, text, text, text, text, text, text)
  is 'Supplier-owner audited manual delivery arrangement boundary. Resolves supplier ownership server-side, requires ready_for_delivery, preserves reservation, stock, payment, and commercial snapshots, and records supplier_order_delivery_arranged once.';
