# Risellar Supplier Order Phase 1 Plan

## Summary

Supplier Order Phase 1 should introduce the smallest safe backend surface for suppliers to read their own newly placed Pay on Delivery orders and make one audited decision: accept or reject. It must not activate supplier preparation, delivery, payment collection, settlement, commission release, withdrawals, refunds, or admin order transitions.

The existing checkout flow creates orders in `placed_pending_confirmation`, reserves stock, stores immutable order-item snapshots, and leaves Pay on Delivery as `not_collected`. Supplier Phase 1 should build on that state without changing customer, reseller, payment, or finance contracts.

## Current Order-State Findings

The real schema defines `public.order_status` as:

- `draft`
- `placed_pending_confirmation`
- `customer_confirmed`
- `delivery_quote_pending`
- `delivery_quote_ready`
- `delivery_quote_approved`
- `supplier_preparing`
- `ready_for_pickup_or_dispatch`
- `out_for_delivery`
- `delivered_payment_pending`
- `payment_collected`
- `settlement_due`
- `completed`
- `cancelled`
- `customer_refused`
- `failed`
- `disputed`

The schema does not currently include `supplier_confirmed`, `supplier_rejected`, or `expired` as order-status enum values. The schema does include `supplier_preparing`, but supplier preparation remains deferred and should not be reused as acceptance unless the product decision explicitly chooses that tradeoff.

Current order creation uses:

- `order_status = 'placed_pending_confirmation'`
- `payment_method = 'pay_on_delivery'`
- `payment_collection_status = 'not_collected'`
- `delivery_status = 'estimate_selected'`
- `customer_confirmation_status = 'pending'`
- `delivery_quote_status = 'pending'`
- stock reservation status `reserved`

Terminal/dormant statuses already present include `completed`, `cancelled`, `customer_refused`, `failed`, and `disputed`. Later operational statuses already present include `supplier_preparing`, `ready_for_pickup_or_dispatch`, `out_for_delivery`, `delivered_payment_pending`, `payment_collected`, and `settlement_due`.

## Minimum Supplier-State Decision

Recommended Phase 1 state model:

```text
placed_pending_confirmation -> supplier_confirmed
placed_pending_confirmation -> supplier_rejected
```

Because those two target states do not exist today, S2/S4 implementation must plan a forward enum extension before applying decision RPCs. Do not use `supplier_preparing` as the acceptance state in Phase 1 because that would imply preparation is active.

Customer-safe labels:

- `placed_pending_confirmation`: Placed - waiting for supplier confirmation
- `supplier_confirmed`: Supplier confirmed your order
- `supplier_rejected`: Supplier could not fulfil this order

If enum extension is deferred, the fallback is to keep `order_status = placed_pending_confirmation` and add a separate supplier decision field in a forward migration. That is more invasive and should be chosen only if enum changes are rejected.

## Supplier Phase 1 Scope

In scope:

- supplier-safe order list plan
- supplier-safe order detail plan
- accept/reject decision RPC plan
- stock reservation release on rejection
- idempotent repeated accept/reject behavior
- customer-visible status labels
- audit event plan
- development-only boundary and browser QA plan

Out of scope:

- supplier preparation
- ready for pickup/dispatch
- delivery quotes or delivery assignment
- payment collection
- payment provider rows
- settlement creation or verification
- reseller commission release
- withdrawals
- refunds
- customer cancellation
- admin order transitions

## Implementation Guardrails

Future supplier writes must be database RPCs, not direct table updates from UI code. The browser/server action may send only an order id, decision-specific safe inputs, and an optional idempotency key. Supplier id, customer id, product id, status, stock values, prices, margins, commission, and settlement amounts must be resolved server-side.

Supplier order reads must be scoped by active supplier ownership or explicitly approved supplier staff membership. Customer, reseller, anonymous, and admin-staff contracts should not accidentally satisfy supplier actor checks.
