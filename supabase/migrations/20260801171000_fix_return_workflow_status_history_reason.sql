-- D7 forward fix: keep return workflow status-history reason codes aligned
-- with the existing dispute_status_history allowlist.

create or replace function public.return_workflow_record_dispute_status(
  p_dispute_id uuid,
  p_previous_status text,
  p_new_status text,
  p_actor_profile_id uuid,
  p_actor_role text,
  p_reason_code text,
  p_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_reason_code text := case
    when p_reason_code = 'return_requested' then 'return_review'
    when p_reason_code in ('customer_response', 'supplier_response', 'admin_request', 'admin_review', 'return_review', 'refund_review', 'resolution_recorded', 'case_closed', 'case_cancelled', 'system_event') then p_reason_code
    else 'return_review'
  end;
begin
  if p_previous_status is distinct from p_new_status then
    insert into public.dispute_status_history(
      dispute_id,
      previous_status,
      new_status,
      changed_by_profile_id,
      changed_by_role,
      reason_code,
      created_at
    )
    values (
      p_dispute_id,
      p_previous_status,
      p_new_status,
      p_actor_profile_id,
      p_actor_role,
      v_reason_code,
      now()
    )
    on conflict do nothing;
  end if;
end;
$fn$;
