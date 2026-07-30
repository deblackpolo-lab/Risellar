# Risellar Checkout Phase C Group R6 Failure Root Cause Report

## A. Exact four failures

The first R5 boundary run failed after the cleanup and Phase C migrations were applied to DEVELOPMENT:

- `customer cannot alter commercial snapshots`: operation unexpectedly succeeded.
- `duplicate confirmation does not increment reserved stock twice`: expected one matching row, observed zero.
- `insufficient stock failure does not increment reserved stock`: expected one matching row, observed zero.
- `reserved stock increments once`: expected one matching row, observed zero.

## B. Post-failure fixture state

Read-only aggregate checks found zero remaining checkout-order test profiles, products, listings, drafts, orders, order items, stock reservations, and related audit fixture rows. The failed boundary script did not leave persistent test fixtures.

## C. Actual stock schema

The active stock model is `product_variants.total_stock_quantity`, `reserved_stock_quantity`, `sold_stock_quantity`, `returned_stock_quantity`, and `variant_status`. `stock_reservations` stores one reservation row with `variant_id`, `order_id`, `quantity`, `reservation_status`, and `expires_at`.

## D. RPC stock path

The RPC locks the trusted draft variant with `FOR UPDATE`, computes availability from total minus reserved minus sold, inserts one order and one order item, increments `product_variants.reserved_stock_quantity`, inserts one `stock_reservations` row, records one inventory movement, converts the draft, and writes audit logs.

## E. Test harness stock path

The failed stock assertions queried `public.product_variants` while still in simulated customer context. The product-variant RLS policy intentionally allows supplier/admin reads, not customer reads, so the assertion query returned zero visible rows even though the owner-context diagnostic saw the reserved-stock increment.

## F. Reserved-stock root cause

Root cause: test harness defect. The RPC reserved stock correctly; the assertion read the correct row through an auth context that cannot see product-variant stock rows.

## G. Duplicate-idempotency root cause

Root cause: test harness defect. Duplicate confirmation returned the same order and did not create a second order. The repeated reserved-stock assertion again read `product_variants` through customer context and observed zero visible rows.

## H. Insufficient-stock baseline root cause

Root cause: test harness defect. The insufficient-stock RPC correctly raised `INSUFFICIENT_STOCK` and left no partial order. The baseline reserved-stock assertion again queried product variants from customer context.

## I. Commercial-snapshot security root cause

The direct commercial-snapshot update ran under simulated authenticated customer context, but RLS allowed zero rows to be updated. PostgreSQL treats an `UPDATE` affecting zero rows as a successful statement, so the helper incorrectly marked it as a failure because it only considered thrown errors as blocked.

## J. Whether the security issue is real

The specific commercial-snapshot mutation was a privileged-test/zero-row false positive, not proof of a successful customer mutation. However direct table grants on order and stock tables are broader than the approved Phase C boundary, so R6 should tighten direct write grants for checkout-created commercial data.

## K. Required migration fix

Create a forward migration that revokes direct insert/update/delete/truncate write privileges from `anon` and `authenticated` on `orders`, `order_items`, `stock_reservations`, and `product_variants`. Keep controlled writes inside reviewed SECURITY DEFINER RPCs.

## L. Required test-harness fix

Move reserved-stock assertions to owner/reset context or use a dedicated owner-context helper after the RPC call. Keep customer-facing assertions for safe order/reservation views. Keep commercial-snapshot protection, and treat permission errors or zero affected rows as blocked.

## M. Risks

The grant-tightening migration must not break approved RPC behavior, must not weaken RLS, and must not enable checkout UI. The harness must not hide real direct-write defects by accepting non-zero customer row updates.

## N. Exact proposed changes

- Add a forward R6 security-grant migration.
- Update the development-only Phase C boundary test stock assertions to read product-variant reserved stock outside customer context.
- Update the commercial-snapshot assertion to pass only when the customer update throws or affects zero rows.
- Rerun the boundary test once after dry-run/apply.
