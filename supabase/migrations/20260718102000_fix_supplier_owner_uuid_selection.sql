-- Fix supplier owner selection in product management RPCs.
-- Forward patch only. Do not apply to production before development RPC boundary tests pass.

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

  select count(*)
  into v_supplier_count
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

  return v_supplier_id;
end;
$$;

comment on function public.current_verified_supplier_owner_id()
  is 'Returns the authenticated active approved supplier owner supplier id. If multiple active approved supplier records exist, selects deterministically by created_at then UUID text until explicit supplier selection is added.';
