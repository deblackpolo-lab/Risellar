# Risellar Dispute D10 Future Earnings Offset Report

## Summary

D10 supports a finance-controlled future-earnings offset path for reseller liability recovery. The offset path is disabled by default and must be explicitly enabled by an authorized finance actor.

## Controls

- Finance authorization uses active finance-capable `admin_staff` membership.
- Future offsets cannot be enabled by customer, supplier, reseller, inactive admin, or unsupported staff roles.
- Recovery attempts are idempotency-keyed.
- Reusing the same idempotency key with a different commission or payload raises a conflict.
- Offset application cannot exceed the liability boundary.
- Concurrent offset attempts serialize without over-recovery.

## Verification

The D10 SQL suite passed 49 assertions. The D10 external concurrency harness passed all recovery/offset race scenarios. Regression suites for D6 through D9, settlement verification, reseller withdrawal, and finance-history safe reads also passed after the D10 patch.

## Scope

No live collection, payment processor, refund processor, order mutation, stock reservation, delivery, settlement payout, commission payout, withdrawal payout, or customer purchase path was connected.
