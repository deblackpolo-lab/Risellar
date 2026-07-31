# Risellar Payment Phase 1 Supplier-Reported Backend Report

## A. Summary

Implemented the development-only Pay on Delivery supplier payment reporting backend for the narrow `delivered -> payment_reported` transition. The flow lets the owning approved supplier report that Pay on Delivery cash was received after delivery, while keeping settlement verification, commission release, withdrawals, online payments, refunds, cancellation, and order completion deferred.

## B. Schema And Migration

Created forward migration:

- `supabase/migrations/20260730220000_supplier_order_payment_reported_rpc.sql`

The migration adds:

- `order_status = payment_reported`
- `payment_collection_status = supplier_reported`
- order payment report tracking columns
- `public.supplier_payment_reports` with RLS enabled and forced
- `public.supplier_report_order_payment_received(...)`
- safe-read updates for supplier and customer order views

The first development apply attempt stopped before recording the migration because the new RLS policy referenced a nonexistent helper. The migration was corrected to use the existing `public.has_admin_role('finance_staff')` admin_staff-backed helper, then dry-run and development apply succeeded.

## C. RPC Behavior

The RPC:

- requires authenticated user context
- requires active approved supplier_owner membership
- blocks admin_staff, customer, and reseller contexts from supplier reporting
- locks order, payment report, reservation, and variant rows
- only permits Pay on Delivery orders that are already delivered and still not collected
- rejects non-delivered orders and non-Pay-on-Delivery payment methods
- validates server-side financial snapshots
- creates exactly one supplier payment report
- moves order status to `payment_reported`
- moves payment status to `supplier_reported`

## D. Stock Finalization

On successful reporting, reserved stock is committed exactly once:

- stock reservation becomes `committed`
- variant reserved stock decreases by the reserved quantity
- variant sold stock increases by the same quantity
- variant total stock remains unchanged
- a `sale_committed` inventory movement is written

## E. Settlement And Commission State

The RPC creates finance obligations without completing them:

- supplier settlement row is created as `due`
- settlement remains unverified
- reseller commission row is created as `awaiting_supplier_settlement`
- commission `available_at` remains null
- commission `withdrawal_id` remains null
- reseller available balance is not increased
- no withdrawal is created

## F. Idempotency And Conflict Handling

Same-key retries return the already reported state without duplicating:

- supplier payment report
- settlement
- commission
- audit event
- stock movement
- stock decrement/increment

Conflicting retries are blocked with `CONFLICTING_RETRY`.

## G. Audit Logging

The backend writes audited events for the supplier payment report and stock/settlement effects. Boundary tests verified the payment-report audit event and the sale-committed movement. Live browser QA verified at least one payment-report audit event existed after submit.

## H. Security Protections

Protected behavior preserved:

- no service role in app/components
- no client amount, currency, settlement, commission, stock, or status inputs
- no direct client table writes
- no payment-provider integration
- no delivery-provider integration
- no order completion
- no commission release
- no withdrawal creation
- no settlement verification
- no refund/cancellation path

## I. Development Apply And Tests

Commands run:

- `npx supabase db push --dry-run` passed and showed only `20260730220000_supplier_order_payment_reported_rpc.sql`
- first `npx supabase db push` stopped on missing helper `public.current_profile_has_any_role(text[])`
- migration was fixed to use `public.has_admin_role('finance_staff')`
- `npx supabase db push --dry-run` passed again
- `npx supabase db push` succeeded against the confirmed development project
- `npx supabase db query --linked --file scripts/rpc/supplier-order-payment-reported-rpc-tests-dev-only.sql` passed
- `npx supabase db query --linked --file scripts/rpc/supplier-order-payment-reported-concurrency-tests-dev-only.sql` passed
- `git diff --check` passed
- `npm test` passed: 41 test files, 238 tests
- `npm run lint` passed
- `npm run build` passed
- `npm run typecheck` passed
- `npx tsc --noEmit` passed

## J. Boundary Assertions Passed

Verified:

- supplier_owner can report payment for own delivered Pay on Delivery order
- anonymous/customer/reseller/admin_staff contexts are blocked
- delivered/not-collected preconditions are enforced
- payment status becomes `supplier_reported`
- order status becomes `payment_reported`
- stock reservation is committed
- reserved stock decreases once
- sold stock increases once
- total stock remains unchanged
- settlement obligation is due and unverified
- reseller commission remains locked
- reseller available balance remains unchanged
- no withdrawal is created
- same-key retry is idempotent
- conflicting retry is blocked
- customer-safe read shows supplier-reported payment wording
- customer-safe read omits supplier private payment note

## K. Files Changed

- `supabase/migrations/20260730220000_supplier_order_payment_reported_rpc.sql`
- `scripts/rpc/supplier-order-payment-reported-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-payment-reported-concurrency-tests-dev-only.sql`
- `lib/orders/supplier-order-shared.ts`
- `lib/orders/supplier-order-read.ts`
- `app/supplier/orders/actions.ts`
- `app/supplier/orders/[id]/page.tsx`
- `components/supplier/supplier-order-rpc-screens.tsx`
- `tests/supplier-order-payment-reported.test.ts`
- `tests/supplier-order-ui.test.tsx`
- `docs/RISELLAR_PAYMENT_PHASE_1_SUPPLIER_REPORTED_BACKEND_REPORT.md`
- `docs/RISELLAR_PAYMENT_PHASE_1_SUPPLIER_REPORTED_UI_AND_LIVE_QA_REPORT.md`

## L. Deferred

Deferred by design:

- online payment provider integration
- settlement verification
- commission release
- reseller available-balance update
- withdrawal flow
- proof upload
- refunds/cancellations/disputes
- order completion
- delivery provider automation

## M. Status

Backend foundation passed development apply, RPC boundary tests, double-submit guard tests, full repository verification, and secret/scope scan. Safe to commit with the UI/live QA report if no new changes are introduced.

## N. Secret And Scope Scan

Confirmed:

- `.env.local` is ignored and not staged
- `supabase/.temp` is ignored
- `.next` is ignored
- `.codex-dev-server.*.log` is ignored
- no app/component service-role usage was found
- no checkout/order/payment-provider/delivery-provider/withdrawal integration references were added in app/components/lib
- broad secret-like hits were documentation/test guard strings, env var names, and server-only token handling references, not committed secret values
- production Supabase was not used
