# Risellar Supplier Fulfilment Phase 2 Backend Report

## A. Summary

Supplier Fulfilment Phase 2 adds the audited supplier preparation transition for accepted Pay on Delivery orders:

`supplier_confirmed` -> `supplier_preparing`

The phase does not implement delivery, payment collection, commission release, settlement, withdrawal, refund, cancellation, admin transitions, or notifications.

## B. Schema Findings

Development schema audit confirmed:

- `supplier_preparing` already existed in the order status enum.
- `supplier_start_preparing` did not already exist before this phase.
- `orders` did not have a preparation timestamp column before this phase.
- No separate preparation workflow table existed.

The smallest safe model was used: order status, one preparation timestamp, idempotency metadata, and one audit event.

## C. Migration Created

Created:

- `supabase/migrations/20260730150000_supplier_order_start_preparing_rpc.sql`

The migration adds:

- `orders.supplier_preparing_at`
- `orders.supplier_preparation_by_profile_id`
- `orders.supplier_preparation_idempotency_key`
- `public.supplier_start_preparing(p_order_id uuid, p_idempotency_key text default null)`
- supplier-safe and customer-safe read label updates
- authenticated-only execute grant for the new RPC

## D. RPC Design

`supplier_start_preparing`:

- resolves the current profile server-side
- requires active `supplier_owner`
- requires an active approved supplier account
- resolves supplier ownership through order items
- requires a single supplier scope
- locks order, order item, reservation, and variant rows
- requires `supplier_confirmed`
- requires Pay on Delivery payment collection to remain `not_collected`
- requires active, unexpired reserved stock
- returns the existing supplier-safe order detail shape

The browser/client cannot provide supplier id, customer id, variant id, reservation id, stock values, payment status, order status, or commercial fields.

## E. Actionability

Allowed:

- active approved supplier_owner for their own single-supplier order
- order status `supplier_confirmed`
- reservation status `reserved`
- reservation not expired
- payment collection status `not_collected`

Blocked:

- pending/unconfirmed orders
- rejected orders
- expired/released/failed/missing reservations
- cross-supplier access
- customer, reseller, admin_staff, and anonymous contexts
- missing/unauthorized orders with non-enumerating unavailable behavior

## F. Idempotency

The UI/server action uses stable idempotency keys:

- `supplier-start-preparing:${orderId}`

Repeated calls return the durable `Preparing order` state and do not create duplicate transitions, duplicate audit events, reservation changes, stock changes, or payment/delivery/finance side effects.

## G. Audit Event

The RPC writes exactly one audit event on the first transition:

- `supplier_order_preparation_started`

The audit metadata is scoped to operational transition fields and does not log secrets, JWT/session data, customer email, customer address text, or full private customer information.

## H. Preservation Checks

The RPC preserves:

- reservation status
- reservation quantity
- reserved stock
- total stock
- sold stock
- payment collection status

It does not insert or update delivery quotes, payments, commissions, settlements, withdrawals, refunds, cancellations, stock reservations, product variants, or preparation subsystem rows.

## I. Safe-Read Mappings

Supplier-safe mapping:

- `supplier_preparing` -> `Preparing order`

Customer-safe mapping:

- `supplier_preparing` -> `Supplier is preparing your order`

Payment remains:

- `Payment not collected`

Delivery remains:

- `Delivery not arranged yet`

Reservation remains:

- supplier-safe: `Stock reserved`
- customer-safe: `Stock reserved for this order`

## J. Dry-Run And Apply

Dry-run command:

- `npx supabase db push --dry-run --include-all` - passed.

Dry-run showed only:

- `20260730150000_supplier_order_start_preparing_rpc.sql`

Development apply command:

- `npx supabase db push --include-all` - passed.

No production Supabase project was used. No destructive reset command was run.

## K. SQL Tests

Boundary test:

- `npx supabase db query --linked --file scripts/rpc/supplier-order-start-preparing-rpc-tests-dev-only.sql` - passed.

Passed assertions included:

- supplier starts preparing own confirmed order
- status becomes `supplier_preparing`
- preparation timestamp populated
- reservation remains reserved
- reservation quantity unchanged
- reserved stock unchanged
- total stock unchanged
- sold stock unchanged
- payment remains `not_collected`
- audit event created
- duplicate call returns same state
- duplicate call creates no duplicate transition or audit event
- pending/rejected/expired/released/failed/missing-reservation cases blocked
- cross-supplier, customer, reseller, admin_staff, and anonymous contexts blocked
- no payment/delivery/finance side effects
- fixture data rolled back

Concurrency/idempotency test:

- `npx supabase db query --linked --file scripts/rpc/supplier-order-start-preparing-concurrency-tests-dev-only.sql` - passed.

Passed assertions included:

- two start-preparing calls converge
- one preparation audit event
- preparation timestamp stable
- reservation unchanged
- stock unchanged

## L. Automated Verification

Pre-QA verification:

- `git diff --check` - passed with Windows line-ending warnings only.
- `npm test` - passed, 36 files / 198 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- `npx tsc --noEmit` - passed.

## M. Security Scope

Confirmed:

- no service role use in `app/` or `components/`
- no direct browser/client table writes
- no broad table grants added
- no RLS/policy weakening
- no production connection
- no migration repair or destructive reset
- no delivery/payment/finance implementation

## N. Current Status

The backend migration is applied to the confirmed development project and the development-only SQL boundary/concurrency tests passed.
