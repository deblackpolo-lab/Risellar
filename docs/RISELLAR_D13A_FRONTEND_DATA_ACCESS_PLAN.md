# Risellar D13-A Frontend Data Access Plan

Date: 2026-08-02

## Summary

D13 UI pages must call existing role-specific RPCs through server-only helpers and pass safe DTOs to client components. Direct table reads and service-role clients are out of scope for frontend routes.

## Data Access Rules

- Server components load safe-read DTOs.
- Server actions call mutation RPCs with signed-in user context.
- Client components receive only role-safe fields.
- Idempotency keys are generated in server actions or form helpers and reused for retries.
- Revalidation happens after successful mutation only.
- Stale-state errors must map to role-safe copy.
- RPC errors must not expose SQL, table names, IDs, or internal notes in the browser.

## Planned Route Contracts

| Route group | Safe reads | Mutations |
| --- | --- | --- |
| /customer/disputes | list_customer_disputes_safe, get_customer_dispute_safe | customer_open_order_dispute, customer_add_dispute_response |
| /customer/returns | list_customer_returns_safe, get_customer_return_safe | customer_request_item_return, customer_mark_return_in_transit |
| /customer/refunds | list_customer_refunds_safe, get_customer_refund_safe | customer_confirm_refund_received |
| /supplier/disputes | list_supplier_disputes_safe, get_supplier_dispute_safe | supplier_add_dispute_response |
| /supplier/returns | list_supplier_returns_safe, get_supplier_return_safe | supplier_confirm_return_received, supplier_report_return_condition |
| /supplier/refunds | list_supplier_refunds_safe, get_supplier_refund_safe | supplier_report_refund_sent |
| /reseller/liabilities | get_reseller_liability_impact_safe, list_reseller_liabilities_safe | None in D13 UI except existing withdrawal request controls |
| /admin/disputes | list_admin_disputes_safe, get_admin_dispute_safe | admin_assign_dispute, admin_request_dispute_information, admin_change_dispute_status, admin_close_dispute |
| /admin/returns | list_admin_returns_safe, get_admin_return_safe | admin_approve_return, admin_reject_return, admin_accept_return, admin_decline_return, admin_complete_return |
| /admin/refunds | list_support_refunds_safe, list_finance_refunds_safe, get_customer_refund_safe where role-safe, get_supplier_refund_safe where role-safe | admin_approve_refund_obligation, admin_report_platform_refund_sent, admin_verify_refund_report, admin_reject_refund_report, admin_complete_refund |
| /admin/finance-holds | list_finance_holds_safe, get_finance_hold_safe | finance_create_dispute_hold, finance_release_dispute_hold, finance_cancel_dispute_hold, finance_hold_reseller_commission, finance_release_reseller_commission_hold |
| /admin/liabilities | list_finance_reseller_liabilities_safe | finance_approve_reseller_liability, finance_waive_reseller_liability, finance_absorb_reseller_liability, finance_mark_withdrawal_allocation_disputed, finance_release_withdrawal_allocation |
| /admin/withdrawals | Existing withdrawal safe reads | Existing admin_mark_reseller_withdrawal_paid |

## DTO Boundaries

Customer DTOs may show:

- customer-safe order reference
- public product snapshot
- public status labels
- customer messages
- customer-visible return/refund next action

Supplier DTOs may show:

- supplier-owned item slice
- supplier action requirements
- public customer-safe delivery context only where existing order safe reads allow it
- supplier private notes only to supplier

Reseller DTOs may show:

- commission impact status
- liability/recovery status
- wallet impact labels
- safe product/order reference

Support DTOs may show:

- operational case context
- public party messages
- internal support notes
- assignment/status controls
- no finance-only mutation fields

Finance DTOs may show:

- refund obligations and cap-safe amounts
- finance holds
- liability/recovery records
- settlement and withdrawal review data
- no arbitrary override fields

## Loading, Empty, And Error States

Every planned route needs:

- loading state that does not flash private data
- empty state scoped to the signed-in role
- not-found for unauthorized or missing records
- stale-state copy for already-transitioned cases
- retry-safe action results

