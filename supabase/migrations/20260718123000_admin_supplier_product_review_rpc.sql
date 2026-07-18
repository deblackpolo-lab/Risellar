-- Admin supplier product review RPC foundation.
-- Development/code foundation only. Do not apply to production before development RPC boundary tests pass.

create or replace function public.review_supplier_product(
  p_product_id uuid,
  p_decision text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.products%rowtype;
  v_supplier public.suppliers%rowtype;
  v_actor_profile_id uuid;
  v_decision text;
  v_reason text;
  v_before jsonb;
  v_after jsonb;
begin
  v_actor_profile_id := public.current_profile_id();

  if v_actor_profile_id is null then
    raise exception 'Authenticated active admin profile is required';
  end if;

  if not public.has_admin_role('admin') then
    raise exception 'Admin role is required to review supplier products';
  end if;

  if p_product_id is null then
    raise exception 'Product id is required';
  end if;

  v_decision := lower(trim(coalesce(p_decision, '')));

  if v_decision not in ('approved', 'rejected') then
    raise exception 'Product review decision must be approved or rejected';
  end if;

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
    raise exception 'Supplier not found for product review';
  end if;

  if v_supplier.owner_profile_id = v_actor_profile_id then
    raise exception 'Supplier owners cannot review their own products';
  end if;

  if v_product.approval_status <> 'pending_review' then
    raise exception 'Only pending review products can be reviewed';
  end if;

  v_reason := nullif(trim(coalesce(p_review_notes, '')), '');
  v_before := jsonb_build_object(
    'product_status', v_product.product_status,
    'approval_status', v_product.approval_status,
    'approved_by_profile_id', v_product.approved_by_profile_id,
    'approved_at', v_product.approved_at,
    'rejection_reason', v_product.rejection_reason
  );

  if v_decision = 'approved' then
    update public.products
    set product_status = 'active',
        approval_status = 'approved',
        approved_by_profile_id = v_actor_profile_id,
        approved_at = now(),
        rejection_reason = null,
        updated_at = now()
    where id = p_product_id;

    update public.product_images
    set image_status = 'active',
        updated_at = now()
    where product_id = p_product_id
      and image_status = 'pending_review'
      and deleted_at is null;
  else
    update public.products
    set product_status = 'rejected',
        approval_status = 'rejected',
        approved_by_profile_id = null,
        approved_at = null,
        rejection_reason = coalesce(v_reason, 'Rejected by admin review'),
        updated_at = now()
    where id = p_product_id;
  end if;

  select jsonb_build_object(
    'product_status', p.product_status,
    'approval_status', p.approval_status,
    'approved_by_profile_id', p.approved_by_profile_id,
    'approved_at', p.approved_at,
    'rejection_reason', p.rejection_reason,
    'decision', v_decision
  )
  into v_after
  from public.products p
  where p.id = p_product_id;

  perform public.create_audit_log_entry(
    'review_supplier_product',
    'products',
    p_product_id,
    coalesce(v_reason, 'admin_product_review_' || v_decision),
    v_before,
    v_after
  );

  return p_product_id;
end;
$$;

revoke all on function public.review_supplier_product(uuid, text, text) from public;
grant execute on function public.review_supplier_product(uuid, text, text) to authenticated;

comment on function public.review_supplier_product(uuid, text, text)
  is 'Admin-only audited supplier product approval/rejection RPC. Requires active admin_staff role, prevents supplier self-approval, and writes audit logs.';
