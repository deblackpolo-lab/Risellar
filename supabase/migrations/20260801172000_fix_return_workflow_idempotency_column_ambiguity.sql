-- D7 forward fix: qualify return_actions columns inside PL/pgSQL functions
-- whose RETURNS TABLE column names include return_id/status.

create or replace function public.admin_reject_return(
  p_return_id uuid,
  p_public_reason text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_admin record;
  v_actor_role text;
  v_return public.order_item_returns%rowtype;
  v_public_reason text := public.return_workflow_safe_text(p_public_reason, true, 1200);
  v_internal_note text := public.return_workflow_safe_text(p_internal_note, false, 2000);
  v_fingerprint text;
begin
  select * into v_admin from public.current_dispute_support_admin();
  if v_admin.profile_id is null then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  v_actor_role := public.return_workflow_admin_actor_role(v_admin.admin_role);
  perform pg_advisory_xact_lock(hashtextextended('d7:return-review:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || v_public_reason || ':' || coalesce(v_internal_note, ''));

  select r.* into v_return
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_admin.profile_id and ra.action_type = 'admin_reject' and ra.idempotency_key = v_key;
  if found then
    if exists (
      select 1
      from public.return_actions ra2
      where ra2.return_id = p_return_id
        and ra2.actor_profile_id = v_admin.profile_id
        and ra2.action_type = 'admin_reject'
        and ra2.idempotency_key = v_key
        and ra2.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status not in ('requested', 'under_review') then raise exception 'RETURN_NOT_REVIEWABLE' using errcode = '23514'; end if;

  update public.order_item_returns
  set status = 'rejected',
      admin_public_note = v_public_reason,
      admin_internal_note = v_internal_note,
      reviewed_by_profile_id = v_admin.profile_id,
      reviewed_at = coalesce(reviewed_at, now()),
      rejected_at = coalesce(rejected_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_admin.profile_id, v_actor_role, 'admin_reject', v_key, v_fingerprint, v_return.id, v_return.status);

  perform public.return_workflow_audit(v_admin.profile_id, v_admin.admin_role, 'return_rejected', v_return.id, jsonb_build_object('status', v_return.status), 'return_rejected');
  return query select v_return.id, v_return.status;
end;
$fn$;

create or replace function public.customer_mark_return_in_transit(
  p_return_id uuid,
  p_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_customer_id uuid := public.current_dispute_customer_id();
  v_note text := public.return_workflow_safe_text(p_note, false, 1200);
  v_return public.order_item_returns%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null or v_customer_id is null then raise exception 'CUSTOMER_REQUIRED' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('d7:return-customer:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || coalesce(v_note, ''));

  select r.* into v_return
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_profile_id and ra.action_type = 'customer_in_transit' and ra.idempotency_key = v_key;
  if found then
    if exists (
      select 1
      from public.return_actions ra2
      where ra2.return_id = p_return_id
        and ra2.actor_profile_id = v_profile_id
        and ra2.action_type = 'customer_in_transit'
        and ra2.idempotency_key = v_key
        and ra2.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and customer_profile_id = v_profile_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status <> 'approved' then raise exception 'RETURN_NOT_APPROVED' using errcode = '23514'; end if;
  if not public.return_workflow_is_physical_method(coalesce(v_return.approved_method, v_return.requested_method)) then
    raise exception 'RETURN_NOT_PHYSICAL' using errcode = '23514';
  end if;

  update public.order_item_returns
  set status = 'in_transit',
      customer_note = coalesce(v_note, customer_note),
      in_transit_at = coalesce(in_transit_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_profile_id, 'customer', 'customer_in_transit', v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_profile_id, 'customer', 'return_marked_in_transit', v_return.id, jsonb_build_object('status', v_return.status), 'return_marked_in_transit');
  return query select v_return.id, v_return.status;
end;
$fn$;

create or replace function public.supplier_confirm_return_received(
  p_return_id uuid,
  p_supplier_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_supplier_id uuid := public.current_dispute_supplier_id();
  v_note text := public.return_workflow_safe_text(p_supplier_note, false, 1200);
  v_return public.order_item_returns%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null or v_supplier_id is null then raise exception 'SUPPLIER_REQUIRED' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('d7:return-supplier:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || coalesce(v_note, ''));

  select r.* into v_return
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_profile_id and ra.action_type = 'supplier_received' and ra.idempotency_key = v_key;
  if found then
    if exists (
      select 1
      from public.return_actions ra2
      where ra2.return_id = p_return_id
        and ra2.actor_profile_id = v_profile_id
        and ra2.action_type = 'supplier_received'
        and ra2.idempotency_key = v_key
        and ra2.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and supplier_id = v_supplier_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status not in ('approved', 'in_transit') then raise exception 'RETURN_NOT_RECEIVABLE' using errcode = '23514'; end if;
  if not public.return_workflow_is_physical_method(coalesce(v_return.approved_method, v_return.requested_method)) then raise exception 'RETURN_NOT_PHYSICAL' using errcode = '23514'; end if;

  update public.order_item_returns
  set status = 'received',
      supplier_note = v_note,
      received_at = coalesce(received_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_profile_id, 'supplier', 'supplier_received', v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_profile_id, 'supplier_owner', 'return_received', v_return.id, jsonb_build_object('status', v_return.status), 'return_received');
  return query select v_return.id, v_return.status;
end;
$fn$;

create or replace function public.supplier_report_return_condition(
  p_return_id uuid,
  p_condition text,
  p_inventory_outcome text,
  p_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text, inspection_condition text, inventory_outcome text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_profile_id uuid := public.current_profile_id();
  v_supplier_id uuid := public.current_dispute_supplier_id();
  v_condition text := lower(trim(coalesce(p_condition, '')));
  v_outcome text := lower(trim(coalesce(p_inventory_outcome, '')));
  v_note text := public.return_workflow_safe_text(p_note, false, 1200);
  v_return public.order_item_returns%rowtype;
  v_fingerprint text;
begin
  if v_profile_id is null or v_supplier_id is null then raise exception 'SUPPLIER_REQUIRED' using errcode = '42501'; end if;
  if not public.return_workflow_is_condition(v_condition) or v_condition = 'inspection_pending' then raise exception 'INVALID_RETURN_CONDITION' using errcode = '23514'; end if;
  if not public.return_workflow_is_inventory_outcome(v_outcome) or v_outcome = 'pending' then raise exception 'INVALID_INVENTORY_OUTCOME' using errcode = '23514'; end if;

  perform pg_advisory_xact_lock(hashtextextended('d7:return-supplier:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || v_condition || ':' || v_outcome || ':' || coalesce(v_note, ''));

  select r.* into v_return
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_profile_id and ra.action_type = 'supplier_condition' and ra.idempotency_key = v_key;
  if found then
    if exists (
      select 1
      from public.return_actions ra2
      where ra2.return_id = p_return_id
        and ra2.actor_profile_id = v_profile_id
        and ra2.action_type = 'supplier_condition'
        and ra2.idempotency_key = v_key
        and ra2.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status, v_return.inspection_condition, v_return.inventory_outcome;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and supplier_id = v_supplier_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;
  if v_return.status <> 'received' then raise exception 'RETURN_NOT_RECEIVED' using errcode = '23514'; end if;

  update public.order_item_returns
  set status = 'inspected',
      inspection_condition = v_condition,
      inventory_outcome = v_outcome,
      supplier_note = coalesce(v_note, supplier_note),
      inspected_at = coalesce(inspected_at, now()),
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_profile_id, 'supplier', 'supplier_condition', v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_profile_id, 'supplier_owner', 'returned_item_inspected', v_return.id, jsonb_build_object('status', v_return.status, 'inspection_condition', v_return.inspection_condition), 'returned_item_inspected');
  perform public.return_workflow_audit(v_profile_id, 'supplier_owner', 'return_inventory_outcome_recommended', v_return.id, jsonb_build_object('inventory_outcome', v_return.inventory_outcome), 'return_inventory_outcome_recommended');
  return query select v_return.id, v_return.status, v_return.inspection_condition, v_return.inventory_outcome;
end;
$fn$;

create or replace function public.return_workflow_admin_final(
  p_return_id uuid,
  p_next_status text,
  p_action_type text,
  p_audit_action text,
  p_public_note text,
  p_internal_note text,
  p_idempotency_key text
)
returns table (return_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_key text := public.return_workflow_assert_key(p_idempotency_key);
  v_admin record;
  v_actor_role text;
  v_return public.order_item_returns%rowtype;
  v_public_note text := public.return_workflow_safe_text(p_public_note, false, 1200);
  v_internal_note text := public.return_workflow_safe_text(p_internal_note, false, 2000);
  v_fingerprint text;
begin
  select * into v_admin from public.current_dispute_support_admin();
  if v_admin.profile_id is null then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  v_actor_role := public.return_workflow_admin_actor_role(v_admin.admin_role);
  if p_next_status not in ('accepted', 'declined', 'completed') then raise exception 'INVALID_RETURN_STATUS' using errcode = '23514'; end if;
  if p_action_type not in ('admin_accept', 'admin_decline', 'admin_complete') then raise exception 'INVALID_RETURN_ACTION' using errcode = '23514'; end if;

  perform pg_advisory_xact_lock(hashtextextended('d7:return-final:' || p_return_id::text, 0));
  v_fingerprint := md5(p_return_id::text || ':' || p_next_status || ':' || coalesce(v_public_note, '') || ':' || coalesce(v_internal_note, ''));

  select r.* into v_return
  from public.return_actions ra
  join public.order_item_returns r on r.id = ra.result_return_id
  where ra.return_id = p_return_id and ra.actor_profile_id = v_admin.profile_id and ra.action_type = p_action_type and ra.idempotency_key = v_key;
  if found then
    if exists (
      select 1
      from public.return_actions ra2
      where ra2.return_id = p_return_id
        and ra2.actor_profile_id = v_admin.profile_id
        and ra2.action_type = p_action_type
        and ra2.idempotency_key = v_key
        and ra2.request_fingerprint <> v_fingerprint
    ) then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;
    return query select v_return.id, v_return.status;
    return;
  end if;

  select * into v_return from public.order_item_returns where id = p_return_id and deleted_at is null for update;
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = '42501'; end if;

  if p_next_status in ('accepted', 'declined') and v_return.status <> 'inspected' then
    raise exception 'RETURN_NOT_INSPECTED' using errcode = '23514';
  end if;
  if p_next_status = 'completed' and v_return.status not in ('accepted', 'declined', 'rejected', 'cancelled') then
    raise exception 'RETURN_NOT_COMPLETABLE' using errcode = '23514';
  end if;

  update public.order_item_returns
  set status = p_next_status,
      admin_public_note = coalesce(v_public_note, admin_public_note),
      admin_internal_note = coalesce(v_internal_note, admin_internal_note),
      accepted_at = case when p_next_status = 'accepted' then coalesce(accepted_at, now()) else accepted_at end,
      declined_at = case when p_next_status = 'declined' then coalesce(declined_at, now()) else declined_at end,
      completed_at = case when p_next_status = 'completed' then coalesce(completed_at, now()) else completed_at end,
      updated_at = now()
  where id = p_return_id
  returning * into v_return;

  insert into public.return_actions(return_id, actor_profile_id, actor_role, action_type, idempotency_key, request_fingerprint, result_return_id, result_status)
  values (p_return_id, v_admin.profile_id, v_actor_role, p_action_type, v_key, v_fingerprint, v_return.id, v_return.status);
  perform public.return_workflow_audit(v_admin.profile_id, v_admin.admin_role, p_audit_action, v_return.id, jsonb_build_object('status', v_return.status), p_audit_action);
  return query select v_return.id, v_return.status;
end;
$fn$;
