create or replace function public.get_reseller_approved_products()
returns table (
  product_id uuid,
  supplier_id uuid,
  supplier_display_name text,
  category text,
  name text,
  slug text,
  description text,
  brand text,
  product_status public.product_status,
  approval_status public.approval_status,
  reseller_cost_amount numeric,
  max_customer_price_amount numeric,
  currency_code text,
  available_stock_quantity integer,
  image_count integer,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
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

  return query
  select
    p.id as product_id,
    p.supplier_id,
    coalesce(nullif(trim(s.public_display_name), ''), s.business_name) as supplier_display_name,
    p.category,
    p.name,
    p.slug,
    p.description,
    p.brand,
    p.product_status,
    p.approval_status,
    p.reseller_cost_amount,
    p.max_customer_price_amount,
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
    p.created_at,
    p.updated_at
  from public.products p
  join public.suppliers s on s.id = p.supplier_id
  where p.deleted_at is null
    and p.product_status = 'active'
    and p.approval_status = 'approved'
    and s.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
  order by p.updated_at desc, p.created_at desc, p.id::text asc;
end;
$$;

revoke all on function public.get_reseller_approved_products() from public;
grant execute on function public.get_reseller_approved_products() to authenticated;

comment on function public.get_reseller_approved_products()
  is 'Read-only approved product catalog for active approved resellers. Returns reseller-safe product, pricing, stock, image-count, and public supplier display fields only; no listing, stock reservation, checkout, or customer catalog write path.';
