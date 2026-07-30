# Risellar Supplier Order Stock Release Design

## Current Stock Model

The active inventory model uses:

- `product_variants.total_stock_quantity`
- `product_variants.reserved_stock_quantity`
- `product_variants.sold_stock_quantity`
- `stock_reservations.reservation_status`
- `inventory_movements`

The variant table enforces:

```text
reserved_stock_quantity + sold_stock_quantity <= total_stock_quantity
```

Checkout order creation currently increments `reserved_stock_quantity`, creates a `reserved` stock reservation, and writes a `reservation_created` movement in the same transaction that creates the order.

## Rejection Release Rule

Supplier rejection should be the first supplier-side stock-release flow. It must:

- change reservation from `reserved` to `released`
- decrement `reserved_stock_quantity` by reservation quantity exactly once
- leave `total_stock_quantity` unchanged
- leave `sold_stock_quantity` unchanged
- set `released_at`
- store a safe release reason
- write inventory movement and audit events
- run atomically with the order-status change

Available stock increases because reserved stock decreases; physical stock is unchanged.

## Lock Order

Use one consistent lock order across future supplier decision, cancellation, and expiry flows:

1. `orders`
2. `stock_reservations`
3. `product_variants`

This matches the decision being order-driven while still protecting reservation and variant counters from double-release races.

## Idempotency and Safety

Release may run only when:

- order belongs to the supplier actor
- order is still `placed_pending_confirmation`
- reservation is `reserved`
- reservation order id matches the locked order
- variant id matches the reservation
- reserved stock is at least the reservation quantity

Repeated rejection of an already released reservation must return the existing rejected summary and must not update variant counters again.

If a variant has less reserved stock than the reservation quantity, the RPC should raise `STOCK_RELEASE_FAILED` and roll back the whole transaction rather than making counters negative.

## Inventory Movement

Recommended movement:

- `movement_type = 'reservation_released'`
- `quantity_delta = 0` if movements represent physical total quantity only
- or a documented negative reserved-delta convention if introduced later
- `previous_total_quantity` and `new_total_quantity` remain the same
- `order_id` set
- `created_by_profile_id` set to supplier actor
- reason includes safe reason code only

The movement must not include full customer address, customer phone, supplier private notes, or financial private fields.

## Reservation Expiry Interaction

For Phase 1, accepting an expired reservation should fail with `RESERVATION_EXPIRED`. Do not attempt automatic stock reacquisition.

Recommended behavior:

- expired reservation cannot be accepted
- rejection can release an expired-but-still-reserved hold only through an explicit expiry/release path if designed later
- order should move to a future expired or failed state through a separate system/admin expiry flow, not through supplier accept

Customer-safe wording:

```text
The stock hold expired before the supplier confirmed the order. No payment was collected.
```

No background expiry scheduler is planned in Supplier Phase 1 unless one already exists and is explicitly approved.
