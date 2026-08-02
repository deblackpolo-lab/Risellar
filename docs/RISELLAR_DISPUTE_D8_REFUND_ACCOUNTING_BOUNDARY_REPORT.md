# Risellar D8 Refund Accounting Boundary Report

## Boundary

Risellar still uses the Pay on Delivery model in development: the customer pays the supplier directly, and Risellar records supplier payment reports and later finance verification. D8 therefore models refund obligations and manual refund verification only. It does not move money.

## Amount Authority

Refund amounts are capped from immutable order snapshots:

- Item value uses `order_items.line_total_amount`.
- Delivery fee uses `orders.final_delivery_amount`; if the snapshot is missing, the refundable delivery fee maximum is zero.
- Order-level total uses `orders.total_payable_amount`.
- Currency is derived from the order `currency_code`.
- Current product price is never used as refund authority.

## Components

The approved amount must equal:

- `item_amount_component`
- plus `delivery_fee_component`
- plus `goodwill_component`

D8 keeps goodwill deferred by requiring `goodwill_component = 0` and rejecting `goodwill_refund`.

## Cumulative Caps

D8 enforces:

- exact active duplicate prevention for the same dispute/scope/type/responsibility,
- cumulative item component caps across active, verified, and completed obligations for the same order item,
- cumulative delivery fee caps for the order,
- cumulative order approved amount caps for the order.

The cumulative cap trigger was added as a forward fix after the implementation review identified that order-wide caps alone were not sufficient for same-item multi-dispute races.

## Deferred Accounting

D8 intentionally does not create or mutate:

- supplier settlements,
- reseller commissions,
- reseller wallets,
- withdrawals,
- finance holds,
- stock reservations,
- inventory movements,
- payment provider refunds,
- payout provider transfers.

D9 may begin with finance holds and accounting adjustments only after the D8 manual obligation boundary is accepted.
