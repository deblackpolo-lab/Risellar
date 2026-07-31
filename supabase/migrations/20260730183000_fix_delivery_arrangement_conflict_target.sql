-- Delivery Arrangement Phase 1 runtime patch.
-- Fixes PL/pgSQL ambiguity in supplier_arrange_order_delivery without changing
-- supplier ownership, actionability, idempotency, stock, payment, or audit rules.
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
  on conflict on constraint delivery_arrangements_order_id_key do nothing
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
comment on function public.supplier_arrange_order_delivery(uuid, text, numeric, date, text, text, text, text, text, text)
  is 'Supplier-owner audited manual delivery arrangement boundary. Uses the delivery_arrangements_order_id_key conflict target to avoid PL/pgSQL output-column ambiguity while preserving stock, payment, commercial, and audit protections.';