# Risellar Dispute D10 Concurrency Report

## Summary

D10 concurrency verification used a development-only external harness to prove reseller liability and withdrawal-recovery races serialize safely. The harness runs independent Supabase CLI child processes so each actor uses a separate database backend session.

## Scenarios Verified

- Same idempotency key for the same liability request returns one durable result.
- Same liability scope with different keys does not create duplicate active liability records.
- Two future-earnings offsets against one liability cannot over-apply recovery.
- Two withdrawals racing for the same commission cannot reserve the same available amount twice.
- Allocation dispute and payout-style withdrawal flow remain serialized without negative wallet or duplicate allocation.

## Invariants

The harness verifies distinct database sessions, safe conflict or retry behavior, no duplicate business transitions, no negative balances, no duplicate audit rows for idempotent retries, no direct paid-withdrawal reversal, and no notification/provider side effects.

## Result

The D10 concurrency harness passed in DEVELOPMENT. The final required D10 regression batch also reran D10 concurrency successfully alongside D6, D7, D8, D9, settlement, withdrawal, and finance-history regressions.

## Scope

No production project was used. No UI, provider integration, payment, refund, stock, delivery, settlement payout, commission payout, withdrawal payout, customer purchase flow, or notification send path was introduced.
