# Risellar Supplier Order Test and QA Plan

## Development-Only SQL Boundary Tests

Planned scripts:

- `scripts/rpc/supplier-order-safe-read-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-decision-rpc-tests-dev-only.sql`

The scripts should use fake development fixtures, wrap test data in transactions when possible, and roll back/clean up. They must not use production data or print private identifiers.

## Safe Read Tests

Required assertions:

1. Supplier owner can read own order.
2. Supplier staff with approved read permission can read own order if staff support is included.
3. Supplier cannot read another supplier's order.
4. Customer cannot call supplier order read RPC.
5. Reseller cannot call supplier order read RPC.
6. Admin staff does not satisfy supplier route/helper contract.
7. Anonymous caller is blocked.
8. Missing or unauthorized order does not leak existence.
9. Customer fulfilment fields are limited to necessary snapshot fields.
10. Reseller private contact is absent.
11. Platform margin, reseller margin, commission, settlement, payout, and risk fields are absent.
12. Deleted order/item rows are hidden.

## Decision Tests

Required assertions:

1. Supplier accepts own actionable order.
2. Accept changes only supplier decision/order status.
3. Reservation remains `reserved` after accept.
4. Duplicate accept returns the same accepted state.
5. Supplier cannot accept another supplier's order.
6. Customer, reseller, admin, and anonymous callers are blocked.
7. Supplier rejects own actionable order.
8. Reject changes order to rejected state.
9. Reject marks reservation `released`.
10. Reject decrements `reserved_stock_quantity` once.
11. Duplicate reject does not double-release.
12. Reserved stock never becomes negative.
13. Rejection reason is required and allowlisted.
14. Rejection note is optional and length-limited.
15. Expired reservation cannot be accepted.
16. Accepted order cannot be rejected.
17. Rejected order cannot be accepted.
18. Failed transaction leaves no partial order/reservation/variant state.
19. No payment is collected.
20. No delivery quote/job is created.
21. No supplier preparation is created.
22. No commission is released.
23. No settlement is completed.
24. No withdrawal is created.
25. Audit events are created.
26. Fixtures roll back or are cleaned up.

## Concurrency Tests

Plan true two-session tests for:

- accept versus reject on the same order
- two concurrent reject attempts
- repeated accept retry
- rejection versus future expiry release
- lock waits ending in one terminal decision
- reserved stock decremented once under racing rejection attempts

Expected outcome: exactly one terminal decision wins, the loser receives a safe idempotent or not-actionable response, and stock counters remain valid.

## Browser QA

Future browser QA should verify:

- supplier owner can open `/supplier/orders`
- supplier owner can open `/supplier/orders/[orderId]`
- supplier sees only own new orders
- safe list/detail fields render
- accept updates the page and customer order status
- reject requires reason and confirmation
- reject releases stock in development database
- duplicate browser submit shows stable final state
- customer order page reflects accepted/rejected status
- non-supplier accounts are blocked
- no payment, delivery, preparation, settlement, commission, or withdrawal UI is activated

## Normal Validation

Each implementation group should run:

- `git status --short`
- `git diff --check`
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- `npx tsc --noEmit` when requested

Also run a secret/scope scan for ignored local files, service-role imports, private identifiers, and accidental checkout/payment/delivery/finance expansion.
