-- D9 forward patch: cast finance audit actor roles to the existing user_role enum.
-- Development-safe forward migration; does not weaken finance authorization.

create or replace function public.finance_d9_make_audit(
  p_actor_profile_id uuid,
  p_actor_role text,
  p_action text,
  p_target_entity_type text,
  p_target_entity_id uuid,
  p_before jsonb,
  p_after jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_actor_role public.user_role;
begin
  if p_actor_role not in ('finance_staff', 'super_admin', 'support_staff', 'admin') then
    raise exception 'INVALID_AUDIT_ACTOR_ROLE' using errcode = '42501';
  end if;

  v_actor_role := p_actor_role::public.user_role;

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
    p_actor_profile_id,
    v_actor_role,
    p_action,
    p_target_entity_type,
    p_target_entity_id,
    p_before,
    coalesce(p_after, '{}'::jsonb) || jsonb_build_object('finance_actor_role', p_actor_role),
    null
  );
end;
$fn$;

revoke all on function public.finance_d9_make_audit(uuid, text, text, text, uuid, jsonb, jsonb) from public, anon, authenticated;
