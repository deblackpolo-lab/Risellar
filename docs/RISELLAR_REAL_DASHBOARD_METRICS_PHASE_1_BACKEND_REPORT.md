# Risellar Real Dashboard Metrics Phase 1 Backend Report

## A. Summary

Real Dashboard Metrics Phase 1 replaces placeholder dashboard metrics with read-only, role-scoped Supabase RPC reads for customer, reseller, supplier, and finance-admin dashboard surfaces in the confirmed development project.

## B. Migrations

- `supabase/migrations/20260731234500_real_dashboard_metrics_safe_read_rpcs.sql`
- `supabase/migrations/20260731235000_fix_dashboard_metrics_supplier_currency_ambiguity.sql`

The first migration adds safe dashboard summary RPCs. The forward patch fixes the supplier dashboard currency selection ambiguity without weakening RLS/RPC behavior.

## C. RPCs

- `get_customer_dashboard_summary_safe`
- `get_reseller_dashboard_summary_safe`
- `get_supplier_dashboard_summary_safe`
- `get_admin_dashboard_summary_safe`

The RPCs are `SECURITY DEFINER`, use a fixed `search_path`, are granted only to `authenticated`, and do not accept browser-supplied tenant identifiers.

## D. Security Model

Dashboard reads use Clerk native session tokens through the user-context Supabase server client. Service role access is not used by dashboard routes or client components.

Role scoping remains server-side:

- customer dashboard resolves the current profile
- reseller dashboard resolves the verified reseller
- supplier dashboard resolves the verified supplier owner
- admin dashboard requires finance admin access through `admin_staff` / `has_admin_role('finance_staff')`

No checkout, order creation, payment, delivery, settlement verification, withdrawal payment, stock reservation, commission release, or payout mutation path was added by this phase.

## E. Data Separation

Current-state metrics remain separate from selected-period metrics.

Finance totals are grouped by currency. No silent currency conversion is performed.

Verified platform revenue is separate from gross completed sales. Pending supplier settlements are not counted as verified platform revenue, and pending reseller withdrawals are not counted as paid withdrawals.

## F. Boundary Test Result

The development-only dashboard RPC boundary test passed after the supplier currency ambiguity patch.

Verified assertions included:

- customer reads own dashboard counts
- reseller reads own balances and period metrics
- supplier reads own order and finance metrics
- finance admin reads dashboard finance metrics
- support staff cannot read finance dashboard
- anonymous users are blocked
- dashboard reads do not mutate order, payment, settlement, commission, withdrawal, stock, or audit rows

## G. Commands Run

- `npx supabase db push` applied the dashboard RPC migration to development only.
- `npx supabase db push` applied the UUID/currency patch migration to development only.
- `npx supabase db query --linked --file scripts/rpc/real-dashboard-metrics-safe-read-rpc-tests-dev-only.sql` passed.
- `git diff --check` passed with line-ending normalization warnings only.
- `npm test` passed: 46 files, 269 tests.
- `npm run lint` passed.
- `npm run build` passed.
- `npm run typecheck` passed.
- `npx tsc --noEmit` passed.

## H. Secret And Scope Safety

No secrets, JWTs, cookies, service-role values, production project identifiers, or private QA identifiers are documented here.

`.env.local`, `.next`, `.local-recovery`, `supabase/.temp`, and `.codex-dev-server.*.log` remain ignored and must not be staged.

## I. Files Changed

- dashboard RPC migrations
- dashboard SQL boundary test script
- dashboard server helpers
- role-specific dashboard routes
- shared dashboard UI component
- finance admin route gate helper
- focused tests

## J. Current Status

Backend foundation is ready to commit after final file-scope review and staging.
