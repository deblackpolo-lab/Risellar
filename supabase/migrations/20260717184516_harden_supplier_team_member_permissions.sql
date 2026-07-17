-- Harden supplier team member permission visibility.
-- Development/production-safe patch migration: no secrets and no production data.

drop policy if exists "supplier_team_select_members_or_admin" on public.supplier_team_members;

create policy "supplier_team_select_owner_support_admin"
  on public.supplier_team_members for select
  using (public.is_supplier_owner(supplier_id) or public.has_admin_role('support_staff'));

drop function if exists public.get_supplier_operational_team_members(uuid);

create function public.get_supplier_operational_team_members(target_supplier_id uuid default null)
returns table (
  id uuid,
  supplier_id uuid,
  profile_id uuid,
  supplier_role public.supplier_role,
  staff_status public.staff_status,
  member_full_name text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    stm.id,
    stm.supplier_id,
    stm.profile_id,
    stm.supplier_role,
    stm.staff_status,
    p.full_name as member_full_name,
    stm.created_at,
    stm.updated_at
  from public.supplier_team_members stm
  join public.profiles p
    on p.id = stm.profile_id
  where stm.deleted_at is null
    and p.deleted_at is null
    and (target_supplier_id is null or stm.supplier_id = target_supplier_id)
    and (
      public.is_supplier_member(stm.supplier_id)
      or public.has_admin_role('support_staff')
    )
  order by stm.created_at asc, stm.id asc;
$$;

revoke all on function public.get_supplier_operational_team_members(uuid) from public;
grant execute on function public.get_supplier_operational_team_members(uuid) to authenticated;

comment on policy "supplier_team_select_owner_support_admin" on public.supplier_team_members
  is 'Direct supplier_team_members reads expose permissions, so they are limited to supplier owners and support/admin roles.';

comment on function public.get_supplier_operational_team_members(uuid)
  is 'Returns supplier-scoped team member operational fields without permissions for authenticated supplier members and support/admin roles.';
