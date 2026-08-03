# Risellar Root Auth Role Redirect Report

Date: 2026-08-03

## A. Original Problem

Production `/` rendered the old Phase 1 design foundation shell even though Risellar does not yet have an approved public homepage. Signed-out and signed-in users could see placeholder root content instead of passing through secure account routing.

## B. New Root Behavior

`app/page.tsx` now performs a server-side redirect before rendering UI:

- signed out: `/sign-in`
- active customer: `/customer/dashboard`
- active approved supplier owner role: `/supplier/dashboard`
- active approved reseller role: `/reseller/dashboard`
- active support, finance, admin, or super-admin staff: `/admin/dashboard`
- missing profile mapping: `/auth/qa-profile-sync`
- inactive/restricted/suspended/closed account: existing safe edge-case account status surface
- unknown or inconsistent role: `/sign-in`

The root route no longer renders the Phase 1 shell, design-system link, mock dashboard preview, account cards, or marketing copy.

## C. Server-Side Auth Method

The root route uses Clerk server auth, `getCurrentSyncedProfile`, and Supabase authenticated-user RPC checks for active `admin_staff`. It does not use localStorage, browser-supplied role data, query-string role data, or `profiles.primary_role` as admin authority.

## D. Role Precedence

Deterministic precedence:

1. Signed-out visitors go to `/sign-in`.
2. Missing profile mapping goes to `/auth/qa-profile-sync`.
3. Non-active account statuses go to safe account-status surfaces.
4. Active `admin_staff` wins over `primary_role` for root routing.
5. Workspace roles route by verified server profile role.
6. Unknown/inconsistent roles do not reach a dashboard.

This keeps mixed customer/admin QA accounts out of customer-only workflows. Support staff can reach `/admin/dashboard`, but finance RPCs still enforce finance/admin authority and do not grant support-only users finance mutation or finance-private reads.

## E. Redirect-Loop Protection

The root resolver never redirects authenticated users back to `/`. `/sign-in` remains outside the protected route matcher and is not hardcoded to a role dashboard. Dashboard route guards remain active for direct URL access.

## F. Tests Added

`tests/root-auth-redirect.test.ts` covers signed-out, customer, supplier, reseller, support, finance, admin/super-admin, mixed-role precedence, inactive/suspended, onboarding, missing profile, unknown role, no old shell rendering, no client-side role authority, wrong-role blocking, and customer disputes unaffected.

Updated `tests/real-dashboard-metrics-safe-read.test.ts` to assert the new root/admin-dashboard access helper while preserving finance RPC protections.

## G. Local Browser QA

Local unauthenticated HTTP request to `http://localhost:400/` returned a server redirect to `/sign-in`.

The current Codex browser customer session opened `http://localhost:400/` and landed on `/customer/dashboard` without rendering the old Phase 1 design shell.

Other role redirects are covered by focused root resolver tests unless each role is manually signed into the browser.

## H. Production QA

Pending final post-push Vercel smoke check. Local build includes `/` as a dynamic route and `/customer/disputes` as a dynamic customer route.

## I. Security And Scope Scan

Passed before commit:

- `.env.local`, `supabase/.temp`, `.next`, and `.codex-dev-server-401.*.log` are ignored.
- No service-role reference was found in `app/`, `components/`, or `middleware.ts`.
- Root redirect source does not use localStorage, browser cookies, window location role data, query-string role data, or `profiles.primary_role` as admin authority.
- Broader secret scan found only key-name placeholders, environment-presence checks, server-only helper references, and negative test/doc assertions. No real secret values, bearer tokens, API secrets, cookies, JWTs, profile IDs, or production data were added.
- No checkout, order, payment, delivery, settlement, commission, withdrawal, stock, inventory, or dispute workflow integration was changed by this root-route patch.

## J. Commands

- `git diff --check`: passed with Windows line-ending warnings only.
- `npm test`: passed, 50 files and 309 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.
- `curl.exe -I --max-time 10 http://localhost:400/`: returned `307 Temporary Redirect` with `location: /sign-in`.
