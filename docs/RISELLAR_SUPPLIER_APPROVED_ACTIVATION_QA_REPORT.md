# Risellar Supplier Approved Activation QA Report

## A. Summary

Supplier owner activation was prepared at the route-access foundation level and reviewed against the confirmed development Supabase project named `Risellar`.

Live supplier approval activation was not executed in this pass because the development project currently has only:

- the admin test profile, which has active `admin_staff` membership and must not be repurposed as the supplier requester;
- the existing approved reseller profile, which is already `primary_role = reseller` and is not eligible for a clean supplier-owner self-service request.

No separate customer-only Clerk development test account/profile was available for safe supplier approval QA. I did not modify the admin profile, did not modify the reseller profile, and did not create synthetic production-looking user data.

The route-access foundation now has explicit supplier-owner tests confirming `supplier_owner` can access the supplier route family and cannot access admin or reseller route families.

No checkout, orders, products, inventory, settlements, commissions, payments, delivery, or production data integration was started.

## B. Supplier Request Result

No new supplier onboarding request was submitted in this pass.

Reason: there is no separate customer-only development profile available. The existing reseller profile already had a rejected supplier request and an approved reseller role. The admin test profile has `primary_role = customer`, but also has active `admin_staff` membership and should not be used as a supplier onboarding requester.

Current development request state:

| Request | requested_role | status | requester role | Notes |
| --- | --- | --- | --- | --- |
| `3ba07930-0e7d-4d34-ad02-9df00b818586` | `supplier_owner` | `rejected` | `reseller` | Existing rejected supplier request for the approved reseller profile |
| `746fa658-61c7-42fb-b329-19d179023e9b` | `reseller` | `approved` | `reseller` | Existing approved reseller activation |

## C. Admin Approval Result

No supplier owner request was approved in this pass.

The audited `review_role_onboarding_request` RPC was not called for a new supplier request because no safe customer-only requester profile exists yet.

## D. Supabase Row Verification

Read-only development Supabase checks confirmed:

- Linked project: `Risellar`
- Project status: `ACTIVE_HEALTHY`
- Existing admin profile: `primary_role = customer`, active `admin_staff` membership
- Existing requester profile: `primary_role = reseller`
- Existing supplier request: `status = rejected`
- Existing reseller request: `status = approved`

No profile role was changed during this pass.

## E. Supplier Route Access Result

Automated route-policy tests now explicitly verify that an approved supplier owner profile can access:

- `/supplier/dashboard`
- `/supplier/products`
- `/supplier/inventory`
- `/supplier/settlements`
- `/supplier/team`

These tests use the existing `canAccessRoute` helper and the role-enforced `RouteAccessBoundary` foundation.

Live browser QA for a real signed-in `supplier_owner` account remains blocked until a separate development customer account submits a supplier request and is approved.

## F. Admin Route Block Result

Automated route-policy tests verify that `supplier_owner` cannot access:

- `/admin/dashboard`
- `/admin/onboarding-requests`

Admin access remains represented through active `public.admin_staff` membership and `has_admin_role('admin')`, not `profiles.primary_role`.

## G. Existing Reseller Isolation Result

The existing approved reseller session remains blocked from supplier-owner routes.

Manual browser check:

- Requested: `/supplier/dashboard`
- Final URL: `/reseller/dashboard`
- Result: reseller remained in reseller workspace and did not receive supplier-owner access.

This confirms the rejected supplier request did not grant `supplier_owner` access and the approved reseller did not automatically become supplier owner.

## H. Route Guard/Helper Changes

No route boundary implementation changes were needed beyond the existing role-based route access foundation from commit `170e9970`.

The only code change in this pass was expanded test coverage for supplier-owner route access and isolation.

## I. Tests Added/Updated

Updated `tests/auth-profile-sync.test.ts` to cover:

- `supplier_owner` can access the supplier route family;
- `supplier_owner` cannot access admin routes;
- `supplier_owner` does not automatically receive reseller route access;
- customer and reseller remain blocked from supplier-owner routes;
- rejected supplier request does not imply supplier-owner access;
- admin access remains separate from `profiles.primary_role`.

## J. Manual QA Notes And Limitations

Manual QA used development test accounts only.

Completed:

- Confirmed existing approved reseller is blocked from `/supplier/dashboard`.
- Confirmed route policy supports an approved `supplier_owner`.
- Confirmed no production data was used.

Blocked:

- Full submit/approve/sign-in supplier-owner browser QA needs a separate Clerk development test account whose profile is still `customer`.
- Current available profiles are not suitable for safe supplier approval activation:
  - admin profile should not be repurposed as supplier requester;
  - reseller profile is already promoted and has a rejected supplier request.

Recommended manual setup:

1. Create/sign in with a separate Clerk development supplier test account.
2. Visit `/auth/qa-profile-sync` to create the customer profile.
3. Submit `/onboarding/supplier`.
4. Sign in as the admin test account.
5. Approve the supplier request through `/admin/onboarding-requests`.
6. Sign in as the supplier test account.
7. Verify supplier routes render and admin/reseller routes are blocked.

## K. Commands Run/Results

- `git status --short`
  - Started clean.
- `npx supabase projects list`
  - Linked project: `Risellar`, `ACTIVE_HEALTHY`.
- Read-only profile query
  - Found two development profiles: admin test profile and approved reseller profile.
- Read-only role onboarding request query
  - Found existing reseller approved request and existing supplier rejected request.
- Browser check as existing approved reseller
  - `/supplier/dashboard` redirected to `/reseller/dashboard`.

- `git diff --check`
  - Passed; line-ending warnings only.
- `npm test`
  - Passed: 21 files, 114 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.
- `npm run typecheck`
  - Passed.

## L. Secret Scan Result

- `.env.local` ignored: yes.
- `.env.local` tracked: no.
- `.env.local` staged: no.
- `supabase/.temp/` ignored: yes.
- Service-role references in `app/` or `components/`: no.
- Real Clerk/Supabase/service-role values in docs/source: none found.
- Bearer tokens, passwords, API secrets, or production data: none found.
- Secret scan produced only existing false-positive documentation lines that say bearer/API secrets were not found; no secret value was present.

## M. Files Changed

- `tests/auth-profile-sync.test.ts`
- `docs/RISELLAR_SUPPLIER_APPROVED_ACTIVATION_QA_REPORT.md`

## N. Current Git Status

- Modified: `tests/auth-profile-sync.test.ts`
- Untracked: `docs/RISELLAR_SUPPLIER_APPROVED_ACTIVATION_QA_REPORT.md`
- No files staged.

## O. Whether Safe To Commit

Safe to commit the supplier route foundation test/report update.

Live supplier approval activation remains blocked until a separate customer-only Clerk development test account/profile is available.
