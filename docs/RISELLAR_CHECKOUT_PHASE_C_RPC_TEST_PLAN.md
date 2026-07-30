# Risellar Checkout Phase C RPC Test Plan

## R6 boundary result update

R6 reran the development-only `create_order_from_checkout_draft` boundary suite after applying the forward direct-write grant hardening migration and correcting the test harness context. The suite passed with all returned assertions marked `passed = true`.

The four previous failures were resolved:

- customer commercial snapshot mutation is blocked by permission/RLS
- reserved stock increments once
- duplicate confirmation returns the same order and does not double-reserve
- insufficient-stock failure leaves no partial order/item/reservation and preserves reserved-stock baseline

True two-session oversell concurrency is still not verified. Do not treat the single-session boundary suite as concurrency proof.

## Test Script

Future development-only script:

```text
scripts/rpc/checkout-order-stock-rpc-tests-dev-only.sql
```

The script must use fake/dev-only fixture data inside `begin`/`rollback`. It must not use production data and must not leave persistent orders, reservations, movements, payments, delivery quotes, commissions, settlements, or withdrawals.

## Positive Assertions

- customer can create an order from own `review_pending` checkout draft
- order starts with `order_status = 'placed_pending_confirmation'`
- payment method is `pay_on_delivery`
- payment collection status is `not_collected`
- customer confirmation status is `pending`
- order item snapshot stores server-calculated price/margin/commission/settlement amounts
- stock reservation row is created with `reservation_status = 'reserved'`
- variant `reserved_stock_quantity` increments by order quantity
- inventory movement is created with reservation movement type
- audit log rows are created
- repeated call for same draft returns/reuses one order and does not double-reserve

## Negative Assertions

- unauthenticated context cannot create order
- reseller cannot create customer order
- supplier cannot create customer order
- admin cannot create an order as a customer through the customer RPC unless a separate support/admin override RPC is explicitly designed
- customer A cannot convert customer B draft
- abandoned draft cannot be converted
- bare `draft` without delivery address cannot be converted
- already converted draft cannot create a second order
- inactive listing cannot create order
- archived listing cannot create order
- pending/rejected/hidden product cannot create order
- inactive/unapproved supplier cannot create order
- inactive/deleted variant cannot create order
- insufficient stock blocks order creation
- browser-sent price/margin/status fields are impossible to pass
- another customer's address cannot be attached through draft conversion

## Side-Effect Assertions

After the positive order creation test:

- exactly one order is created for the draft
- exactly one order item is created
- exactly one active reservation is created
- exactly one reservation movement is created
- no `delivery_quotes` rows are created
- no `settlements` rows are created
- no `commissions` rows are created
- no `withdrawals` rows are created
- no payment/provider rows are created

## Concurrency Simulation

Use two fake customers and one variant with one available unit:

1. Customer A creates a draft and places an order for quantity 1.
2. Customer B creates a draft for the same listing and attempts to place an order for quantity 1.
3. Customer A succeeds.
4. Customer B receives `INSUFFICIENT_STOCK`.
5. Reserved quantity remains 1 and never exceeds total stock.

This is not a full parallel transaction test, but it verifies the row-locking and stock math boundary.

## Reservation Release Tests

If Group C2 includes release/cancel RPCs, assert:

- customer can cancel own unconfirmed order
- cancellation releases stock once
- repeated cancellation is idempotent
- expired reservations can be released by support/admin/system context
- confirmed orders cannot be cancelled through unconfirmed cancellation RPC

If release/cancel is deferred, document that active reservations require a follow-up implementation before broad manual QA.

## Result Table Harness

Any temporary result table used after simulated role changes must grant only temp-table permissions needed by simulated roles:

```sql
grant select, insert, update on table checkout_order_stock_test_results to authenticated;
```

Do not grant permissions on real application tables from the test harness.
