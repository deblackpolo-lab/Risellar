-- Checkout Phase C Group 2: order creation and atomic stock reservation RPC foundation.
-- Forward migration only. Do not connect payments, delivery quotes, supplier preparation,
-- commission release, settlement completion, withdrawals, refunds, or checkout UI confirmation.
-- Reservation expiry belongs to stock_reservations.expires_at; this migration does not use orders.expires_at.

alter table public.orders
  add column if not exists checkout_draft_id uuid references public.checkout_drafts(id) on delete restrict,
  add column if not exists idempotency_key text;

alter table public.orders
  drop constraint if exists orders_idempotency_key_not_blank;

alter table public.orders
  add constraint orders_idempotency_key_not_blank
  check (idempotency_key is null or length(trim(idempotency_key)) > 0);

create unique index if not exists orders_checkout_draft_unique_idx
  on public.orders(checkout_draft_id)
  where checkout_draft_id is not null;

create unique index if not exists orders_customer_idempotency_key_unique_idx
  on public.orders(customer_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists orders_checkout_draft_created_idx
  on public.orders(checkout_draft_id, created_at desc)
  where checkout_draft_id is not null;

alter table public.checkout_drafts
  add column if not exists converted_order_id uuid references public.orders(id) on delete restrict,
  add column if not exists converted_at timestamptz;

alter table public.checkout_drafts
  drop constraint if exists checkout_drafts_status_check;

alter table public.checkout_drafts
  add constraint checkout_drafts_status_check
  check (draft_status in ('draft', 'review_pending', 'abandoned', 'converted'));

create index if not exists checkout_drafts_converted_order_idx
  on public.checkout_drafts(converted_order_id)
  where converted_order_id is not null;

create sequence if not exists public.order_number_sequence;

create or replace function public.generate_order_number()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_number text;
begin
  v_order_number := 'RSR-' || to_char(now(), 'YYYYMMDD') || '-' ||
    lpad(nextval('public.order_number_sequence'::regclass)::text, 6, '0');

  return v_order_number;
end;
$$;

create or replace function public.checkout_order_safe_row(p_order_id uuid)
returns table (
  order_id uuid,
  order_number text,
  checkout_draft_id uuid,
  order_status public.order_status,
  payment_method public.payment_method,
  payment_collection_status public.payment_collection_status,
  delivery_status public.delivery_status,
  customer_confirmation_status public.confirmation_status,
  delivery_quote_status public.delivery_quote_status,
  customer_id uuid,
  reseller_id uuid,
  shop_id uuid,
  reseller_product_id uuid,
  product_id uuid,
  product_name text,
  product_slug text,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  subtotal_product_amount numeric,
  total_payable_amount numeric,
  currency_code text,
  reservation_status public.reservation_status,
  reservation_expires_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    o.id as order_id,
    o.order_number,
    o.checkout_draft_id,
    o.order_status,
    o.payment_method,
    o.payment_collection_status,
    o.delivery_status,
    o.customer_confirmation_status,
    o.delivery_quote_status,
    o.customer_id,
    o.reseller_id,
    o.shop_id,
    oi.reseller_product_id,
    oi.product_id,
    cd.product_name_snapshot as product_name,
    cd.product_slug_snapshot as product_slug,
    oi.quantity,
    oi.customer_product_price_snapshot_amount as final_customer_price_amount,
    oi.line_total_amount,
    o.subtotal_product_amount,
    o.total_payable_amount,
    o.currency_code,
    sr.reservation_status,
    sr.expires_at as reservation_expires_at,
    o.created_at,
    o.updated_at
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  left join public.checkout_drafts cd on cd.id = o.checkout_draft_id
  left join public.stock_reservations sr on sr.order_id = o.id
  where o.id = p_order_id
    and o.deleted_at is null
    and (
      public.is_order_participant(o.id)
      or public.has_admin_role('support_staff')
    )
  order by sr.created_at asc nulls last
  limit 1;
$$;

create or replace function public.create_order_from_checkout_draft(
  p_checkout_draft_id uuid,
  p_idempotency_key text default null
)
returns table (
  order_id uuid,
  order_number text,
  checkout_draft_id uuid,
  order_status public.order_status,
  payment_method public.payment_method,
  payment_collection_status public.payment_collection_status,
  delivery_status public.delivery_status,
  customer_confirmation_status public.confirmation_status,
  delivery_quote_status public.delivery_quote_status,
  customer_id uuid,
  reseller_id uuid,
  shop_id uuid,
  reseller_product_id uuid,
  product_id uuid,
  product_name text,
  product_slug text,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  subtotal_product_amount numeric,
  total_payable_amount numeric,
  currency_code text,
  reservation_status public.reservation_status,
  reservation_expires_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_context record;
  v_draft public.checkout_drafts%rowtype;
  v_existing_order_id uuid;
  v_listing public.reseller_products%rowtype;
  v_shop public.reseller_shops%rowtype;
  v_reseller public.resellers%rowtype;
  v_product public.products%rowtype;
  v_supplier public.suppliers%rowtype;
  v_variant public.product_variants%rowtype;
  v_address public.customer_delivery_addresses%rowtype;
  v_available_stock integer;
  v_order_id uuid;
  v_order_item_id uuid;
  v_reservation_id uuid;
  v_order_number text;
  v_idempotency_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_line_total numeric(12,2);
  v_settlement_due_amount numeric(12,2);
  v_commission_amount numeric(12,2);
  v_reservation_reference text;
begin
  if p_checkout_draft_id is null then
    raise exception 'DRAFT_ID_REQUIRED'
      using errcode = '23514';
  end if;

  if v_idempotency_key is not null and length(v_idempotency_key) > 120 then
    raise exception 'IDEMPOTENCY_KEY_TOO_LONG'
      using errcode = '23514';
  end if;

  select *
  into v_context
  from public.checkout_draft_current_customer_context()
  limit 1;

  select *
  into v_draft
  from public.checkout_drafts cd
  where cd.id = p_checkout_draft_id
    and cd.deleted_at is null
  for update;

  if not found then
    raise exception 'DRAFT_NOT_FOUND'
      using errcode = '42501';
  end if;

  if v_draft.customer_id <> v_context.customer_id then
    raise exception 'DRAFT_NOT_OWNED'
      using errcode = '42501';
  end if;

  select o.id
  into v_existing_order_id
  from public.orders o
  where o.checkout_draft_id = v_draft.id
    and o.deleted_at is null
  order by o.created_at asc, o.id::text asc
  limit 1;

  if v_existing_order_id is not null then
    perform public.create_audit_log_entry(
      'duplicate_confirmation_reused',
      'orders',
      v_existing_order_id,
      'Existing checkout draft order returned for idempotent retry',
      null,
      jsonb_build_object(
        'checkout_draft_id', v_draft.id,
        'idempotency_key_present', v_idempotency_key is not null
      )
    );

    return query
    select *
    from public.checkout_order_safe_row(v_existing_order_id);

    return;
  end if;

  if v_draft.draft_status <> 'review_pending' then
    raise exception 'DRAFT_NOT_CONFIRMABLE'
      using errcode = '42501';
  end if;

  if v_draft.delivery_address_id is null or v_draft.delivery_address_snapshot = '{}'::jsonb then
    raise exception 'ADDRESS_REQUIRED'
      using errcode = '23514';
  end if;

  select *
  into v_address
  from public.customer_delivery_addresses a
  where a.id = v_draft.delivery_address_id
    and a.customer_id = v_context.customer_id
    and a.deleted_at is null;

  if not found then
    raise exception 'ADDRESS_NOT_OWNED'
      using errcode = '42501';
  end if;

  select *
  into v_listing
  from public.reseller_products rp
  where rp.id = v_draft.reseller_product_id
    and rp.product_id = v_draft.product_id
    and rp.reseller_id = v_draft.reseller_id
    and rp.shop_id = v_draft.shop_id
    and rp.listing_status = 'active'
    and rp.deleted_at is null
  for update;

  if not found then
    raise exception 'LISTING_UNAVAILABLE'
      using errcode = '42501';
  end if;

  if v_listing.variant_id is null or v_draft.variant_id is null or v_listing.variant_id <> v_draft.variant_id then
    raise exception 'VARIANT_UNAVAILABLE'
      using errcode = '42501';
  end if;

  select *
  into v_shop
  from public.reseller_shops rs
  where rs.id = v_listing.shop_id
    and rs.shop_status = 'active'
    and rs.deleted_at is null;

  if not found then
    raise exception 'LISTING_UNAVAILABLE'
      using errcode = '42501';
  end if;

  select *
  into v_reseller
  from public.resellers r
  where r.id = v_listing.reseller_id
    and r.approval_status = 'approved'
    and r.deleted_at is null;

  if not found then
    raise exception 'LISTING_UNAVAILABLE'
      using errcode = '42501';
  end if;

  select *
  into v_product
  from public.products p
  where p.id = v_listing.product_id
    and p.supplier_id = v_draft.supplier_id
    and p.product_status = 'active'
    and p.approval_status = 'approved'
    and p.deleted_at is null;

  if not found then
    raise exception 'PRODUCT_UNAVAILABLE'
      using errcode = '42501';
  end if;

  select *
  into v_supplier
  from public.suppliers s
  where s.id = v_product.supplier_id
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and s.deleted_at is null;

  if not found then
    raise exception 'SUPPLIER_UNAVAILABLE'
      using errcode = '42501';
  end if;

  select *
  into v_variant
  from public.product_variants pv
  where pv.id = v_draft.variant_id
    and pv.product_id = v_product.id
    and pv.variant_status in ('active', 'low_stock')
    and pv.deleted_at is null
  for update;

  if not found then
    raise exception 'VARIANT_UNAVAILABLE'
      using errcode = '42501';
  end if;

  v_available_stock := v_variant.total_stock_quantity - v_variant.reserved_stock_quantity - v_variant.sold_stock_quantity;

  if v_available_stock < v_draft.quantity then
    raise exception 'INSUFFICIENT_STOCK'
      using errcode = '23514';
  end if;

  v_line_total := round(v_listing.customer_product_price_amount * v_draft.quantity, 2);
  v_settlement_due_amount := round((v_product.platform_margin_amount + v_listing.reseller_margin_amount) * v_draft.quantity, 2);
  v_commission_amount := round(v_listing.reseller_margin_amount * v_draft.quantity, 2);
  v_order_number := public.generate_order_number();
  v_reservation_reference := 'RSV-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

  insert into public.orders(
    order_number,
    customer_id,
    reseller_id,
    shop_id,
    checkout_draft_id,
    idempotency_key,
    order_status,
    payment_method,
    payment_collection_status,
    delivery_status,
    customer_confirmation_status,
    delivery_quote_status,
    subtotal_product_amount,
    delivery_estimate_min_amount,
    delivery_estimate_max_amount,
    final_delivery_amount,
    total_payable_amount,
    currency_code,
    delivery_address_snapshot,
    customer_contact_snapshot
  )
  values (
    v_order_number,
    v_context.customer_id,
    v_draft.reseller_id,
    v_draft.shop_id,
    v_draft.id,
    v_idempotency_key,
    'placed_pending_confirmation',
    'pay_on_delivery',
    'not_collected',
    'estimate_selected',
    'pending',
    'pending',
    v_line_total,
    0,
    0,
    null,
    v_line_total,
    v_draft.currency_code,
    v_draft.delivery_address_snapshot,
    v_draft.customer_contact_snapshot
  )
  returning id into v_order_id;

  insert into public.order_items(
    order_id,
    supplier_id,
    product_id,
    variant_id,
    reseller_product_id,
    quantity,
    supplier_base_price_snapshot_amount,
    platform_margin_snapshot_amount,
    reseller_margin_snapshot_amount,
    reseller_cost_snapshot_amount,
    customer_product_price_snapshot_amount,
    line_total_amount,
    settlement_due_amount,
    commission_amount
  )
  values (
    v_order_id,
    v_product.supplier_id,
    v_product.id,
    v_variant.id,
    v_listing.id,
    v_draft.quantity,
    v_product.base_price_amount,
    v_product.platform_margin_amount,
    v_listing.reseller_margin_amount,
    v_product.reseller_cost_amount,
    v_listing.customer_product_price_amount,
    v_line_total,
    v_settlement_due_amount,
    v_commission_amount
  )
  returning id into v_order_item_id;

  update public.product_variants pv
  set reserved_stock_quantity = pv.reserved_stock_quantity + v_draft.quantity,
      updated_at = now()
  where pv.id = v_variant.id;

  insert into public.stock_reservations(
    reservation_reference,
    customer_id,
    reseller_id,
    reseller_product_id,
    product_id,
    variant_id,
    order_id,
    quantity,
    reservation_status,
    expires_at
  )
  values (
    v_reservation_reference,
    v_context.customer_id,
    v_draft.reseller_id,
    v_listing.id,
    v_product.id,
    v_variant.id,
    v_order_id,
    v_draft.quantity,
    'reserved',
    now() + interval '1 hour'
  )
  returning id into v_reservation_id;

  insert into public.inventory_movements(
    supplier_id,
    product_id,
    variant_id,
    movement_type,
    quantity_delta,
    previous_total_quantity,
    new_total_quantity,
    reason,
    order_id,
    created_by_profile_id
  )
  values (
    v_product.supplier_id,
    v_product.id,
    v_variant.id,
    'reservation_created',
    -v_draft.quantity,
    v_variant.total_stock_quantity,
    v_variant.total_stock_quantity,
    'Stock reserved for checkout draft order',
    v_order_id,
    v_context.profile_id
  );

  update public.checkout_drafts cd
  set draft_status = 'converted',
      converted_order_id = v_order_id,
      converted_at = now(),
      updated_at = now()
  where cd.id = v_draft.id;

  perform public.create_audit_log_entry(
    'order_created',
    'orders',
    v_order_id,
    'Customer created Pay on Delivery order from checkout draft',
    null,
    jsonb_build_object(
      'checkout_draft_id', v_draft.id,
      'order_status', 'placed_pending_confirmation',
      'payment_method', 'pay_on_delivery',
      'quantity', v_draft.quantity
    )
  );

  perform public.create_audit_log_entry(
    'order_item_created',
    'order_items',
    v_order_item_id,
    'Order item snapshot created for checkout draft order',
    null,
    jsonb_build_object(
      'order_id', v_order_id,
      'product_id', v_product.id,
      'variant_id', v_variant.id,
      'reseller_product_id', v_listing.id,
      'quantity', v_draft.quantity
    )
  );

  perform public.create_audit_log_entry(
    'stock_reserved',
    'stock_reservations',
    v_reservation_id,
    'Variant stock reserved atomically for checkout draft order',
    null,
    jsonb_build_object(
      'order_id', v_order_id,
      'product_id', v_product.id,
      'variant_id', v_variant.id,
      'quantity', v_draft.quantity,
      'expires_in_minutes', 60
    )
  );

  perform public.create_audit_log_entry(
    'checkout_draft_converted',
    'checkout_drafts',
    v_draft.id,
    'Checkout draft converted to Pay on Delivery order',
    null,
    jsonb_build_object(
      'order_id', v_order_id,
      'reservation_id', v_reservation_id
    )
  );

  return query
  select *
  from public.checkout_order_safe_row(v_order_id);
exception
  when unique_violation then
    if p_checkout_draft_id is not null then
      select o.id
      into v_existing_order_id
      from public.orders o
      where o.checkout_draft_id = p_checkout_draft_id
        and o.deleted_at is null
      order by o.created_at asc, o.id::text asc
      limit 1;

      if v_existing_order_id is not null then
        return query
        select *
        from public.checkout_order_safe_row(v_existing_order_id);

        return;
      end if;
    end if;

    raise exception 'ORDER_CREATION_FAILED'
      using errcode = '23505';
end;
$$;

revoke all on function public.generate_order_number() from public;
revoke all on function public.checkout_order_safe_row(uuid) from public;
revoke all on function public.create_order_from_checkout_draft(uuid, text) from public;

grant execute on function public.create_order_from_checkout_draft(uuid, text) to authenticated;
grant execute on function public.checkout_order_safe_row(uuid) to authenticated;

comment on function public.create_order_from_checkout_draft(uuid, text)
  is 'Creates one Pay on Delivery order, one order item, and one stock reservation from an owned review_pending checkout draft. Does not collect payment, create delivery quotes, release commission, complete settlement, or create withdrawals.';

comment on column public.orders.checkout_draft_id
  is 'Nullable for legacy rows. Future checkout-created orders use this as one-order-per-draft idempotency key.';

comment on column public.orders.idempotency_key
  is 'Optional customer-scoped idempotency key for safe retry handling. Not required for one-order-per-draft enforcement.';
