-- Disputes D8 forward fix: enforce cumulative item and delivery component caps.
-- This preserves the manual-refund boundary and does not mutate finance, stock,
-- order, payment, settlement, commission, wallet, withdrawal, or notification data.

create or replace function public.refund_workflow_cap_bearing_status(p_status text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_status in (
    'approved',
    'awaiting_responsible_party',
    'reported_sent',
    'awaiting_customer_confirmation',
    'under_verification',
    'verified',
    'completed'
  );
$$;

create or replace function public.refund_workflow_enforce_cumulative_caps()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_item public.order_items%rowtype;
  v_item_committed numeric(12,2) := 0;
  v_delivery_committed numeric(12,2) := 0;
  v_order_committed numeric(12,2) := 0;
  v_delivery_max numeric(12,2) := 0;
begin
  if new.deleted_at is not null or not public.refund_workflow_cap_bearing_status(new.status) then
    return new;
  end if;

  select * into v_order
  from public.orders o
  where o.id = new.order_id and o.deleted_at is null
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = '42501';
  end if;

  if new.order_item_id is not null then
    select * into v_item
    from public.order_items oi
    where oi.id = new.order_item_id and oi.order_id = new.order_id
    for update;

    if not found then
      raise exception 'ORDER_ITEM_NOT_FOUND' using errcode = '42501';
    end if;

    select coalesce(sum(r.item_amount_component), 0)
    into v_item_committed
    from public.order_refunds r
    where r.order_item_id = new.order_item_id
      and r.id is distinct from new.id
      and r.deleted_at is null
      and public.refund_workflow_cap_bearing_status(r.status);

    if v_item_committed + coalesce(new.item_amount_component, 0) > coalesce(v_item.line_total_amount, 0) then
      raise exception 'REFUND_ITEM_REMAINING_CAP_EXCEEDED' using errcode = '23514';
    end if;
  elsif coalesce(new.item_amount_component, 0) <> 0 then
    raise exception 'ITEM_SCOPE_REQUIRED' using errcode = '23514';
  end if;

  v_delivery_max := coalesce(v_order.final_delivery_amount, 0);
  select coalesce(sum(r.delivery_fee_component), 0)
  into v_delivery_committed
  from public.order_refunds r
  where r.order_id = new.order_id
    and r.id is distinct from new.id
    and r.deleted_at is null
    and public.refund_workflow_cap_bearing_status(r.status);

  if v_delivery_committed + coalesce(new.delivery_fee_component, 0) > v_delivery_max then
    raise exception 'REFUND_DELIVERY_REMAINING_CAP_EXCEEDED' using errcode = '23514';
  end if;

  select coalesce(sum(r.approved_amount), 0)
  into v_order_committed
  from public.order_refunds r
  where r.order_id = new.order_id
    and r.id is distinct from new.id
    and r.deleted_at is null
    and public.refund_workflow_cap_bearing_status(r.status);

  if v_order_committed + coalesce(new.approved_amount, 0) > coalesce(v_order.total_payable_amount, 0) then
    raise exception 'REFUND_ORDER_REMAINING_CAP_EXCEEDED' using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists order_refunds_enforce_cumulative_caps on public.order_refunds;
create trigger order_refunds_enforce_cumulative_caps
before insert or update of status, deleted_at on public.order_refunds
for each row execute function public.refund_workflow_enforce_cumulative_caps();

revoke all on function public.refund_workflow_cap_bearing_status(text) from public, anon, authenticated;
revoke all on function public.refund_workflow_enforce_cumulative_caps() from public, anon, authenticated;

comment on function public.refund_workflow_enforce_cumulative_caps() is
  'D8 refund safety trigger enforcing cumulative immutable item, delivery, and order caps across active, verified, and completed manual refund obligations.';
