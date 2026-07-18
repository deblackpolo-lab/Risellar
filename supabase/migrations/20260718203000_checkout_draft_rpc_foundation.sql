-- Checkout Phase B Group 1: checkout draft RPC foundation.
-- Forward migration only. Does not create orders, stock reservations, payments, delivery quotes,
-- settlements, commissions, withdrawals, or customer purchase flow side effects.

create table if not exists public.checkout_drafts (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  customer_profile_id uuid not null references public.profiles(id) on delete restrict,
  reseller_product_id uuid not null references public.reseller_products(id) on delete restrict,
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  shop_id uuid not null references public.reseller_shops(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid references public.product_variants(id) on delete restrict,
  quantity integer not null default 1,
  draft_status text not null default 'draft',
  product_name_snapshot text not null,
  product_slug_snapshot text,
  product_description_snapshot text,
  product_category_snapshot text,
  product_brand_snapshot text,
  product_image_snapshot jsonb not null default '{}'::jsonb,
  final_customer_price_snapshot_amount numeric(12,2) not null,
  line_total_snapshot_amount numeric(12,2) not null,
  currency_code text not null default 'GHS',
  customer_contact_snapshot jsonb not null default '{}'::jsonb,
  delivery_address_id uuid references public.customer_delivery_addresses(id) on delete restrict,
  delivery_address_snapshot jsonb not null default '{}'::jsonb,
  public_listing_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  abandoned_at timestamptz,
  deleted_at timestamptz,
  constraint checkout_drafts_quantity_positive check (quantity > 0),
  constraint checkout_drafts_status_check check (draft_status in ('draft', 'review_pending', 'abandoned')),
  constraint checkout_drafts_price_nonnegative check (
    final_customer_price_snapshot_amount >= 0
    and line_total_snapshot_amount >= 0
  )
);

create index if not exists checkout_drafts_customer_status_created_idx
  on public.checkout_drafts(customer_id, draft_status, created_at desc)
  where deleted_at is null;

create index if not exists checkout_drafts_listing_idx
  on public.checkout_drafts(reseller_product_id, created_at desc)
  where deleted_at is null;

alter table public.checkout_drafts enable row level security;
alter table public.checkout_drafts force row level security;

drop policy if exists "checkout_drafts_select_own_or_support" on public.checkout_drafts;
create policy "checkout_drafts_select_own_or_support"
  on public.checkout_drafts for select
  using (public.is_customer_owner(customer_id) or public.has_admin_role('support_staff'));

drop policy if exists "checkout_drafts_insert_own" on public.checkout_drafts;
create policy "checkout_drafts_insert_own"
  on public.checkout_drafts for insert
  with check (public.is_customer_owner(customer_id));

drop policy if exists "checkout_drafts_update_own_or_support" on public.checkout_drafts;
create policy "checkout_drafts_update_own_or_support"
  on public.checkout_drafts for update
  using (public.is_customer_owner(customer_id) or public.has_admin_role('support_staff'))
  with check (public.is_customer_owner(customer_id) or public.has_admin_role('support_staff'));

create or replace function public.checkout_phase_b_normalize_quantity(p_quantity integer)
returns integer
language plpgsql
immutable
set search_path = public
as $$
begin
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'INVALID_QUANTITY'
      using errcode = '23514';
  end if;

  return p_quantity;
end;
$$;

create or replace function public.checkout_draft_current_customer_context()
returns table (
  profile_id uuid,
  customer_id uuid,
  actor_role public.user_role
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_actor_role public.user_role;
  v_customer_id uuid;
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED'
      using errcode = '28000';
  end if;

  select p.primary_role
  into v_actor_role
  from public.profiles p
  where p.id = v_profile_id
    and p.account_status = 'active'
    and p.deleted_at is null;

  if v_actor_role is null then
    raise exception 'ACTIVE_PROFILE_REQUIRED'
      using errcode = '28000';
  end if;

  if v_actor_role <> 'customer' then
    raise exception 'CUSTOMER_ROLE_REQUIRED'
      using errcode = '42501';
  end if;

  v_customer_id := public.current_customer_id();

  return query
  select v_profile_id, v_customer_id, v_actor_role;
end;
$$;

create or replace function public.checkout_draft_safe_row(p_draft_id uuid)
returns table (
  draft_id uuid,
  draft_status text,
  customer_id uuid,
  reseller_product_id uuid,
  product_id uuid,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  currency_code text,
  delivery_address_id uuid,
  customer_contact_snapshot jsonb,
  delivery_address_snapshot jsonb,
  public_listing_snapshot jsonb,
  abandoned_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    cd.id as draft_id,
    cd.draft_status,
    cd.customer_id,
    cd.reseller_product_id,
    cd.product_id,
    cd.product_name_snapshot as product_name,
    cd.product_slug_snapshot as product_slug,
    cd.product_image_snapshot,
    cd.quantity,
    cd.final_customer_price_snapshot_amount as final_customer_price_amount,
    cd.line_total_snapshot_amount as line_total_amount,
    cd.currency_code,
    cd.delivery_address_id,
    cd.customer_contact_snapshot,
    cd.delivery_address_snapshot,
    cd.public_listing_snapshot,
    cd.abandoned_at,
    cd.created_at,
    cd.updated_at
  from public.checkout_drafts cd
  where cd.id = p_draft_id
    and cd.deleted_at is null
    and (public.is_customer_owner(cd.customer_id) or public.has_admin_role('support_staff'));
$$;

create or replace function public.create_checkout_draft_from_listing(
  p_listing_id uuid,
  p_quantity integer default 1
)
returns table (
  draft_id uuid,
  draft_status text,
  customer_id uuid,
  reseller_product_id uuid,
  product_id uuid,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  currency_code text,
  delivery_address_id uuid,
  customer_contact_snapshot jsonb,
  delivery_address_snapshot jsonb,
  public_listing_snapshot jsonb,
  abandoned_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_context record;
  v_listing record;
  v_quantity integer := public.checkout_phase_b_normalize_quantity(p_quantity);
  v_draft_id uuid;
  v_contact_snapshot jsonb;
  v_image_snapshot jsonb;
  v_public_listing_snapshot jsonb;
begin
  if p_listing_id is null then
    raise exception 'LISTING_ID_REQUIRED'
      using errcode = '23514';
  end if;

  select *
  into v_context
  from public.checkout_draft_current_customer_context()
  limit 1;

  select
    rp.id as listing_id,
    rp.reseller_id,
    rp.shop_id,
    rp.product_id,
    rp.variant_id,
    rp.customer_product_price_amount,
    rp.share_slug,
    p.supplier_id,
    p.name,
    p.slug,
    p.description,
    p.category,
    p.brand,
    p.currency_code
  into v_listing
  from public.reseller_products rp
  join public.reseller_shops rs on rs.id = rp.shop_id
  join public.resellers r on r.id = rp.reseller_id
  join public.products p on p.id = rp.product_id
  join public.suppliers s on s.id = p.supplier_id
  where rp.id = p_listing_id
    and rp.listing_status = 'active'
    and rp.deleted_at is null
    and rs.shop_status = 'active'
    and rs.deleted_at is null
    and r.approval_status = 'approved'
    and r.deleted_at is null
    and p.product_status = 'active'
    and p.approval_status = 'approved'
    and p.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and s.deleted_at is null
  for update of rp;

  if v_listing.listing_id is null then
    raise exception 'CHECKOUT_LISTING_NOT_AVAILABLE'
      using errcode = '42501';
  end if;

  select jsonb_build_object(
           'email', p.email,
           'full_name', p.full_name,
           'phone', p.phone,
           'whatsapp', p.whatsapp
         )
  into v_contact_snapshot
  from public.profiles p
  where p.id = v_context.profile_id;

  select jsonb_build_object(
           'image_count', count(*)::integer,
           'primary_image_alt', (
             select pi2.alt_text
             from public.product_images pi2
             where pi2.product_id = v_listing.product_id
               and pi2.image_status = 'active'
               and pi2.deleted_at is null
             order by pi2.is_primary desc, pi2.sort_order asc, pi2.created_at asc, pi2.id::text asc
             limit 1
           )
         )
  into v_image_snapshot
  from public.product_images pi
  where pi.product_id = v_listing.product_id
    and pi.image_status = 'active'
    and pi.deleted_at is null;

  v_public_listing_snapshot := jsonb_build_object(
    'listing_id', v_listing.listing_id,
    'share_slug', v_listing.share_slug,
    'product_id', v_listing.product_id,
    'product_slug', v_listing.slug,
    'product_name', v_listing.name,
    'category', v_listing.category,
    'brand', v_listing.brand
  );

  insert into public.checkout_drafts(
    customer_id,
    customer_profile_id,
    reseller_product_id,
    reseller_id,
    shop_id,
    supplier_id,
    product_id,
    variant_id,
    quantity,
    draft_status,
    product_name_snapshot,
    product_slug_snapshot,
    product_description_snapshot,
    product_category_snapshot,
    product_brand_snapshot,
    product_image_snapshot,
    final_customer_price_snapshot_amount,
    line_total_snapshot_amount,
    currency_code,
    customer_contact_snapshot,
    public_listing_snapshot
  )
  values (
    v_context.customer_id,
    v_context.profile_id,
    v_listing.listing_id,
    v_listing.reseller_id,
    v_listing.shop_id,
    v_listing.supplier_id,
    v_listing.product_id,
    v_listing.variant_id,
    v_quantity,
    'draft',
    v_listing.name,
    v_listing.slug,
    v_listing.description,
    v_listing.category,
    v_listing.brand,
    coalesce(v_image_snapshot, '{}'::jsonb),
    v_listing.customer_product_price_amount,
    round(v_listing.customer_product_price_amount * v_quantity, 2),
    v_listing.currency_code,
    coalesce(v_contact_snapshot, '{}'::jsonb),
    v_public_listing_snapshot
  )
  returning id into v_draft_id;

  perform public.create_audit_log_entry(
    'create_checkout_draft',
    'checkout_drafts',
    v_draft_id,
    'Customer created checkout draft from active approved reseller listing',
    null,
    jsonb_build_object(
      'customer_id', v_context.customer_id,
      'reseller_product_id', v_listing.listing_id,
      'product_id', v_listing.product_id,
      'quantity', v_quantity,
      'final_customer_price_snapshot_amount', v_listing.customer_product_price_amount,
      'line_total_snapshot_amount', round(v_listing.customer_product_price_amount * v_quantity, 2)
    )
  );

  return query
  select *
  from public.checkout_draft_safe_row(v_draft_id);
end;
$$;

create or replace function public.get_checkout_draft(p_draft_id uuid)
returns table (
  draft_id uuid,
  draft_status text,
  customer_id uuid,
  reseller_product_id uuid,
  product_id uuid,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  currency_code text,
  delivery_address_id uuid,
  customer_contact_snapshot jsonb,
  delivery_address_snapshot jsonb,
  public_listing_snapshot jsonb,
  abandoned_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_context record;
begin
  if p_draft_id is null then
    raise exception 'DRAFT_ID_REQUIRED'
      using errcode = '23514';
  end if;

  select *
  into v_context
  from public.checkout_draft_current_customer_context()
  limit 1;

  return query
  select *
  from public.checkout_draft_safe_row(p_draft_id);
end;
$$;

create or replace function public.update_checkout_draft_contact_address(
  p_draft_id uuid,
  p_address_id uuid,
  p_contact_phone text default null
)
returns table (
  draft_id uuid,
  draft_status text,
  customer_id uuid,
  reseller_product_id uuid,
  product_id uuid,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  currency_code text,
  delivery_address_id uuid,
  customer_contact_snapshot jsonb,
  delivery_address_snapshot jsonb,
  public_listing_snapshot jsonb,
  abandoned_at timestamptz,
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
  v_address public.customer_delivery_addresses%rowtype;
  v_before jsonb;
  v_contact_snapshot jsonb;
  v_address_snapshot jsonb;
begin
  if p_draft_id is null then
    raise exception 'DRAFT_ID_REQUIRED'
      using errcode = '23514';
  end if;

  if p_address_id is null then
    raise exception 'ADDRESS_ID_REQUIRED'
      using errcode = '23514';
  end if;

  select *
  into v_context
  from public.checkout_draft_current_customer_context()
  limit 1;

  select *
  into v_draft
  from public.checkout_drafts cd
  where cd.id = p_draft_id
    and cd.customer_id = v_context.customer_id
    and cd.deleted_at is null
  for update;

  if not found then
    raise exception 'CHECKOUT_DRAFT_NOT_FOUND'
      using errcode = '42501';
  end if;

  if v_draft.draft_status = 'abandoned' then
    raise exception 'CHECKOUT_DRAFT_NOT_ACTIVE'
      using errcode = '42501';
  end if;

  select *
  into v_address
  from public.customer_delivery_addresses a
  where a.id = p_address_id
    and a.customer_id = v_context.customer_id
    and a.deleted_at is null;

  if not found then
    raise exception 'CUSTOMER_ADDRESS_NOT_FOUND'
      using errcode = '42501';
  end if;

  select to_jsonb(cd)
  into v_before
  from public.checkout_drafts cd
  where cd.id = p_draft_id;

  select jsonb_build_object(
           'email', p.email,
           'full_name', p.full_name,
           'phone', coalesce(nullif(trim(coalesce(p_contact_phone, '')), ''), p.phone),
           'whatsapp', p.whatsapp
         )
  into v_contact_snapshot
  from public.profiles p
  where p.id = v_context.profile_id;

  v_address_snapshot := jsonb_build_object(
    'label', v_address.label,
    'recipient_name', v_address.recipient_name,
    'phone', v_address.phone,
    'region', v_address.region,
    'city', v_address.city,
    'area', v_address.area,
    'street_address', v_address.street_address,
    'landmark', v_address.landmark,
    'is_default', v_address.is_default
  );

  update public.checkout_drafts cd
  set draft_status = 'review_pending',
      delivery_address_id = v_address.id,
      customer_contact_snapshot = coalesce(v_contact_snapshot, '{}'::jsonb),
      delivery_address_snapshot = v_address_snapshot,
      updated_at = now()
  where cd.id = p_draft_id;

  perform public.create_audit_log_entry(
    'update_checkout_draft_contact_address',
    'checkout_drafts',
    p_draft_id,
    'Customer attached contact and delivery address snapshot to checkout draft',
    v_before,
    (
      select to_jsonb(cd)
      from public.checkout_drafts cd
      where cd.id = p_draft_id
    )
  );

  return query
  select *
  from public.checkout_draft_safe_row(p_draft_id);
end;
$$;

create or replace function public.abandon_checkout_draft(p_draft_id uuid)
returns table (
  draft_id uuid,
  draft_status text,
  customer_id uuid,
  reseller_product_id uuid,
  product_id uuid,
  product_name text,
  product_slug text,
  product_image_snapshot jsonb,
  quantity integer,
  final_customer_price_amount numeric,
  line_total_amount numeric,
  currency_code text,
  delivery_address_id uuid,
  customer_contact_snapshot jsonb,
  delivery_address_snapshot jsonb,
  public_listing_snapshot jsonb,
  abandoned_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_context record;
  v_before jsonb;
begin
  if p_draft_id is null then
    raise exception 'DRAFT_ID_REQUIRED'
      using errcode = '23514';
  end if;

  select *
  into v_context
  from public.checkout_draft_current_customer_context()
  limit 1;

  select to_jsonb(cd)
  into v_before
  from public.checkout_drafts cd
  where cd.id = p_draft_id
    and cd.customer_id = v_context.customer_id
    and cd.deleted_at is null
  for update;

  if v_before is null then
    raise exception 'CHECKOUT_DRAFT_NOT_FOUND'
      using errcode = '42501';
  end if;

  update public.checkout_drafts cd
  set draft_status = 'abandoned',
      abandoned_at = coalesce(cd.abandoned_at, now()),
      updated_at = now()
  where cd.id = p_draft_id
    and cd.customer_id = v_context.customer_id
    and cd.deleted_at is null;

  perform public.create_audit_log_entry(
    'abandon_checkout_draft',
    'checkout_drafts',
    p_draft_id,
    'Customer abandoned checkout draft before order creation',
    v_before,
    (
      select to_jsonb(cd)
      from public.checkout_drafts cd
      where cd.id = p_draft_id
    )
  );

  return query
  select *
  from public.checkout_draft_safe_row(p_draft_id);
end;
$$;

revoke all on table public.checkout_drafts from public;
revoke all on function public.checkout_phase_b_normalize_quantity(integer) from public;
revoke all on function public.checkout_draft_current_customer_context() from public;
revoke all on function public.checkout_draft_safe_row(uuid) from public;
revoke all on function public.create_checkout_draft_from_listing(uuid, integer) from public;
revoke all on function public.get_checkout_draft(uuid) from public;
revoke all on function public.update_checkout_draft_contact_address(uuid, uuid, text) from public;
revoke all on function public.abandon_checkout_draft(uuid) from public;

grant execute on function public.create_checkout_draft_from_listing(uuid, integer) to authenticated;
grant execute on function public.get_checkout_draft(uuid) to authenticated;
grant execute on function public.update_checkout_draft_contact_address(uuid, uuid, text) to authenticated;
grant execute on function public.abandon_checkout_draft(uuid) to authenticated;

comment on table public.checkout_drafts
  is 'Checkout Phase B draft-only table. Stores customer-owned server-calculated public listing snapshots without creating orders, stock reservations, payments, delivery quotes, settlements, commissions, or withdrawals.';

comment on function public.create_checkout_draft_from_listing(uuid, integer)
  is 'Creates a customer-owned checkout draft from an active approved reseller listing using server-calculated price snapshots. Does not reserve stock or create an order.';

comment on function public.update_checkout_draft_contact_address(uuid, uuid, text)
  is 'Attaches customer-owned delivery address/contact snapshots to an existing customer checkout draft. Does not create delivery quotes or orders.';

comment on function public.abandon_checkout_draft(uuid)
  is 'Softly abandons a customer-owned checkout draft before order creation. No stock or payment side effects.';
