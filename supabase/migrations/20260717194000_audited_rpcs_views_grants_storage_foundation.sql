-- Backend Security Phase 1: audited RPCs, safe views, grants, and storage foundation.
-- This migration is a code/schema foundation only. It does not connect frontend flows
-- to live data and does not apply anything to production by itself.

create or replace function public.create_audit_log_entry(
  p_action text,
  p_target_entity_type text,
  p_target_entity_id uuid default null,
  p_reason text default null,
  p_before_data jsonb default null,
  p_after_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_profile_id uuid;
  v_actor_role public.user_role;
  v_audit_log_id uuid;
begin
  v_actor_profile_id := public.current_profile_id();

  if v_actor_profile_id is null then
    raise exception 'Authenticated active profile is required for audited actions';
  end if;

  if length(trim(coalesce(p_action, ''))) = 0 then
    raise exception 'Audit action is required';
  end if;

  if length(trim(coalesce(p_target_entity_type, ''))) = 0 then
    raise exception 'Audit target entity type is required';
  end if;

  select p.primary_role
  into v_actor_role
  from public.profiles p
  where p.id = v_actor_profile_id;

  insert into public.audit_logs (
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
    v_actor_profile_id,
    v_actor_role,
    trim(p_action),
    trim(p_target_entity_type),
    p_target_entity_id,
    p_before_data,
    coalesce(p_after_data, '{}'::jsonb),
    nullif(trim(coalesce(p_reason, '')), '')
  )
  returning id into v_audit_log_id;

  return v_audit_log_id;
end;
$$;

create or replace function public.admin_manual_override_record(
  p_action_type text,
  p_target_entity_type text,
  p_target_entity_id uuid,
  p_reason text,
  p_before_data jsonb default null,
  p_after_data jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_profile_id uuid;
  v_admin_action_id uuid;
begin
  v_actor_profile_id := public.current_profile_id();

  if not public.has_admin_role('admin') then
    raise exception 'Admin role is required to record manual overrides';
  end if;

  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Manual override reason is required';
  end if;

  insert into public.admin_actions (
    actor_profile_id,
    action_type,
    action_status,
    target_entity_type,
    target_entity_id,
    reason,
    before_data,
    after_data,
    applied_at
  )
  values (
    v_actor_profile_id,
    trim(p_action_type),
    'applied',
    trim(p_target_entity_type),
    p_target_entity_id,
    trim(p_reason),
    p_before_data,
    p_after_data,
    now()
  )
  returning id into v_admin_action_id;

  perform public.create_audit_log_entry(
    'admin_manual_override_record',
    p_target_entity_type,
    p_target_entity_id,
    p_reason,
    p_before_data,
    jsonb_build_object('admin_action_id', v_admin_action_id, 'after_data', p_after_data)
  );

  return v_admin_action_id;
end;
$$;

create or replace function public.confirm_customer_order(
  p_order_id uuid,
  p_reason text default 'customer_confirmed'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found';
  end if;

  if not public.is_customer_owner(v_order.customer_id) then
    raise exception 'Only the order customer can confirm this order';
  end if;

  if v_order.customer_confirmation_status <> 'pending' then
    raise exception 'Order confirmation is not pending';
  end if;

  update public.orders
  set customer_confirmation_status = 'confirmed',
      confirmation_source = 'customer_rpc',
      confirmed_at = now(),
      order_status = 'customer_confirmed',
      updated_at = now()
  where id = p_order_id;

  perform public.create_audit_log_entry(
    'confirm_customer_order',
    'orders',
    p_order_id,
    p_reason,
    jsonb_build_object('customer_confirmation_status', v_order.customer_confirmation_status, 'order_status', v_order.order_status),
    jsonb_build_object('customer_confirmation_status', 'confirmed', 'order_status', 'customer_confirmed')
  );

  return p_order_id;
end;
$$;

create or replace function public.release_expired_reservation(
  p_reservation_id uuid,
  p_reason text default 'reservation_expired'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.stock_reservations%rowtype;
  v_variant public.product_variants%rowtype;
  v_supplier_id uuid;
begin
  if not public.has_admin_role('support_staff') then
    raise exception 'Support/admin role is required to release expired reservations';
  end if;

  select *
  into v_reservation
  from public.stock_reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Stock reservation not found';
  end if;

  if v_reservation.reservation_status not in ('pending', 'reserved') then
    raise exception 'Only pending or reserved reservations can be expired';
  end if;

  if v_reservation.expires_at > now() then
    raise exception 'Reservation has not expired';
  end if;

  select *
  into v_variant
  from public.product_variants
  where id = v_reservation.variant_id
  for update;

  select p.supplier_id
  into v_supplier_id
  from public.products p
  where p.id = v_reservation.product_id;

  update public.product_variants
  set reserved_stock_quantity = greatest(0, reserved_stock_quantity - v_reservation.quantity),
      updated_at = now()
  where id = v_reservation.variant_id;

  update public.stock_reservations
  set reservation_status = 'expired',
      released_at = now(),
      release_reason = p_reason,
      updated_at = now()
  where id = p_reservation_id;

  insert into public.inventory_movements (
    supplier_id,
    product_id,
    variant_id,
    movement_type,
    quantity_delta,
    previous_total_quantity,
    new_total_quantity,
    reason,
    order_id,
    created_by_profile_id
  )
  values (
    v_supplier_id,
    v_reservation.product_id,
    v_reservation.variant_id,
    'reservation_released',
    v_reservation.quantity,
    v_variant.total_stock_quantity,
    v_variant.total_stock_quantity,
    p_reason,
    v_reservation.order_id,
    public.current_profile_id()
  );

  perform public.create_audit_log_entry(
    'release_expired_reservation',
    'stock_reservations',
    p_reservation_id,
    p_reason,
    jsonb_build_object('reservation_status', v_reservation.reservation_status, 'reserved_stock_quantity', v_variant.reserved_stock_quantity),
    jsonb_build_object('reservation_status', 'expired')
  );

  return p_reservation_id;
end;
$$;

create or replace function public.mark_order_ready_for_delivery(
  p_order_id uuid,
  p_reason text default 'supplier_ready_for_delivery'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (
    public.has_admin_role('support_staff')
    or exists (
      select 1
      from public.order_items oi
      where oi.order_id = p_order_id
        and public.is_supplier_member(oi.supplier_id)
    )
  ) then
    raise exception 'Supplier member or support/admin role is required';
  end if;

  update public.orders
  set order_status = 'ready_for_pickup_or_dispatch',
      delivery_status = 'ready',
      updated_at = now()
  where id = p_order_id
    and customer_confirmation_status in ('confirmed', 'manual_confirmed')
    and order_status in ('customer_confirmed', 'supplier_preparing', 'delivery_quote_approved');

  if not found then
    raise exception 'Order is not in a ready-for-delivery transition state';
  end if;

  perform public.create_audit_log_entry(
    'mark_order_ready_for_delivery',
    'orders',
    p_order_id,
    p_reason,
    null,
    jsonb_build_object('order_status', 'ready_for_pickup_or_dispatch', 'delivery_status', 'ready')
  );

  return p_order_id;
end;
$$;

create or replace function public.record_delivery_quote(
  p_order_id uuid,
  p_delivery_method text,
  p_quoted_amount numeric,
  p_expires_at timestamptz default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote_id uuid;
begin
  if p_quoted_amount < 0 then
    raise exception 'Delivery quote amount cannot be negative';
  end if;

  if not (
    public.has_admin_role('support_staff')
    or exists (
      select 1
      from public.order_items oi
      where oi.order_id = p_order_id
        and public.is_supplier_member(oi.supplier_id)
    )
  ) then
    raise exception 'Supplier member or support/admin role is required to record delivery quotes';
  end if;

  insert into public.delivery_quotes (
    order_id,
    quoted_by_profile_id,
    quote_status,
    delivery_method,
    quoted_amount,
    expires_at,
    notes
  )
  values (
    p_order_id,
    public.current_profile_id(),
    'quoted',
    trim(p_delivery_method),
    p_quoted_amount,
    p_expires_at,
    p_notes
  )
  returning id into v_quote_id;

  update public.orders
  set delivery_quote_status = 'quoted',
      delivery_status = 'quote_ready',
      order_status = case
        when order_status in ('customer_confirmed', 'supplier_preparing') then 'delivery_quote_ready'
        else order_status
      end,
      updated_at = now()
  where id = p_order_id;

  perform public.create_audit_log_entry(
    'record_delivery_quote',
    'delivery_quotes',
    v_quote_id,
    p_notes,
    null,
    jsonb_build_object('order_id', p_order_id, 'quoted_amount', p_quoted_amount)
  );

  return v_quote_id;
end;
$$;

create or replace function public.approve_delivery_quote(
  p_delivery_quote_id uuid,
  p_reason text default 'customer_approved_delivery_quote'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote public.delivery_quotes%rowtype;
  v_order public.orders%rowtype;
begin
  select *
  into v_quote
  from public.delivery_quotes
  where id = p_delivery_quote_id
  for update;

  if not found then
    raise exception 'Delivery quote not found';
  end if;

  if v_quote.quote_status <> 'quoted' then
    raise exception 'Only quoted delivery quotes can be approved';
  end if;

  if v_quote.expires_at is not null and v_quote.expires_at <= now() then
    raise exception 'Delivery quote has expired';
  end if;

  select *
  into v_order
  from public.orders
  where id = v_quote.order_id
  for update;

  if not public.is_customer_owner(v_order.customer_id) then
    raise exception 'Only the order customer can approve this delivery quote';
  end if;

  update public.delivery_quotes
  set quote_status = 'approved',
      customer_approved_at = now(),
      updated_at = now()
  where id = p_delivery_quote_id;

  update public.orders
  set delivery_quote_status = 'approved',
      delivery_status = 'quote_approved',
      order_status = 'delivery_quote_approved',
      final_delivery_amount = v_quote.quoted_amount,
      total_payable_amount = subtotal_product_amount + v_quote.quoted_amount,
      updated_at = now()
  where id = v_quote.order_id;

  perform public.create_audit_log_entry(
    'approve_delivery_quote',
    'delivery_quotes',
    p_delivery_quote_id,
    p_reason,
    jsonb_build_object('quote_status', v_quote.quote_status),
    jsonb_build_object('quote_status', 'approved', 'quoted_amount', v_quote.quoted_amount)
  );

  return p_delivery_quote_id;
end;
$$;

create or replace function public.submit_supplier_settlement_proof(
  p_settlement_id uuid,
  p_proof_storage_path text,
  p_proof_reference text default null,
  p_reason text default 'supplier_submitted_settlement_proof'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settlement public.settlements%rowtype;
begin
  select *
  into v_settlement
  from public.settlements
  where id = p_settlement_id
  for update;

  if not found then
    raise exception 'Settlement not found';
  end if;

  if not public.is_supplier_owner(v_settlement.supplier_id) then
    raise exception 'Only the supplier owner can submit settlement proof';
  end if;

  if length(trim(coalesce(p_proof_storage_path, ''))) = 0 or p_proof_storage_path ~* '^https?://' then
    raise exception 'Settlement proof must use a private storage path';
  end if;

  update public.settlements
  set settlement_status = 'proof_submitted',
      proof_storage_path = trim(p_proof_storage_path),
      proof_reference = nullif(trim(coalesce(p_proof_reference, '')), ''),
      proof_uploaded_by_profile_id = public.current_profile_id(),
      updated_at = now()
  where id = p_settlement_id;

  perform public.create_audit_log_entry(
    'submit_supplier_settlement_proof',
    'settlements',
    p_settlement_id,
    p_reason,
    jsonb_build_object('settlement_status', v_settlement.settlement_status),
    jsonb_build_object('settlement_status', 'proof_submitted')
  );

  return p_settlement_id;
end;
$$;

create or replace function public.verify_supplier_settlement(
  p_settlement_id uuid,
  p_paid_amount numeric,
  p_review_notes text,
  p_approved boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settlement public.settlements%rowtype;
  v_new_paid numeric(12,2);
  v_new_outstanding numeric(12,2);
  v_new_status public.settlement_status;
begin
  if not public.has_admin_role('finance_staff') then
    raise exception 'Finance/admin role is required to verify settlements';
  end if;

  if p_paid_amount < 0 then
    raise exception 'Paid amount cannot be negative';
  end if;

  select *
  into v_settlement
  from public.settlements
  where id = p_settlement_id
  for update;

  if not found then
    raise exception 'Settlement not found';
  end if;

  if not p_approved then
    update public.settlements
    set settlement_status = 'verifying',
        reviewed_by_profile_id = public.current_profile_id(),
        review_notes = p_review_notes,
        updated_at = now()
    where id = p_settlement_id;
  else
    v_new_paid := least(v_settlement.due_amount, p_paid_amount);
    v_new_outstanding := greatest(0, v_settlement.due_amount - v_new_paid);
    v_new_status := case when v_new_outstanding = 0 then 'paid' else 'partially_settled' end;

    update public.settlements
    set settlement_status = v_new_status,
        paid_amount = v_new_paid,
        outstanding_amount = v_new_outstanding,
        verified_at = now(),
        verified_by_profile_id = public.current_profile_id(),
        reviewed_by_profile_id = public.current_profile_id(),
        review_notes = p_review_notes,
        updated_at = now()
    where id = p_settlement_id;
  end if;

  perform public.create_audit_log_entry(
    'verify_supplier_settlement',
    'settlements',
    p_settlement_id,
    p_review_notes,
    jsonb_build_object('settlement_status', v_settlement.settlement_status, 'paid_amount', v_settlement.paid_amount),
    jsonb_build_object('approved', p_approved, 'paid_amount', p_paid_amount)
  );

  return p_settlement_id;
end;
$$;

create or replace function public.mark_settlement_overdue(
  p_settlement_id uuid,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_admin_role('finance_staff') then
    raise exception 'Finance/admin role is required to mark settlements overdue';
  end if;

  update public.settlements
  set settlement_status = 'overdue',
      risk_level = 'medium',
      review_notes = p_reason,
      reviewed_by_profile_id = public.current_profile_id(),
      updated_at = now()
  where id = p_settlement_id
    and settlement_status not in ('paid', 'written_off');

  if not found then
    raise exception 'Settlement cannot be marked overdue';
  end if;

  perform public.create_audit_log_entry('mark_settlement_overdue', 'settlements', p_settlement_id, p_reason);
  return p_settlement_id;
end;
$$;

create or replace function public.restrict_supplier_for_overdue_settlement(
  p_supplier_id uuid,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_admin_role('finance_staff') then
    raise exception 'Finance/admin role is required to restrict suppliers for overdue settlements';
  end if;

  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Restriction reason is required';
  end if;

  update public.suppliers
  set supplier_status = 'restricted',
      settlement_status = 'overdue',
      risk_level = 'restricted',
      updated_at = now()
  where id = p_supplier_id;

  if not found then
    raise exception 'Supplier not found';
  end if;

  perform public.create_audit_log_entry('restrict_supplier_for_overdue_settlement', 'suppliers', p_supplier_id, p_reason);
  return p_supplier_id;
end;
$$;

create or replace function public.mark_commission_pending(
  p_commission_id uuid,
  p_reason text default 'commission_pending_supplier_settlement'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_admin_role('finance_staff') then
    raise exception 'Finance/admin role is required to update commission status';
  end if;

  update public.commissions
  set commission_status = 'awaiting_supplier_settlement',
      held_reason = p_reason,
      updated_at = now()
  where id = p_commission_id
    and commission_status in ('pending_order', 'awaiting_customer_confirmation', 'awaiting_delivery_payment');

  if not found then
    raise exception 'Commission cannot be moved to awaiting supplier settlement';
  end if;

  perform public.create_audit_log_entry('mark_commission_pending', 'commissions', p_commission_id, p_reason);
  return p_commission_id;
end;
$$;

create or replace function public.release_commission_after_settlement(
  p_commission_id uuid,
  p_reason text default 'supplier_settlement_verified'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_admin_role('finance_staff') then
    raise exception 'Finance/admin role is required to release commissions';
  end if;

  update public.commissions c
  set commission_status = 'available',
      available_at = now(),
      held_reason = null,
      updated_at = now()
  from public.settlements s
  where c.id = p_commission_id
    and c.settlement_id = s.id
    and s.settlement_status = 'paid'
    and c.commission_status in ('awaiting_supplier_settlement', 'held');

  if not found then
    raise exception 'Commission cannot be released until linked settlement is paid';
  end if;

  update public.resellers r
  set commission_available_amount = r.commission_available_amount + c.commission_amount,
      commission_pending_amount = greatest(0, r.commission_pending_amount - c.commission_amount),
      updated_at = now()
  from public.commissions c
  where c.id = p_commission_id
    and r.id = c.reseller_id;

  perform public.create_audit_log_entry('release_commission_after_settlement', 'commissions', p_commission_id, p_reason);
  return p_commission_id;
end;
$$;

create or replace function public.request_commission_withdrawal(
  p_reseller_id uuid,
  p_requested_amount numeric,
  p_provider text default null,
  p_account_name text default null,
  p_account_number_masked text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reseller public.resellers%rowtype;
  v_withdrawal_id uuid;
begin
  if not public.is_reseller_owner(p_reseller_id) then
    raise exception 'Only the reseller owner can request this withdrawal';
  end if;

  if p_requested_amount <= 0 then
    raise exception 'Withdrawal amount must be positive';
  end if;

  select *
  into v_reseller
  from public.resellers
  where id = p_reseller_id
  for update;

  if v_reseller.commission_available_amount < p_requested_amount then
    raise exception 'Insufficient available commission balance';
  end if;

  insert into public.withdrawals (
    reseller_id,
    requested_amount,
    withdrawal_status,
    provider,
    account_name,
    account_number_masked,
    requested_by_profile_id
  )
  values (
    p_reseller_id,
    p_requested_amount,
    'requested',
    p_provider,
    p_account_name,
    p_account_number_masked,
    public.current_profile_id()
  )
  returning id into v_withdrawal_id;

  update public.resellers
  set commission_available_amount = commission_available_amount - p_requested_amount,
      commission_pending_amount = commission_pending_amount + p_requested_amount,
      updated_at = now()
  where id = p_reseller_id;

  perform public.create_audit_log_entry(
    'request_commission_withdrawal',
    'withdrawals',
    v_withdrawal_id,
    'reseller_requested_withdrawal',
    null,
    jsonb_build_object('reseller_id', p_reseller_id, 'requested_amount', p_requested_amount)
  );

  return v_withdrawal_id;
end;
$$;

create or replace function public.approve_or_reject_withdrawal(
  p_withdrawal_id uuid,
  p_approved boolean,
  p_approved_amount numeric default null,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_withdrawal public.withdrawals%rowtype;
  v_approved_amount numeric(12,2);
begin
  if not public.has_admin_role('finance_staff') then
    raise exception 'Finance/admin role is required to approve or reject withdrawals';
  end if;

  select *
  into v_withdrawal
  from public.withdrawals
  where id = p_withdrawal_id
  for update;

  if not found then
    raise exception 'Withdrawal not found';
  end if;

  if v_withdrawal.withdrawal_status <> 'requested' then
    raise exception 'Only requested withdrawals can be reviewed';
  end if;

  if p_approved then
    v_approved_amount := coalesce(p_approved_amount, v_withdrawal.requested_amount);
    if v_approved_amount <= 0 or v_approved_amount > v_withdrawal.requested_amount then
      raise exception 'Approved amount must be positive and cannot exceed requested amount';
    end if;

    update public.withdrawals
    set withdrawal_status = 'processing',
        approved_amount = v_approved_amount,
        approved_by_profile_id = public.current_profile_id(),
        failed_reason = null,
        updated_at = now()
    where id = p_withdrawal_id;
  else
    update public.withdrawals
    set withdrawal_status = 'rejected',
        approved_amount = 0,
        approved_by_profile_id = public.current_profile_id(),
        failed_reason = p_reason,
        updated_at = now()
    where id = p_withdrawal_id;

    update public.resellers
    set commission_available_amount = commission_available_amount + v_withdrawal.requested_amount,
        commission_pending_amount = greatest(0, commission_pending_amount - v_withdrawal.requested_amount),
        updated_at = now()
    where id = v_withdrawal.reseller_id;
  end if;

  perform public.create_audit_log_entry(
    'approve_or_reject_withdrawal',
    'withdrawals',
    p_withdrawal_id,
    p_reason,
    jsonb_build_object('withdrawal_status', v_withdrawal.withdrawal_status),
    jsonb_build_object('approved', p_approved, 'approved_amount', p_approved_amount)
  );

  return p_withdrawal_id;
end;
$$;

create or replace view public.supplier_settlement_summary
with (security_invoker = true)
as
select
  s.supplier_id,
  count(*)::integer as settlement_count,
  coalesce(sum(s.due_amount), 0)::numeric(12,2) as total_due_amount,
  coalesce(sum(s.paid_amount), 0)::numeric(12,2) as total_paid_amount,
  coalesce(sum(s.outstanding_amount), 0)::numeric(12,2) as total_outstanding_amount,
  count(*) filter (where s.settlement_status = 'overdue')::integer as overdue_count,
  max(s.updated_at) as latest_settlement_updated_at
from public.settlements s
where s.deleted_at is null
group by s.supplier_id;

create or replace view public.reseller_commission_summary
with (security_invoker = true)
as
select
  c.reseller_id,
  count(*)::integer as commission_count,
  coalesce(sum(c.commission_amount) filter (where c.commission_status = 'available'), 0)::numeric(12,2) as available_amount,
  coalesce(sum(c.commission_amount) filter (where c.commission_status in ('pending_order', 'awaiting_customer_confirmation', 'awaiting_delivery_payment', 'awaiting_supplier_settlement', 'held')), 0)::numeric(12,2) as pending_amount,
  coalesce(sum(c.commission_amount) filter (where c.commission_status = 'paid'), 0)::numeric(12,2) as paid_amount,
  max(c.updated_at) as latest_commission_updated_at
from public.commissions c
group by c.reseller_id;

create or replace view public.supplier_product_image_review_queue
with (security_invoker = true)
as
select
  pi.id,
  pi.product_id,
  p.supplier_id,
  pi.variant_id,
  pi.storage_path,
  pi.alt_text,
  pi.sort_order,
  pi.image_status,
  pi.is_primary,
  pi.created_by_profile_id,
  pi.created_at,
  pi.updated_at
from public.product_images pi
join public.products p on p.id = pi.product_id
where pi.deleted_at is null
  and p.deleted_at is null;

create or replace function public.storage_path_supplier_id(p_object_name text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
declare
  v_supplier_id_text text;
begin
  v_supplier_id_text := split_part(coalesce(p_object_name, ''), '/', 1);

  if v_supplier_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return null;
  end if;

  return v_supplier_id_text::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

do $$
begin
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    insert into storage.buckets (id, name, public)
    values ('product-images', 'product-images', false)
    on conflict (id) do update
      set public = false;

    execute 'drop policy if exists "product_images_storage_select_supplier_admin" on storage.objects';
    execute 'create policy "product_images_storage_select_supplier_admin"
      on storage.objects for select to authenticated
      using (
        bucket_id = ''product-images''
        and (
          public.is_supplier_member(public.storage_path_supplier_id(name))
          or public.has_admin_role(''support_staff'')
        )
      )';

    execute 'drop policy if exists "product_images_storage_insert_supplier" on storage.objects';
    execute 'create policy "product_images_storage_insert_supplier"
      on storage.objects for insert to authenticated
      with check (
        bucket_id = ''product-images''
        and public.has_supplier_permission(public.storage_path_supplier_id(name), ''products.create'')
      )';

    execute 'drop policy if exists "product_images_storage_update_supplier" on storage.objects';
    execute 'create policy "product_images_storage_update_supplier"
      on storage.objects for update to authenticated
      using (
        bucket_id = ''product-images''
        and public.has_supplier_permission(public.storage_path_supplier_id(name), ''products.create'')
      )
      with check (
        bucket_id = ''product-images''
        and public.has_supplier_permission(public.storage_path_supplier_id(name), ''products.create'')
      )';
  end if;
end;
$$;

revoke all on function public.create_audit_log_entry(text, text, uuid, text, jsonb, jsonb) from public;
grant execute on function public.create_audit_log_entry(text, text, uuid, text, jsonb, jsonb) to authenticated;

revoke all on function public.admin_manual_override_record(text, text, uuid, text, jsonb, jsonb) from public;
grant execute on function public.admin_manual_override_record(text, text, uuid, text, jsonb, jsonb) to authenticated;

revoke all on function public.confirm_customer_order(uuid, text) from public;
revoke all on function public.release_expired_reservation(uuid, text) from public;
revoke all on function public.mark_order_ready_for_delivery(uuid, text) from public;
revoke all on function public.record_delivery_quote(uuid, text, numeric, timestamptz, text) from public;
revoke all on function public.approve_delivery_quote(uuid, text) from public;
grant execute on function public.confirm_customer_order(uuid, text) to authenticated;
grant execute on function public.release_expired_reservation(uuid, text) to authenticated;
grant execute on function public.mark_order_ready_for_delivery(uuid, text) to authenticated;
grant execute on function public.record_delivery_quote(uuid, text, numeric, timestamptz, text) to authenticated;
grant execute on function public.approve_delivery_quote(uuid, text) to authenticated;

revoke all on function public.submit_supplier_settlement_proof(uuid, text, text, text) from public;
revoke all on function public.verify_supplier_settlement(uuid, numeric, text, boolean) from public;
revoke all on function public.mark_settlement_overdue(uuid, text) from public;
revoke all on function public.restrict_supplier_for_overdue_settlement(uuid, text) from public;
grant execute on function public.submit_supplier_settlement_proof(uuid, text, text, text) to authenticated;
grant execute on function public.verify_supplier_settlement(uuid, numeric, text, boolean) to authenticated;
grant execute on function public.mark_settlement_overdue(uuid, text) to authenticated;
grant execute on function public.restrict_supplier_for_overdue_settlement(uuid, text) to authenticated;

revoke all on function public.mark_commission_pending(uuid, text) from public;
revoke all on function public.release_commission_after_settlement(uuid, text) from public;
revoke all on function public.request_commission_withdrawal(uuid, numeric, text, text, text) from public;
revoke all on function public.approve_or_reject_withdrawal(uuid, boolean, numeric, text) from public;
grant execute on function public.mark_commission_pending(uuid, text) to authenticated;
grant execute on function public.release_commission_after_settlement(uuid, text) to authenticated;
grant execute on function public.request_commission_withdrawal(uuid, numeric, text, text, text) to authenticated;
grant execute on function public.approve_or_reject_withdrawal(uuid, boolean, numeric, text) to authenticated;

revoke all on function public.storage_path_supplier_id(text) from public;
grant execute on function public.storage_path_supplier_id(text) to authenticated;

revoke all on public.supplier_settlement_summary from public;
revoke all on public.reseller_commission_summary from public;
revoke all on public.supplier_product_image_review_queue from public;
grant select on public.supplier_settlement_summary to authenticated;
grant select on public.reseller_commission_summary to authenticated;
grant select on public.supplier_product_image_review_queue to authenticated;

comment on function public.create_audit_log_entry(text, text, uuid, text, jsonb, jsonb)
  is 'Authenticated audit log writer used by controlled RPCs; validates active caller profile and writes actor role server-side.';

comment on function public.confirm_customer_order(uuid, text)
  is 'Customer-owned audited order confirmation. Does not mutate price snapshots.';

comment on function public.release_expired_reservation(uuid, text)
  is 'Support/admin audited stock reservation expiry release. Uses row locks and never creates a client DELETE path.';

comment on function public.record_delivery_quote(uuid, text, numeric, timestamptz, text)
  is 'Supplier/support audited delivery quote creation. Customer price total is only changed by approve_delivery_quote.';

comment on function public.submit_supplier_settlement_proof(uuid, text, text, text)
  is 'Supplier-owner audited settlement proof metadata update. Requires private storage path, not a public URL.';

comment on function public.verify_supplier_settlement(uuid, numeric, text, boolean)
  is 'Finance/admin audited settlement verification. Commission release is intentionally separate and requires paid settlement.';

comment on function public.release_commission_after_settlement(uuid, text)
  is 'Finance/admin audited commission release. Requires linked settlement to be paid.';

comment on function public.request_commission_withdrawal(uuid, numeric, text, text, text)
  is 'Reseller-owned audited withdrawal request with balance lock and available-to-pending balance movement.';

comment on view public.supplier_settlement_summary
  is 'Security-invoker supplier settlement summary view; table RLS remains authoritative.';

comment on view public.reseller_commission_summary
  is 'Security-invoker reseller commission summary view; table RLS remains authoritative.';

comment on view public.supplier_product_image_review_queue
  is 'Security-invoker product image metadata view for supplier/admin review workflows; table RLS remains authoritative.';

comment on function public.storage_path_supplier_id(text)
  is 'Parses supplier UUID from storage object paths formatted as supplier_id/product_id/file_name. Invalid paths return null.';

comment on schema public
  is 'Backend Security Phase 1 adds audited RPC foundations. Full create_order_with_snapshot/reserve_stock_for_order and production public image approval rules remain deferred until idempotency, cart, and storage validation tests are in place.';
