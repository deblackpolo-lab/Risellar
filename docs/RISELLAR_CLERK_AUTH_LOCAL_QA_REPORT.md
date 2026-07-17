# Risellar Clerk Auth Local QA Report

## A. Summary

Local auth QA passed for the Clerk profile sync foundation.

The QA verified:

- public routes still render without auth
- Clerk sign-in/sign-up routes render
- protected routes require auth
- middleware does not break static assets
- profile sync helpers keep secrets server-only
- no live business data integration was started

No production Supabase project was connected. No migrations were applied.

## B. Public Route QA

Checked with the local dev server on port 400.

Public route results:

| Route | Result |
| --- | --- |
| `/` | HTTP 200 |
| `/preview` | HTTP 200 |
| `/design-system` | HTTP 200 |
| `/shop/amas-beauty-plug` | HTTP 200 |
| `/shop/amas-beauty-plug/product/nike-air-force-1-07-green-white` | HTTP 200 |
| `/sign-in` | HTTP 200 |
| `/sign-up` | HTTP 200 |

Public shop/product, preview, and design-system mock routes still render without auth.

## C. Protected Route QA

Checked unauthenticated access with browser-style `Accept: text/html` headers.

Protected route results:

| Route | Result |
| --- | --- |
| `/checkout/payment` | HTTP 307 to Clerk dev auth handshake |
| `/customer/orders/rsr-20260713-00021` | HTTP 307 to Clerk dev auth handshake |
| `/reseller/dashboard` | HTTP 307 to Clerk dev auth handshake |
| `/reseller/products` | HTTP 307 to Clerk dev auth handshake |
| `/supplier/dashboard` | HTTP 307 to Clerk dev auth handshake |
| `/supplier/products` | HTTP 307 to Clerk dev auth handshake |
| `/supplier/inventory` | HTTP 307 to Clerk dev auth handshake |
| `/supplier/settlements` | HTTP 307 to Clerk dev auth handshake |
| `/supplier/team` | HTTP 307 to Clerk dev auth handshake |
| `/admin/dashboard` | HTTP 307 to Clerk dev auth handshake |

Checked unauthenticated non-browser-style requests as well; Clerk returned HTTP 404 for protected routes, which is an expected block behavior for non-document requests.

## D. Sign-In/Sign-Up Route QA

- `/sign-in` returned HTTP 200.
- `/sign-up` returned HTTP 200.
- Response bodies contained Clerk sign-in/sign-up content markers.

Manual interactive Google/email-password login was not performed during this QA pass. That remains the next browser/manual QA step if the user wants to validate a real development Clerk session.

## E. Profile Sync Helper Review

Reviewed:

- `lib/auth/profile-sync-core.ts`
- `lib/auth/profile-sync.ts`
- `lib/auth/clerk.ts`

Result: pass.

Findings:

- Clerk ID maps to `public.profiles.clerk_user_id`.
- Email is required and normalized to lowercase.
- Display name is optional.
- Phone number is not required.
- New profiles default to `customer`.
- Reseller, supplier, admin, support, finance, and super-admin roles are not self-assignable.
- Existing profile is read before insert.
- Profile creation uses the server-only helper path.
- No service-role client path was introduced.

Small fix applied during QA:

- Tightened `lib/auth/profile-sync-core.ts` so only `customer` is self-assignable during profile sync.
- Updated `tests/auth-profile-sync.test.ts` to assert reseller/supplier roles are not self-assignable.

## F. Role Guard/Redirect Review

Reviewed:

- `lib/auth/role-redirect.ts`
- `lib/auth/route-guards.ts`
- `middleware.ts`

Result: pass.

Findings:

- Middleware protects checkout account/payment/review/success, customer, reseller, supplier, and admin route families.
- Public preview/design-system/shop routes remain public.
- Route guard helper matches `/supplier/inventory-manager/*` before broader `/supplier/*`.
- Role guard checks use server-verified profile role/onboarding data shape.
- Unauthenticated users are directed to `/sign-in` by redirect helper logic.
- Role redirects use existing role policy defaults.

## G. Secret Safety Review

Result: pass.

Findings:

- `.env.local` exists locally but is ignored.
- `.env.local` is not staged.
- `.env.local` is not tracked.
- `supabase/.temp/` is ignored and not staged.
- `SUPABASE_SERVICE_ROLE_KEY` appears only in server-only Supabase admin/profile sync paths.
- `CLERK_SECRET_KEY` and `SUPABASE_DB_PASSWORD` were not exposed in client code.
- No high-confidence real Clerk/Supabase/service-role values, bearer tokens, passwords, API secrets, or production data were found in source/docs files by the scan.

No secret values were printed.

## H. Issues Found

One issue found and fixed:

- The initial profile sync core allowed requested `reseller` and `supplier_owner` roles as self-assignable. The QA scope requires supplier/reseller roles to come from onboarding/approval later, so this was tightened to customer-only self-assignment.

No major auth behavior break was found.

## I. Fixes Applied

- `lib/auth/profile-sync-core.ts`: changed self-assignable roles to `customer` only.
- `tests/auth-profile-sync.test.ts`: updated expectations for reseller/supplier self-assignment denial.
- `docs/RISELLAR_CLERK_PROFILE_SYNC_FOUNDATION_REPORT.md`: updated security summary to match the stricter self-assignment rule.

No middleware weakening, RLS/RPC/storage weakening, migration, production connection, or business data integration was performed.

## J. Commands Run/Results

Local route QA:

- `npm run dev` - started local dev server on port 400.
- Public route HTTP checks - all requested public routes returned HTTP 200.
- Protected route HTTP checks - all requested protected routes returned HTTP 307 to Clerk dev auth handshake for browser-style requests.
- Static asset check - sampled `/_next/static/css/app/layout.css?...` returned HTTP 200.
- Sign-in/sign-up body check - Clerk content markers found.
- Local dev server was stopped after route QA.

Static/security review:

- `rg` secret/server-only scan across `app`, `components`, `lib`, and `middleware.ts` - server-only references stayed in server helpers.

Tests and build:

- `npm test -- tests/auth-profile-sync.test.ts` - passed; 8 tests.
- `git status --short` - showed expected uncommitted auth foundation files.
- `git diff --check` - passed with line-ending warnings only.
- `npm test` - passed; 20 test files and 93 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - first run failed because `.next/types/**/*.ts` entries were referenced before generated `.next` type files existed; after `npm run build`, rerun passed.

Commands intentionally not run:

- `supabase db push`
- migration apply commands
- destructive reset commands
- production Supabase commands
- checkout/order/product/settlement/commission/payment integration commands
- `npm audit fix --force`

## K. Files Changed

Existing foundation files:

- `app/layout.tsx`
- `app/sign-in/[[...sign-in]]/page.tsx`
- `app/sign-up/[[...sign-up]]/page.tsx`
- `middleware.ts`
- `lib/auth/clerk.ts`
- `lib/auth/profile-sync-core.ts`
- `lib/auth/profile-sync.ts`
- `lib/auth/role-redirect.ts`
- `lib/auth/route-guards.ts`
- `tests/auth-profile-sync.test.ts`
- `docs/RISELLAR_CLERK_PROFILE_SYNC_FOUNDATION_REPORT.md`

New QA report:

- `docs/RISELLAR_CLERK_AUTH_LOCAL_QA_REPORT.md`

## L. Current Git Status

Recorded after report creation:

```text
 M app/layout.tsx
 M lib/auth/clerk.ts
?? app/sign-in/
?? app/sign-up/
?? docs/RISELLAR_CLERK_AUTH_LOCAL_QA_REPORT.md
?? docs/RISELLAR_CLERK_PROFILE_SYNC_FOUNDATION_REPORT.md
?? lib/auth/profile-sync-core.ts
?? lib/auth/profile-sync.ts
?? lib/auth/role-redirect.ts
?? lib/auth/route-guards.ts
?? middleware.ts
?? tests/auth-profile-sync.test.ts
```

## M. Whether Safe To Commit

Safe to commit: yes.

Recommended commit scope:

- `app/layout.tsx`
- `app/sign-in/[[...sign-in]]/page.tsx`
- `app/sign-up/[[...sign-up]]/page.tsx`
- `middleware.ts`
- `lib/auth/clerk.ts`
- `lib/auth/profile-sync-core.ts`
- `lib/auth/profile-sync.ts`
- `lib/auth/role-redirect.ts`
- `lib/auth/route-guards.ts`
- `tests/auth-profile-sync.test.ts`
- `docs/RISELLAR_CLERK_PROFILE_SYNC_FOUNDATION_REPORT.md`
- `docs/RISELLAR_CLERK_AUTH_LOCAL_QA_REPORT.md`

Production remains blocked until separate production auth and Supabase approval exists.
