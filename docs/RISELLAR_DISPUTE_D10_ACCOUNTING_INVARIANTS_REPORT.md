# Risellar Dispute D10 Accounting Invariants Report

## Summary

D10 protects paid-withdrawal recovery by making liability and recovery explicit, future-facing, and auditable. It avoids destructive ledger rewrites and avoids claiming exact historical allocation where the older withdrawal model did not store per-commission allocation.

## Verified Invariants

- Paid withdrawals are not reversed silently.
- Liability targets remain immutable after creation.
- Recovery cannot exceed the tracked liability boundary.
- Duplicate recovery attempts are blocked or idempotent according to key and payload.
- Same idempotency key with a different commission or payload raises a conflict.
- Future-earnings offset is disabled by default and must be finance-enabled.
- Withdrawal allocation reservations do not enqueue transactional notification outbox events.
- Wallet balances never become negative.
- Available, locked, pending, withdrawn, and recovered concepts remain separate.
- Order, payment, refund, return, stock, reservation, delivery, settlement, commission payout, withdrawal payout, and provider-event tables are not mutated by D10 tests except for the intended D10 recovery/accounting records.

## Regression Coverage

The full required regression batch passed after D10:

- D6 admin dispute SQL and external concurrency.
- D7 return workflow SQL and external concurrency.
- D8 refund workflow SQL and external concurrency.
- D9 finance holds SQL and external concurrency.
- D10 reseller liability SQL and external concurrency.
- Admin settlement verification SQL and concurrency.
- Reseller withdrawal SQL and concurrency.
- Finance history safe-read tests.

## Status

The accounting invariants are verified for the development-only backend/RPC layer. UI and provider integrations remain deferred.
