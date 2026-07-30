# Risellar Checkout Phase C Order State Machine

## Scope

This is the planned order/reservation state model for the next backend implementation. No code or database changes are included here.

## Initial State

The first real order creation RPC should create the order in:

- `order_status = 'placed_pending_confirmation'`
- `customer_confirmation_status = 'pending'`
- `payment_method = 'pay_on_delivery'`
- `payment_collection_status = 'not_collected'`
- `delivery_status = 'estimate_selected'`
- `delivery_quote_status = 'pending'`

This matches the existing enum vocabulary and the business rule that stock reservation happens at order placement, while customer confirmation remains a separate step.

## Recommended Transitions

| From | To | Actor | Planned RPC | Stock effect |
| --- | --- | --- | --- | --- |
| checkout draft `review_pending` | order `placed_pending_confirmation` | customer | `create_order_from_checkout_draft` | reserve stock |
| `placed_pending_confirmation` | `customer_confirmed` | customer | future `confirm_customer_order` | keep reservation |
| `placed_pending_confirmation` | `cancelled` | customer/support | future `cancel_unconfirmed_order` | release reservation |
| `placed_pending_confirmation` | failed/no order | system RPC | order creation RPC | no partial reservation |
| `placed_pending_confirmation` | `failed` or expired status | system/admin job | future expiry/release RPC | release reservation |
| `customer_confirmed` | `delivery_quote_pending` | support/admin/supplier ops | future delivery phase | no new stock mutation |
| `delivery_quote_ready` | `delivery_quote_approved` | customer | future quote RPC | no new stock mutation |
| `delivered_payment_pending` | `payment_collected` | supplier/admin/finance | future POD settlement phase | convert reserved to sold later |
| payment/settlement verified | `completed` | admin/finance | future settlement phase | sold stock remains |

## Cancellation Rules

Cancellation before customer confirmation should release reserved stock and write an audit log. Cancellation after confirmation, preparation, dispatch, or delivery requires later operations rules because supplier work, delivery, disputes, or payment collection may already be in progress.

## Expiry Rule

Recommended MVP reservation hold: 60 minutes from order creation while `customer_confirmation_status = 'pending'`. Expiry release must be idempotent:

- only active `reserved` reservations can be expired/released
- decrement `reserved_stock_quantity` once
- insert a `reservation_released` or `order_cancelled_release` inventory movement
- update order status only if still in a pre-confirmation state

## Pay-On-Delivery Boundary

Pay on Delivery is the only active payment method in this phase. The order tracks that the customer will pay later, but does not mark payment collected, create payment provider state, create settlement rows, or release commission.

## Delivery Boundary

Delivery estimates and final delivery quote workflow remain separate. Order creation can copy the customer address snapshot and estimate fields already present in the schema, but final delivery quote creation/approval stays deferred.

## Terminal/Blocked States

Use existing enum states for later phases:

- `cancelled`
- `customer_refused`
- `failed`
- `disputed`
- `completed`

Phase C should only implement the minimum states needed for draft conversion, active reservation, cancellation/expiry planning, and safe read visibility.
