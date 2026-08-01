# Risellar Dispute D4 Customer Concurrency Report

## Summary

True parallel linked-query probes were run against isolated DEVELOPMENT-only fixtures to verify D4 idempotency and active-case protection under concurrent requests. Fixture records were cleaned after verification.

## Cases Tested

1. Two simultaneous `customer_open_order_dispute` calls using the same idempotency key.
2. Two simultaneous `customer_open_order_dispute` calls using different keys but the same active-dispute fingerprint.
3. Two simultaneous `customer_add_dispute_response` calls using the same idempotency key.

## Results

- Same-key open: one call created the dispute and the other returned the existing safe result.
- Active-fingerprint open: one active dispute existed after concurrent calls.
- Same-key response: one message existed after concurrent calls.
- No orphan status-history rows were observed.
- Fixture order/payment statuses remained unchanged.
- No unique-violation details were exposed in successful loser-call results.

## Cleanup

The concurrency fixtures were removed after verification. A cleanup check returned zero matching fixture profiles, orders, and disputes.

## Caveat

Response-versus-case-closure was not exercised through a real admin closure RPC because D4 intentionally does not create admin mutation RPCs. That scenario remains for a future admin dispute group.

## Commands

- Fixture setup: passed.
- Parallel same-key open batch: one call created, one returned existing.
- Parallel active-fingerprint open batch: one call created, one returned existing.
- Parallel same-key response batch: one call created, one returned existing.
- Verification query: all six concurrency assertions passed.
- Cleanup query: passed.
- Cleanup verification query: zero matching fixture profiles, orders, and disputes remained.

## Conclusion

D4 concurrency protections are verified for the customer-owned open and response paths that D4 implements.
