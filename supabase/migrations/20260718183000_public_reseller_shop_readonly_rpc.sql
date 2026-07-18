-- Public reseller shop read-only RPC foundation.
-- Development/code foundation only. Dry-run before applying to development.
-- Does not connect checkout, orders, stock reservation, payments, delivery,
-- settlements, commissions, withdrawals, or customer purchase flows.

create or replace function public.public_stock_availability_label(p_product_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when coalesce(sum(greatest(pv.total_stock_quantity - pv.reserved_stock_quantity, 0)), 0) <= 0 then 'Out of stock'
    when coalesce(sum(greatest(pv.total_stock_quantity - pv.reserved_stock_quantity, 0)), 0) <= 3 then 'Low stock'
    else coalesce(sum(greatest(pv.total_stock_quantity - pv.reserved_stock_quantity, 0)), 0)::integer::text || ' available'
  end
  from public.product_variants pv
  where pv.product_id = p_product_id
    and pv.variant_status in ('active', 'low_stock')
    and pv.deleted_at is null;
$$;

create or replace function public.get_public_reseller_shop(p_shop_slug text)
returns table (
  shop_slug text,
  shop_display_name text,
  shop_bio text,
  listing_id uuid,
  product_slug text,
  share_slug text,
  name text,
  description text,
  category text,
  brand text,
  listing_status public.listing_status,
  product_status public.product_status,
  approval_status public.approval_status,
  customer_product_price_amount numeric,
  currency_code text,
  stock_availability_label text,
  image_count integer,
  primary_image_alt text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    rs.shop_slug,
    rs.display_name as shop_display_name,
    rs.bio as shop_bio,
    rp.id as listing_id,
    p.slug as product_slug,
    rp.share_slug,
    p.name,
    p.description,
    p.category,
    p.brand,
    rp.listing_status,
    p.product_status,
    p.approval_status,
    rp.customer_product_price_amount,
    p.currency_code,
    public.public_stock_availability_label(p.id) as stock_availability_label,
    coalesce((
      select count(*)::integer
      from public.product_images pi
      where pi.product_id = p.id
        and pi.image_status = 'active'
        and pi.deleted_at is null
    ), 0) as image_count,
    (
      select pi.alt_text
      from public.product_images pi
      where pi.product_id = p.id
        and pi.image_status = 'active'
        and pi.deleted_at is null
      order by pi.is_primary desc, pi.sort_order asc, pi.created_at asc, pi.id::text asc
      limit 1
    ) as primary_image_alt
  from public.reseller_shops rs
  join public.reseller_products rp on rp.shop_id = rs.id
  join public.products p on p.id = rp.product_id
  join public.suppliers s on s.id = p.supplier_id
  where rs.shop_slug = lower(trim(p_shop_slug))
    and rs.shop_status = 'active'
    and rs.visibility in ('public', 'private_until_shop_flow')
    and rs.deleted_at is null
    and rp.listing_status = 'active'
    and rp.deleted_at is null
    and p.product_status = 'active'
    and p.approval_status = 'approved'
    and p.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and s.deleted_at is null
  order by rp.updated_at desc, rp.created_at desc, rp.id::text asc;
$$;

create or replace function public.get_public_reseller_shop_product(
  p_shop_slug text,
  p_product_slug text
)
returns table (
  shop_slug text,
  shop_display_name text,
  shop_bio text,
  listing_id uuid,
  product_slug text,
  share_slug text,
  name text,
  description text,
  category text,
  brand text,
  listing_status public.listing_status,
  product_status public.product_status,
  approval_status public.approval_status,
  customer_product_price_amount numeric,
  currency_code text,
  stock_availability_label text,
  image_count integer,
  primary_image_alt text
)
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.get_public_reseller_shop(p_shop_slug) public_shop
  where public_shop.share_slug = lower(trim(p_product_slug))
     or public_shop.product_slug = lower(trim(p_product_slug))
  limit 1;
$$;

revoke all on function public.public_stock_availability_label(uuid) from public;
revoke all on function public.get_public_reseller_shop(text) from public;
revoke all on function public.get_public_reseller_shop_product(text, text) from public;

grant execute on function public.get_public_reseller_shop(text) to anon, authenticated;
grant execute on function public.get_public_reseller_shop_product(text, text) to anon, authenticated;

comment on function public.get_public_reseller_shop(text)
  is 'Public read-only reseller shop listing RPC. Exposes only active approved listing/product fields and final customer price; does not expose supplier base price, platform margin, reseller margin, private supplier data, orders, stock reservations, commissions, or settlements.';

comment on function public.get_public_reseller_shop_product(text, text)
  is 'Public read-only reseller shop product detail RPC scoped by shop slug and listing share slug/product slug. No checkout or mutation behavior.';
