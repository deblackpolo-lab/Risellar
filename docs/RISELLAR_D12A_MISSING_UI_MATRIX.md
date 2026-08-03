# Risellar D12-A Missing UI Matrix

Date: 2026-08-03

## Purpose

Track D12/D13 dispute, return, refund, and support UI gaps as backend-verified workflow slices are activated in the browser.

## Customer Disputes

Status: **D13-B local implementation and authenticated browser QA complete; final verification, commit, push, and production smoke pending.**

Routes:

- `/customer/disputes`
- `/customer/disputes/[id]`
- `/customer/orders/[id]/report-problem`
- `/customer/orders/[id]/report-issue` redirects to report-problem

Connected RPCs:

- `list_customer_disputes_safe`
- `get_customer_dispute_safe`
- `customer_open_order_dispute`
- `customer_add_dispute_response`
- `list_customer_order_items_for_dispute_safe`

Remaining:

- Final verification and security scan.
- Commit, push, and production smoke.

## Remaining Mock/Pending Route Groups

- Customer returns/refunds.
- Supplier disputes/returns/refunds.
- Admin/support disputes.
- Admin returns/refunds/finance holds/liabilities.
- Reseller liability and withdrawal-review UI follow-ups.

## Scope Guard

No refund, return, evidence upload, payment, stock, delivery, settlement, commission, withdrawal, or notification mutation should be activated by D13-B.
