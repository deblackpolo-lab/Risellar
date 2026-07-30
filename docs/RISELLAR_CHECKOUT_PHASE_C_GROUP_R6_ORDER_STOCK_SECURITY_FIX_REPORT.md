# Risellar Checkout Phase C Group R6 Order Stock Security Fix Report

## A. Executive summary

R6 diagnosed the four failed Phase C order-creation RPC boundary assertions after the R5 DEVELOPMENT apply. The RPC stock reservation path was functioning, but the test harness read supplier-only stock rows from customer context. The commercial-snapshot mutation assertion was also a harness issue: the customer `UPDATE` affected zero rows, but the helper treated a non-throwing zero-row update as success.

R6 added a forward security hardening migration to revoke direct write privileges on checkout-created order/stock commercial tables, updated the development-only boundary test harness, applied the corrective migration to DEVELOPMENT, and reran the boundary test successfully.

Final checkout confirmation remains disabled. No production project, migration repair, stale Claude RPC, payment, delivery, supplier-preparation, commission, settlement, withdrawal, or refund flow was used or implemented.

## B. Baseline commit and branch

- Baseline commit: `b94dcadb6afa933e9bb91f8c933a38d7353ecd0e`
- Branch: `main`
- Existing supplier/package/tsconfig status entries remained metadata/no-content-diff entries.

## C. Root causes

- Stock failures: test harness context mismatch.
- Duplicate/idempotency stock failure: same stock visibility issue.
- Insufficient-stock baseline failure: same stock visibility issue.
- Commercial-snapshot failure: zero-row RLS-blocked update was treated as an unexpected success.
- Security hardening need: direct write grants on Phase C order/stock tables were broader than the approved boundary, even though RLS blocked the specific customer snapshot mutation.

## D. Post-failure fixture state

Aggregate post-failure checks found zero test profiles, products, listings, drafts, orders, order items, stock reservations, and related audit fixture rows. No manual fixture deletion was performed.

## E. Corrective migration

Created and applied to DEVELOPMENT:

- `supabase/migrations/20260718214000_fix_phase_c_order_stock_security.sql`

The migration revokes direct `insert`, `update`, `delete`, and `truncate` privileges from `anon` and `authenticated` on:

- `public.orders`
- `public.order_items`
- `public.stock_reservations`
- `public.product_variants`

It keeps controlled writes inside audited SECURITY DEFINER RPCs.

## F. RPC changes

No RPC body change was required. The diagnostic proved `create_order_from_checkout_draft(uuid,text)` increments reserved stock and creates one stock reservation inside the transaction.

## G. Stock-model correction

No stock model correction was required. The active model remains:

- `total_stock_quantity`
- `reserved_stock_quantity`
- `sold_stock_quantity`
- reservation rows in `stock_reservations`

The test harness now checks supplier/internal stock values outside simulated customer context.

## H. Idempotency correction

No RPC idempotency correction was required. Duplicate retry returned the same order and did not double-reserve stock.

## I. Security/RLS correction

Direct write privileges were tightened for checkout-created order/stock commercial tables. RLS remains enabled/forced, and policies were not weakened.

## J. Test-harness correction

Updated:

- `scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql`

Changes:

- Added a helper that treats permission errors or zero affected rows as blocked direct mutation.
- Moved product-variant reserved-stock assertions out of simulated customer context.
- Preserved all original security and stock assertions.

## K. Dry-run result

`npx supabase db push --dry-run --include-all` passed and showed only:

- `20260718214000_fix_phase_c_order_stock_security.sql`

## L. Apply result

`npx supabase db push --include-all` applied the R6 corrective migration successfully to the confirmed DEVELOPMENT Risellar project.

## M. Boundary-test result

`npx supabase db query --linked --file scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql` passed. All returned rows had `passed = true`.

The previously failed assertions now pass:

- Commercial snapshot mutation blocked by permission/RLS.
- Reserved stock increments once.
- Duplicate confirmation does not increment reserved stock twice.
- Insufficient stock preserves the pre-failure reserved-stock baseline.

## N. Concurrency-test result

True two-session concurrency was not run. It remains blocked because the repository does not yet provide a safe approved two-session fixture and cleanup method, and R6 did not create persistent order fixtures ad hoc.

## O. Post-test cleanup result

Aggregate post-test checks found zero test profiles, products, listings, drafts, orders, order items, stock reservations, and related audit fixture rows.

## P. Application verification

- `npm test`: passed; 30 files, 158 tests.
- `npm run lint`: passed.
- `npm run build`: passed; 168 static pages generated.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

Runtime HTTP health was blocked by a stale local Next dev cache/server chunk error on port 400. The attempted combined stale-server stop/cache clear command was rejected by local safety policy, so runtime HTTP was not claimed as passing.
Runtime was then recovered by gently stopping the port-400 listener and restarting `npm run dev:400`. HTTP checks returned 200 for `/`, `/sign-in`, `/sign-up`, a known public shop route, and a known public product route. `/checkout/cart` returned 200; later checkout step routes returned 404 and remain deferred. Source scan confirmed final confirmation controls still render disabled "Confirm order coming soon" buttons and no active `Place Order` action.

## Q. Security/privacy scan

- `.env.local`, `.local-recovery`, `.next`, and `supabase/.temp` remain ignored.
- Temporary SQL/evidence files were kept under ignored `.local-recovery/`.
- No credentials, project identifiers, connection strings, database passwords, JWTs, cookies, tokens, environment values, customer identifiers, or order identifiers were added to reports.
- No production project was accessed.
- No migration repair was run.
- No service-role imports were added to `app/` or `components/`.
- No order-confirmation UI was enabled.
- No payment/delivery/preparation/finance implementation was added.

## R. Files changed

- `supabase/migrations/20260718214000_fix_phase_c_order_stock_security.sql`
- `scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql`
- `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_R6_FAILURE_ROOT_CAUSE_REPORT.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_R6_ORDER_STOCK_SECURITY_FIX_REPORT.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_RECONCILIATION_GROUP_R5_DEV_APPLY_AND_RPC_TEST_REPORT.md`
- Related Phase C planning/report docs

## S. Current Git status

R6 leaves tracked migration/test/report changes unstaged. Pre-existing supplier/package/tsconfig metadata/no-content-diff entries remain visible in `git status --short`.

## T. Whether Phase C backend now passes

Yes for the single-session RPC boundary suite. True concurrency remains unverified.

## U. Whether RPC security passes

Yes. The boundary test confirms role checks and direct commercial snapshot mutation protection.

## V. Whether stock reservation passes

Yes. The boundary test confirms one reservation, one reserved-stock increment, duplicate no-double-reserve, and insufficient-stock rollback.

## W. Whether concurrency is verified

No. True two-session concurrency remains pending.

## X. Whether files are safe to commit

Yes, after final secret/scope scan and explicit commit approval. Do not commit `.local-recovery/`, `.next/`, `supabase/.temp/`, logs, or backup/evidence files.

## Y. Whether order-confirmation UI planning may begin

Not yet. Plan the true two-session concurrency fixture/cleanup method first, then run it before enabling final confirmation UI.

## Z. Exact next step

Commit the R6 corrective migration, updated boundary test, and reports. Do not enable the final checkout confirmation UI.
