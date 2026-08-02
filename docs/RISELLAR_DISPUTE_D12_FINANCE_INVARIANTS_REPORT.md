# Risellar Dispute D12 Finance Invariants Report

Date: 2026-08-02

## Verified Invariants

D12 backend regression and concurrency tests verified:

- Refund caps derive from immutable order/item/delivery snapshots.
- Current product price changes do not increase refund caps.
- Cumulative partial refunds cannot exceed maximums.
- Supplier-responsible and platform-responsible refund paths are separated.
- Supplier cannot report another supplier's refund.
- Supplier cannot report platform refunds.
- Support-only admin cannot approve or verify money actions.
- Finance staff can perform approved finance actions only through controlled RPCs.
- Active finance holds block affected settlement verification.
- Unrelated settlements remain unaffected.
- Settlement becomes eligible after blocker release.
- Commission/wallet hold projections keep locked and available values separate.
- Reseller liability amount/currency are derived server-side.
- Reseller cannot approve own liability.
- Future offset is disabled by default and must be enabled by finance.
- Same-currency eligible future commission only is used for offset.
- No cross-currency offset is allowed.
- Withdrawal allocations total exactly to the requested amount.
- The same commission cannot fund two pending withdrawals.
- Disputed allocations block payout.
- Paid withdrawals remain immutable.
- Historical unallocated paid withdrawals are not guessed or backfilled.
- Wallet available-to-withdraw never goes below zero.

## Side-Effect Results

Regression suites reported no unintended mutation to:

- Orders
- Order items
- Payment status/payment reports
- Settlements outside controlled finance RPCs
- Commissions outside controlled finance/withdrawal RPCs
- Wallet projections outside controlled finance/withdrawal RPCs
- Withdrawals outside controlled withdrawal RPCs
- Stock
- Reservations
- Delivery records
- Provider payment/delivery systems

Notification processing was verified as outbox/provider-event only and not a business-state mutator.

## Release Note

Finance backend invariants are verified. Browser release remains blocked by missing support/super-admin QA identities and mock-only dispute/return/refund UI screens.
