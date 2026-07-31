# Risellar Finance Visibility Phase 1 Backend Report

## A. Summary

Finance Visibility Phase 1 added safe read-only finance RPC contracts for reseller, supplier, and finance-admin history dashboards. The backend work is scoped to visibility only: it does not create payment movement, settlement movement, commission release, wallet balance changes, withdrawal requests, provider calls, stock changes, or order status changes.

## B. Schema Audit

The implementation uses the existing verified finance flow as the source of truth:

- reseller balances and withdrawals come from the existing reseller wallet/withdrawal model
- reseller earnings come from commission rows
- supplier settlement history comes from supplier payment reports, settlement obligations, and order item finance amounts
- admin finance history is derived from settlement and withdrawal rows
- platform revenue is derived only from verified/paid settlement data

The withdrawal item allocation model remains deferred. Wallet-level pending/withdrawn totals are shown separately from commission-row history so the UI does not fabricate per-commission withdrawn allocation.

## C. RPCs Created

Migration created:

- `supabase/migrations/20260731230000_finance_history_and_dashboard_safe_read_rpcs.sql`

Forward patch migrations created and applied to development after boundary-test runtime bugs:

- `supabase/migrations/20260731231000_fix_finance_summary_currency_column_ambiguity.sql`
- `supabase/migrations/20260731232000_fix_admin_finance_settlement_history_order_id_ambiguity.sql`

Safe read RPCs:

- `get_reseller_finance_summary_safe`
- `list_reseller_earnings_history_safe`
- `list_reseller_withdrawal_history_safe`
- `get_supplier_finance_summary_safe`
- `list_supplier_settlement_history_safe`
- `get_admin_finance_summary_safe`
- `list_admin_settlement_history_safe`
- `list_admin_withdrawal_history_safe`

## D. Security Boundaries

The RPCs use authenticated execution only with explicit owner/admin resolution on the server side. Public and anonymous execution was revoked. User-owned calls resolve the signed-in reseller or supplier through existing verified-role helper functions. Admin finance calls require finance-admin access through the existing admin staff boundary.

The read RPC bodies do not contain `insert`, `update`, `delete`, `for update`, wallet mutation, commission mutation, settlement mutation, withdrawal mutation, order mutation, payment mutation, stock mutation, provider integration, or service-role dependency.

## E. Date And Filter Semantics

Date filters are validated server-side. Invalid status filters are rejected. Pagination uses stable cursor inputs where history lists need it.

Business dates are explicit:

- reseller earnings: commission created/earned timestamp
- reseller withdrawals: requested or paid timestamps
- supplier settlements: payment reported / settlement verified timestamps
- admin settlements: reported / verified timestamps
- admin withdrawals: requested / paid timestamps

Current balances are not treated as selected-period activity. Period totals and current-state totals are kept separate.

## F. Accounting Rules

Verified platform revenue is derived only from paid/verified supplier settlement data. Gross completed sales stay separate from platform revenue. Reseller commission unlocked is separate from withdrawals paid. Multiple currencies are grouped by currency code; no automatic conversion or silent mixing was added.

## G. Boundary Test Result

Development SQL boundary test:

- `npx supabase db query --linked --file scripts/rpc/finance-history-safe-read-rpc-tests-dev-only.sql`
- Result: passed after the two forward patch migrations above

Passed assertions included:

- reseller can read own summary, earnings history, and withdrawal history
- supplier/customer/anonymous are blocked from reseller/admin finance contracts
- supplier can read own finance summary and settlement history
- finance admin can read finance summary, settlement history, and withdrawal history
- support-only admin is blocked from finance summary
- private payout/customer/supplier/admin fields are absent from safe results
- verified platform revenue stays separate from gross sales
- no order, settlement, commission, withdrawal, stock, or audit rows changed from read RPC execution
- fixture/test data rolled back

## H. Runtime Fixes

Two implementation bugs were found by the development boundary tests and fixed with forward migrations:

- `currency_code` ambiguity in summary RPC result queries
- `order_id` ambiguity in admin settlement history query

Both were PL/pgSQL column-name ambiguity issues, not confirmed security gaps. No RLS/RPC/storage policy was weakened.

## I. Development Apply And Runtime Recovery

The original stale port-400 process was identified as PID `16728`, a `node.exe` process for this Risellar workspace. Only that PID was stopped. A fresh server was started on port 400 and served the current uncommitted finance worktree.

After `npm run build`, the dev runtime became stale again because the production build rewrote `.next` while the dev server was still running. The second port-400 process, PID `7096`, was stopped exactly. The generated `.next` directory was removed with a workspace path guard, then a fresh dev server was started on port 400 as PID `16628`.

No source files, migrations, tests, reports, `.env.local`, `node_modules`, `.git`, or Supabase state were deleted or reset.

## J. Commands Run

- `git diff --check`: passed
- `npm test`: passed, 44 files / 255 tests
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed
- `npx supabase db push --dry-run --include-all`: passed before development apply
- `npx supabase db push --include-all`: applied the finance read RPC migration and the two forward fix migrations to the confirmed development project
- `npx supabase db query --linked --file scripts/rpc/finance-history-safe-read-rpc-tests-dev-only.sql`: passed
- final aggregate no-side-effect check: before/after counts and status totals matched for orders, settlements, commissions, withdrawals, stock reservations, and audit logs

## K. Secret And Scope Scan

Secret/scope scan result:

- `.env.local` is ignored and not staged
- `supabase/.temp` is ignored
- `.next` is ignored
- `.codex-dev-server.*.log` files are ignored
- no service-role usage was found in `app/` or `components/`
- no real Clerk/Supabase/service-role values were added in this finance diff
- no bearer tokens, passwords, API secrets, production data, or provider credentials were added
- no new checkout/order/stock/payment/delivery/provider integration was added by this phase

Existing false-positive scan hits are limited to server-only `lib/supabase/admin.ts`, negative test assertions, and older documentation that names environment variable labels.

## L. Targeted Runtime Fix

A live admin route sweep surfaced a React duplicate-key warning in finance-adjacent admin settlement/withdrawal list rendering. The fix was limited to adding index-stable keys to:

- `components/admin/admin-supplier-settlement-rpc-screens.tsx`
- `components/admin/admin-reseller-withdrawal-rpc-screens.tsx`

No RPC, RLS, policy, migration, or finance mutation logic was changed for this UI key fix.

## M. Current Git Status

Intentional finance files are modified/untracked. Recurring metadata-only entries remain visible for `next-env.d.ts`, `package.json`, `package-lock.json`, and `tsconfig.json`; those were not staged.

## N. Completion Result

Backend Finance Visibility Phase 1 is implemented and verified at SQL, static-test, build, typecheck, live role QA, final route-sweep, no-side-effect, and security-scan levels. It is safe to commit the intentional Finance Visibility Phase 1 files.
