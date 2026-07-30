# Risellar Checkout Phase C C5 Reservation Status RPC Fix Report

## A. Executive Summary

The customer-safe order read RPC failed at runtime because it compared `public.reservation_status` to a nonexistent enum value, `cancelled`. A forward migration corrected the customer-facing reservation label mapping without changing ownership checks, return shape, stock behavior, order creation, payment, delivery, supplier preparation, or finance flows.

## B. Baseline Commit And Branch

- Baseline commit: `43133e649e0f9a060389cc602e978239c16dcb01`
- Branch: `main`

## C. Applied Original C5 Migration Status

`20260730120000_customer_order_safe_read_rpc.sql` was already applied to the confirmed development Supabase project.

## D. Exact RPC Failure

The development-only boundary test reached `public.get_customer_order_safe(uuid)` and failed with an invalid enum input error for `reservation_status = 'cancelled'`.

## E. Actual Reservation Status Enum Values

`public.reservation_status` values:

- `pending`
- `reserved`
- `committed`
- `released`
- `expired`
- `failed`

The enum is used by `public.stock_reservations.reservation_status`. It does not include `cancelled`.

## F. Root Cause

The RPC returned a text label, but its `CASE sr.reservation_status` branch included `when 'cancelled'`. PostgreSQL coerced that literal to `public.reservation_status`, causing runtime failure before the read result could be returned.

## G. Correct Customer-Safe Mapping

The corrected mapping uses only actual enum values:

- `reserved`: Stock reserved for this order
- `pending`: Stock reservation pending
- `released`: Stock reservation released
- `committed`: Stock reservation committed
- `expired`: Stock reservation expired
- `failed`: Stock reservation failed
- null/other: Stock reservation unavailable

## H. Forward Corrective Migration

Created and applied:

- `supabase/migrations/20260730121000_fix_customer_order_safe_read_reservation_status.sql`

The migration recreates only `public.get_customer_order_safe(uuid)` with the same return shape, security-definer behavior, explicit search path, customer-only ownership checks, active admin_staff block, missing-order no-row behavior, and internal-field exclusions.

## I. RPC Return-Shape Compatibility

The function still returns the same `RETURNS TABLE` contract. TypeScript helper expectations did not need to change.

## J. SQL Test Changes

The development-only test harness keeps the earlier corrections:

- no `address_status` fixture column
- active address uses `deleted_at is null`
- metadata assertion uses `pg_catalog.pg_proc`

No ownership, field-leak, or no-side-effect assertion was weakened.

## K. Dry-Run Result

Dry-run for `20260730121000_fix_customer_order_safe_read_reservation_status.sql` passed and showed only that migration pending.

Dry-run for `20260730122000_revoke_anon_customer_order_safe_read.sql` passed and showed only that migration pending.

## L. Apply Result

Both forward migrations applied successfully to the confirmed development Supabase project.

## M. Boundary-Test Result

`npx supabase db query --linked --file scripts/rpc/customer-order-safe-read-rpc-tests-dev-only.sql` passed. Every returned assertion had `passed=true`.

## N. Ownership/Role Results

- customer can read own order
- customer cannot read another customer's order
- reseller is blocked
- supplier_owner is blocked
- active admin_staff is blocked
- anonymous execution is blocked
- missing order does not leak existence

## O. Field-Leak Results

The safe read output did not expose supplier base price, platform margin, reseller margin/cost, commission, settlement due amount, internal/admin/risk fields, or raw participant/product linkage IDs.

## P. Reservation Result

The live RPC no longer contains the invalid reservation `cancelled` branch. It contains the `failed` branch and returned `Stock reserved for this order` for the fixture reservation.

## Q. No-Side-Effect Result

The read flow created no new order, order item, stock reservation, delivery quote, commission, settlement, or withdrawal.

## R. Fixture Cleanup

Marker-scoped aggregate checks returned zero rows for profiles, customers, addresses, suppliers, resellers, products, variants, listings, drafts, orders, order items, stock reservations, audit fixtures, delivery quotes, commissions, settlements, and withdrawals.

## S. Application Verification

- `git diff --check`: passed
- `npm test`: passed, 31 files and 165 tests
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed

## T. Security/Privacy Scan

No production project was used. No sensitive identifiers, private row IDs, credentials, tokens, cookies, or environment values were added to docs or source. `.env.local`, `.local-recovery`, `.next`, `supabase/.temp`, and local dev-server logs are ignored and unstaged. No service-role imports exist in `app/` or `components/`. No application UI was changed.

## U. Files Changed

- `scripts/rpc/customer-order-safe-read-rpc-tests-dev-only.sql`
- `supabase/migrations/20260730121000_fix_customer_order_safe_read_reservation_status.sql`
- `supabase/migrations/20260730122000_revoke_anon_customer_order_safe_read.sql`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C5_CUSTOMER_ORDER_READ_BOUNDARY_REPORT.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C5_SAFE_READ_TEST_FIX_REPORT.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C5_RESERVATION_STATUS_RPC_FIX_REPORT.md`

## V. Current Git Status

The C5-B1 files are modified/untracked and not staged. Pre-existing supplier/package/type-config entries remain visible in `git status` and were not changed for this task.

## W. Whether C5 Is Fully Complete

C5 is fully complete at the customer-safe order read boundary level.

## X. Whether Files Are Safe To Commit

Yes, the C5-B1 corrected test harness, forward migrations, and reports are safe to commit when explicitly requested.

## Y. Whether C6 May Begin

C6 may begin after this C5-B1 fix set is committed and pushed.

## Z. Exact Recommended Next Step

Commit and push the C5-B1 reservation-status RPC fix, anon grant hardening, corrected boundary test, and reports. Then begin Checkout Phase C C6.
