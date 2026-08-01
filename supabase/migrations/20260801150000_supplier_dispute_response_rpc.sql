-- Disputes, Returns, and Refunds D5: supplier dispute response backend.
-- Forward-only. Adds supplier response RPC only; no UI, returns, refunds,
-- finance holds, order/payment/stock/reservation, settlement, commission,
-- withdrawal, evidence, or notification side effects are introduced here.

create or replace function public.supplier_add_dispute_response(
  p_dispute_id uuid,
  p_body text,
  p_idempotency_key text
)
returns table (
  message_id uuid,
  dispute_id uuid,
  created boolean,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
  v_supplier_id uuid;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_key text := nullif(trim(coalesce(p_idempotency_key, '')), '');
  v_dispute record;
  v_existing_message record;
  v_message_id uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_new_status text;
begin
  if p_dispute_id is null then
    raise exception 'DISPUTE_ID_REQUIRED' using errcode = '23514';
  end if;

  v_profile_id := public.current_profile_id();
  v_supplier_id := public.current_dispute_supplier_id();

  if v_profile_id is null or v_supplier_id is null then
    raise exception 'SUPPLIER_REQUIRED' using errcode = '42501';
  end if;

  if v_key is null
    or length(v_key) not between 8 and 140
    or v_key ~* '(password|secret|token|jwt|cookie)' then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '23514';
  end if;

  if v_body is null
    or length(v_body) not between 1 and 2000
    or v_body ~ '<[^>]+>'
    or v_body ~* '(password|secret|token|jwt|cookie|card number|cvv|otp|pin|phone|address|bank account|mobile money)' then
    raise exception 'INVALID_RESPONSE_BODY' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('supplier_add_dispute_response:key:' || v_profile_id::text || ':' || p_dispute_id::text || ':' || v_key, 0));

  select
    dm.id,
    dm.body,
    dm.created_at
  into v_existing_message
  from public.dispute_messages dm
  where dm.dispute_id = p_dispute_id
    and dm.author_profile_id = v_profile_id
    and dm.idempotency_key = v_key
    and dm.deleted_at is null
  order by dm.created_at asc, dm.id::text asc
  limit 1;

  if found then
    select od.status
    into v_new_status
    from public.order_disputes od
    where od.id = p_dispute_id
      and od.deleted_at is null
      and (
        (
          od.scope_type = 'supplier'
          and od.affected_supplier_id = v_supplier_id
          and od.affected_order_item_id is null
        )
        or (
          od.scope_type = 'order_item'
          and od.affected_supplier_id = v_supplier_id
          and exists (
            select 1
            from public.order_items oi
            where oi.id = od.affected_order_item_id
              and oi.order_id = od.order_id
              and oi.supplier_id = v_supplier_id
          )
        )
        or (
          od.scope_type = 'order'
          and od.affected_supplier_id is null
          and od.affected_order_item_id is null
          and (
            select count(distinct oi.supplier_id)
            from public.order_items oi
            where oi.order_id = od.order_id
          ) = 1
          and exists (
            select 1
            from public.order_items oi
            where oi.order_id = od.order_id
              and oi.supplier_id = v_supplier_id
          )
        )
      );

    if v_new_status is null or coalesce(v_existing_message.body, '') <> v_body then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = '23505';
    end if;

    message_id := v_existing_message.id;
    dispute_id := p_dispute_id;
    created := false;
    status := v_new_status;
    created_at := v_existing_message.created_at;
    return next;
    return;
  end if;

  select
    od.id,
    od.order_id,
    od.status,
    od.scope_type,
    od.affected_supplier_id,
    od.affected_order_item_id,
    od.supplier_action_required,
    od.customer_action_required
  into v_dispute
  from public.order_disputes od
  where od.id = p_dispute_id
    and od.deleted_at is null
    and (
      (
        od.scope_type = 'supplier'
        and od.affected_supplier_id = v_supplier_id
        and od.affected_order_item_id is null
      )
      or (
        od.scope_type = 'order_item'
        and od.affected_supplier_id = v_supplier_id
        and exists (
          select 1
          from public.order_items oi
          where oi.id = od.affected_order_item_id
            and oi.order_id = od.order_id
            and oi.supplier_id = v_supplier_id
        )
      )
      or (
        od.scope_type = 'order'
        and od.affected_supplier_id is null
        and od.affected_order_item_id is null
        and (
          select count(distinct oi.supplier_id)
          from public.order_items oi
          where oi.order_id = od.order_id
        ) = 1
        and exists (
          select 1
          from public.order_items oi
          where oi.order_id = od.order_id
            and oi.supplier_id = v_supplier_id
        )
      )
    )
  for update of od;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND' using errcode = '42501';
  end if;

  if v_dispute.status not in ('open', 'awaiting_supplier', 'under_review', 'return_review', 'refund_review') then
    raise exception 'DISPUTE_RESPONSE_NOT_ALLOWED' using errcode = '23514';
  end if;

  insert into public.dispute_messages(
    id,
    dispute_id,
    author_profile_id,
    author_role,
    message_type,
    body,
    visibility,
    is_system_message,
    created_at,
    idempotency_key
  )
  values (
    v_message_id,
    p_dispute_id,
    v_profile_id,
    'supplier',
    'participant_response',
    v_body,
    'supplier_and_admin',
    false,
    v_now,
    v_key
  );

  v_new_status := v_dispute.status;

  if v_dispute.status = 'awaiting_supplier' then
    update public.order_disputes od
    set status = 'under_review',
        supplier_action_required = false,
        updated_at = v_now
    where od.id = p_dispute_id;

    v_new_status := 'under_review';

    insert into public.dispute_status_history(
      dispute_id,
      previous_status,
      new_status,
      changed_by_profile_id,
      changed_by_role,
      reason_code,
      public_note,
      internal_note,
      created_at,
      idempotency_key
    )
    values (
      p_dispute_id,
      'awaiting_supplier',
      'under_review',
      v_profile_id,
      'supplier',
      'supplier_response',
      'Supplier responded. Case is back under review.',
      null,
      v_now,
      'sup-rsp-status:' || md5(v_key)
    );

    insert into public.audit_logs(
      actor_profile_id,
      actor_role,
      action,
      target_entity_type,
      target_entity_id,
      after_data,
      reason,
      created_at
    )
    values (
      v_profile_id,
      'supplier_owner',
      'dispute_status_changed',
      'order_disputes',
      p_dispute_id,
      jsonb_build_object(
        'old_status', 'awaiting_supplier',
        'new_status', 'under_review',
        'actor_role', 'supplier',
        'scope_type', v_dispute.scope_type,
        'target_supplier_present', v_dispute.affected_supplier_id is not null,
        'target_order_item_present', v_dispute.affected_order_item_id is not null,
        'idempotency_key_present', true
      ),
      'supplier response moved dispute under review',
      v_now
    );
  else
    update public.order_disputes od
    set updated_at = v_now
    where od.id = p_dispute_id;
  end if;

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    after_data,
    reason,
    created_at
  )
  values (
    v_profile_id,
    'supplier_owner',
    'dispute_supplier_response_added',
    'dispute_messages',
    v_message_id,
    jsonb_build_object(
      'dispute_id', p_dispute_id,
      'status', v_new_status,
      'scope_type', v_dispute.scope_type,
      'target_supplier_present', v_dispute.affected_supplier_id is not null,
      'target_order_item_present', v_dispute.affected_order_item_id is not null,
      'idempotency_key_present', true
    ),
    'supplier added dispute response',
    v_now
  );

  message_id := v_message_id;
  dispute_id := p_dispute_id;
  created := true;
  status := v_new_status;
  created_at := v_now;
  return next;
end;
$fn$;

revoke all on function public.supplier_add_dispute_response(uuid, text, text) from public, anon, authenticated;
grant execute on function public.supplier_add_dispute_response(uuid, text, text) to authenticated;

comment on function public.supplier_add_dispute_response(uuid, text, text) is
  'D5 supplier-only audited dispute response RPC. Resolves supplier identity server-side, authorizes through D5-A affected supplier/item scope, appends supplier-private text response, optionally moves awaiting_supplier to under_review, and does not mutate order/payment/finance/stock/business state.';
