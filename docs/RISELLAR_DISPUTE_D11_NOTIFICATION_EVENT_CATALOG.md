# Risellar Disputes D11 Notification Event Catalog

## Summary

D11 adds notification coverage for the disputes, returns, refunds, finance hold, reseller liability, and withdrawal review workflows. Events reuse the existing durable email outbox, processor, redirect-mode sender, retry handling, and Resend webhook path.

No D11 UI was activated. No email is sent directly from SQL. The database mapper only enqueues safe notification work from trusted audit-log events.

## Recipient Roles

- `customer`: order-owning customer profile
- `supplier`: affected supplier profile only
- `reseller`: attributed reseller profile only
- `support_admin`: active support-capable admin staff
- `finance_admin`: active finance staff or super admin only

Recipient email addresses are resolved server-side by the existing notification processor through verified Clerk primary email lookup. Recipient emails are not stored in notification payloads.

## Customer Events

- `dispute_opened_customer`
- `dispute_information_requested_customer`
- `dispute_status_updated_customer`
- `dispute_resolved_customer`
- `dispute_closed_customer`
- `return_requested_customer`
- `return_approved_customer`
- `return_rejected_customer`
- `return_received_customer`
- `return_accepted_customer`
- `return_declined_customer`
- `return_completed_customer`
- `refund_approved_customer`
- `refund_reported_sent_customer`
- `refund_customer_confirmation_required`
- `refund_verified_customer`
- `refund_completed_customer`

Customer CTAs use the nearest safe customer order route until dedicated dispute, return, and refund detail routes are activated.

## Supplier Events

- `dispute_opened_supplier`
- `dispute_information_requested_supplier`
- `dispute_status_updated_supplier`
- `dispute_resolved_supplier`
- `return_requested_supplier`
- `return_approved_supplier`
- `return_in_transit_supplier`
- `return_received_supplier`
- `return_inspection_required_supplier`
- `return_completed_supplier`
- `refund_obligation_supplier`
- `refund_report_required_supplier`
- `refund_customer_disputed_not_received_supplier`
- `refund_verified_supplier`
- `supplier_liability_created`
- `supplier_liability_updated`

Supplier notifications route only to the affected supplier owner profile. Order-wide multi-supplier disputes do not fan out to every supplier.

## Reseller Events

- `dispute_affecting_commission_reseller`
- `commission_hold_created_reseller`
- `commission_hold_released_reseller`
- `reseller_liability_review_created`
- `reseller_liability_approved`
- `future_earnings_offset_enabled`
- `liability_recovery_applied`
- `liability_recovered`
- `withdrawal_blocked_by_finance_review`
- `withdrawal_allocation_released`
- `withdrawal_ready_after_review`

Reseller notifications use wallet or withdrawal routes and expose only safe status or allowed amount context.

## Support/Admin Events

- `new_dispute_admin`
- `dispute_response_received_admin`
- `dispute_information_received_admin`
- `return_requested_admin`
- `return_received_admin`
- `return_inspected_admin`
- `refund_customer_disputed_not_received_admin`
- `refund_reported_sent_admin`

Support/admin events are queue or action notifications only. They do not expose raw private notes, account references, or provider payloads.

## Finance Admin Events

- `refund_approval_required_finance`
- `refund_reported_sent_finance`
- `refund_customer_disputed_not_received_finance`
- `refund_verification_required_finance`
- `finance_hold_created_finance`
- `settlement_blocked_finance`
- `commission_hold_created_finance`
- `reseller_liability_review_finance`
- `withdrawal_blocked_finance`

Finance notifications route only to active `finance_staff` or `super_admin` admin staff.

## Event Keys

D11 event keys use:

`<notification_type>:<business_entity_id>:<audit_log_id>:<recipient_role>`

This keeps retries stable, separates intended recipient roles, and prevents duplicate outbox rows for repeated mapper execution.
