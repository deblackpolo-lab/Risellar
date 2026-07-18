# Risellar Reseller Approved Activation QA Report

## A. Summary

Approved reseller activation was verified against the confirmed development Supabase project named `Risellar`.

The approved development requester profile now has `profiles.primary_role = reseller` only after the audited admin review RPC approved the reseller request. The rejected supplier owner request for the same profile remains rejected and did not grant supplier owner access.

During manual browser QA, the approved reseller test session could access the reseller route family. Before this pass, supplier routes were still rendering for the same signed-in reseller session because middleware was auth-only and page rendering did not enforce the existing role-policy helper. A server-side route access boundary was added so protected route families now enforce the existing role policy before rendering.

No checkout, orders, products, inventory, settlements, commissions, payments, delivery, or production data integration was started.

## B. Approved Reseller Profile Verification

Read-only development Supabase verification checked the previously reviewed development requests:

| Request | requested_role | status | requester role | reviewed_at |
| --- | --- | --- | --- | --- |
| `746fa658-61c7-42fb-b329-19d179023e9b` | `reseller` | `approved` | `reseller` | set |
| `3ba07930-0e7d-4d34-ad02-9df00b818586` | `supplier_owner` | `rejected` | `reseller` | set |

Verified requester profile:

- Profile id: `86e88b08-7c4f-4090-a8e7-211f2997b900`
- Masked email: `de***@gmail.com`
- `account_status`: `active`
- `primary_role`: `reseller`

## C. Reseller Route Access Result

Manual browser QA used the signed-in approved reseller test session on `http://localhost:400`.

These routes rendered for the approved reseller:

- `/reseller/dashboard`
- `/reseller/products`
- `/reseller/shop`
- `/reseller/my-products`
- `/reseller/wallet`

Observed examples:

- `/reseller/dashboard` rendered the reseller dashboard and stayed on `/reseller/dashboard`.
- `/reseller/products` rendered the product catalog page.
- `/reseller/shop` and `/reseller/my-products` rendered reseller shop surfaces.
- `/reseller/wallet` rendered the wallet page.

These remain mock/frontend surfaces only. No real reseller product, order, wallet, commission, or payment integration was connected.

## D. Supplier Route Block Result

Before the route-boundary fix, the signed-in approved reseller session could render `/supplier/dashboard`, which showed the route-policy helper was role-safe but the app shell still enforced only authentication at render time.

After the route access boundary was added, the same approved reseller session was redirected back to `/reseller/dashboard` for:

- `/supplier/dashboard`
- `/supplier/products`
- `/supplier/inventory`
- `/supplier/settlements`
- `/supplier/team`

This confirms the rejected supplier owner request did not grant supplier-owner route access.

## E. Admin Route Block Result

The same approved reseller session was redirected back to `/reseller/dashboard` for:

- `/admin/dashboard`
- `/admin/onboarding-requests`

Unauthenticated HTTP checks also confirmed Clerk protection headers for reseller, supplier, and admin protected route families.

Admin access remains based on active `public.admin_staff` membership via `has_admin_role('admin')`, not `profiles.primary_role`.

## F. Route Guard/Helper Changes

Added `lib/auth/route-access-boundary.tsx`.

The boundary:

- Reads the current pathname from a middleware-set request header.
- Uses existing `getRoutePolicyForPath` and `canAccessRoute` policy helpers.
- Fetches the signed-in synced profile only for protected routes.
- For admin routes, checks active admin staff membership through `getRoleOnboardingAdminAccess`.
- Redirects unauthorized profiles to their trusted role home path.

Updated `middleware.ts` to pass `x-risellar-pathname` into the request headers while preserving existing Clerk `auth.protect()` route protection.

Updated `app/layout.tsx` to wrap rendered pages with `RouteAccessBoundary`.

Updated `lib/auth/route-guards.ts` with `getVerifiedRouteAccessProfile`, which maps:

- active `admin_staff` membership to admin route access;
- normal profile roles to their matching route role;
- `profiles.primary_role = admin` without active `admin_staff` to no route-admin access.

## G. Tests Added/Updated

Updated `tests/auth-profile-sync.test.ts` to cover:

- approved reseller route family access;
- customer and reseller blocking from supplier-owner routes;
- reseller blocking from admin routes;
- rejected supplier request not implying supplier-owner access;
- route access profile mapping;
- `profiles.primary_role = admin` not being sufficient without active `admin_staff`.

## H. Manual QA Notes

Manual QA was performed with development test accounts only.

The signed-in browser session matched the approved reseller behavior:

- reseller routes rendered;
- supplier routes redirected to `/reseller/dashboard`;
- admin route redirected to `/reseller/dashboard`.

No production Supabase connection was used. The linked project was confirmed as the development project named `Risellar`.

## I. Commands Run/Results

- `git status --short`
  - Started clean.
- `npx supabase --version`
  - `2.109.1`
- `npx supabase projects list`
  - Linked project: `Risellar`, `ACTIVE_HEALTHY`.
- Read-only linked Supabase query for the reviewed reseller/supplier requests
  - Confirmed reseller request approved, supplier_owner request rejected, requester role `reseller`.
- Unauthenticated `curl.exe -I` checks for reseller/supplier/admin protected routes
  - Confirmed Clerk signed-out protection headers.
- Browser QA on signed-in approved reseller session
  - Reseller routes rendered.
  - Supplier-owner and admin routes redirected to `/reseller/dashboard`.
- `git diff --check`
  - Passed; line-ending warnings only.
- `npm test`
  - Passed: 21 files, 113 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.
- `npm run typecheck`
  - Passed.

## J. Secret Scan Result

- `.env.local` ignored: yes.
- `.env.local` tracked: no.
- `.env.local` staged: no.
- `supabase/.temp/` ignored: yes.
- Service-role references in `app/` or `components/`: no.
- Real Clerk/Supabase/service-role values in docs/source: none found.
- Bearer tokens, passwords, API secrets, or production data: none found.
- Secret scan produced one false-positive documentation line that says bearer tokens/passwords/API secrets were not found; no secret value was present.

## K. Files Changed

- `app/layout.tsx`
- `middleware.ts`
- `lib/auth/route-access-boundary.tsx`
- `lib/auth/route-guards.ts`
- `tests/auth-profile-sync.test.ts`
- `docs/RISELLAR_RESELLER_APPROVED_ACTIVATION_QA_REPORT.md`

## L. Current Git Status

- Modified: `app/layout.tsx`
- Modified: `lib/auth/route-guards.ts`
- Modified: `middleware.ts`
- Modified: `tests/auth-profile-sync.test.ts`
- Untracked: `docs/RISELLAR_RESELLER_APPROVED_ACTIVATION_QA_REPORT.md`
- Untracked: `lib/auth/route-access-boundary.tsx`
- No files staged.

## M. Whether Safe To Proceed

Safe to proceed with commit review.

Production remains blocked for broader business data workflows. This phase only verifies approved reseller activation, route access, and onboarding state.
