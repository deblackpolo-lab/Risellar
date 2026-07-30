# Risellar Checkout Phase C C4 Customer Order Read Model Plan

## Summary

The order-creation RPC returns a customer-safe order summary, and the migration also defines `checkout_order_safe_row(uuid)`. The current application pages under `/customer/orders` and `/checkout/success` are still mock/placeholder screens. Before the final order-confirmation UI is enabled, the app needs a reviewed customer order read boundary.

## Existing Backend Contract

Existing function:

`public.checkout_order_safe_row(p_order_id uuid)`

Observed public-safe output categories:

- order id and order number
- checkout draft id
- order/payment/delivery/customer confirmation statuses
- customer id
- reseller/shop/product linkage ids
- product name and product slug from checkout draft snapshot
- quantity
- final customer price amount
- line total and payable total
- currency
- reservation status and reservation expiry
- created and updated timestamps

The function filters by participant access or admin support access. It does not expose supplier base price, platform margin, reseller margin, payout data, commission ledger data, settlement ledger data, private supplier contacts, risk score, or admin notes.

## Current UI State

Current source review found:

- `/customer/orders` renders `CustomerOrdersScreen`, which is a placeholder/mock customer order state.
- `/customer/orders/[id]` renders `CustomerOrderTrackingScreen`, which uses mock order data.
- `/checkout/success` renders `CheckoutSuccessScreen`, which explicitly states that no order was created.
- No app helper currently wraps `checkout_order_safe_row(uuid)` for customer order pages.
- No customer order list RPC/helper is currently wired.

## C5 Backend-Read Requirement

C5 should be treated as required before enabling final order confirmation in the UI.

Minimum acceptable C5 result:

- A server-only helper for reading a single customer-owned order through `checkout_order_safe_row(uuid)`.
- Tests proving customer A can read only customer A order.
- Tests proving customer B, reseller, supplier, and unauthenticated users cannot read another customer order.
- Tests proving sensitive supplier/reseller/admin/finance fields are not mapped to UI data.
- Tests proving no direct table reads are added in client components.

Preferred C5 result:

- A dedicated `get_customer_order(p_order_id uuid)` RPC or a documented decision that `checkout_order_safe_row(uuid)` is the safe read contract.
- A dedicated `list_customer_orders()` RPC if `/customer/orders` is to show real order history.
- Boundary tests for both single-order and list reads.

## Order Detail Page Plan

Future route:

`/customer/orders/[id]`

The page should show only:

- order number
- order status
- customer confirmation status
- payment method and payment collection status
- delivery status and delivery quote status
- product name
- quantity
- final customer price
- total payable amount
- selected delivery/contact snapshot
- reservation status and expiry
- created timestamp

The page must not show:

- supplier base price
- platform margin
- reseller margin
- commission amount
- settlement amount
- supplier payout data
- supplier private contact data
- risk score
- admin/internal notes

## Order List Plan

Future route:

`/customer/orders`

Initial live scope should be narrow:

- list only the signed-in customer's own orders
- show order number, product name, status, total payable, payment method, and created timestamp
- hide finance/internal fields
- keep confirmation, delivery quote, returns, refunds, and support actions disabled or planned until their backend phases are verified

## Route Protection

Existing policy protects:

- `/checkout/draft/:slug*` for `customer`
- `/checkout/success` for `customer`
- `/customer/:slug*` for `customer`

Future implementation should keep:

- unauthenticated users redirected to Clerk
- reseller/supplier/admin profiles blocked unless their primary role is also customer according to current route policy
- admin support access handled only through a separate admin route if needed, not by customer pages

## C4 Decision

Do not wire the final order-confirmation action until C5 confirms the order-read model. The backend creation RPC is verified, but the app still needs a safe post-order read path for refresh, success display, and customer order history.
