# Risellar Supplier Order Accept/Reject State Machine

## Scope

Plan the supplier decision state machine for the first supplier order-handling backend phase. No migrations, RPCs, or source files are created here.

## Required Enum Extension

The current `public.order_status` enum does not contain `supplier_confirmed` or `supplier_rejected`. The future decision RPC migration should add these values with a forward-only migration before using them.

Do not use `supplier_preparing` for acceptance in this phase because preparation remains out of scope.

## Planned Transitions

| From | To | Actor | Stock effect |
| --- | --- | --- | --- |
| `placed_pending_confirmation` | `supplier_confirmed` | active supplier owner or approved supplier staff with order decision permission | reservation remains `reserved` |
| `placed_pending_confirmation` | `supplier_rejected` | active supplier owner or approved supplier staff with order decision permission | reservation becomes `released`; reserved stock decrements once |

Forbidden:

- customer accepts/rejects supplier order
- reseller accepts/rejects supplier order
- admin uses supplier RPCs
- supplier accepts/rejects another supplier's order
- supplier changes price, margin, customer, reseller, product, stock quantity, payment status, delivery status, settlement, or commission
- accepted order becomes rejected through retry
- rejected order becomes accepted through retry

## Accept RPC Contract

Planned RPC:

```sql
public.supplier_accept_order(
  p_order_id uuid,
  p_idempotency_key text default null
)
```

Inputs must not include supplier id, customer id, product id, price, status, stock values, commission, or settlement amount.

Required steps:

1. Validate authenticated active supplier actor.
2. Resolve supplier ownership or approved staff membership server-side.
3. Lock `orders` row `FOR UPDATE`.
4. Confirm the supplier owns at least one order item on the order.
5. Confirm `order_status = 'placed_pending_confirmation'`.
6. Confirm an active `reserved` stock reservation exists for the supplier item.
7. Confirm reservation has not expired.
8. Set `order_status = 'supplier_confirmed'`.
9. Preserve stock reservation as `reserved`.
10. Write audit log.
11. Return supplier-safe order summary.

Idempotency:

- repeated accept on an already `supplier_confirmed` order by the same supplier returns the confirmed summary
- repeated accept must not create extra audit noise except an optional duplicate-action audit event
- accept after rejection returns `ALREADY_REJECTED` or `ORDER_NOT_ACTIONABLE`

Accept must not mark preparing, delivered, payment collected, settlement due, commission available, or delivery arranged.

## Reject RPC Contract

Planned RPC:

```sql
public.supplier_reject_order(
  p_order_id uuid,
  p_reason_code text,
  p_reason_note text default null,
  p_idempotency_key text default null
)
```

Inputs must not include stock values, customer ids, supplier ids, price fields, status fields, commission, or settlement amount.

Required steps:

1. Validate authenticated active supplier actor.
2. Resolve supplier ownership or approved staff membership server-side.
3. Validate controlled rejection reason.
4. Lock `orders` row `FOR UPDATE`.
5. Confirm the supplier owns the order item.
6. Confirm `order_status = 'placed_pending_confirmation'`.
7. Lock the `stock_reservations` row.
8. Lock the `product_variants` row.
9. Mark order `supplier_rejected`.
10. Mark reservation `released`.
11. Set `released_at`.
12. Set a safe release reason.
13. Decrement `product_variants.reserved_stock_quantity` exactly once.
14. Preserve `total_stock_quantity` and `sold_stock_quantity`.
15. Insert inventory movement/audit events.
16. Return supplier-safe summary.

Idempotency:

- repeated reject on an already `supplier_rejected` order returns the rejected summary
- repeated reject must not decrement reserved stock again
- reject after accept returns `ALREADY_CONFIRMED` or `ORDER_NOT_ACTIONABLE`

## Rejection Reasons

Controlled reason codes:

- `out_of_stock`
- `product_unavailable`
- `unable_to_fulfil`
- `incorrect_listing`
- `supplier_temporarily_closed`
- `other`

Customer-visible message:

```text
The supplier could not fulfil this order. No payment was collected.
```

The free-text note should be optional, length-limited, and supplier/admin-only. It must not be displayed to customers unless separately reviewed and sanitized.

## Error Mapping

- `AUTH_REQUIRED`: Sign in to manage this order.
- `SUPPLIER_REQUIRED`: Use an approved supplier account.
- `ORDER_NOT_FOUND` or `ORDER_NOT_OWNED`: This order is unavailable.
- `ORDER_NOT_ACTIONABLE`: This order can no longer be accepted or rejected.
- `RESERVATION_NOT_FOUND`: The stock reservation is unavailable.
- `RESERVATION_EXPIRED`: The stock reservation has expired.
- `ALREADY_CONFIRMED`: This order has already been accepted.
- `ALREADY_REJECTED`: This order has already been rejected.
- `INVALID_REJECTION_REASON`: Choose a valid rejection reason.
- `STOCK_RELEASE_FAILED`: We could not release the reserved stock safely.
- `UNKNOWN`: We could not update this order. Please try again.

Raw SQL errors must not be exposed to the browser.
