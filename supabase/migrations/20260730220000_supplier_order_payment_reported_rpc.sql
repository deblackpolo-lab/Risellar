-- Pay on Delivery Payment Phase 1: supplier reports customer payment received.
-- This records an unverified supplier payment report after delivery, commits
-- reserved stock to sold stock exactly once, creates pending supplier settlement
-- and locked reseller commission rows, and keeps admin settlement verification,
-- commission release, withdrawals, refunds, online payments, and order
-- completion deferred.

alter type public.order_status add value if not exists 'payment_reported' after 'delivered';
alter type public.payment_collection_status add value if not exists 'supplier_reported' after 'not_collected';

alter table public.orders
  add column if not exists payment_reported_at timestamptz,
  add column if not exists payment_reported_by_profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists payment_reported_idempotency_key text;

alter table public.orders
  drop constraint if exists orders_payment_reported_idempotency_key_check;

alter table public.orders
  add constraint orders_payment_reported_idempotency_key_check
  check (payment_reported_idempotency_key is null or length(trim(payment_reported_idempotency_key)) between 1 and 140);

create table if not exists public.supplier_payment_reports (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  reported_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  payment_method public.payment_method not null default 'pay_on_delivery',
  reported_amount numeric(12,2) not null,
  currency_code text not null default 'GHS',
  payment_reference text,
  supplier_private_note text,
  idempotency_key text,
  reported_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint supplier_payment_reports_amount_nonnegative check (reported_amount >= 0),
  constraint supplier_payment_reports_reference_length check (payment_reference is null or length(payment_reference) <= 100),
  constraint supplier_payment_reports_note_length check (supplier_private_note is null or length(supplier_private_note) <= 300),
  constraint supplier_payment_reports_reference_not_secret check (payment_reference is null or payment_reference !~* '(pin|password|secret|card number|cvv|otp)'),
  constraint supplier_payment_reports_note_not_html check (supplier_private_note is null or supplier_private_note !~ '<[^>]+>')
);

alter table public.supplier_payment_reports enable row level security;
alter table public.supplier_payment_reports force row level security;

create index if not exists supplier_payment_reports_supplier_reported_at_idx
  on public.supplier_payment_reports(supplier_id, reported_at desc)
  where deleted_at is null;

drop policy if exists "supplier_payment_reports_select_owner_or_admin" on public.supplier_payment_reports;
create policy "supplier_payment_reports_select_owner_or_admin"
  on public.supplier_payment_reports for select
  using (
    exists (
      select 1
      from public.suppliers s
      where s.id = supplier_payment_reports.supplier_id
        and s.owner_profile_id = public.current_profile_id()
        and s.deleted_at is null
    )
    or public.has_admin_role('finance_staff')
  );

drop policy if exists "supplier_payment_reports_insert_owner_rpc_only" on public.supplier_payment_reports;
create policy "supplier_payment_reports_insert_owner_rpc_only"
  on public.supplier_payment_reports for insert
  with check (
    exists (
      select 1
      from public.suppliers s
      join public.profiles p on p.id = s.owner_profile_id
      where s.id = supplier_payment_reports.supplier_id
        and s.owner_profile_id = public.current_profile_id()
        and p.primary_role = 'supplier_owner'
        and p.account_status = 'active'
        and p.deleted_at is null
        and s.supplier_status = 'active'
        and s.verification_status = 'approved'
        and s.deleted_at is null
    )
  );

revoke all on public.supplier_payment_reports from public, anon, authenticated;

create index if not exists idx_orders_payment_reported_at
  on public.orders(payment_reported_at)
  where payment_reported_at is not null and deleted_at is null;

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
  delivery_confirmation_note text,
  payment_reported_at timestamptz,
  payment_reference text,
  supplier_payment_private_note text,
  platform_amount_due numeric,
  reseller_commission_due numeric,
  settlement_status_label text,
  commission_status_label text
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
      when o.order_status::text = 'payment_reported' then 'Payment reported - settlement pending'
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
    case o.payment_collection_status::text
      when 'not_collected' then 'Payment not collected'
      when 'supplier_reported' then 'Payment reported by supplier'
      when 'pending' then 'Payment pending'
      when 'collected' then 'Payment collected'
      when 'failed' then 'Payment failed'
      when 'refunded' then 'Payment refunded'
      when 'disputed' then 'Payment disputed'
      else 'Payment status unavailable'
    end as payment_status_label,
    case
      when o.order_status::text = 'payment_reported' then 'Delivered - payment reported by supplier'
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
    o.delivery_confirmation_note,
    o.payment_reported_at,
    spr.payment_reference,
    spr.supplier_private_note as supplier_payment_private_note,
    case when spr.id is not null then coalesce(st.due_amount, round(sum(oi.settlement_due_amount) over (partition by o.id), 2)) - round(sum(oi.commission_amount) over (partition by o.id), 2) else null end as platform_amount_due,
    case when spr.id is not null then round(sum(oi.commission_amount) over (partition by o.id), 2) else null end as reseller_commission_due,
    case
      when st.settlement_status = 'due' then 'Pending settlement to Risellar'
      when st.settlement_status is null and spr.id is not null then 'Pending settlement to Risellar'
      else null
    end as settlement_status_label,
    case
      when cm.commission_status = 'awaiting_supplier_settlement' then 'Locked until settlement is verified'
      when cm.commission_status is null and spr.id is not null then 'Locked until settlement is verified'
      else null
    end as commission_status_label
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
  left join public.supplier_payment_reports spr on spr.order_id = o.id and spr.deleted_at is null
  left join public.settlements st on st.order_id = o.id and st.deleted_at is null
  left join public.commissions cm on cm.order_item_id = oi.id
  where o.id = p_order_id
    and oi.supplier_id = v_supplier_id
    and o.deleted_at is null
  order by sr.created_at asc nulls last
  limit 1;
end;
$fn$;

create or replace function public.supplier_report_order_payment_received(
  p_order_id uuid,
  p_payment_reference text default null,
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
  delivery_arranged_at timestamptz,
  out_for_delivery_at timestamptz,
  dispatch_reference text,
  customer_dispatch_instruction text,
  delivered_at timestamptz,
  delivery_confirmation_note text,
  payment_reported_at timestamptz,
  payment_reference text,
  supplier_payment_private_note text,
  platform_amount_due numeric,
  reseller_commission_due numeric,
  settlement_status_label text,
  commission_status_label text
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
  v_variant public.product_variants%rowtype;
  v_arrangement_id uuid;
  v_payment_reference text := nullif(trim(coalesce(p_payment_reference, '')), '');
  v_supplier_private_note text := nullif(trim(coalesce(p_supplier_private_note, '')), '');
  v_idempotency_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_payment_report public.supplier_payment_reports%rowtype;
  v_supplier_amount numeric;
  v_platform_amount numeric;
  v_commission_amount numeric;
  v_settlement_due numeric;
  v_line_total numeric;
  v_settlement_id uuid;
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

  if v_payment_reference is not null and length(v_payment_reference) > 100 then
    raise exception 'FIELD_TOO_LONG'
      using errcode = '23514';
  end if;

  if v_supplier_private_note is not null and length(v_supplier_private_note) > 300 then
    raise exception 'FIELD_TOO_LONG'
      using errcode = '23514';
  end if;

  if coalesce(v_payment_reference, '') ~ '<[^>]+>'
    or coalesce(v_supplier_private_note, '') ~ '<[^>]+>' then
    raise exception 'INVALID_PAYMENT_FIELD'
      using errcode = '23514';
  end if;

  if coalesce(v_payment_reference, '') ~* '(pin|password|secret|card number|cvv|otp)'
    or coalesce(v_supplier_private_note, '') ~* '(pin|password|secret|card number|cvv|otp)' then
    raise exception 'INVALID_PAYMENT_FIELD'
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
    min(oi.supplier_id::text)::uuid as supplier_id,
    min(oi.variant_id::text)::uuid as variant_id,
    round(sum(oi.supplier_base_price_snapshot_amount * oi.quantity), 2) as supplier_amount,
    round(sum(oi.platform_margin_snapshot_amount * oi.quantity), 2) as platform_amount,
    round(sum(oi.commission_amount), 2) as commission_amount,
    round(sum(oi.settlement_due_amount), 2) as settlement_due,
    round(sum(oi.line_total_amount), 2) as line_total
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

  select *
  into v_payment_report
  from public.supplier_payment_reports spr
  where spr.order_id = p_order_id
    and spr.deleted_at is null
  for update;

  if v_order.order_status::text = 'payment_reported' then
    if v_payment_report.id is not null
      and v_order.payment_reported_idempotency_key is not distinct from v_idempotency_key
      and v_payment_report.payment_reference is not distinct from v_payment_reference
      and v_payment_report.supplier_private_note is not distinct from v_supplier_private_note then
      return query select * from public.get_supplier_order_safe(p_order_id);
      return;
    end if;

    raise exception 'CONFLICTING_RETRY'
      using errcode = '23505';
  end if;

  if v_order.order_status::text <> 'delivered' then
    raise exception 'ORDER_NOT_DELIVERED'
      using errcode = '23514';
  end if;

  if v_order.delivered_at is null then
    raise exception 'ORDER_NOT_DELIVERED'
      using errcode = '23514';
  end if;

  if v_order.payment_method <> 'pay_on_delivery' then
    raise exception 'PAYMENT_METHOD_NOT_SUPPORTED'
      using errcode = '23514';
  end if;

  if v_order.payment_collection_status::text <> 'not_collected' then
    raise exception 'PAYMENT_ALREADY_COLLECTED'
      using errcode = '23514';
  end if;

  select da.id
  into v_arrangement_id
  from public.delivery_arrangements da
  where da.order_id = p_order_id
    and da.supplier_id = v_supplier_id
    and da.deleted_at is null
  limit 1;

  if v_arrangement_id is null or v_order.out_for_delivery_at is null then
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

  select *
  into v_variant
  from public.product_variants pv
  where pv.id = v_reservation.variant_id
    and pv.product_id = v_reservation.product_id
    and pv.deleted_at is null
  for update;

  if v_variant.id is null or v_variant.reserved_stock_quantity < v_reservation.quantity then
    raise exception 'STOCK_STATE_INCONSISTENT'
      using errcode = '23514';
  end if;

  v_supplier_amount := coalesce(v_item.supplier_amount, 0);
  v_platform_amount := coalesce(v_item.platform_amount, 0);
  v_commission_amount := coalesce(v_item.commission_amount, 0);
  v_settlement_due := coalesce(v_item.settlement_due, 0);
  v_line_total := coalesce(v_item.line_total, 0);

  if round(v_supplier_amount + v_platform_amount + v_commission_amount, 2) <> round(v_order.total_payable_amount, 2)
    or round(v_platform_amount + v_commission_amount, 2) <> round(v_settlement_due, 2)
    or round(v_line_total, 2) <> round(v_order.total_payable_amount, 2) then
    raise exception 'FINANCIAL_SNAPSHOT_INVALID'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.settlements st
    where st.order_id = p_order_id
      and st.deleted_at is null
  ) then
    raise exception 'CONFLICTING_RETRY'
      using errcode = '23505';
  end if;

  if exists (
    select 1
    from public.commissions cm
    where cm.order_id = p_order_id
  ) then
    raise exception 'CONFLICTING_RETRY'
      using errcode = '23505';
  end if;

  insert into public.supplier_payment_reports(
    order_id,
    supplier_id,
    reported_by_profile_id,
    payment_method,
    reported_amount,
    currency_code,
    payment_reference,
    supplier_private_note,
    idempotency_key
  )
  values (
    p_order_id,
    v_supplier_id,
    v_profile_id,
    v_order.payment_method,
    v_order.total_payable_amount,
    v_order.currency_code,
    v_payment_reference,
    v_supplier_private_note,
    v_idempotency_key
  );

  insert into public.settlements(
    supplier_id,
    order_id,
    settlement_status,
    due_amount,
    paid_amount,
    outstanding_amount,
    due_at,
    verified_at,
    verified_by_profile_id,
    risk_level
  )
  values (
    v_supplier_id,
    p_order_id,
    'due',
    v_settlement_due,
    0,
    v_settlement_due,
    now() + interval '7 days',
    null,
    null,
    'low'
  )
  returning id into v_settlement_id;

  insert into public.commissions(
    reseller_id,
    order_id,
    order_item_id,
    settlement_id,
    commission_status,
    commission_amount,
    available_at,
    withdrawal_id,
    held_reason
  )
  select
    v_order.reseller_id,
    p_order_id,
    oi.id,
    v_settlement_id,
    'awaiting_supplier_settlement',
    oi.commission_amount,
    null,
    null,
    'payment_reported_locked'
  from public.order_items oi
  where oi.order_id = p_order_id;

  update public.stock_reservations sr
  set reservation_status = 'committed',
      committed_at = coalesce(sr.committed_at, now()),
      updated_at = now()
  where sr.id = v_reservation.id;

  update public.product_variants pv
  set reserved_stock_quantity = pv.reserved_stock_quantity - v_reservation.quantity,
      sold_stock_quantity = pv.sold_stock_quantity + v_reservation.quantity,
      updated_at = now()
  where pv.id = v_variant.id
    and pv.reserved_stock_quantity >= v_reservation.quantity;

  if not found then
    raise exception 'STOCK_STATE_INCONSISTENT'
      using errcode = '23514';
  end if;

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
    v_supplier_id,
    v_reservation.product_id,
    v_reservation.variant_id,
    'sale_committed',
    -v_reservation.quantity,
    v_variant.total_stock_quantity,
    v_variant.total_stock_quantity,
    'Reserved stock committed after supplier reported Pay on Delivery payment received',
    p_order_id,
    v_profile_id
  );

  update public.orders o
  set order_status = 'payment_reported'::text::public.order_status,
      payment_collection_status = 'supplier_reported'::text::public.payment_collection_status,
      payment_reported_at = coalesce(o.payment_reported_at, now()),
      payment_reported_by_profile_id = coalesce(o.payment_reported_by_profile_id, v_profile_id),
      payment_reported_idempotency_key = coalesce(o.payment_reported_idempotency_key, v_idempotency_key),
      updated_at = now()
  where o.id = p_order_id;

  select count(*)::integer
  into v_existing_audit_count
  from public.audit_logs al
  where al.target_entity_type = 'orders'
    and al.target_entity_id = p_order_id
    and al.action = 'supplier_order_payment_reported';

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
      'supplier_order_payment_reported',
      'orders',
      p_order_id,
      jsonb_build_object('order_status', v_order.order_status::text, 'payment_collection_status', v_order.payment_collection_status::text),
      jsonb_build_object(
        'order_status', 'payment_reported',
        'payment_collection_status', 'supplier_reported',
        'reported_amount_source', 'order_total_snapshot',
        'stock_reservation_status', 'committed',
        'settlement_status', 'due',
        'commission_status', 'awaiting_supplier_settlement',
        'reference_present', v_payment_reference is not null,
        'private_note_present', v_supplier_private_note is not null,
        'idempotency_key_present', v_idempotency_key is not null
      ),
      'Supplier reported Pay on Delivery payment received; settlement and commission remain pending verification'
    );
  end if;

  perform public.create_audit_log_entry(
    'stock_sale_committed',
    'stock_reservations',
    v_reservation.id,
    'Reserved stock committed to sold stock after supplier payment report',
    null,
    jsonb_build_object(
      'order_id', p_order_id,
      'quantity', v_reservation.quantity,
      'total_stock_changed', false
    )
  );

  perform public.create_audit_log_entry(
    'supplier_settlement_due_created',
    'settlements',
    v_settlement_id,
    'Supplier settlement obligation created after payment report',
    null,
    jsonb_build_object(
      'order_id', p_order_id,
      'settlement_status', 'due',
      'commission_status', 'awaiting_supplier_settlement'
    )
  );

  return query select * from public.get_supplier_order_safe(p_order_id);
end;
$fn$;

comment on function public.supplier_report_order_payment_received(uuid, text, text, text)
  is 'Supplier-owner Pay on Delivery payment report boundary. Records supplier report, commits reserved stock to sold, creates pending settlement and locked commission, and does not complete order, verify settlement, release commission, or create withdrawal.';

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
      when o.order_status::text = 'payment_reported' then 'Payment reported by supplier'
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
    case o.payment_collection_status::text
      when 'not_collected' then 'Payment not collected'
      when 'supplier_reported' then 'Payment reported by supplier'
      when 'pending' then 'Payment pending'
      when 'collected' then 'Payment collected'
      when 'failed' then 'Payment failed'
      when 'refunded' then 'Payment refunded'
      when 'disputed' then 'Payment disputed'
      else 'Payment status unavailable'
    end as payment_collection_label,
    case
      when o.order_status::text = 'payment_reported' then 'Delivery completed - supplier reported receiving Pay on Delivery payment'
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
      when o.order_status::text = 'payment_reported' then 'Supplier reported receiving the Pay on Delivery payment. Risellar has not independently verified the payment, and the order is awaiting settlement verification.'
      when o.order_status::text = 'out_for_delivery' then 'Risellar has not collected the order or delivery fee. Please pay according to the Pay on Delivery arrangement.'
      else null
    end as dispatch_notice,
    o.delivered_at,
    case
      when o.order_status::text = 'payment_reported' then 'Delivery completed. Supplier reported payment received; Risellar has not independently verified the payment or settlement.'
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

drop function if exists public.list_supplier_orders_safe(text, integer, timestamptz, uuid);

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
      when o.order_status::text = 'payment_reported' then 'Payment reported - settlement pending'
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
    case o.payment_collection_status::text
      when 'not_collected' then 'Payment not collected'
      when 'supplier_reported' then 'Payment reported by supplier'
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
    coalesce(nullif(o.delivery_address_snapshot ->> 'recipient_name', ''), nullif(o.customer_contact_snapshot ->> 'full_name', '')) as recipient_name,
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

revoke all on function public.supplier_report_order_payment_received(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.supplier_report_order_payment_received(uuid, text, text, text) to authenticated;

revoke all on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) to authenticated;

revoke all on function public.get_supplier_order_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_supplier_order_safe(uuid) to authenticated;

revoke all on function public.get_customer_order_safe(uuid) from public, anon, authenticated;
grant execute on function public.get_customer_order_safe(uuid) to authenticated;

comment on table public.supplier_payment_reports
  is 'Supplier-reported Pay on Delivery payment claim. This is unverified and does not complete settlement, release commission, or enable withdrawal.';
comment on column public.orders.payment_reported_at
  is 'Timestamp when owning supplier reported Pay on Delivery payment received. Does not mean Risellar verified settlement or completed the order.';
