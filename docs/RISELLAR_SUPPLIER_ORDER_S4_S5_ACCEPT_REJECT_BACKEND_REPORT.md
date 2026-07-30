# Risellar Supplier Order S4/S5 Accept/Reject Backend Report

## A. Executive summary

Implemented the supplier order accept/reject backend boundary for the confirmed DEVELOPMENT Risellar Supabase project. The phase adds explicit `supplier_confirmed` and `supplier_rejected` order states, audited supplier decision RPCs, deterministic supplier ownership checks, idempotent terminal behavior, rejection stock release, and safe-read status compatibility.

Supplier order UI was not connected or enabled.

## B. Baseline commit and branch

- Baseline commit supplied by task: `3852d0fd7667d5f2fc8ad9057707401c199dafa6`
- Branch: `main`

## C. Existing status findings

`public.order_status` existed as an enum. It already included `placed_pending_confirmation` and `supplier_preparing`, but did not include `supplier_confirmed` or `supplier_rejected`.

## D. State-model decision

The backend uses explicit terminal supplier decision states:

- `placed_pending_confirmation` -> `supplier_confirmed`
- `placed_pending_confirmation` -> `supplier_rejected`

It does not reuse `supplier_preparing` and does not overload cancellation states.

## E. Single-supplier assumption result

The development database showed current orders with items have a maximum distinct supplier count of `1`; no multi-supplier order was found. The RPC also rejects orders unless the order has exactly one item and one supplier attribution.

## F. Supplier ownership rule

The caller supplies only `p_order_id` and optional idempotency/rejection metadata. Supplier ownership is resolved server-side:

authenticated profile -> active `supplier_owner` profile -> active approved supplier -> `order_items.supplier_id` -> order.

Cross-supplier access raises a non-enumerating blocked result.

## G. Actionability rules

An order is actionable only when:

- `order_status = placed_pending_confirmation`
- `payment_collection_status = not_collected`
- exactly one supplier-owned order item exists
- a matching reservation exists
- reservation status is `reserved`
- reservation is unexpired

## H. Accept RPC

Created `public.supplier_accept_order(p_order_id uuid, p_idempotency_key text default null)`.

It sets `order_status = supplier_confirmed`, records `supplier_confirmed_at`, preserves stock reservation/payment state, writes `supplier_order_accepted`, and returns the existing supplier-safe order detail shape.

## I. Reject RPC

Created `public.supplier_reject_order(p_order_id uuid, p_reason_code text, p_reason_note text default null, p_idempotency_key text default null)`.

It sets `order_status = supplier_rejected`, stores the approved reason code and private note, releases the reservation, decrements reserved stock exactly once, writes audit events, and returns the supplier-safe order detail shape.

## J. Rejection reasons

Allowed reason codes:

- `out_of_stock`
- `product_unavailable`
- `unable_to_fulfil`
- `incorrect_listing`
- `supplier_temporarily_closed`
- `other`

Unsupported values are rejected.

## K. Note privacy

The optional rejection note is trimmed, limited to 500 characters, and stored on the order decision field. Broad audit rows store only safe reason metadata, not the full note.

## L. Lock sequence

Both decision RPCs use this sequence:

1. `orders`
2. `order_items`
3. `stock_reservations`
4. `product_variants` for rejection

## M. Idempotency

Terminal order state remains the source of truth. Idempotency keys are trimmed and length-limited to 120 characters. Repeated accept/reject calls for the same terminal action return the existing terminal result without duplicate state transition or stock mutation. Conflicting terminal actions are blocked.

## N. Stock-release design

Acceptance preserves reservation and stock. Rejection sets reservation status to `released`, populates `released_at`, decrements `product_variants.reserved_stock_quantity` by the reservation quantity, preserves total and sold stock, and writes an inventory movement with `reservation_released`.

## O. Reservation-expiry behavior

Expired reservations are not automatically reacquired. Accept/reject actionability requires `expires_at > now()`.

## P. Audit events

Implemented:

- `supplier_order_accepted`
- `supplier_order_rejected`
- `stock_reservation_released`
- `reserved_stock_decremented`

## Q. Customer-safe read compatibility

`get_customer_order_safe(uuid)` now maps:

- `supplier_confirmed` -> `Supplier confirmed your order`
- `supplier_rejected` -> `Supplier could not fulfil this order`

Supplier rejection notes are not returned.

## R. Supplier-safe read compatibility

`list_supplier_orders_safe(...)` and `get_supplier_order_safe(uuid)` now map:

- `supplier_confirmed` -> `Supplier confirmed`
- `supplier_rejected` -> `Rejected - stock released`

Only `placed_pending_confirmation` with active reserved stock remains actionable.

## S. Migration

Created `supabase/migrations/20260730140000_supplier_order_accept_reject_rpc.sql`.

## T. Dry-run

`npx supabase db push --dry-run --include-all` passed and showed only `20260730140000_supplier_order_accept_reject_rpc.sql` pending.

## U. Apply result

`npx supabase db push --include-all` applied the migration to the confirmed DEVELOPMENT project only.

## V. Boundary-test result

`scripts/rpc/supplier-order-decision-rpc-tests-dev-only.sql` passed after harness-only corrections for fixture uniqueness and audit visibility.

## W. Automatic harness-only fixes

- Added a unique checkout draft for the missing-reservation fixture.
- Moved audit/internal side-effect assertions out of simulated supplier role context so audit RLS remains intact.
- Tightened supplier negative tests to run under the intended supplier context.

No assertions were removed or weakened.

## X. Ownership/cross-role results

Supplier-owner own actions passed. Cross-supplier access, customer, reseller, admin_staff, anonymous, and missing order cases were blocked.

## Y. Acceptance results

Acceptance produced `supplier_confirmed`, preserved reservation, preserved reserved/total/sold stock, preserved payment status, wrote one audit event, and remained idempotent.

## Z. Rejection results

Rejection produced `supplier_rejected`, stored the reason code, validated note length, released reservation, decremented reserved stock once, preserved total/sold stock, wrote audit/movement events, and remained idempotent.

## AA. No-side-effect results

No payment table side effect was present. Delivery quotes, settlements, commissions, and withdrawals were unchanged. Supplier preparation, delivery, payment collection, commission, settlement, withdrawal, refund, cancellation, and commercial snapshot mutation were not implemented.

## AB. Cleanup

Boundary and concurrency harnesses use transaction rollback. Development fixture data is rolled back after assertion summary.

## AC. Automated verification

Verification commands:

- `git diff --check`: passed
- `npx vitest run tests/supplier-order-decision.test.ts`: passed, 6 tests
- `npx supabase db push --dry-run --include-all`: passed, one pending migration
- `npx supabase db push --include-all`: passed, development apply only
- `npx supabase db query --linked --file scripts/rpc/supplier-order-decision-rpc-tests-dev-only.sql`: passed after harness-only fixes
- `npx supabase db query --linked --file scripts/rpc/supplier-order-decision-concurrency-tests-dev-only.sql`: passed after harness-only audit visibility fix
- `npm test`: passed, 34 files and 184 tests
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed

## AD. Security/privacy scan

No secrets, credentials, project identifiers, connection strings, private row identifiers, JWTs, cookies, or access tokens were added to docs/source. `.env.local`, `.local-recovery`, `.next`, and `supabase/.temp` remain ignored and unstaged.

Focused scans confirmed:

- no service-role imports in `app/` or `components/`
- no `supplier_accept_order` or `supplier_reject_order` references in app UI/helper code
- no supplier order UI was connected
- no preparation, delivery, payment, commission, settlement, withdrawal, refund, or cancellation implementation was added

## AE. Files changed

- `supabase/migrations/20260730140000_supplier_order_accept_reject_rpc.sql`
- `scripts/rpc/supplier-order-decision-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-decision-concurrency-tests-dev-only.sql`
- `tests/supplier-order-decision.test.ts`
- `docs/RISELLAR_SUPPLIER_ORDER_S4_S5_ACCEPT_REJECT_BACKEND_REPORT.md`
- `docs/RISELLAR_SUPPLIER_ORDER_S5_DECISION_CONCURRENCY_REPORT.md`

## AF. Git status

Git status is recorded in the final response after verification. Known pre-existing metadata/no-content-diff entries are not staged.

## AG. Whether backend phase is complete

Backend S4/S5 is complete after final commit/push passes.

## AH. Whether supplier UI phase may begin

Supplier UI work may be planned after the backend commit lands.

## AI. Exact recommended next step

Plan supplier order UI integration for accept/reject buttons using the proven RPCs, keeping preparation/delivery/payment/finance phases deferred.
