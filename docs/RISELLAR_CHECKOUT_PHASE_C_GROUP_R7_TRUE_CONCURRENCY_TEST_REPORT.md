# Risellar Checkout Phase C Group R7 True Concurrency Test Report

## A. Executive summary

Checkout Phase C Group R7 true two-session stock concurrency verification passed against the confirmed DEVELOPMENT Risellar Supabase project. Two independent linked database sessions attempted to create orders from two different customer-owned `review_pending` drafts for the same one-unit product variant. Exactly one session succeeded and exactly one session failed with `INSUFFICIENT_STOCK`.

The successful transaction created exactly one order, one order item, and one stock reservation. Reserved stock increased from `0` to `1`, available stock became `0`, and stock never became negative. The losing transaction left no partial order, item, reservation, or draft conversion. Winner idempotency retry returned the existing order without creating duplicate rows or changing stock. All R7 fixtures were cleaned up.

Final order-confirmation UI remains disabled. No payment, delivery, supplier-preparation, commission, settlement, withdrawal, or refund flow was implemented or triggered.

## B. Baseline commit and branch

- Baseline commit: `5eac233d6db8f57bb4b6b80eb6dcd1f3a7f1ee85`
- Branch: `main`

## C. DEVELOPMENT project confirmation

The linked Supabase project was confirmed as the DEVELOPMENT Risellar project without printing the project ref, connection string, credentials, or environment values. Production Supabase was not accessed.

## D. Fixture design

R7 used isolated DEVELOPMENT-only fixtures:

- one active approved supplier profile/foundation
- one active approved supplier product
- one active product variant with one available unit
- one approved reseller profile
- one active reseller shop/listing
- two active customer profiles
- two active delivery addresses
- two `review_pending` checkout drafts

Both checkout drafts targeted the same listing/product/variant and each requested quantity `1`.

## E. Fixture isolation marker, masked

Fixture marker: `r7-concurrency-[masked]`

The full marker was stored only under ignored `.local-recovery/phase-c-r7-concurrency/` evidence and was not added to tracked files.

## F. Variant stock baseline

Before the concurrent calls:

- `total_stock_quantity = 1`
- `reserved_stock_quantity = 0`
- `sold_stock_quantity = 0`
- calculated available stock = `1`
- existing marker-scoped orders = `0`
- existing marker-scoped reservations = `0`

## G. Two-session method

Two separate PowerShell background jobs launched two independent `npx supabase db query --linked` processes. Each process opened its own PostgreSQL connection and ran its own ignored SQL file.

## H. Auth-context method

Each session independently simulated authenticated customer context by setting the same request JWT claim pattern used by the existing development-only RPC boundary tests. The RPC invocation itself ran under simulated `authenticated` customer context. Service role was not used from application code.

## I. Synchronization method

Both sessions used a shared UTC start timestamp. Session A held its database transaction open briefly after successful RPC execution, causing Session B to wait during the same order/stock row-lock path before returning `INSUFFICIENT_STOCK`.

## J. Session A result

Session A result: `SUCCESS`.

## K. Session B result

Session B result: `INSUFFICIENT_STOCK`.

## L. Winning/losing result summary without IDs

Exactly one customer draft converted to an order. The other customer draft remained `review_pending` with no converted order.

## M. Order/item/reservation counts

After concurrent execution and before cleanup:

- successful RPC count = `1`
- insufficient-stock result count = `1`
- marker-scoped order count = `1`
- marker-scoped order-item count = `1`
- marker-scoped stock-reservation count = `1`
- duplicate order per draft = `0`
- duplicate reservation = `0`

## N. Reserved-stock result

Reserved stock increased exactly once, from `0` to `1`.

## O. Available-stock result

Calculated available stock moved from `1` to `0` and did not become negative.

## P. Losing-transaction rollback result

The losing draft stayed `review_pending`, had no `converted_order_id`, and had no order or stock reservation. Retrying the losing draft while available stock was `0` returned `INSUFFICIENT_STOCK` and created no partial rows.

## Q. Winner idempotency retry result

Retrying the winning converted draft with the same idempotency key returned the same existing order and did not create a second order, order item, reservation, or stock mutation.

## R. No-side-effect verification

Marker-scoped verification found:

- delivery quotes = `0`
- commissions = `0`
- settlements = `0`
- withdrawals = `0` by marker scope
- no payment collection was triggered
- no supplier-preparation flow was triggered
- no final order-confirmation UI was enabled

## S. Fixture cleanup result

Cleanup used an ignored, marker-scoped SQL script under `.local-recovery/phase-c-r7-concurrency/`. It removed only R7 fixtures in dependency order and did not use `TRUNCATE`, migration repair, migration edits, production data, or broad unscoped deletes.

## T. Post-cleanup verification

Post-cleanup marker-scoped counts were all zero for:

- profiles
- customers
- customer delivery addresses
- suppliers
- resellers
- reseller shops
- reseller listings
- products
- product variants
- checkout drafts
- orders
- order items
- stock reservations
- inventory movements
- audit logs
- delivery quotes
- commissions
- settlements

No R7 reserved-stock imbalance remained.

## U. Security/privacy scan

- `.env.local` remains ignored and untracked.
- `.local-recovery/` remains ignored and untracked.
- `.next/` remains ignored and untracked.
- `supabase/.temp/` remains ignored and untracked.
- R7 temporary SQL, session output, and evidence files remain ignored and untracked.
- No credentials, connection strings, project identifiers, JWTs, cookies, tokens, customer IDs, draft IDs, order IDs, product IDs, variant IDs, or private row data were added to this report.
- No service-role imports were added to `app/` or `components/`.
- No production project was accessed.
- No migration was created, modified, repaired, or applied in R7.
- No application source was modified.

## U1. Commands run/results

- `git status --short`: showed only pre-existing metadata/no-content-diff entries before R7; after R7 it also shows this new report.
- `git rev-parse HEAD`: matched `5eac233d6db8f57bb4b6b80eb6dcd1f3a7f1ee85`.
- `git branch --show-current`: `main`.
- `git diff --name-status`, `git diff --numstat`, `git diff --summary`: no meaningful application-source diff.
- `git diff --check`: passed.
- `npx supabase --version`: `2.109.1`.
- `psql --version`: available.
- Read-only schema and pre-fixture aggregate checks: passed.
- R7 fixture setup: created two customer drafts against one one-unit variant.
- Two-session concurrency execution: one `SUCCESS`, one `INSUFFICIENT_STOCK`.
- Post-concurrency aggregate verification: passed.
- Winner idempotency retry: passed.
- Losing draft retry with zero available stock: passed with `INSUFFICIENT_STOCK`.
- R7 cleanup: passed.
- Post-cleanup aggregate verification: all marker-scoped counts returned zero.
- `npm test`: passed; 30 files, 158 tests.
- `npm run lint`: passed.
- `npm run build`: passed; 168 static pages generated.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## U2. Runtime HTTP result

The stale port-400 Risellar dev server was restarted safely after the production build. Runtime probes returned:

- `/`: HTTP 200
- `/sign-in`: HTTP 200
- `/sign-up`: HTTP 200
- public shop unavailable state: HTTP 200
- public product unavailable state: HTTP 200
- `/checkout/cart`: HTTP 200

No active public shop/product pair existed after cleanup, so runtime used safe unavailable public-shop routes rather than a real active listing. Checkout step routes such as `/checkout/review` returned 404 in the unauthenticated HTTP probe even though the build includes the route. Source scan confirmed final confirmation controls remain disabled with "Confirm order coming soon" text and no active `Place Order` action.

## V. Files changed

Tracked file created:

- `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_R7_TRUE_CONCURRENCY_TEST_REPORT.md`

Ignored local recovery files were created under:

- `.local-recovery/phase-c-r7-concurrency/`

## W. Current Git status

Expected tracked report change plus pre-existing metadata/no-content-diff entries. R7 did not modify application source.

## X. Whether true concurrency passed

Yes. Two independent PostgreSQL sessions overlapped and produced exactly one success plus exactly one `INSUFFICIENT_STOCK` result.

## Y. Whether oversell protection is verified

Yes. The one-unit variant produced exactly one order and one reservation, reserved stock ended at `1`, available stock ended at `0`, and no negative availability or duplicate reservation occurred.

## Z. Whether files are safe to commit

Yes, after final verification and explicit commit approval. Stage only the R7 report. Do not stage `.local-recovery/`, `.next/`, `supabase/.temp/`, temporary SQL, session output, logs, backups, or evidence files.

## AA. Whether order-confirmation UI planning may begin

Yes. The Phase C backend now has passing single-session RPC boundaries and true two-session oversell concurrency verification. Final UI confirmation should still be planned and implemented as a separate task.

## AB. Exact recommended next step

Commit the R7 true-concurrency report only, then begin a separate planning task for safely enabling final order-confirmation UI without connecting payments, delivery, supplier preparation, commissions, settlements, withdrawals, or refunds.
