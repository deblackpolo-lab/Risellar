# Risellar D8 Refund Concurrency Report

## Harness

`scripts/rpc/refund-workflow-d8-concurrency-dev-only.mjs` runs true multi-process checks using separate Supabase linked-query sessions and fake development-only fixtures.

## Scenarios Passed

- Same refund approval with the same idempotency key produced one obligation.
- Same financial scope with different approval keys produced one active obligation.
- Two partial approvals against the same item remaining amount did not exceed the item cap.
- Full-vs-partial approval for the same item produced one valid capped outcome.
- Supplier sent-report retry produced one report action.
- Supplier report vs finance rejection produced one valid final report/reject action.
- Customer confirmed-received vs disputed-not-received produced one customer confirmation outcome.
- Finance verify vs finance reject produced one finance outcome.
- Completion vs report rejection did not allow completion before verification.
- Refund approval vs dispute closure did not leave a closed dispute with a newly approved refund.
- Refund approval vs return decline kept the accepted-return policy consistent.
- Two finance admins verifying simultaneously produced one verification.

## Invariants

The harness verified no duplicate refund/action rows for conflicting races, cumulative item totals stayed within immutable line totals, and no stock, reservation, inventory movement, settlement, commission, withdrawal, notification, delivery, order, or payment side effects were created.

## Cleanup

The harness removes its fake profiles, orders, items, disputes, returns, refund rows, refund actions, and audit rows after each run. No permanent D8 QA refund fixtures are required.
