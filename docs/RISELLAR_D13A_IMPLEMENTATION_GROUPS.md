# Risellar D13-A Implementation Groups

Date: 2026-08-02

## D13-B - Customer Disputes UI

Status: source implementation, safe item selector migration, focused automated tests, SQL boundary tests, and authenticated customer browser QA completed locally; final verification, commit, push, and production smoke are still pending.

Routes:

- /customer/disputes
- /customer/disputes/[id]
- /customer/orders/[id]/report-issue
- /customer/orders/[id]/report-problem

RPCs:

- list_customer_disputes_safe
- get_customer_dispute_safe
- customer_open_order_dispute
- customer_add_dispute_response
- list_customer_order_items_for_dispute_safe

Tests:

- customer list/detail ownership
- report-problem validates required fields
- no supplier/admin/private fields
- unauthenticated blocked

Stop conditions:

- direct table mutation
- refund, payment, stock, settlement, commission, withdrawal, or notification mutation

Implementation notes:

- `/customer/orders/[id]/report-issue` redirects to the real `/customer/orders/[id]/report-problem` route.
- Item-specific browser reasons use the safe customer-owned order item selector.
- Supplier targeting remains backend-derived by the D5-A `customer_open_order_dispute` RPC.

## D13-C - Customer Returns And Refunds UI

Routes:

- /customer/returns
- /customer/returns/[id]
- /customer/refunds
- /customer/refunds/[id]
- /customer/orders/[id]/return-request
- /customer/orders/[id]/refund-status

RPCs:

- list_customer_returns_safe
- get_customer_return_safe
- customer_request_item_return
- customer_mark_return_in_transit
- list_customer_refunds_safe
- get_customer_refund_safe
- customer_confirm_refund_received

Stop conditions:

- customer sets refund amount
- customer changes payment/order/stock records directly

## D13-D - Supplier Disputes UI

Routes:

- /supplier/disputes
- /supplier/disputes/[id]

RPCs:

- list_supplier_disputes_safe
- get_supplier_dispute_safe
- supplier_add_dispute_response

Stop conditions:

- cross-supplier record exposure
- supplier final-resolves a dispute

## D13-E - Supplier Returns And Refunds UI

Routes:

- /supplier/returns
- /supplier/returns/[id]
- /supplier/refunds
- /supplier/refunds/[id]

RPCs:

- list_supplier_returns_safe
- get_supplier_return_safe
- supplier_confirm_return_received
- supplier_report_return_condition
- list_supplier_refunds_safe
- get_supplier_refund_safe
- supplier_report_refund_sent

Stop conditions:

- supplier self-approves refunds or bypasses finance verification

## D13-F - Support/Admin Disputes UI

Routes:

- /admin/disputes
- /admin/disputes/[id]

RPCs:

- list_admin_disputes_safe
- get_admin_dispute_safe
- admin_assign_dispute
- admin_request_dispute_information
- admin_change_dispute_status
- admin_close_dispute

Stop conditions:

- support_staff gets finance mutation authority
- mock data remains on activated routes

## D13-G - Admin Return Management UI

Routes:

- /admin/returns
- /admin/returns/[id]

RPCs:

- list_admin_returns_safe
- get_admin_return_safe
- admin_approve_return
- admin_reject_return
- admin_accept_return
- admin_decline_return
- admin_complete_return

Stop conditions:

- arbitrary set-status UI
- direct table writes

## D13-H - Finance Refund And Hold UI

Routes:

- /admin/refunds
- /admin/refunds/[id]
- /admin/finance-holds
- /admin/finance-holds/[id]
- /admin/liabilities
- /admin/liabilities/[id]

RPCs:

- list_finance_refunds_safe
- admin_approve_refund_obligation
- admin_report_platform_refund_sent
- admin_verify_refund_report
- admin_reject_refund_report
- admin_complete_refund
- list_finance_holds_safe
- get_finance_hold_safe
- finance_create_dispute_hold
- finance_release_dispute_hold
- finance_cancel_dispute_hold
- list_finance_reseller_liabilities_safe
- finance_approve_reseller_liability
- finance_waive_reseller_liability
- finance_absorb_reseller_liability

Stop conditions:

- support-only user can mutate finance state
- refund caps or idempotency checks bypassed

## D13-I - Reseller Liability And Withdrawal-Review UI

Routes:

- /reseller/liabilities
- /reseller/liabilities/[id]
- existing /reseller/wallet
- existing /reseller/withdrawals

RPCs:

- get_reseller_liability_impact_safe
- list_reseller_liabilities_safe
- existing withdrawal safe-read RPCs

Stop conditions:

- false per-commission withdrawal allocation
- private settlement/payout fields shown

## D13-J - Navigation, Responsive States, Errors, Deployment, Browser QA

Scope:

- role-scoped navigation items
- mobile layouts
- empty/error/stale states
- route sweeps
- browser QA by role
- production smoke after deployment

Commit boundary:

- one commit after all route groups pass local verification and safe development browser QA
