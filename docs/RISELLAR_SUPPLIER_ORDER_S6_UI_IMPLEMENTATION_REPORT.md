# Risellar Supplier Order Handling S6 UI Implementation Report

## A. Summary

Supplier Order Handling S6 connects the supplier order list and detail screens to the audited supplier order read and decision RPCs. The implementation is scoped to supplier accept/reject decisions for Pay on Delivery orders that already have reserved stock.

No preparation, delivery, payment collection, commission, settlement, withdrawal, refund, cancellation, or admin transition workflow was connected.

## B. Routes Connected

- `/supplier/orders`
- `/supplier/orders/[id]`
- Supplier dashboard quick action now links to `/supplier/orders`.

The legacy design placeholder screens remain preserved for older mock routes, but the real route files now render RPC-backed order list/detail screens.

## C. Server Actions And Helpers

Created server-only supplier order helpers:

- `list_supplier_orders_safe`
- `get_supplier_order_safe`
- `supplier_accept_order`
- `supplier_reject_order`

Created supplier order server actions:

- accept supplier order
- reject supplier order

The actions use Clerk native session tokens with the anon/user-context Supabase client. They do not import or expose the service role.

## D. UI Behavior

The supplier order list groups orders into:

- New orders
- Confirmed
- Rejected

Order cards show supplier-safe operational fields only:

- order number
- product name
- quantity
- recipient label when available
- supplier expected amount
- payment status
- reservation status
- location summary

The order detail page shows:

- supplier expected amount
- customer total
- Pay on Delivery status
- reservation status and quantity
- fulfilment contact snapshot
- safe reseller shop context
- decision timeline

## E. Accept Behavior

Accept is available only for actionable `placed_pending_confirmation` orders.

The accept form requires an acknowledgement:

`Confirm that you can fulfil this order. Stock is already reserved.`

Accept uses `supplier_accept_order` and a stable idempotency key. It does not mutate orders directly from the client or expose supplier/commercial identifiers for editing.

## F. Reject Behavior

Reject is available only for actionable `placed_pending_confirmation` orders.

The reject form requires a safe reason code. The tested browser QA reason was `unable_to_fulfil`.

Reject copy clearly states that rejecting releases reserved stock and that the customer will not be charged. Private rejection notes remain internal.

Reject uses `supplier_reject_order` and a stable idempotency key. It does not create payment, delivery, preparation, commission, settlement, withdrawal, refund, or cancellation rows.

## G. Security And Scope Protections

- Supplier routes remain `supplier_owner` only.
- Admin_staff, customer, and reseller profiles are blocked from supplier order routes by route policy tests.
- Server actions require a signed-in Clerk session and synced Supabase profile.
- The service role is not used in app/components.
- The UI does not accept supplier id, product id, stock, price, payment, delivery, preparation, finance, or admin status fields from the browser.
- Direct table updates are not used by the UI.
- The supplier dashboard now advertises only order accept/reject decisions as live; preparation, delivery, payment, settlement, commission, and withdrawal remain deferred.

## H. Tests Added Or Updated

- Added `tests/supplier-order-ui.test.tsx`.
- Updated `tests/supplier-order-decision.test.ts`.
- Updated `tests/phase6.test.tsx` for the live order decision dashboard affordance.

Focused tests verify:

- safe list/detail payloads
- safe field mapping
- audited RPC names only
- stable accept/reject idempotency keys
- rejection reason validation
- acknowledgement-gated Accept button
- customer/admin/reseller route blocking
- no service-role use in app/components
- no payment, delivery, preparation, commission, settlement, or withdrawal integration in S6 UI paths

## I. Browser QA Dependency

Live browser QA required two actionable development orders with active reserved stock. Existing visible pending orders had unavailable reservations, so two isolated dev-only QA orders were prepared for the signed-in supplier account.

The first preferred setup path attempted to use checkout/listing RPCs, but development data had no eligible listing for the signed-in supplier. A direct dev-only fixture setup matching the supplier-order RPC boundary fixture pattern was used for the two QA orders only.

## J. Commands Run

- `npm test -- tests/supplier-order-ui.test.tsx tests/supplier-order-decision.test.ts tests/supplier-order-read.test.ts tests/phase6.test.tsx` - passed.
- `git diff --check` - passed with Windows line-ending warnings only.
- `npm test` - passed, 35 files and 191 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- `npx tsc --noEmit` - passed.

## K. Files Changed

- `app/supplier/orders/actions.ts`
- `app/supplier/orders/page.tsx`
- `app/supplier/orders/[id]/page.tsx`
- `components/supplier/supplier-order-rpc-screens.tsx`
- `components/supplier/screens.tsx`
- `lib/orders/supplier-order-read.ts`
- `lib/orders/supplier-order-shared.ts`
- `tests/supplier-order-ui.test.tsx`
- `tests/supplier-order-decision.test.ts`
- `tests/phase6.test.tsx`

## L. Current Status

Implementation passed final verification and is safe to commit with the S7 browser QA report.
