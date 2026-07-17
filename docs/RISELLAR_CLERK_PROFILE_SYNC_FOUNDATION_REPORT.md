# Risellar Clerk Profile Sync Foundation Report

## A. Summary

Implemented the safe Clerk-to-Supabase profile sync foundation only.

This work keeps the current mock frontend intact and does not connect checkout, products, orders, settlements, commissions, payments, Resend, WhatsApp, or production Supabase data.

## B. Clerk Setup Changes

- Wrapped the root app layout in `ClerkProvider`.
- Added Clerk-hosted route surfaces:
  - `/sign-in/[[...sign-in]]`
  - `/sign-up/[[...sign-up]]`
- Added `middleware.ts` with Clerk auth protection for sensitive route families:
  - `/checkout/account`
  - `/checkout/delivery`
  - `/checkout/payment`
  - `/checkout/review`
  - `/checkout/success`
  - `/customer/*`
  - `/reseller/*`
  - `/supplier/*`
  - `/admin/*`

Public mock/review and storefront routes remain outside middleware protection:

- `/`
- `/preview`
- `/design-system`
- `/shop/*`

## C. Supabase Profile Sync Changes

Added profile sync helpers:

- `lib/auth/profile-sync-core.ts`
- `lib/auth/profile-sync.ts`

The core helper:

- normalizes Clerk user id, email, and display name
- lowercases email before insert
- defaults new profiles to `customer`
- blocks reseller, supplier, admin, support, finance, and super-admin self-assigned roles
- finds an existing profile before attempting insert
- creates a profile insert payload only for supported `public.profiles` columns

The server helper:

- imports `server-only`
- uses the existing Supabase admin helper only on the server
- reads/creates rows in `public.profiles`
- does not expose the Supabase service role to client code

## D. Role/Route Guard Changes

Added:

- `lib/auth/route-guards.ts`
- `lib/auth/role-redirect.ts`

Route guard helpers:

- identify public routes
- match protected route policies
- keep `/supplier/inventory-manager/*` more specific than `/supplier/*`
- evaluate access from trusted profile role and onboarding state

Role redirect helpers:

- route signed-in users according to existing role redirect rules
- send missing profiles/auth state to `/sign-in`

## E. Public/Protected Route Strategy

Current middleware provides auth-only protection for sensitive route families.

Role-specific enforcement is intentionally kept in server-side helper logic so future route loaders/server actions can use database-verified profile data rather than Clerk client metadata or UI hiding.

This preserves the rule that admin, supplier, and reseller roles must not be self-assigned by the browser.

## F. What Is Implemented Now

- Clerk app provider foundation.
- Clerk sign-in/sign-up route foundation.
- Middleware auth protection foundation.
- Current Clerk user identity normalization.
- Server-only find-or-create Supabase profile helper.
- Safe default profile role of `customer`.
- Privileged role self-assignment blocking.
- Route guard and role redirect helpers.
- Focused tests for profile sync and route guard behavior.

## G. What Is Deferred

- Real checkout database integration.
- Real product, order, stock, settlement, commission, payment, Resend, or WhatsApp integration.
- Production Supabase connection or migration apply.
- Clerk webhooks.
- Admin role assignment tooling.
- Supplier/reseller onboarding persistence and approval workflows.
- Route-by-route server component redirects across every app page.
- Storage HTTP/API manual QA.

## H. Security Checks

- `CLERK_SECRET_KEY` remains server-only.
- `SUPABASE_SERVICE_ROLE_KEY` remains server-only.
- Profile sync server helper imports `server-only`.
- Browser Supabase helper still uses only public URL and anon key.
- Client code does not import the Supabase admin helper.
- New profile sync defaults to `customer`.
- Reseller, supplier, admin, support, finance, and super-admin roles cannot be self-assigned by the profile sync helper.
- No direct client role update path was added.
- No RLS, RPC, or storage policy was weakened.

## I. Migration Needed Or Not

No migration is needed for this foundation.

The existing schema already supports:

- `public.profiles.clerk_user_id`
- `public.profiles.email`
- `public.profiles.full_name`
- `public.profiles.primary_role`
- safe default role `customer`
- database constraint blocking self-admin/support/finance/super-admin signup roles

No migration was created, dry-run, or applied.

## J. Commands Run/Results

Pre-report commands:

- `git status --short` - clean at start.
- Source docs and helper files were reviewed.
- `npm test -- tests/auth-profile-sync.test.ts` - first run failed because the new modules did not exist yet; this was the expected TDD red state.
- `npm test -- tests/auth-profile-sync.test.ts` - passed after implementation; 8 tests passed.
- `npm run typecheck` - passed after implementation.

Final validation commands are recorded after this report is created.

Final validation:

- `git status --short` - showed only the expected auth foundation files.
- `git diff --check` - passed with line-ending warnings only.
- `npm test` - passed; 20 test files and 93 tests.
- `npm run typecheck` - first final run failed because `.next/types/**/*.ts` entries were referenced before generated `.next` type files existed; after `npm run build` generated the files, rerun passed.
- `npm run lint` - passed.
- `npm run build` - passed; Next generated 160 static pages plus Clerk sign-in/sign-up routes and middleware.
- Secret scan - passed.

## K. Secret Scan Result

Final secret scan passed.

Result:

- `.env.local` exists locally but is ignored.
- `.env.local` was not staged.
- `.env.local` is not tracked.
- `supabase/.temp/` is ignored and not staged.
- No high-confidence real Clerk/Supabase/service-role values, bearer tokens, passwords, API secrets, or production data were found in tracked docs/source files by the scan.
- No secret values were added to this report.

## L. Files Changed

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

## M. Current Git Status

```text
 M app/layout.tsx
 M lib/auth/clerk.ts
?? app/sign-in/
?? app/sign-up/
?? docs/RISELLAR_CLERK_PROFILE_SYNC_FOUNDATION_REPORT.md
?? lib/auth/profile-sync-core.ts
?? lib/auth/profile-sync.ts
?? lib/auth/role-redirect.ts
?? lib/auth/route-guards.ts
?? middleware.ts
?? tests/auth-profile-sync.test.ts
```

## N. Ready For Auth QA

Ready for local auth QA: yes, with limits.

Allowed next QA:

- Verify Clerk Google and email/password sign-in surfaces locally.
- Verify protected routes redirect signed-out users.
- Verify profile sync helper behavior through server-only test utilities or a development-only route if separately approved.

Still blocked:

- Production Supabase usage.
- Production migrations.
- Live checkout/order/product/settlement/commission/payment integration.
- Admin role assignment workflows.
