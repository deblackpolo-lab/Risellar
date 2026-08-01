# Risellar Dispute D6 Admin Investigation Backend Report

## Summary

D6 added controlled backend-only admin/support dispute investigation RPCs for the confirmed DEVELOPMENT Risellar Supabase project.

Implemented RPCs:

- `admin_assign_dispute(uuid, uuid, text)`
- `admin_request_dispute_information(uuid, text, text, text, text)`
- `admin_change_dispute_status(uuid, text, text, text, text)`
- `admin_record_non_financial_resolution(uuid, text, text, text, text)`
- `admin_close_dispute(uuid, text, text, text)`

No dispute UI was activated. No admin pages, buttons, forms, or routes were created.

## Migration Result

Applied to DEVELOPMENT:

- `20260801160000_admin_dispute_investigation_and_resolution_rpcs.sql`

Forward fix applied to DEVELOPMENT:

- `20260801161000_fix_admin_dispute_rowtype_reads.sql`

The forward fix corrected composite rowtype reads in the already-applied D6 RPCs. It did not change RLS, table grants, state rules, or business side effects.

## Verification

Development-only SQL boundary test:

- `scripts/rpc/admin-dispute-investigation-resolution-tests-dev-only.sql`
- Result: 103 assertions passed
- Fixtures: wrapped in transaction and rolled back

External concurrency harness:

- `scripts/rpc/admin-dispute-d6-concurrency-dev-only.mjs`
- Result: 12 true two-session scenarios passed
- Invariants: 61 checks passed
- Fixtures: isolated DEVELOPMENT-only records were cleaned after verification

Verified:

- anonymous/customer/supplier/reseller blocked
- inactive/suspended admin blocked
- finance-only staff blocked
- support/admin/super admin allowed through controlled RPCs
- assignment idempotency and conflict handling
- information request targeting and privacy
- controlled status transition matrix
- non-financial resolution mapping
- closure eligibility
- direct table writes blocked
- customer/supplier/reseller safe-read privacy
- no order/payment/stock/reservation/settlement/commission/wallet/withdrawal/return/notification side effects
- independent concurrent D6 sessions do not create duplicate messages/history/audits/actions, conflicting resolutions, orphan closure, or terminal-state participant responses

## Defects And Fixes

Defect found after first D6 apply:

- Composite row reads used `select od` / `select daa` into rowtype variables.
- Runtime effect: invalid UUID syntax when assigning composite text into the first rowtype field.
- Classification: D6 RPC implementation bug, not a confirmed authorization or privacy gap.

Fix:

- Forward migration `20260801161000_fix_admin_dispute_rowtype_reads.sql`.
- Replaced composite row reads with expanded row reads in the five D6 RPCs.

Dev-only test harness fixes:

- Adjusted fixture dispute reason/outcome tuples to satisfy existing active-dispute uniqueness.
- Reset role context before protected-table verification queries.
- Added a two-process concurrency harness with a harness-local result recorder for simulated authenticated sessions.

No forward concurrency defect migration was required after the two-session harness passed.

## Current Boundary

D6 remains backend-only. Return execution, refund execution, finance holds, settlement changes, commission changes, wallet changes, withdrawal changes, stock changes, notifications, evidence uploads, and UI remain deferred.
