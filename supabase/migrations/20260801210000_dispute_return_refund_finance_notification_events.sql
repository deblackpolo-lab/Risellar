-- Disputes, Returns, and Refunds D11: transactional notification mappings.
-- Forward-only, notification-only. Reuses the existing durable email outbox.
-- No business state, provider, UI, payment, delivery, stock, wallet, settlement,
-- commission, refund, return, withdrawal, or dispute mutation is introduced.

alter table public.notification_outbox
  drop constraint if exists notification_outbox_event_type_allowed;

alter table public.notification_outbox
  add constraint notification_outbox_event_type_allowed check (
    event_type in (
      'order_placed_customer',
      'order_placed_supplier',
      'supplier_order_accepted',
      'supplier_order_rejected',
      'supplier_order_preparing',
      'order_ready_for_delivery',
      'delivery_arranged',
      'order_out_for_delivery',
      'order_delivered',
      'supplier_payment_reported_customer',
      'supplier_payment_reported_finance',
      'settlement_verified_supplier',
      'settlement_verified_customer',
      'reseller_commission_available',
      'withdrawal_requested_reseller',
      'withdrawal_requested_finance',
      'withdrawal_paid_reseller',
      'dispute_opened_customer',
      'dispute_information_requested_customer',
      'dispute_status_updated_customer',
      'dispute_resolved_customer',
      'dispute_closed_customer',
      'return_requested_customer',
      'return_approved_customer',
      'return_rejected_customer',
      'return_received_customer',
      'return_accepted_customer',
      'return_declined_customer',
      'return_completed_customer',
      'refund_approved_customer',
      'refund_reported_sent_customer',
      'refund_customer_confirmation_required',
      'refund_verified_customer',
      'refund_completed_customer',
      'dispute_opened_supplier',
      'dispute_information_requested_supplier',
      'dispute_status_updated_supplier',
      'dispute_resolved_supplier',
      'return_requested_supplier',
      'return_approved_supplier',
      'return_in_transit_supplier',
      'return_received_supplier',
      'return_inspection_required_supplier',
      'return_completed_supplier',
      'refund_obligation_supplier',
      'refund_report_required_supplier',
      'refund_customer_disputed_not_received_supplier',
      'refund_verified_supplier',
      'supplier_liability_created',
      'supplier_liability_updated',
      'dispute_affecting_commission_reseller',
      'commission_hold_created_reseller',
      'commission_hold_released_reseller',
      'reseller_liability_review_created',
      'reseller_liability_approved',
      'future_earnings_offset_enabled',
      'liability_recovery_applied',
      'liability_recovered',
      'withdrawal_blocked_by_finance_review',
      'withdrawal_allocation_released',
      'withdrawal_ready_after_review',
      'new_dispute_admin',
      'dispute_response_received_admin',
      'dispute_information_received_admin',
      'return_requested_admin',
      'return_received_admin',
      'return_inspected_admin',
      'refund_customer_disputed_not_received_admin',
      'refund_reported_sent_admin',
      'refund_approval_required_finance',
      'refund_reported_sent_finance',
      'refund_customer_disputed_not_received_finance',
      'refund_verification_required_finance',
      'finance_hold_created_finance',
      'settlement_blocked_finance',
      'commission_hold_created_finance',
      'reseller_liability_review_finance',
      'withdrawal_blocked_finance'
    )
  );

create or replace function public.notification_d11_event_key(
  p_event_type text,
  p_entity_id uuid,
  p_audit_log_id uuid,
  p_recipient_role text
)
returns text
language plpgsql
stable
set search_path = public
as $fn$
declare
  v_key text;
begin
  if p_event_type is null
    or p_entity_id is null
    or p_audit_log_id is null
    or nullif(trim(coalesce(p_recipient_role, '')), '') is null then
    raise exception 'EMAIL_NOTIFICATION_EVENT_KEY_PART_INVALID';
  end if;

  v_key := p_event_type || ':' || p_entity_id::text || ':' || p_audit_log_id::text || ':' || p_recipient_role;

  if length(v_key) > 256 then
    raise exception 'EMAIL_NOTIFICATION_EVENT_KEY_TOO_LONG';
  end if;

  return v_key;
end;
$fn$;

create or replace function public.notification_d11_enqueue(
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_audit_log_id uuid,
  p_recipient_profile_id uuid,
  p_recipient_role text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if p_recipient_profile_id is null then
    return;
  end if;

  perform public.enqueue_email_notification(
    public.notification_d11_event_key(p_event_type, p_entity_id, p_audit_log_id, p_recipient_role),
    p_event_type,
    p_entity_type,
    p_entity_id,
    p_recipient_profile_id,
    p_recipient_role,
    coalesce(p_payload, '{}'::jsonb)
      - 'recipient_email'
      - 'email'
      - 'phone'
      - 'whatsapp'
      - 'address'
      - 'customer_address'
      - 'customerAddress'
      - 'supplier_private_note'
      - 'supplierPrivateNote'
      - 'admin_note'
      - 'adminInternalNote'
      - 'admin_internal_note'
      - 'internal_note'
      - 'internal_notes'
      - 'payment_reference'
      - 'refund_reference'
      - 'external_reference_masked'
      - 'provider_payload'
      - 'audit_metadata'
  );
end;
$fn$;

create or replace function public.notification_d11_active_support_admin_profiles(p_preferred_profile_id uuid default null)
returns table(profile_id uuid)
language sql
stable
security definer
set search_path = public
as $fn$
  select ads.profile_id
  from public.admin_staff ads
  join public.profiles p on p.id = ads.profile_id
  where ads.staff_status = 'active'
    and ads.deleted_at is null
    and ads.admin_role in ('support_staff', 'admin', 'super_admin')
    and p.account_status = 'active'
    and p.deleted_at is null
    and (p_preferred_profile_id is null or ads.profile_id = p_preferred_profile_id)
  union all
  select ads.profile_id
  from public.admin_staff ads
  join public.profiles p on p.id = ads.profile_id
  where p_preferred_profile_id is not null
    and not exists (
      select 1
      from public.admin_staff preferred
      join public.profiles preferred_profile on preferred_profile.id = preferred.profile_id
      where preferred.profile_id = p_preferred_profile_id
        and preferred.staff_status = 'active'
        and preferred.deleted_at is null
        and preferred.admin_role in ('support_staff', 'admin', 'super_admin')
        and preferred_profile.account_status = 'active'
        and preferred_profile.deleted_at is null
    )
    and ads.staff_status = 'active'
    and ads.deleted_at is null
    and ads.admin_role in ('support_staff', 'admin', 'super_admin')
    and p.account_status = 'active'
    and p.deleted_at is null
$fn$;

create or replace function public.notification_d11_active_finance_profiles()
returns table(profile_id uuid)
language sql
stable
security definer
set search_path = public
as $fn$
  select ads.profile_id
  from public.admin_staff ads
  join public.profiles p on p.id = ads.profile_id
  where ads.staff_status = 'active'
    and ads.deleted_at is null
    and ads.admin_role in ('finance_staff', 'super_admin')
    and p.account_status = 'active'
    and p.deleted_at is null
$fn$;

create or replace function public.enqueue_d11_notifications_from_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_dispute record;
  v_return record;
  v_refund record;
  v_hold record;
  v_liability record;
  v_allocation record;
  v_admin_profile_id uuid;
  v_target_role text;
  v_payload jsonb;
begin
  begin
    if new.target_entity_type = 'order_disputes' then
      select
        od.id,
        od.order_id,
        od.affected_supplier_id,
        od.assigned_admin_profile_id,
        od.reason_code,
        od.status,
        o.order_number,
        o.currency_code,
        c.profile_id as customer_profile_id,
        r.profile_id as reseller_profile_id,
        s.owner_profile_id as supplier_profile_id,
        coalesce(target_product.name, first_product.name, 'Order item') as product_name
      into v_dispute
      from public.order_disputes od
      join public.orders o on o.id = od.order_id and o.deleted_at is null
      join public.customers c on c.id = o.customer_id and c.deleted_at is null
      join public.resellers r on r.id = o.reseller_id and r.deleted_at is null
      left join public.suppliers s on s.id = od.affected_supplier_id and s.deleted_at is null
      left join public.order_items target_item on target_item.id = od.affected_order_item_id and target_item.order_id = od.order_id
      left join public.products target_product on target_product.id = target_item.product_id
      left join lateral (
        select p.name
        from public.order_items oi
        join public.products p on p.id = oi.product_id
        where oi.order_id = od.order_id
        order by oi.created_at asc, oi.id asc
        limit 1
      ) first_product on true
      where od.id = new.target_entity_id
        and od.deleted_at is null;

      if v_dispute.id is null then
        return new;
      end if;

      v_payload := jsonb_build_object(
        'orderNumber', v_dispute.order_number,
        'productName', v_dispute.product_name,
        'safeStatus', initcap(replace(v_dispute.status, '_', ' ')),
        'currency', v_dispute.currency_code,
        'ctaPath', '/customer/orders/' || v_dispute.order_id::text
      );

      if new.action = 'dispute_opened' then
        perform public.notification_d11_enqueue('dispute_opened_customer', 'order_disputes', v_dispute.id, new.id, v_dispute.customer_profile_id, 'customer', v_payload);
        if v_dispute.supplier_profile_id is not null then
          perform public.notification_d11_enqueue('dispute_opened_supplier', 'order_disputes', v_dispute.id, new.id, v_dispute.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_dispute.order_id::text));
        end if;
        if v_dispute.reason_code = 'commission_missing' then
          perform public.notification_d11_enqueue('dispute_affecting_commission_reseller', 'order_disputes', v_dispute.id, new.id, v_dispute.reseller_profile_id, 'reseller', jsonb_build_object('orderNumber', v_dispute.order_number, 'safeStatus', 'Under review', 'ctaPath', '/reseller/wallet'));
        end if;
        for v_admin_profile_id in select profile_id from public.notification_d11_active_support_admin_profiles(v_dispute.assigned_admin_profile_id) loop
          perform public.notification_d11_enqueue('new_dispute_admin', 'order_disputes', v_dispute.id, new.id, v_admin_profile_id, 'support_admin', v_payload || jsonb_build_object('ctaPath', '/admin/disputes/' || v_dispute.id::text));
        end loop;
      elsif new.action = 'dispute_information_requested' then
        v_target_role := coalesce(new.after_data ->> 'target_role', new.after_data ->> 'requested_from_role');
        if v_target_role = 'customer' then
          perform public.notification_d11_enqueue('dispute_information_requested_customer', 'order_disputes', v_dispute.id, new.id, v_dispute.customer_profile_id, 'customer', v_payload);
        elsif v_target_role = 'supplier' and v_dispute.supplier_profile_id is not null then
          perform public.notification_d11_enqueue('dispute_information_requested_supplier', 'order_disputes', v_dispute.id, new.id, v_dispute.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_dispute.order_id::text));
        end if;
      elsif new.action in ('dispute_customer_response_added', 'dispute_supplier_response_added') then
        for v_admin_profile_id in select profile_id from public.notification_d11_active_support_admin_profiles(v_dispute.assigned_admin_profile_id) loop
          perform public.notification_d11_enqueue('dispute_response_received_admin', 'order_disputes', v_dispute.id, new.id, v_admin_profile_id, 'support_admin', v_payload || jsonb_build_object('ctaPath', '/admin/disputes/' || v_dispute.id::text));
        end loop;
      elsif new.action = 'dispute_status_changed' then
        perform public.notification_d11_enqueue('dispute_status_updated_customer', 'order_disputes', v_dispute.id, new.id, v_dispute.customer_profile_id, 'customer', v_payload);
        if v_dispute.supplier_profile_id is not null then
          perform public.notification_d11_enqueue('dispute_status_updated_supplier', 'order_disputes', v_dispute.id, new.id, v_dispute.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_dispute.order_id::text));
        end if;
      elsif new.action = 'dispute_resolution_recorded' then
        perform public.notification_d11_enqueue('dispute_resolved_customer', 'order_disputes', v_dispute.id, new.id, v_dispute.customer_profile_id, 'customer', v_payload);
        if v_dispute.supplier_profile_id is not null then
          perform public.notification_d11_enqueue('dispute_resolved_supplier', 'order_disputes', v_dispute.id, new.id, v_dispute.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_dispute.order_id::text));
        end if;
      elsif new.action = 'dispute_closed' then
        perform public.notification_d11_enqueue('dispute_closed_customer', 'order_disputes', v_dispute.id, new.id, v_dispute.customer_profile_id, 'customer', v_payload);
      end if;

    elsif new.target_entity_type = 'order_item_return' then
      select
        ret.id,
        ret.order_id,
        ret.supplier_id,
        ret.customer_profile_id,
        ret.status,
        o.order_number,
        o.currency_code,
        s.owner_profile_id as supplier_profile_id,
        p.name as product_name
      into v_return
      from public.order_item_returns ret
      join public.orders o on o.id = ret.order_id and o.deleted_at is null
      join public.suppliers s on s.id = ret.supplier_id and s.deleted_at is null
      join public.order_items oi on oi.id = ret.order_item_id
      join public.products p on p.id = oi.product_id
      where ret.id = new.target_entity_id
        and ret.deleted_at is null;

      if v_return.id is null then
        return new;
      end if;

      v_payload := jsonb_build_object(
        'orderNumber', v_return.order_number,
        'productName', v_return.product_name,
        'safeStatus', initcap(replace(v_return.status, '_', ' ')),
        'currency', v_return.currency_code,
        'ctaPath', '/customer/orders/' || v_return.order_id::text
      );

      if new.action = 'return_requested' then
        perform public.notification_d11_enqueue('return_requested_customer', 'order_item_return', v_return.id, new.id, v_return.customer_profile_id, 'customer', v_payload);
        perform public.notification_d11_enqueue('return_requested_supplier', 'order_item_return', v_return.id, new.id, v_return.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_return.order_id::text));
        for v_admin_profile_id in select profile_id from public.notification_d11_active_support_admin_profiles(null) loop
          perform public.notification_d11_enqueue('return_requested_admin', 'order_item_return', v_return.id, new.id, v_admin_profile_id, 'support_admin', v_payload || jsonb_build_object('ctaPath', '/admin/returns/' || v_return.id::text));
        end loop;
      elsif new.action = 'return_approved' then
        perform public.notification_d11_enqueue('return_approved_customer', 'order_item_return', v_return.id, new.id, v_return.customer_profile_id, 'customer', v_payload);
        perform public.notification_d11_enqueue('return_approved_supplier', 'order_item_return', v_return.id, new.id, v_return.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_return.order_id::text));
      elsif new.action = 'return_rejected' then
        perform public.notification_d11_enqueue('return_rejected_customer', 'order_item_return', v_return.id, new.id, v_return.customer_profile_id, 'customer', v_payload);
      elsif new.action = 'return_marked_in_transit' then
        perform public.notification_d11_enqueue('return_in_transit_supplier', 'order_item_return', v_return.id, new.id, v_return.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_return.order_id::text));
      elsif new.action = 'return_received' then
        perform public.notification_d11_enqueue('return_received_customer', 'order_item_return', v_return.id, new.id, v_return.customer_profile_id, 'customer', v_payload);
        perform public.notification_d11_enqueue('return_received_supplier', 'order_item_return', v_return.id, new.id, v_return.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_return.order_id::text));
        for v_admin_profile_id in select profile_id from public.notification_d11_active_support_admin_profiles(null) loop
          perform public.notification_d11_enqueue('return_received_admin', 'order_item_return', v_return.id, new.id, v_admin_profile_id, 'support_admin', v_payload || jsonb_build_object('ctaPath', '/admin/returns/' || v_return.id::text));
        end loop;
      elsif new.action = 'returned_item_inspected' then
        perform public.notification_d11_enqueue('return_inspection_required_supplier', 'order_item_return', v_return.id, new.id, v_return.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_return.order_id::text));
        for v_admin_profile_id in select profile_id from public.notification_d11_active_support_admin_profiles(null) loop
          perform public.notification_d11_enqueue('return_inspected_admin', 'order_item_return', v_return.id, new.id, v_admin_profile_id, 'support_admin', v_payload || jsonb_build_object('ctaPath', '/admin/returns/' || v_return.id::text));
        end loop;
      elsif new.action = 'return_accepted' then
        perform public.notification_d11_enqueue('return_accepted_customer', 'order_item_return', v_return.id, new.id, v_return.customer_profile_id, 'customer', v_payload);
      elsif new.action = 'return_declined' then
        perform public.notification_d11_enqueue('return_declined_customer', 'order_item_return', v_return.id, new.id, v_return.customer_profile_id, 'customer', v_payload);
      elsif new.action = 'return_completed' then
        perform public.notification_d11_enqueue('return_completed_customer', 'order_item_return', v_return.id, new.id, v_return.customer_profile_id, 'customer', v_payload);
        perform public.notification_d11_enqueue('return_completed_supplier', 'order_item_return', v_return.id, new.id, v_return.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_return.order_id::text));
      end if;

    elsif new.target_entity_type = 'order_refund' then
      select
        ref.id,
        ref.order_id,
        ref.customer_profile_id,
        ref.affected_supplier_id,
        ref.responsible_party_role,
        ref.status,
        ref.approved_amount,
        ref.currency_code,
        o.order_number,
        s.owner_profile_id as supplier_profile_id,
        p.name as product_name
      into v_refund
      from public.order_refunds ref
      join public.orders o on o.id = ref.order_id and o.deleted_at is null
      left join public.suppliers s on s.id = ref.affected_supplier_id and s.deleted_at is null
      left join public.order_items oi on oi.id = ref.order_item_id
      left join public.products p on p.id = oi.product_id
      where ref.id = new.target_entity_id
        and ref.deleted_at is null;

      if v_refund.id is null then
        return new;
      end if;

      v_payload := jsonb_build_object(
        'orderNumber', v_refund.order_number,
        'productName', coalesce(v_refund.product_name, 'Order item'),
        'safeStatus', initcap(replace(v_refund.status, '_', ' ')),
        'amount', v_refund.currency_code || ' ' || v_refund.approved_amount::text,
        'currency', v_refund.currency_code,
        'ctaPath', '/customer/orders/' || v_refund.order_id::text
      );

      if new.action = 'refund_obligation_approved' then
        perform public.notification_d11_enqueue('refund_approved_customer', 'order_refund', v_refund.id, new.id, v_refund.customer_profile_id, 'customer', v_payload);
        if v_refund.responsible_party_role = 'supplier' and v_refund.supplier_profile_id is not null then
          perform public.notification_d11_enqueue('refund_obligation_supplier', 'order_refund', v_refund.id, new.id, v_refund.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_refund.order_id::text));
          perform public.notification_d11_enqueue('refund_report_required_supplier', 'order_refund', v_refund.id, new.id, v_refund.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_refund.order_id::text));
        elsif v_refund.responsible_party_role = 'platform' then
          for v_admin_profile_id in select profile_id from public.notification_d11_active_finance_profiles() loop
            perform public.notification_d11_enqueue('refund_approval_required_finance', 'order_refund', v_refund.id, new.id, v_admin_profile_id, 'finance_admin', v_payload || jsonb_build_object('ctaPath', '/admin/finance'));
          end loop;
        end if;
      elsif new.action = 'refund_reported_sent' then
        perform public.notification_d11_enqueue('refund_reported_sent_customer', 'order_refund', v_refund.id, new.id, v_refund.customer_profile_id, 'customer', v_payload);
        perform public.notification_d11_enqueue('refund_customer_confirmation_required', 'order_refund', v_refund.id, new.id, v_refund.customer_profile_id, 'customer', v_payload);
        for v_admin_profile_id in select profile_id from public.notification_d11_active_finance_profiles() loop
          perform public.notification_d11_enqueue('refund_reported_sent_finance', 'order_refund', v_refund.id, new.id, v_admin_profile_id, 'finance_admin', v_payload || jsonb_build_object('ctaPath', '/admin/finance'));
        end loop;
        for v_admin_profile_id in select profile_id from public.notification_d11_active_support_admin_profiles(null) loop
          perform public.notification_d11_enqueue('refund_reported_sent_admin', 'order_refund', v_refund.id, new.id, v_admin_profile_id, 'support_admin', v_payload || jsonb_build_object('ctaPath', '/admin/refunds/' || v_refund.id::text));
        end loop;
      elsif new.action = 'refund_customer_disputed_not_received' then
        if v_refund.supplier_profile_id is not null then
          perform public.notification_d11_enqueue('refund_customer_disputed_not_received_supplier', 'order_refund', v_refund.id, new.id, v_refund.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_refund.order_id::text));
        end if;
        for v_admin_profile_id in select profile_id from public.notification_d11_active_finance_profiles() loop
          perform public.notification_d11_enqueue('refund_customer_disputed_not_received_finance', 'order_refund', v_refund.id, new.id, v_admin_profile_id, 'finance_admin', v_payload || jsonb_build_object('ctaPath', '/admin/finance'));
        end loop;
        for v_admin_profile_id in select profile_id from public.notification_d11_active_support_admin_profiles(null) loop
          perform public.notification_d11_enqueue('refund_customer_disputed_not_received_admin', 'order_refund', v_refund.id, new.id, v_admin_profile_id, 'support_admin', v_payload || jsonb_build_object('ctaPath', '/admin/refunds/' || v_refund.id::text));
        end loop;
      elsif new.action = 'refund_verified' then
        perform public.notification_d11_enqueue('refund_verified_customer', 'order_refund', v_refund.id, new.id, v_refund.customer_profile_id, 'customer', v_payload);
        if v_refund.supplier_profile_id is not null then
          perform public.notification_d11_enqueue('refund_verified_supplier', 'order_refund', v_refund.id, new.id, v_refund.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/orders/' || v_refund.order_id::text));
        end if;
        for v_admin_profile_id in select profile_id from public.notification_d11_active_finance_profiles() loop
          perform public.notification_d11_enqueue('refund_verification_required_finance', 'order_refund', v_refund.id, new.id, v_admin_profile_id, 'finance_admin', v_payload || jsonb_build_object('ctaPath', '/admin/finance'));
        end loop;
      elsif new.action = 'refund_completed' then
        perform public.notification_d11_enqueue('refund_completed_customer', 'order_refund', v_refund.id, new.id, v_refund.customer_profile_id, 'customer', v_payload);
      end if;

    elsif new.target_entity_type = 'finance_holds' then
      select
        fh.id,
        fh.order_id,
        fh.supplier_id,
        fh.reseller_profile_id,
        fh.hold_type,
        fh.status,
        fh.amount,
        fh.currency_code,
        o.order_number,
        s.owner_profile_id as supplier_profile_id
      into v_hold
      from public.finance_holds fh
      join public.orders o on o.id = fh.order_id and o.deleted_at is null
      left join public.suppliers s on s.id = fh.supplier_id and s.deleted_at is null
      where fh.id = new.target_entity_id
        and fh.deleted_at is null;

      if v_hold.id is null then
        return new;
      end if;

      v_payload := jsonb_build_object(
        'orderNumber', v_hold.order_number,
        'safeStatus', initcap(replace(v_hold.hold_type, '_', ' ')),
        'amount', v_hold.currency_code || ' ' || v_hold.amount::text,
        'currency', v_hold.currency_code,
        'ctaPath', '/admin/finance'
      );

      if new.action = 'finance_hold_created' then
        for v_admin_profile_id in select profile_id from public.notification_d11_active_finance_profiles() loop
          perform public.notification_d11_enqueue('finance_hold_created_finance', 'finance_holds', v_hold.id, new.id, v_admin_profile_id, 'finance_admin', v_payload);
          if v_hold.hold_type = 'commission_availability_hold' then
            perform public.notification_d11_enqueue('commission_hold_created_finance', 'finance_holds', v_hold.id, new.id, v_admin_profile_id, 'finance_admin', v_payload);
          elsif v_hold.hold_type = 'reseller_liability_review' then
            perform public.notification_d11_enqueue('reseller_liability_review_finance', 'finance_holds', v_hold.id, new.id, v_admin_profile_id, 'finance_admin', v_payload);
          elsif v_hold.hold_type = 'withdrawal_review_hold' then
            perform public.notification_d11_enqueue('withdrawal_blocked_finance', 'finance_holds', v_hold.id, new.id, v_admin_profile_id, 'finance_admin', v_payload || jsonb_build_object('ctaPath', '/admin/withdrawals/' || coalesce((new.after_data ->> 'withdrawal_id'), v_hold.id::text)));
          end if;
        end loop;
        if v_hold.hold_type = 'commission_availability_hold' and v_hold.reseller_profile_id is not null then
          perform public.notification_d11_enqueue('commission_hold_created_reseller', 'finance_holds', v_hold.id, new.id, v_hold.reseller_profile_id, 'reseller', v_payload || jsonb_build_object('ctaPath', '/reseller/wallet'));
        elsif v_hold.hold_type = 'reseller_liability_review' and v_hold.reseller_profile_id is not null then
          perform public.notification_d11_enqueue('reseller_liability_review_created', 'finance_holds', v_hold.id, new.id, v_hold.reseller_profile_id, 'reseller', v_payload || jsonb_build_object('ctaPath', '/reseller/wallet'));
        elsif v_hold.hold_type = 'withdrawal_review_hold' and v_hold.reseller_profile_id is not null then
          perform public.notification_d11_enqueue('withdrawal_blocked_by_finance_review', 'finance_holds', v_hold.id, new.id, v_hold.reseller_profile_id, 'reseller', v_payload || jsonb_build_object('ctaPath', '/reseller/withdrawals'));
        elsif v_hold.hold_type = 'supplier_liability_hold' then
          perform public.notification_d11_enqueue('supplier_liability_created', 'finance_holds', v_hold.id, new.id, v_hold.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/settlements'));
        end if;
      elsif new.action = 'finance_hold_released' then
        if v_hold.hold_type = 'commission_availability_hold' and v_hold.reseller_profile_id is not null then
          perform public.notification_d11_enqueue('commission_hold_released_reseller', 'finance_holds', v_hold.id, new.id, v_hold.reseller_profile_id, 'reseller', v_payload || jsonb_build_object('ctaPath', '/reseller/wallet'));
        elsif v_hold.hold_type = 'withdrawal_review_hold' and v_hold.reseller_profile_id is not null then
          perform public.notification_d11_enqueue('withdrawal_ready_after_review', 'finance_holds', v_hold.id, new.id, v_hold.reseller_profile_id, 'reseller', v_payload || jsonb_build_object('ctaPath', '/reseller/withdrawals'));
        elsif v_hold.hold_type = 'supplier_liability_hold' then
          perform public.notification_d11_enqueue('supplier_liability_updated', 'finance_holds', v_hold.id, new.id, v_hold.supplier_profile_id, 'supplier', v_payload || jsonb_build_object('ctaPath', '/supplier/settlements'));
        end if;
      end if;

    elsif new.target_entity_type = 'reseller_liabilities' then
      select id, reseller_profile_id, status, outstanding_amount, recovered_amount, currency_code
      into v_liability
      from public.reseller_liabilities
      where id = new.target_entity_id
        and deleted_at is null;

      if v_liability.id is null then
        return new;
      end if;

      v_payload := jsonb_build_object(
        'safeStatus', initcap(replace(v_liability.status, '_', ' ')),
        'amount', v_liability.currency_code || ' ' || v_liability.outstanding_amount::text,
        'currency', v_liability.currency_code,
        'ctaPath', '/reseller/wallet'
      );

      if new.action = 'reseller_liability_approved' then
        perform public.notification_d11_enqueue('reseller_liability_approved', 'reseller_liabilities', v_liability.id, new.id, v_liability.reseller_profile_id, 'reseller', v_payload);
      elsif new.action = 'reseller_future_earnings_offset_enabled' then
        perform public.notification_d11_enqueue('future_earnings_offset_enabled', 'reseller_liabilities', v_liability.id, new.id, v_liability.reseller_profile_id, 'reseller', v_payload);
      elsif new.action = 'reseller_liability_recovery_applied' then
        perform public.notification_d11_enqueue('liability_recovery_applied', 'reseller_liabilities', v_liability.id, new.id, v_liability.reseller_profile_id, 'reseller', v_payload);
      elsif new.action in ('reseller_liability_waived', 'reseller_liability_platform_absorbed') then
        perform public.notification_d11_enqueue('liability_recovered', 'reseller_liabilities', v_liability.id, new.id, v_liability.reseller_profile_id, 'reseller', v_payload);
      end if;

    elsif new.target_entity_type = 'withdrawal_commission_allocations' then
      select wca.id, wca.withdrawal_id, wca.reseller_profile_id, wca.allocated_amount, wca.currency_code
      into v_allocation
      from public.withdrawal_commission_allocations wca
      where wca.id = new.target_entity_id;

      if v_allocation.id is null then
        return new;
      end if;

      if new.action = 'withdrawal_allocation_released' then
        perform public.notification_d11_enqueue(
          'withdrawal_allocation_released',
          'withdrawal_commission_allocations',
          v_allocation.id,
          new.id,
          v_allocation.reseller_profile_id,
          'reseller',
          jsonb_build_object('amount', v_allocation.currency_code || ' ' || v_allocation.allocated_amount::text, 'currency', v_allocation.currency_code, 'ctaPath', '/reseller/withdrawals')
        );
      end if;
    end if;
  exception
    when others then
      return new;
  end;

  return new;
end;
$fn$;

drop trigger if exists enqueue_d11_notifications_from_audit_log_trigger on public.audit_logs;
create trigger enqueue_d11_notifications_from_audit_log_trigger
after insert on public.audit_logs
for each row
execute function public.enqueue_d11_notifications_from_audit_log();

revoke all on function public.notification_d11_event_key(text, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.notification_d11_enqueue(text, text, uuid, uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.notification_d11_active_support_admin_profiles(uuid) from public, anon, authenticated;
revoke all on function public.notification_d11_active_finance_profiles() from public, anon, authenticated;
revoke all on function public.enqueue_d11_notifications_from_audit_log() from public, anon, authenticated;

comment on function public.enqueue_d11_notifications_from_audit_log() is
  'D11 notification-only mapper for dispute, return, refund, finance hold, reseller liability, and withdrawal review audit events. Enqueues safe outbox rows only and never mutates business state.';
