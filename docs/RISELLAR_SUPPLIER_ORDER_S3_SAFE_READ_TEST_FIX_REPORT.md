# Risellar Supplier Order S3 Safe Read Test Fix Report

## A. Executive Summary

Fixed a development-only supplier order safe-read RPC boundary test fixture mismatch against the current `public.checkout_drafts` schema. The fix updates only the SQL test harness. The supplier order read RPCs, migrations, RLS policies, application source, supplier order UI, and supplier accept/reject behavior were not changed.

The corrected boundary test was rerun once against the confirmed DEVELOPMENT Risellar Supabase project and passed with every returned assertion marked `passed=true`.

## B. Baseline Commit and Branch

- Baseline commit: `7ad9dd7fa422617883efdf02511bdec93c3a0ecc`
- Branch: `main`
- Staged files at precheck: none
- Existing visible supplier/package/type-config entries still had no content diff.

## C. Applied S2 Migration Status

`supabase/migrations/20260730130000_supplier_order_safe_read_rpc.sql` was already applied to the confirmed DEVELOPMENT Risellar Supabase project before this focused fix. Migration history was not modified, repaired, or reset.

## D. Original SQL Boundary-Test Error

The first S2/S3 boundary test run failed during fixture setup before meaningful assertions:

```text
ERROR: 42703: column "final_customer_price_amount" of relation "checkout_drafts" does not exist
```

## E. Actual checkout_drafts Schema

Live schema inspection confirmed `public.checkout_drafts` includes:

- primary key: `id uuid`
- customer references: `customer_id uuid`, `customer_profile_id uuid`
- reseller/listing references: `reseller_product_id uuid`, `reseller_id uuid`, `shop_id uuid`
- supplier/product references: `supplier_id uuid`, `product_id uuid`, `variant_id uuid`
- quantity/status: `quantity integer`, `draft_status text`
- product snapshots: `product_name_snapshot`, `product_slug_snapshot`, `product_description_snapshot`, `product_category_snapshot`, `product_brand_snapshot`, `product_image_snapshot`
- price snapshots: `final_customer_price_snapshot_amount numeric`, `line_total_snapshot_amount numeric`, `currency_code text`
- contact/address snapshots: `customer_contact_snapshot`, `delivery_address_id`, `delivery_address_snapshot`, `public_listing_snapshot`
- lifecycle fields: `created_at`, `updated_at`, `abandoned_at`, `deleted_at`, `converted_order_id`, `converted_at`

The live status constraint allows `draft`, `review_pending`, `abandoned`, and `converted`.

## F. Canonical Draft Price Fields

The canonical storage fields are:

- unit final customer price: `final_customer_price_snapshot_amount`
- total customer line price: `line_total_snapshot_amount`

The names `final_customer_price_amount` and `line_total_amount` are checkout draft RPC return aliases, not table columns.

## G. Root Cause

The supplier order safe-read SQL fixture copied RPC return alias names into a direct `public.checkout_drafts` fixture insert. It also omitted the current required `customer_profile_id` column. This caused a fixture/schema mismatch before supplier order read assertions could run.

## H. Test-Harness Fix

Updated `scripts/rpc/supplier-order-safe-read-rpc-tests-dev-only.sql` to:

- include `customer_profile_id` in the checkout draft fixture insert
- replace `final_customer_price_amount` with `final_customer_price_snapshot_amount`
- replace `line_total_amount` with `line_total_snapshot_amount`
- preserve fake development-only fixture data
- preserve rollback-based cleanup
- preserve all supplier ownership, role, safe-field, privacy, pagination, and no-side-effect assertions

## I. Other Schema-Drift Findings

The broader fixture audit found no additional required changes after the checkout draft fixture corrections. Remaining `line_total_amount` usage is valid on `public.order_items`, and the `supplier_confirmed` string remains intentional as an invalid-status filter assertion.

## J. RPC Changes Made Or Not Made

No RPC changes were made. `public.list_supplier_orders_safe(...)` and `public.get_supplier_order_safe(uuid)` remain unchanged.

## K. Migration Changes Made Or Not Made

No migration was created, edited, applied, repaired, or reset in this task.

## L. Boundary-Test Result

`npx supabase db query --linked --file scripts/rpc/supplier-order-safe-read-rpc-tests-dev-only.sql` passed. Every returned assertion had `passed=true`.

## M. Supplier Ownership Result

Passed:

- active approved supplier owner can list own orders
- active approved supplier owner can read own order detail

## N. Cross-Supplier Isolation Result

Passed:

- supplier cannot list another supplier's order
- supplier cannot read another supplier's order detail

## O. Cross-Role Results

Passed:

- customer blocked
- reseller blocked
- active `admin_staff` profile blocked from supplier-safe contract
- anonymous blocked

## P. Safe-Field Result

Passed. List and detail RPCs returned supplier-safe operational fields such as order status labels, product snapshot, quantity, supplier expected amount, currency, Pay on Delivery/payment labels, reservation labels, fulfilment preview/detail fields, and reseller shop name/slug where appropriate.

## Q. Privacy/Field-Leak Result

Passed. The assertions confirmed customer email/account metadata, reseller private contact, supplier/product/listing linkage ids, platform margin, reseller margin, commission, settlement, risk/admin notes, raw stock totals, payment-provider references, and delivery-provider references were absent.

## R. Pagination/Filter Result

Passed. Limit enforcement worked and the invalid status filter was blocked safely.

## S. No-Side-Effect Result

Passed. The read flow created no order, order item, stock reservation, or inventory movement; changed no stock or order status; and created no payment, delivery, preparation, settlement, commission, withdrawal, or refund side effect.

## T. Fixture-Cleanup Result

Marker-scoped cleanup verification returned zero remaining fixture rows for:

- profiles
- suppliers
- customers
- customer delivery addresses
- resellers
- reseller shops
- products
- variants
- reseller listings
- checkout drafts
- orders
- order items
- stock reservations
- audit fixtures
- delivery quotes
- settlements
- commissions
- withdrawals

## U. Application Verification

- `git diff --check`: passed, with only the normal Windows line-ending warning.
- `npm test`: passed, 33 files and 178 tests.
- `npm run lint`: passed.
- `npm run build`: passed, 168 routes generated.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## V. Security/Privacy Scan

- `.env.local`: ignored and not staged.
- `.local-recovery`: ignored and not staged.
- `.next`: ignored and not staged.
- `supabase/.temp`: ignored and not staged.
- `.codex-dev-server.*.log`: ignored and not staged.
- Temporary SQL/output files were not staged.
- No credentials, connection strings, project identifiers, private row identifiers, JWTs, cookies, access tokens, database passwords, or environment values were added.
- No service-role imports were found in `app/` or `components/`.
- No production Supabase project was accessed.
- No supplier order UI, accept/reject, stock release, payment, delivery, preparation, settlement, commission, withdrawal, or refund implementation was added.

## W. Files Changed

- `scripts/rpc/supplier-order-safe-read-rpc-tests-dev-only.sql`
- `docs/RISELLAR_SUPPLIER_ORDER_S2_SAFE_READ_BACKEND_FOUNDATION_REPORT.md`
- `docs/RISELLAR_SUPPLIER_ORDER_S3_SAFE_READ_TEST_FIX_REPORT.md`

## X. Current Git Status

The working tree has the S3 test harness/report changes above plus pre-existing metadata/no-content-diff visible entries in supplier/package/type-config files. Nothing is staged.

## Y. Whether S2/S3 Is Fully Complete

Yes. The S2 migration is applied to development, the S3 fixture/schema mismatch is fixed, and the development-only supplier order safe-read boundary test passed.

## Z. Whether Files Are Safe To Commit

Yes, when explicitly requested. Commit only the corrected SQL test harness and the two supplier order reports.

## AA. Whether S4 May Begin

Yes, after the S3 fix/report commit boundary is handled. S4 should not be mixed into this uncommitted test-fix work.

## AB. Exact Recommended Next Step

Commit the Supplier Order Handling S3 safe-read test fix and reports, then begin Supplier Order Handling S4 in a separate scoped task.
