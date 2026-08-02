# Risellar Disputes D9 Withdrawal Boundary Report

## Summary

D9 integrates dispute finance holds with reseller withdrawal safety without implementing withdrawal reversal, negative balances, or future earning offsets.

## Boundaries

- Active commission/reseller/withdrawal holds reduce projected withdrawable balance.
- Withdrawal request RPC uses hold-aware available balance.
- Over-held withdrawal is blocked.
- Safe lower withdrawal can proceed when there is sufficient held-adjusted available balance.
- Existing paid withdrawals are preserved.
- A withdrawal review hold must correspond to an outstanding requested withdrawal.

## Verification

D9 SQL verified:

- Wallet safe read reflects active hold impact.
- Over-held withdrawal fails with insufficient available balance.
- No negative wallet state is created.
- Paid withdrawal status remains unchanged.

D9 concurrency verified:

- Commission hold vs withdrawal cannot create unsafe withdrawal.
- Withdrawal review hold vs payout cannot leave a stale active hold after payout wins.

## Deferred

Not implemented in D9:

- Paid-withdrawal reversal.
- Negative wallet balance.
- Future commission offset.
- Payment provider refund/payment workflow.
- Automatic recovery collection.
