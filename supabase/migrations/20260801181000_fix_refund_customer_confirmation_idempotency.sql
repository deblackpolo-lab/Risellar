-- D8 forward fix: customer refund confirmation retries must return the prior
-- idempotent result even after the first call moves the refund to
-- under_verification. No authorization, status, RLS, finance, or side-effect
-- boundary is broadened.

create or replace function public.customer_confirm_refund_received(
  p_refund_id uuid,
  p_received boolean,
  p_note text,
  p_idempotency_key text
)
returns table (refund_id uuid, status text, customer_confirmation_status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.refund_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_note text := public.refund_workflow_safe_text(p_note, false, 1200);
  v_action text;
  v_refund public.order_refunds%rowtype;
  v_existing public.order_refunds%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null then
    raise exception 'CUSTOMER_REQUIRED' using errcode = '42501';
  end if;

  select * into v_refund
  from public.order_refunds r
  where r.id = p_refund_id
    and r.customer_profile_id = v_profile_id
    and r.deleted_at is null
  for update;

  if not found then
    raise exception 'REFUND_NOT_FOUND' using errcode = '42501';
  end if;

  v_action := case when p_received then 'customer_confirm_received' else 'customer_dispute_not_received' end;
  v_fingerprint := md5(jsonb_build_object('refund_id', p_refund_id, 'received', p_received, 'note_present', v_note is not null)::text);

  select r.* into v_existing
  from public.refund_actions a
  join public.order_refunds r on r.id = a.result_refund_id
  where a.refund_id = p_refund_id
    and a.actor_profile_id = v_profile_id
    and a.action_type = v_action
    and a.idempotency_key = v_key;

  if found then
    if exists (
      select 1 from public.refund_actions a
      where a.refund_id = p_refund_id
        and a.actor_profile_id = v_profile_id
        and a.action_type = v_action
        and a.idempotency_key = v_key
        and a.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'REFUND_IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    refund_id := v_existing.id;
    status := v_existing.status;
    customer_confirmation_status := v_existing.customer_confirmation_status;
    return next;
    return;
  end if;

  if v_refund.status not in ('reported_sent', 'awaiting_customer_confirmation') then
    raise exception 'CUSTOMER_CONFIRMATION_NOT_ALLOWED' using errcode = '23514';
  end if;

  update public.order_refunds
  set status = 'under_verification',
      customer_confirmation_status = case when p_received then 'confirmed_received' else 'disputed_not_received' end,
      customer_confirmed_at = case when p_received then now() else null end,
      updated_at = now()
  where id = v_refund.id
  returning * into v_refund;

  perform public.refund_workflow_audit(
    v_profile_id,
    'customer',
    case when p_received then 'refund_customer_confirmed_received' else 'refund_customer_disputed_not_received' end,
    v_refund.id,
    jsonb_build_object('status', v_refund.status, 'customer_confirmation_status', v_refund.customer_confirmation_status),
    null
  );

  insert into public.refund_actions(refund_id, dispute_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_refund_id, result_status)
  values (v_refund.id, null, v_profile_id, 'customer', v_action, v_key, v_fingerprint, v_refund.id, v_refund.status);

  refund_id := v_refund.id;
  status := v_refund.status;
  customer_confirmation_status := v_refund.customer_confirmation_status;
  return next;
end;
$fn$;

grant execute on function public.customer_confirm_refund_received(uuid, boolean, text, text) to authenticated;
