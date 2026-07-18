-- Reseller Add-to-Shop Backend Foundation.
-- Development/code foundation only. Do not apply to production before development RPC boundary tests pass.
-- This migration does not connect public shop, checkout, orders, stock reservation, payments, delivery,
-- settlements, commissions, withdrawals, or customer catalog flows.

create unique index if not exists reseller_products_one_open_default_listing_idx
  on public.reseller_products (reseller_id, product_id)
  where variant_id is null
    and deleted_at is null
    and listing_status <> 'archived';

create or replace function public.current_verified_reseller_id()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_reseller_id uuid;
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'Authenticated active approved reseller profile is required';
  end if;

  select r.id
  into v_reseller_id
  from public.resellers r
  join public.profiles p on p.id = r.profile_id
  where r.profile_id = v_profile_id
    and p.primary_role = 'reseller'
    and p.account_status = 'active'
    and p.deleted_at is null
    and r.approval_status = 'approved'
    and r.deleted_at is null
  order by r.created_at asc, r.id::text asc
  limit 1;

  if v_reseller_id is null then
    raise exception 'Active approved reseller account is required';
  end if;

  return v_reseller_id;
end;
$$;

create or replace function public.reseller_listing_default_margin_cap()
returns numeric
language sql
immutable
as $$
  select 500.00::numeric;
$$;

create or replace function public.reseller_listing_slug_from_product(
  p_product_id uuid,
  p_product_name text
)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(
    lower(trim(coalesce(p_product_name, 'product'))) || '-' || left(replace(p_product_id::text, '-', ''), 8),
    '[^a-z0-9]+',
    '-',
    'g'
  ));
$$;

create or replace function public.reseller_shop_slug_from_reseller(p_reseller_id uuid)
returns text
language sql
immutable
as $$
  select 'shop-' || left(replace(p_reseller_id::text, '-', ''), 24);
$$;

create or replace function public.ensure_reseller_default_shop(p_reseller_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_shop_id uuid;
  v_display_name text;
begin
  if p_reseller_id is null then
    raise exception 'Reseller id is required';
  end if;

  if not public.is_reseller_owner(p_reseller_id) then
    raise exception 'Reseller can only manage own shop';
  end if;

  select rs.id
  into v_shop_id
  from public.reseller_shops rs
  where rs.reseller_id = p_reseller_id
    and rs.deleted_at is null
    and rs.shop_status = 'active'
  order by rs.created_at asc, rs.id::text asc
  limit 1;

  if v_shop_id is not null then
    return v_shop_id;
  end if;

  select r.profile_id, coalesce(nullif(trim(p.full_name), ''), split_part(p.email, '@', 1), 'Risellar Reseller') || ' Shop'
  into v_profile_id, v_display_name
  from public.resellers r
  join public.profiles p on p.id = r.profile_id
  where r.id = p_reseller_id
    and r.deleted_at is null
    and p.deleted_at is null
    and p.account_status = 'active';

  if v_profile_id is null then
    raise exception 'Active reseller profile is required to create shop';
  end if;

  insert into public.reseller_shops (
    reseller_id,
    shop_slug,
    display_name,
    shop_status,
    visibility
  )
  values (
    p_reseller_id,
    public.reseller_shop_slug_from_reseller(p_reseller_id),
    v_display_name,
    'active',
    'private_until_shop_flow'
  )
  on conflict (shop_slug) do update
    set updated_at = now()
  returning id into v_shop_id;

  return v_shop_id;
end;
$$;

create or replace function public.assert_reseller_listing_margin(
  p_product_max_reseller_margin numeric,
  p_reseller_margin numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_margin numeric;
  v_max_margin numeric;
begin
  if p_reseller_margin is null then
    raise exception 'Reseller margin is required';
  end if;

  v_margin := round(p_reseller_margin, 2);
  v_max_margin := coalesce(nullif(p_product_max_reseller_margin, 0), public.reseller_listing_default_margin_cap());

  if v_margin <= 0 then
    raise exception 'Reseller margin must be greater than zero';
  end if;

  if v_margin > v_max_margin then
    raise exception 'Reseller margin exceeds allowed product margin limit';
  end if;

  return v_margin;
end;
$$;

create or replace function public.create_reseller_product_listing(
  p_product_id uuid,
  p_reseller_margin numeric
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reseller_id uuid;
  v_shop_id uuid;
  v_product public.products%rowtype;
  v_supplier public.suppliers%rowtype;
  v_margin numeric;
  v_listing_id uuid;
  v_share_slug text;
  v_customer_price numeric;
begin
  if p_product_id is null then
    raise exception 'Product id is required';
  end if;

  v_reseller_id := public.current_verified_reseller_id();

  select *
  into v_product
  from public.products
  where id = p_product_id
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Product not found';
  end if;

  select *
  into v_supplier
  from public.suppliers
  where id = v_product.supplier_id
    and deleted_at is null;

  if not found then
    raise exception 'Supplier not found for product';
  end if;

  if v_product.product_status <> 'active' or v_product.approval_status <> 'approved' then
    raise exception 'Only active approved products can be listed by resellers';
  end if;

  if v_supplier.supplier_status <> 'active' or v_supplier.verification_status <> 'approved' then
    raise exception 'Only active approved supplier products can be listed';
  end if;

  if exists (
    select 1
    from public.reseller_products rp
    where rp.reseller_id = v_reseller_id
      and rp.product_id = p_product_id
      and rp.variant_id is null
      and rp.deleted_at is null
      and rp.listing_status <> 'archived'
  ) then
    raise exception 'Duplicate active reseller listing already exists for this product';
  end if;

  v_margin := public.assert_reseller_listing_margin(v_product.max_reseller_margin_amount, p_reseller_margin);
  v_customer_price := v_product.base_price_amount + v_product.platform_margin_amount + v_margin;
  v_shop_id := public.ensure_reseller_default_shop(v_reseller_id);
  v_share_slug := public.reseller_listing_slug_from_product(p_product_id, v_product.name);

  while exists (
    select 1
    from public.reseller_products rp
    where rp.shop_id = v_shop_id
      and rp.share_slug = v_share_slug
  ) loop
    v_share_slug := public.reseller_listing_slug_from_product(p_product_id, v_product.name) || '-' || left(replace(gen_random_uuid()::text, '-', ''), 6);
  end loop;

  insert into public.reseller_products (
    reseller_id,
    shop_id,
    product_id,
    variant_id,
    listing_status,
    reseller_margin_amount,
    customer_product_price_amount,
    share_slug
  )
  values (
    v_reseller_id,
    v_shop_id,
    p_product_id,
    null,
    'active',
    v_margin,
    v_customer_price,
    v_share_slug
  )
  returning id into v_listing_id;

  perform public.create_audit_log_entry(
    'create_reseller_product_listing',
    'reseller_products',
    v_listing_id,
    'reseller_add_to_shop',
    null,
    jsonb_build_object(
      'product_id', p_product_id,
      'reseller_id', v_reseller_id,
      'listing_status', 'active',
      'reseller_margin_amount', v_margin,
      'customer_product_price_amount', v_customer_price
    )
  );

  return v_listing_id;
end;
$$;

create or replace function public.update_reseller_product_listing(
  p_listing_id uuid,
  p_reseller_margin numeric default null,
  p_listing_status text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reseller_id uuid;
  v_listing public.reseller_products%rowtype;
  v_product public.products%rowtype;
  v_new_margin numeric;
  v_new_status public.listing_status;
  v_customer_price numeric;
  v_before jsonb;
  v_after jsonb;
begin
  if p_listing_id is null then
    raise exception 'Listing id is required';
  end if;

  v_reseller_id := public.current_verified_reseller_id();

  select *
  into v_listing
  from public.reseller_products
  where id = p_listing_id
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Reseller listing not found';
  end if;

  if v_listing.reseller_id <> v_reseller_id then
    raise exception 'Reseller can only update own listing';
  end if;

  if v_listing.listing_status = 'archived' then
    raise exception 'Archived reseller listings cannot be updated';
  end if;

  select *
  into v_product
  from public.products
  where id = v_listing.product_id
    and deleted_at is null;

  if not found then
    raise exception 'Product not found for listing';
  end if;

  v_new_margin := case
    when p_reseller_margin is null then v_listing.reseller_margin_amount
    else public.assert_reseller_listing_margin(v_product.max_reseller_margin_amount, p_reseller_margin)
  end;

  if p_listing_status is null or length(trim(p_listing_status)) = 0 then
    v_new_status := v_listing.listing_status;
  elsif lower(trim(p_listing_status)) in ('active', 'hidden') then
    v_new_status := lower(trim(p_listing_status))::public.listing_status;
  else
    raise exception 'Listing status can only be active or hidden through this RPC';
  end if;

  v_customer_price := v_product.base_price_amount + v_product.platform_margin_amount + v_new_margin;
  v_before := jsonb_build_object(
    'listing_status', v_listing.listing_status,
    'reseller_margin_amount', v_listing.reseller_margin_amount,
    'customer_product_price_amount', v_listing.customer_product_price_amount
  );

  update public.reseller_products
  set reseller_margin_amount = v_new_margin,
      customer_product_price_amount = v_customer_price,
      listing_status = v_new_status,
      updated_at = now()
  where id = p_listing_id;

  select jsonb_build_object(
    'listing_status', rp.listing_status,
    'reseller_margin_amount', rp.reseller_margin_amount,
    'customer_product_price_amount', rp.customer_product_price_amount
  )
  into v_after
  from public.reseller_products rp
  where rp.id = p_listing_id;

  perform public.create_audit_log_entry(
    'update_reseller_product_listing',
    'reseller_products',
    p_listing_id,
    'reseller_listing_update',
    v_before,
    v_after
  );

  return p_listing_id;
end;
$$;

create or replace function public.archive_reseller_product_listing(
  p_listing_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reseller_id uuid;
  v_listing public.reseller_products%rowtype;
begin
  if p_listing_id is null then
    raise exception 'Listing id is required';
  end if;

  v_reseller_id := public.current_verified_reseller_id();

  select *
  into v_listing
  from public.reseller_products
  where id = p_listing_id
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Reseller listing not found';
  end if;

  if v_listing.reseller_id <> v_reseller_id then
    raise exception 'Reseller can only archive own listing';
  end if;

  update public.reseller_products
  set listing_status = 'archived',
      deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  where id = p_listing_id;

  perform public.create_audit_log_entry(
    'archive_reseller_product_listing',
    'reseller_products',
    p_listing_id,
    'reseller_listing_soft_archive',
    jsonb_build_object(
      'listing_status', v_listing.listing_status,
      'deleted_at', v_listing.deleted_at
    ),
    jsonb_build_object(
      'listing_status', 'archived',
      'deleted_at', now()
    )
  );

  return p_listing_id;
end;
$$;

create or replace function public.get_reseller_shop_products()
returns table (
  listing_id uuid,
  product_id uuid,
  shop_id uuid,
  supplier_id uuid,
  supplier_display_name text,
  category text,
  name text,
  slug text,
  description text,
  brand text,
  listing_status public.listing_status,
  product_status public.product_status,
  approval_status public.approval_status,
  reseller_cost_amount numeric,
  reseller_margin_amount numeric,
  customer_product_price_amount numeric,
  currency_code text,
  available_stock_quantity integer,
  image_count integer,
  share_slug text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_reseller_id uuid;
begin
  v_reseller_id := public.current_verified_reseller_id();

  return query
  select
    rp.id as listing_id,
    p.id as product_id,
    rp.shop_id,
    p.supplier_id,
    coalesce(nullif(trim(s.public_display_name), ''), s.business_name) as supplier_display_name,
    p.category,
    p.name,
    p.slug,
    p.description,
    p.brand,
    rp.listing_status,
    p.product_status,
    p.approval_status,
    p.reseller_cost_amount,
    rp.reseller_margin_amount,
    rp.customer_product_price_amount,
    p.currency_code,
    coalesce((
      select sum(greatest(pv.total_stock_quantity - pv.reserved_stock_quantity, 0))::integer
      from public.product_variants pv
      where pv.product_id = p.id
        and pv.variant_status in ('active', 'low_stock')
        and pv.deleted_at is null
    ), 0) as available_stock_quantity,
    coalesce((
      select count(*)::integer
      from public.product_images pi
      where pi.product_id = p.id
        and pi.image_status = 'active'
        and pi.deleted_at is null
    ), 0) as image_count,
    rp.share_slug,
    rp.created_at,
    rp.updated_at
  from public.reseller_products rp
  join public.products p on p.id = rp.product_id
  join public.suppliers s on s.id = p.supplier_id
  where rp.reseller_id = v_reseller_id
    and rp.deleted_at is null
    and rp.listing_status in ('active', 'hidden', 'needs_review', 'out_of_stock')
    and p.deleted_at is null
    and p.product_status = 'active'
    and p.approval_status = 'approved'
    and s.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
  order by rp.updated_at desc, rp.created_at desc, rp.id::text asc;
end;
$$;

revoke all on function public.current_verified_reseller_id() from public;
revoke all on function public.reseller_listing_default_margin_cap() from public;
revoke all on function public.reseller_listing_slug_from_product(uuid, text) from public;
revoke all on function public.reseller_shop_slug_from_reseller(uuid) from public;
revoke all on function public.ensure_reseller_default_shop(uuid) from public;
revoke all on function public.assert_reseller_listing_margin(numeric, numeric) from public;
revoke all on function public.create_reseller_product_listing(uuid, numeric) from public;
revoke all on function public.update_reseller_product_listing(uuid, numeric, text) from public;
revoke all on function public.archive_reseller_product_listing(uuid) from public;
revoke all on function public.get_reseller_shop_products() from public;

grant execute on function public.create_reseller_product_listing(uuid, numeric) to authenticated;
grant execute on function public.update_reseller_product_listing(uuid, numeric, text) to authenticated;
grant execute on function public.archive_reseller_product_listing(uuid) to authenticated;
grant execute on function public.get_reseller_shop_products() to authenticated;

comment on function public.current_verified_reseller_id()
  is 'Returns the active approved reseller id for the current Clerk/Supabase user context. Does not grant admin or supplier roles.';

comment on function public.create_reseller_product_listing(uuid, numeric)
  is 'Approved-reseller audited add-to-shop RPC. Lists only active approved supplier products, computes customer price server-side, blocks duplicate active listings, and does not reserve stock or create orders/commissions/settlements.';

comment on function public.update_reseller_product_listing(uuid, numeric, text)
  is 'Approved-reseller audited listing update RPC. Updates only own listing margin/status within backend bounds; supplier base price and platform margin remain untouched.';

comment on function public.archive_reseller_product_listing(uuid)
  is 'Approved-reseller audited soft archive RPC. No direct delete path is exposed.';

comment on function public.get_reseller_shop_products()
  is 'Approved-reseller owned shop listing read RPC. Returns reseller-safe listing/product fields only and is not a public/customer storefront feed.';
