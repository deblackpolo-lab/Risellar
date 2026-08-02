# Risellar Disputes D9 Settlement Interaction Report

## Summary

D9 blocks supplier settlement verification when unresolved dispute/refund finance review or active settlement/refund accounting holds exist. It preserves the existing settlement verification flow when no blocker exists.

## Behavior

- Active `settlement_verification_block`, `refund_accounting_hold`, `supplier_liability_hold`, or `platform_liability_hold` blocks settlement verification.
- Open dispute finance review or refund statuses that still require accounting review block settlement verification.
- Released/cleared blockers allow the existing settlement verification RPC to proceed.
- Unrelated supplier settlements remain isolated and verifiable.

## Important Boundary

Commission availability holds and withdrawal review holds reduce reseller withdrawable projections but do not automatically block supplier settlement verification unless a settlement/refund blocker also exists.

## Verification

D9 SQL verified:

- Settlement verification is blocked by active settlement hold.
- Release requires blockers to be resolved.
- Settlement verifies after dispute/refund blockers are cleared.
- `allow_verification` review is blocked when a settlement-blocking hold is active.
- Unrelated supplier settlement can still verify.

D9 concurrency verified:

- Settlement verification vs hold creation does not leave both a paid settlement and an active settlement blocker.
- Release vs verify does not make commission available while an active settlement blocker remains.

## Deferred

No settlement recovery, clawback, provider payment, or automatic liability collection was implemented.
