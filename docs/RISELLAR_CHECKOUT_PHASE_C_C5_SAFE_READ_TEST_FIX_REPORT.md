# Risellar Checkout Phase C C5 Safe Read Test Fix Report

## A. Executive Summary

The C5 development-only customer order safe-read boundary test was corrected for two test-harness drift issues. No application UI, C6 confirmation flow, order creation, payment, delivery, supplier preparation, commission, settlement, withdrawal, refund, RLS, or customer-safe RPC authorization behavior was weakened.

## B. Baseline Commit And Branch

- Baseline commit: `43133e649e0f9a060389cc602e978239c16dcb01`
- Branch: `main`

## C. Applied C5 Migration Status

The original C5 migration, `20260730120000_customer_order_safe_read_rpc.sql`, was already applied to the confirmed development Supabase project before this fix report.

## D. First Test-Harness Defect

The test inserted into `customer_delivery_addresses.address_status`, but the actual table has no `address_status` column. Active addresses are represented by `deleted_at is null`; default address behavior uses `is_default`.

Fix applied:

- removed `address_status` from the fixture insert
- kept the fixture address owned by the intended fake customer
- kept `is_default = true`
- relied on `deleted_at` defaulting to null

## E. Second Test-Harness Defect

The test queried `information_schema.routine_columns`, which does not exist in PostgreSQL. The assertion was intended to verify the safe RPC return shape.

Fix applied:

- replaced the invalid metadata lookup with `pg_catalog.pg_proc`
- targeted the exact function signature `p_order_id uuid`
- inspected `proargnames` and `proargmodes`
- limited return-shape checks to output/table argument modes

## F. Actual RPC Return-Contract Metadata

`public.get_customer_order_safe(p_order_id uuid)` returns a set of table columns including order labels, product snapshot fields, quantity, final customer price, totals, currency, customer contact/address snapshots, safe shop display values, and reservation label/expiry.

## G. Corrected Metadata Assertion

The corrected SQL test asserts:

- the exact read RPC signature exists
- the RPC returns a set
- every expected customer-safe output column is declared
- forbidden internal/commercial columns are not declared

## H. Other Schema/Metadata Drift Findings

The corrected script no longer references `address_status` or `information_schema.routine_columns`. The next failure after those fixes was a live RPC enum comparison defect, not a test-harness metadata defect.

## I. RPC Changes Made Or Not Made

No RPC changes were made as part of the test-harness fixes. The later reservation-status defect was corrected separately by forward migration.

## J. Migration Changes Made Or Not Made

No existing migration was edited. No migration was created solely for the test-harness fixes.

## K. Boundary-Test Result

After the reservation-status RPC fix and grant hardening, the development-only C5 boundary test passed. Every returned assertion had `passed=true`.

## L. Ownership/Role Results

- customer can read own order
- customer cannot read another customer's order
- reseller is blocked
- supplier_owner is blocked
- active admin_staff is blocked from the customer route boundary
- anonymous execution is blocked
- missing order does not leak existence

## M. Field-Leak Results

The test confirmed internal fields remain absent, including supplier base price, platform margin, reseller margin/cost, settlement due amount, commission, risk/admin notes, and raw linkage IDs.

## N. No-Side-Effect Results

The read test created no additional order, order item, stock reservation, delivery quote, commission, settlement, or withdrawal.

## O. Fixture Cleanup

Marker-scoped aggregate checks returned zero fixtures after the test rollback.

## P. Application Verification

- `git diff --check`: passed
- `npm test`: passed, 31 files and 165 tests
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed

## Q. Security/Privacy Scan

Ignored and unstaged: `.env.local`, `.local-recovery`, `.next`, `supabase/.temp`, and local dev-server logs. No service-role imports were found in `app/` or `components/`. No production project was used. No credentials or private identifiers were added.

## R. Files Changed

- `scripts/rpc/customer-order-safe-read-rpc-tests-dev-only.sql`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C5_CUSTOMER_ORDER_READ_BOUNDARY_REPORT.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C5_SAFE_READ_TEST_FIX_REPORT.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C5_RESERVATION_STATUS_RPC_FIX_REPORT.md`
- `supabase/migrations/20260730121000_fix_customer_order_safe_read_reservation_status.sql`
- `supabase/migrations/20260730122000_revoke_anon_customer_order_safe_read.sql`

## S. Current Git Status

The task files are modified/untracked and not staged. Pre-existing supplier/package/type-config entries remain visible in `git status` with no meaningful content diff.

## T. Whether C5 Is Fully Complete

C5 is complete at the customer-safe read-boundary level after the corrected boundary test passed.

## U. Whether Files Are Safe To Commit

Yes, the corrected test script, forward migrations, and reports are safe to commit when explicitly requested.

## V. Whether C6 May Begin

C6 may begin after these C5-B1 corrective files are committed.

## W. Exact Recommended Next Step

Commit the C5-B1 reservation-status RPC fix, grant hardening migration, corrected boundary test harness, and reports. Then begin Checkout Phase C C6 only after that commit is pushed.
