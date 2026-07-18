-- Supplier Product Management Backend Foundation.
-- Code/schema foundation only. Do not apply to production before development SQL/RPC tests pass.

create or replace function public.supplier_product_slug_from_name(p_product_name text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(trim(coalesce(p_product_name, ''))), '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.current_verified_supplier_owner_id()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_supplier_id uuid;
  v_supplier_count integer;
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'Authenticated active supplier owner profile is required';
  end if;

  select count(*), min(s.id)
  into v_supplier_count, v_supplier_id
  from public.suppliers s
  join public.profiles p on p.id = s.owner_profile_id
  where s.owner_profile_id = v_profile_id
    and p.primary_role = 'supplier_owner'
    and p.account_status = 'active'
    and p.deleted_at is null
    and s.supplier_status = 'active'
    and s.verification_status = 'approved'
    and s.deleted_at is null;

  if v_supplier_count = 0 then
    raise exception 'Active approved supplier owner account is required';
  end if;

  if v_supplier_count > 1 then
    raise exception 'Multiple active approved supplier accounts require an explicit supplier selector';
  end if;

  return v_supplier_id;
end;
$$;

create or replace function public.supplier_product_unique_slug(
  p_supplier_id uuid,
  p_product_name text,
  p_existing_product_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base_slug text;
  v_candidate_slug text;
  v_suffix integer := 1;
begin
  v_base_slug := public.supplier_product_slug_from_name(p_product_name);

  if length(v_base_slug) = 0 then
    raise exception 'Product name must contain letters or numbers';
  end if;

  v_candidate_slug := v_base_slug;

  while exists (
    select 1
    from public.products p
    where p.supplier_id = p_supplier_id
      and p.slug = v_candidate_slug
      and p.deleted_at is null
      and (p_existing_product_id is null or p.id <> p_existing_product_id)
  ) loop
    v_suffix := v_suffix + 1;
    v_candidate_slug := v_base_slug || '-' || v_suffix::text;
  end loop;

  return v_candidate_slug;
end;
$$;

create or replace function public.assert_supplier_product_payload(
  p_product_name text,
  p_base_price numeric,
  p_stock_quantity integer default 0
)
returns void
language plpgsql
immutable
as $$
begin
  if length(trim(coalesce(p_product_name, ''))) = 0 then
    raise exception 'Product name is required';
  end if;

  if p_base_price is null or p_base_price <= 0 then
    raise exception 'Base price must be greater than 0';
  end if;

  if p_stock_quantity is null or p_stock_quantity < 0 then
    raise exception 'Stock quantity must be 0 or greater';
  end if;
end;
$$;

create or replace function public.assert_supplier_product_image_path(
  p_supplier_id uuid,
  p_product_id uuid,
  p_storage_path text
)
returns void
language plpgsql
immutable
as $$
declare
  v_expected_prefix text;
begin
  if length(trim(coalesce(p_storage_path, ''))) = 0 then
    raise exception 'Product image storage path is required';
  end if;

  if p_storage_path ~* '^https?://' then
    raise exception 'Product image metadata must use a private storage path';
  end if;

  v_expected_prefix := p_supplier_id::text || '/' || p_product_id::text || '/';

  if p_storage_path not like v_expected_prefix || '%' then
    raise exception 'Product image path must be scoped to supplier/product ownership';
  end if;
end;
$$;

create or replace function public.create_supplier_product(
  p_product_name text,
  p_description text default null,
  p_category text default null,
  p_base_price numeric default null,
  p_stock_quantity integer default 0,
  p_variants jsonb default null,
  p_image_metadata jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
  v_profile_id uuid;
  v_product_id uuid;
  v_slug text;
begin
  perform public.assert_supplier_product_payload(p_product_name, p_base_price, p_stock_quantity);

  if p_variants is not null and p_variants <> 'null'::jsonb then
    raise exception 'Variant JSON creation is deferred; use the default stock quantity foundation for now';
  end if;

  if p_image_metadata is not null and p_image_metadata <> 'null'::jsonb then
    raise exception 'Inline product image metadata is deferred; use add_product_image_metadata after product creation';
  end if;

  v_supplier_id := public.current_verified_supplier_owner_id();
  v_profile_id := public.current_profile_id();
  v_slug := public.supplier_product_unique_slug(v_supplier_id, p_product_name);

  insert into public.products (
    supplier_id,
    category,
    name,
    slug,
    description,
    product_status,
    approval_status,
    base_price_amount,
    platform_margin_amount,
    max_reseller_margin_amount,
    created_by_profile_id
  )
  values (
    v_supplier_id,
    nullif(trim(coalesce(p_category, '')), ''),
    trim(p_product_name),
    v_slug,
    nullif(trim(coalesce(p_description, '')), ''),
    'pending_approval',
    'pending_review',
    p_base_price,
    0,
    0,
    v_profile_id
  )
  returning id into v_product_id;

  insert into public.product_variants (
    product_id,
    variant_name,
    attributes,
    total_stock_quantity,
    reserved_stock_quantity,
    sold_stock_quantity,
    returned_stock_quantity,
    low_stock_threshold,
    variant_status
  )
  values (
    v_product_id,
    'Default',
    '{}'::jsonb,
    p_stock_quantity,
    0,
    0,
    0,
    3,
    case when p_stock_quantity = 0 then 'out_of_stock'::public.variant_status else 'active'::public.variant_status end
  );

  perform public.create_audit_log_entry(
    'create_supplier_product',
    'products',
    v_product_id,
    'supplier_product_created_pending_review',
    null,
    jsonb_build_object(
      'supplier_id', v_supplier_id,
      'product_status', 'pending_approval',
      'approval_status', 'pending_review',
      'base_price_amount', p_base_price,
      'stock_quantity', p_stock_quantity
    )
  );

  return v_product_id;
end;
$$;

create or replace function public.update_supplier_product(
  p_product_id uuid,
  p_product_name text default null,
  p_description text default null,
  p_category text default null,
  p_base_price numeric default null,
  p_brand text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
  v_product public.products%rowtype;
  v_new_name text;
  v_new_slug text;
  v_before jsonb;
begin
  if p_product_id is null then
    raise exception 'Product id is required';
  end if;

  v_supplier_id := public.current_verified_supplier_owner_id();

  select *
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.supplier_id = v_supplier_id
    and p.deleted_at is null
  for update;

  if not found then
    raise exception 'Product was not found for this supplier';
  end if;

  v_new_name := coalesce(nullif(trim(coalesce(p_product_name, '')), ''), v_product.name);
  perform public.assert_supplier_product_payload(v_new_name, coalesce(p_base_price, v_product.base_price_amount), 0);
  v_new_slug := case when v_new_name <> v_product.name then public.supplier_product_unique_slug(v_supplier_id, v_new_name, p_product_id) else v_product.slug end;

  v_before := jsonb_build_object(
    'name', v_product.name,
    'slug', v_product.slug,
    'description', v_product.description,
    'category', v_product.category,
    'brand', v_product.brand,
    'base_price_amount', v_product.base_price_amount,
    'product_status', v_product.product_status,
    'approval_status', v_product.approval_status
  );

  update public.products
  set
    name = v_new_name,
    slug = v_new_slug,
    description = case when p_description is null then description else nullif(trim(p_description), '') end,
    category = case when p_category is null then category else nullif(trim(p_category), '') end,
    brand = case when p_brand is null then brand else nullif(trim(p_brand), '') end,
    base_price_amount = coalesce(p_base_price, base_price_amount),
    product_status = case
      when p_base_price is not null and p_base_price <> v_product.base_price_amount then 'price_change_pending'::public.product_status
      else product_status
    end,
    approval_status = case
      when p_base_price is not null and p_base_price <> v_product.base_price_amount then 'pending_review'::public.approval_status
      else approval_status
    end,
    updated_at = now()
  where id = p_product_id;

  perform public.create_audit_log_entry(
    'update_supplier_product',
    'products',
    p_product_id,
    'supplier_product_safe_fields_updated',
    v_before,
    (
      select jsonb_build_object(
        'name', p.name,
        'slug', p.slug,
        'description', p.description,
        'category', p.category,
        'brand', p.brand,
        'base_price_amount', p.base_price_amount,
        'product_status', p.product_status,
        'approval_status', p.approval_status
      )
      from public.products p
      where p.id = p_product_id
    )
  );

  return p_product_id;
end;
$$;

create or replace function public.archive_supplier_product(
  p_product_id uuid,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
  v_product public.products%rowtype;
begin
  if p_product_id is null then
    raise exception 'Product id is required';
  end if;

  v_supplier_id := public.current_verified_supplier_owner_id();

  select *
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.supplier_id = v_supplier_id
    and p.deleted_at is null
  for update;

  if not found then
    raise exception 'Product was not found for this supplier';
  end if;

  update public.products
  set
    product_status = 'archived',
    approval_status = 'archived',
    deleted_at = coalesce(deleted_at, now()),
    updated_at = now()
  where id = p_product_id;

  update public.product_variants
  set
    variant_status = 'archived',
    deleted_at = coalesce(deleted_at, now()),
    updated_at = now()
  where product_id = p_product_id
    and deleted_at is null;

  update public.product_images
  set
    image_status = 'archived',
    deleted_at = coalesce(deleted_at, now()),
    updated_at = now()
  where product_id = p_product_id
    and deleted_at is null;

  perform public.create_audit_log_entry(
    'archive_supplier_product',
    'products',
    p_product_id,
    coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'supplier_product_archived'),
    jsonb_build_object(
      'product_status', v_product.product_status,
      'approval_status', v_product.approval_status,
      'deleted_at', v_product.deleted_at
    ),
    jsonb_build_object(
      'product_status', 'archived',
      'approval_status', 'archived',
      'deleted_at_set', true
    )
  );

  return p_product_id;
end;
$$;

create or replace function public.add_product_image_metadata(
  p_product_id uuid,
  p_storage_path text,
  p_alt_text text default null,
  p_sort_order integer default 0,
  p_is_primary boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
  v_product public.products%rowtype;
  v_image_id uuid;
begin
  if p_product_id is null then
    raise exception 'Product id is required';
  end if;

  if p_sort_order is null or p_sort_order < 0 then
    raise exception 'Image sort order must be 0 or greater';
  end if;

  v_supplier_id := public.current_verified_supplier_owner_id();

  select *
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.supplier_id = v_supplier_id
    and p.deleted_at is null;

  if not found then
    raise exception 'Product was not found for this supplier';
  end if;

  perform public.assert_supplier_product_image_path(v_supplier_id, p_product_id, p_storage_path);

  if p_is_primary then
    update public.product_images
    set is_primary = false,
        updated_at = now()
    where product_id = p_product_id
      and deleted_at is null;
  end if;

  insert into public.product_images (
    product_id,
    storage_path,
    alt_text,
    sort_order,
    image_status,
    is_primary,
    created_by_profile_id
  )
  values (
    p_product_id,
    trim(p_storage_path),
    nullif(trim(coalesce(p_alt_text, '')), ''),
    p_sort_order,
    'pending_review',
    coalesce(p_is_primary, false),
    public.current_profile_id()
  )
  returning id into v_image_id;

  perform public.create_audit_log_entry(
    'add_product_image_metadata',
    'product_images',
    v_image_id,
    'supplier_product_image_metadata_added_pending_review',
    null,
    jsonb_build_object(
      'product_id', p_product_id,
      'supplier_id', v_supplier_id,
      'storage_path', trim(p_storage_path),
      'image_status', 'pending_review',
      'is_primary', coalesce(p_is_primary, false)
    )
  );

  return v_image_id;
end;
$$;

create or replace function public.get_supplier_products()
returns table (
  product_id uuid,
  supplier_id uuid,
  category text,
  name text,
  slug text,
  description text,
  brand text,
  product_status public.product_status,
  approval_status public.approval_status,
  base_price_amount numeric,
  reseller_cost_amount numeric,
  max_customer_price_amount numeric,
  currency_code text,
  created_at timestamptz,
  updated_at timestamptz,
  image_count integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    p.id as product_id,
    p.supplier_id,
    p.category,
    p.name,
    p.slug,
    p.description,
    p.brand,
    p.product_status,
    p.approval_status,
    p.base_price_amount,
    p.reseller_cost_amount,
    p.max_customer_price_amount,
    p.currency_code,
    p.created_at,
    p.updated_at,
    (
      select count(*)::integer
      from public.product_images pi
      where pi.product_id = p.id
        and pi.deleted_at is null
    ) as image_count
  from public.products p
  where p.deleted_at is null
    and public.is_supplier_member(p.supplier_id)
  order by p.updated_at desc, p.created_at desc;
$$;

revoke all on function public.supplier_product_slug_from_name(text) from public;
revoke all on function public.current_verified_supplier_owner_id() from public;
revoke all on function public.supplier_product_unique_slug(uuid, text, uuid) from public;
revoke all on function public.assert_supplier_product_payload(text, numeric, integer) from public;
revoke all on function public.assert_supplier_product_image_path(uuid, uuid, text) from public;

revoke all on function public.create_supplier_product(text, text, text, numeric, integer, jsonb, jsonb) from public;
revoke all on function public.update_supplier_product(uuid, text, text, text, numeric, text) from public;
revoke all on function public.archive_supplier_product(uuid, text) from public;
revoke all on function public.add_product_image_metadata(uuid, text, text, integer, boolean) from public;
revoke all on function public.get_supplier_products() from public;

grant execute on function public.create_supplier_product(text, text, text, numeric, integer, jsonb, jsonb) to authenticated;
grant execute on function public.update_supplier_product(uuid, text, text, text, numeric, text) to authenticated;
grant execute on function public.archive_supplier_product(uuid, text) to authenticated;
grant execute on function public.add_product_image_metadata(uuid, text, text, integer, boolean) to authenticated;
grant execute on function public.get_supplier_products() to authenticated;

comment on function public.create_supplier_product(text, text, text, numeric, integer, jsonb, jsonb)
  is 'Supplier-owner audited product creation. Requires active approved supplier ownership, creates pending product and default variant, and does not set platform margin or approval directly.';

comment on function public.update_supplier_product(uuid, text, text, text, numeric, text)
  is 'Supplier-owner audited safe product update. Only own products and editable supplier fields; approval/admin fields remain controlled outside this RPC.';

comment on function public.archive_supplier_product(uuid, text)
  is 'Supplier-owner audited soft archive. No hard delete path is exposed.';

comment on function public.add_product_image_metadata(uuid, text, text, integer, boolean)
  is 'Supplier-owner audited product image metadata insert. Requires private storage path scoped as supplier_id/product_id/file_name and defaults image review to pending.';

comment on function public.get_supplier_products()
  is 'Supplier workspace product listing for supplier members. Does not expose other suppliers products.';
