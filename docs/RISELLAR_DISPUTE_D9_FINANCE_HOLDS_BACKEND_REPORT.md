# Risellar Disputes D9 Finance Holds Backend Report

## Summary

Disputes D9 adds backend-only finance hold and adjustment controls for development Supabase. It introduces append-only finance review records and audited RPCs for finance staff/super-admin review of dispute-linked settlement, refund, commission, reseller, supplier, and platform exposure.

No UI route, form, button, hook, or client fetcher was activated.

## Development Scope

- Applied to the confirmed DEVELOPMENT Supabase project only.
- No production Supabase connection was used.
- No provider payment/refund, stock action, notification send, withdrawal recovery, negative-wallet, or future-earnings-offset workflow was implemented.
- Existing paid withdrawals remain preserved; D9 does not reverse paid withdrawals.

## Backend Objects

Created:

- `public.finance_holds`
- `public.finance_adjustments`
- `public.finance_actions`

Primary RPCs:

- `finance_create_dispute_hold`
- `finance_release_dispute_hold`
- `finance_cancel_dispute_hold`
- `finance_review_disputed_settlement`
- `finance_hold_reseller_commission`
- `finance_release_reseller_commission_hold`
- `finance_apply_adjustment`
- `finance_cancel_adjustment`

Safe reads:

- `list_finance_holds_safe`
- `get_finance_hold_safe`
- `list_finance_adjustments_safe`
- `get_finance_adjustment_safe`
- `get_reseller_finance_hold_impact_safe`
- `list_supplier_liabilities_safe`
- `get_supplier_liability_safe`
- `get_dispute_finance_review_summary_safe`

## Forward Fixes

Forward patches were required after the first D9 migration was applied:

- Audit actor role casting for `audit_logs.actor_role`.
- Reseller hold projection through direct hold, commission, and order links.
- Withdrawal review hold race guard.
- Withdrawal guard schema correction.

These were implemented as forward migrations; the already-applied D9 migration was not edited as the only fix.

## Verification

D9 SQL boundary test passed with 52 assertions. D9 multi-process concurrency harness passed 12 scenarios.

The D8 refund regression was updated to reflect the intentional D9 creation of `finance_holds`: D8 now asserts that refund workflow creates no finance hold rows, rather than asserting the table does not exist.

## Result

D9 backend finance holds and settlement controls are complete for backend QA. D10 may plan UI/read-only operational surfacing, but withdrawal recovery, negative balances, provider refunds/payments, and stock actions remain deferred.
