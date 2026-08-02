# Risellar Disputes D9 Commission Hold Report

## Summary

D9 adds commission availability holds that preserve historical commission rows while reducing reseller-safe withdrawable projections.

## Behavior

- Commission amount, status history, and order item price snapshots remain unchanged.
- Active commission holds reduce projected reseller available balance.
- Reseller withdrawal requests respect active commission holds.
- Paid withdrawals are not reversed.
- A withdrawal review hold requires an outstanding requested withdrawal.

## Verification

D9 SQL verified:

- Super-admin can create a commission hold.
- The hold references the specific commission.
- Historical commission amount and status remain unchanged.
- Gross/platform/net snapshots remain unchanged.
- No commission row is deleted.
- Wallet safe read reflects active hold impact.
- Over-held withdrawal is blocked.
- Withdrawal below held-safe available can proceed.
- No negative wallet state is created.

D9 concurrency verified:

- Commission hold vs withdrawal request does not allow unsafe withdrawal.
- Withdrawal review hold vs payout does not allow a paid withdrawal plus stale active withdrawal hold.

## Deferred

D9 does not implement paid-withdrawal reversal, future earnings offsets, automatic clawback, or negative balance creation.
