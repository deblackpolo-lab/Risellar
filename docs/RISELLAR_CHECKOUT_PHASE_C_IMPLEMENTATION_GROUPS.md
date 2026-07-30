# Risellar Checkout Phase C Implementation Groups

## Group C1: Planning

Current group. Deliverables:

- order creation plan
- order state machine
- stock reservation design
- security/RLS plan
- RPC test plan
- implementation grouping
- risk register
- planning report

No migrations, RPCs, app wiring, Supabase mutations, commits, or pushes are included.

## Group C2: Backend Migration And Test Harness, Dry-Run Only

Create a forward migration and development-only RPC test script.

Likely files:

- `supabase/migrations/20260718xxxxxx_checkout_order_stock_rpc_foundation.sql`
- `scripts/rpc/checkout-order-stock-rpc-tests-dev-only.sql`
- `docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_STOCK_BACKEND_FOUNDATION_REPORT.md`

Expected migration work:

- add `orders.checkout_draft_id uuid unique`
- add needed indexes for active reservations by variant/order
- add order number helper
- add `create_order_from_checkout_draft`
- possibly add internal stock reservation helper
- preserve RLS posture

Run only:

- `npx supabase db push --dry-run`
- normal local tests/build/typecheck

Do not apply migration yet.

## Group C3: Development Apply And RPC Boundary Tests

After explicit approval:

- confirm development Supabase project
- run `npx supabase db push`
- run `scripts/rpc/checkout-order-stock-rpc-tests-dev-only.sql`
- update apply/test report

No UI order submission yet.

## Group C4: Checkout UI Confirmation Wiring

After C3 passes:

- connect final review button to server action
- call order creation RPC with draft id only
- show clear success/error states
- keep payment/delivery/settlement/commission deferred
- ensure disabled online payment remains disabled

Manual QA should use development customer account and fake/dev-only listing only.

## Group C5: Order Read Surfaces

Add safe read-only order visibility:

- customer order detail/list
- reseller attributed order visibility
- supplier order queue visibility after customer confirmation rules are defined
- admin/support visibility

Do not add supplier preparation or settlement actions in this group.

## Group C6: Reservation Release And Customer Confirmation

Add explicit lifecycle RPCs:

- `confirm_customer_order`
- `cancel_unconfirmed_order`
- `release_expired_stock_reservations`

This group should define operational ownership and scheduler/manual execution boundaries.

## Deferred Later Groups

- delivery quote creation/approval
- supplier preparation
- Pay on Delivery collection verification
- settlement proof and verification
- commission release
- withdrawals
- online payment provider integration
- customer public purchase flow hardening beyond MVP
