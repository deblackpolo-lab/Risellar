# Risellar Disputes D9 Finance Concurrency Report

## Summary

D9 includes a development-only multi-process concurrency harness for finance holds, settlement blockers, commission holds, withdrawal review boundaries, liability records, and side-effect invariants.

## Harness

Script:

- `scripts/rpc/dispute-finance-holds-d9-concurrency-dev-only.mjs`

The harness uses fake development-only fixtures and cleans up exact fixture IDs. It uses a per-run nonce to avoid collisions if a transient transport failure interrupts cleanup.

## Scenarios Passed

1. Same-key hold approval.
2. Same-scope different-key hold race.
3. Settlement verification vs hold creation.
4. Release vs verify.
5. Commission hold vs withdrawal.
6. Compatible multiple finance hold types.
7. Release vs cancel.
8. Withdrawal review hold vs payout.
9. Two finance users creating supplier liabilities.
10. Adjustment apply vs cancel.
11. Settlement review vs refund state.
12. Side-effect invariants.

## Findings and Fixes

The concurrency run exposed one real D9 race:

- If payout won before a withdrawal review hold was inserted, a stale active withdrawal review hold could still be created.

Fix:

- Added a forward trigger guard requiring an outstanding `requested` withdrawal before inserting/updating an active `withdrawal_review_hold`.

## Result

D9 concurrency passed after forward fixes.
