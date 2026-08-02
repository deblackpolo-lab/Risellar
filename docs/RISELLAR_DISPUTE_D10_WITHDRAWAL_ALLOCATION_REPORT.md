# Risellar Dispute D10 Withdrawal Allocation Report

## Summary

D10 treats the existing withdrawal model conservatively. It does not invent historical per-commission allocation for paid withdrawals. Instead, it adds explicit future-only allocation behavior for new recovery interactions and verifies that allocation reservation is idempotent and race-safe.

## Behavior

- Pending withdrawal interaction remains controlled by finance RPCs.
- Paid withdrawal recovery is represented by explicit liability/recovery records.
- Allocation reservation for future earnings is deterministic and idempotent.
- Duplicate active allocation against the same commission is blocked or handled safely.
- Existing paid withdrawals are not mutated or reversed.
- Allocation audit action normalization prevents unrelated notification outbox enqueueing.

## Verification

Development-only SQL and external concurrency tests passed. The full regression batch confirmed the allocation model does not mutate orders, payments, refunds, stock, delivery, settlements, commission payouts, withdrawal payouts, notification outbox rows, or provider event rows.

## Deferred

Real provider collection, customer-facing refunds, exact historical paid-withdrawal allocation reconstruction, and payout automation remain explicitly deferred.
