-- D10 forward fix: allocation audit can be emitted by reseller-context RPCs.
-- D9 finance audit intentionally accepts only finance actors, so non-finance
-- D10 audit events use the existing general audit helper instead.

create or replace function public.finance_d10_make_audit(
  p_actor_profile_id uuid,
  p_actor_role text,
  p_action text,
  p_target_entity_type text,
  p_target_entity_id uuid,
  p_after_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if p_actor_role in ('finance_staff', 'super_admin') then
    perform public.finance_d9_make_audit(
      p_actor_profile_id,
      p_actor_role,
      p_action,
      p_target_entity_type,
      p_target_entity_id,
      null,
      p_after_data
    );
    return;
  end if;

  perform public.create_audit_log_entry(
    p_action,
    p_target_entity_type,
    p_target_entity_id,
    'D10 audited non-finance action',
    null,
    coalesce(p_after_data, '{}'::jsonb)
  );
end;
$fn$;

revoke all on function public.finance_d10_make_audit(uuid, text, text, text, uuid, jsonb) from public, anon, authenticated;
