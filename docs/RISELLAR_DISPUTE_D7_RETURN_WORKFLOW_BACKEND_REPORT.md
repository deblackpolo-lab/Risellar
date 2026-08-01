# Risellar Dispute D7 Return Workflow Backend Report

## Summary

D7 adds a backend-only return workflow foundation for dispute-linked order items in the confirmed DEVELOPMENT Risellar Supabase project.

Implemented:

- `public.order_item_returns`
- `public.return_actions`
- customer return request RPC
- admin approve/reject RPCs
- customer in-transit RPC
- supplier receive and condition-report RPCs
- admin accept/decline/complete RPCs
- customer, supplier, admin, and reseller-safe read RPCs

No return UI was activated. Dormant Phase 13 return pages remain mock/dormant. Checkout, refunds, payment, delivery, settlement, commission, wallet, withdrawal, stock, reservation, evidence, and notification flows were not connected or mutated.

## Migrations Applied

Applied to DEVELOPMENT:

- `20260801170000_return_workflow_backend_foundation.sql`
- `20260801171000_fix_return_workflow_status_history_reason.sql`
- `20260801172000_fix_return_workflow_idempotency_column_ambiguity.sql`

The two patch migrations are forward-only runtime fixes:

- status-history reason alignment maps return request status history to the existing `return_review` reason code
- PL/pgSQL idempotency checks qualify `return_actions` columns to avoid ambiguity with `RETURNS TABLE` output names

## Legacy Returns Table

The existing `public.returns` table was classified as incompatible with D7 because it mixes refund-adjacent statuses and evidence fields and uses a different enum. It remains untouched and dormant.

D7 uses the narrower `public.order_item_returns` table so return state can be tracked without implying refund execution, stock restock, delivery booking, or finance action.

## RPCs

Mutation RPCs:

- `customer_request_item_return`
- `admin_approve_return`
- `admin_reject_return`
- `customer_mark_return_in_transit`
- `supplier_confirm_return_received`
- `supplier_report_return_condition`
- `admin_accept_return`
- `admin_decline_return`
- `admin_complete_return`

Safe reads:

- `list_customer_returns_safe`
- `get_customer_return_safe`
- `list_supplier_returns_safe`
- `get_supplier_return_safe`
- `list_admin_returns_safe`
- `get_admin_return_safe`
- `get_reseller_return_impact_safe`

All direct table grants remain revoked from `public`, `anon`, and `authenticated`. Browser roles receive execute grants only on controlled RPCs.

## Verification

`scripts/rpc/return-workflow-backend-tests-dev-only.sql` passed in DEVELOPMENT with more than 77 active assertions.

Verified:

- anonymous access blocked
- customer can request own item-scoped eligible return
- customer cannot request another customer's return
- item-scoped dispute requirement enforced
- return quantity bounded by order-item quantity
- same-key retries idempotent
- same-key/different-payload conflicts
- duplicate active return for the same dispute item is not duplicated
- support/admin/super admin review authority uses active `admin_staff`
- finance-only admin blocked
- supplier owner can receive and inspect only own supplier returns
- supplier inventory manager cannot act as supplier owner
- customer/supplier/admin/reseller safe reads are scoped
- direct table writes blocked
- audit rows created without note bodies

## Regression

Relevant regression suites passed after D7:

- D7 SQL boundary test
- D7 two-session concurrency harness
- D6 admin investigation SQL boundary test
- D6 two-session concurrency harness
- D5 supplier response SQL boundary test
- D4 customer dispute SQL boundary test

The D4 dev-only harness required a test-fixture refresh for the already-current D5-A seven-argument `customer_open_order_dispute` signature and target-shape trigger. No D4 RPC or policy was changed.

## Current Boundary

D7 records return workflow intent, review, receipt, inspection, inventory-outcome recommendation, acceptance/decline, and completion only.

It does not:

- create refund rows
- issue provider refunds
- create finance holds
- mutate settlements, commissions, wallets, or withdrawals
- mutate orders or order items
- mutate stock/reservations/product variant counters
- create delivery provider jobs
- create evidence rows/uploads
- create notification outbox rows
- activate UI/routes/forms/buttons

Safe to plan D8 refund-obligation backend next: yes, as a separate phase.
