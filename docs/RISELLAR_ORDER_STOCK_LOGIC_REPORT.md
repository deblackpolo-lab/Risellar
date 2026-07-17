# Risellar Order and Stock Logic Report

## A. Logic Helpers Created

Created `lib/order-stock-logic.ts` with pure TypeScript helpers:

- `calculateProductPriceBreakdown`
- `validateResellerMargin`
- `createOrderPriceSnapshot`
- `getOrderPriceViewForRole`
- `canReserveStock`
- `calculateReservationExpiry`
- `getOrderStatusAfterCustomerConfirmation`
- `getCheckoutPaymentAvailability`

All helpers are deterministic and contain no database calls, API calls, server actions, provider calls, secrets, or environment variable usage.

## B. Business Rules Covered

- Supplier base price plus platform margin plus reseller margin equals the customer product price.
- Delivery fee is tracked separately from product price.
- Pay on Delivery is active and primary.
- Pay Online is represented only as a placeholder.
- Customer-facing price views expose only customer product price, delivery fee, total Pay on Delivery amount, and currency.
- Reseller-facing price views expose reseller cost and reseller profit/margin without exposing the supplier base price as a customer field.
- Admin-facing price views expose the full supplier/platform/reseller/customer breakdown.
- Reseller margin validation rejects negative margins and margins above an approved maximum.
- Order price snapshots freeze supplier base price, platform margin, reseller margin, reseller cost, customer product price, product subtotal, delivery fee, and total Pay on Delivery.
- Later live product price changes do not mutate existing order snapshots.
- Stock reservation checks available stock as `totalStock - reservedStock - soldStock`.
- Reservation logic prevents overselling when requested quantity exceeds available stock.
- Reservation expiry defaults to the MVP one-hour confirmation window.
- Customer confirmation only advances to a reserved/customer-confirmed state when the confirmation is not expired and stock can still be reserved.
- Expired confirmations return an expiry/release path.

## C. Tests Added

Added `tests/order-stock-logic.test.ts` with coverage for:

- Price breakdown math.
- Reseller margin validation.
- Immutable order price snapshots.
- Role-safe price visibility for customer, reseller, and admin.
- Oversell prevention.
- Reservation expiry calculation.
- Customer confirmation status transitions.
- Pay on Delivery active / Pay Online placeholder availability.

## D. Backend Integration Notes

Later server actions or Supabase RPC wrappers should call these helpers before any write:

- Checkout/order creation should recalculate pricing server-side from trusted product/listing inputs, then call `createOrderPriceSnapshot` to populate order item snapshot columns.
- Customer-visible responses should use `getOrderPriceViewForRole(snapshot, "customer")` so supplier base price and platform internals are never returned to the browser.
- Reseller dashboards should use the reseller view to show reseller cost and profit while still hiding admin-only platform internals where needed.
- Admin/order operations pages can use the admin view for reconciliation, settlement review, and support.
- Confirmation flows should use `calculateReservationExpiry`, `canReserveStock`, and `getOrderStatusAfterCustomerConfirmation` as the application-level contract around the database reservation operation.
- `getCheckoutPaymentAvailability` can back frontend/server copy until a real Pay Online provider is selected.

## E. What Still Needs DB/RPC Later

- A Supabase RPC such as `reserve_stock(variant_id, quantity, order_id, expires_at)` that atomically checks and increments reserved stock.
- Transactional order creation that inserts `orders`, `order_items`, `stock_reservations`, and `order_status_events` together.
- Database constraints to enforce `reserved_stock_quantity + sold_stock_quantity <= total_stock_quantity`.
- Reservation expiry/release job or RPC to mark expired reservations and decrement reserved stock.
- Delivery quote persistence and customer delivery quote approval transitions.
- Settlement and commission ledger creation from order item snapshots.
- Real Pay Online provider selection, payment intent creation, and webhook handling.
- Audit logs for sensitive price, reservation, confirmation, release, cancellation, and manual override actions.

## F. Files Changed

- `lib/order-stock-logic.ts`
- `tests/order-stock-logic.test.ts`
- `docs/RISELLAR_ORDER_STOCK_LOGIC_REPORT.md`

Unrelated working tree changes existed and were not part of this task:

- `lib/mock/preview-routes.ts`
- `tests/phase15.test.tsx`
- `docs/RISELLAR_BACKEND_PHASE_0_MASTER_PLAN.md`
- `docs/RISELLAR_FRONTEND_PRD_COVERAGE_AUDIT_REPORT.md`
- `docs/RISELLAR_FRONTEND_PRD_COVERAGE_MATRIX.md`

## G. Commands Run / Results

- `npm test -- tests/order-stock-logic.test.ts`
  - First run failed as expected because `@/lib/order-stock-logic` did not exist yet.
  - Final focused run passed: 1 test file, 8 tests.
- `npm test`
  - Passed: 18 test files, 81 tests.
- `npm run typecheck`
  - Passed: `tsc --noEmit`.
- `npm run lint`
  - Passed: `eslint . --max-warnings=0`.
- `npm run build`
  - First attempt failed after successful compilation because `.next/server/next-font-manifest.json` was missing from a partial build artifact state.
  - Cleared only the generated `.next` directory after verifying it was inside the workspace.
  - Second attempt compiled and generated all static pages, then failed on a transient `.next/export/500.html` rename artifact.
  - Third attempt passed successfully, including 160 generated static pages.

## H. Current Git Status

At report creation time, the active branch is `backend/order-stock-logic`.

Task files are new/untracked before staging:

- `docs/RISELLAR_ORDER_STOCK_LOGIC_REPORT.md`
- `lib/order-stock-logic.ts`
- `tests/order-stock-logic.test.ts`

Unrelated pre-existing working tree changes remain present and should not be included in this task commit:

- Modified: `lib/mock/preview-routes.ts`
- Modified: `tests/phase15.test.tsx`
- Untracked: `docs/RISELLAR_BACKEND_PHASE_0_MASTER_PLAN.md`
- Untracked: `docs/RISELLAR_FRONTEND_PRD_COVERAGE_AUDIT_REPORT.md`
- Untracked: `docs/RISELLAR_FRONTEND_PRD_COVERAGE_MATRIX.md`
