# Risellar Admin Onboarding Review UI Report

## A. Summary

Implemented a focused admin review surface for role onboarding requests at `/admin/onboarding-requests`.
The page lists pending reseller and supplier owner requests through the signed-in admin's Supabase user context and submits approve/reject decisions through the audited `review_role_onboarding_request` RPC.

No checkout, orders, products, inventory, settlements, commissions, payments, or production workflows were connected.

## B. Routes/pages created

- `app/admin/onboarding-requests/page.tsx`
- Added a sidebar navigation link for `Onboarding Requests` in `components/admin/AdminSidebar.tsx`.

The route is under the existing `/admin/:slug*` Clerk-protected admin route policy.

## C. Server action/helper created

- `app/admin/onboarding-requests/actions.ts`
  - Uses Clerk `auth()` and `getToken()`.
  - Ensures the signed-in user has a synced admin profile.
  - Calls `review_role_onboarding_request` through `createSupabaseUserServerClient`.
  - Redirects with safe success/error query states.

- `lib/auth/role-onboarding.ts`
  - Added `RoleOnboardingReviewDecision`.
  - Added `buildRoleOnboardingReviewPayload`.
  - Added `canReviewRoleOnboardingRequests`.
  - Added `mapRoleOnboardingReviewRpcError`.

## D. Security protections

- Review decisions are limited to `approved` or `rejected`.
- Request id is required before RPC execution.
- Review notes are optional and trimmed safely.
- The UI does not expose profile role mutation controls.
- The UI does not call `.from("profiles").update`.
- The action uses Clerk native session token retrieval via `getToken()`, not a deprecated Supabase JWT template.
- The action does not use `createSupabaseAdminClient`.
- Service role remains server-only and is not imported in app/components for this flow.

## E. Admin-only behavior

- `/admin/onboarding-requests` is protected by the existing Clerk middleware route matcher for `/admin(.*)`.
- Role policy confirms `/admin/:slug*` requires the `admin` role.
- The page and server action also check `canReviewRoleOnboardingRequests`, which only allows synced admin profiles.
- Customers, resellers, supplier owners, and supplier inventory managers cannot review requests through the helper.

## F. Approve/reject behavior

- Pending requests render with requester name/email when visible to the admin user context.
- The admin can approve or reject using buttons that submit a fixed `decision` value.
- The UI submits only:
  - `request_id`
  - `decision`
  - optional `review_notes`
- The audited `review_role_onboarding_request` RPC remains responsible for role promotion, request status changes, audit logging, and final authorization.

## G. Tests added/updated

Updated `tests/role-onboarding.test.ts` to verify:

- Admin review payload only accepts `approved` or `rejected`.
- Invalid decisions are blocked.
- Request id is required.
- Review notes are optional and normalized safely.
- Non-admin roles cannot review onboarding requests.
- `/admin/onboarding-requests` is covered by the admin route policy.
- Admin review page/action do not import service-role helpers.
- Admin review page/action do not directly mutate `profiles.primary_role`.
- Admin review action uses `review_role_onboarding_request`.
- Admin review action uses `getToken()` without a Supabase JWT template.

## H. Manual QA result and limitations

Local HTTP check was run against `http://localhost:400`.

- `curl -I http://localhost:400/admin/onboarding-requests` returned Clerk dev signed-out protection headers:
  - `x-clerk-auth-status: signed-out`
  - `x-clerk-auth-reason: protect-rewrite, dev-browser-missing`
- `curl -I http://localhost:400/onboarding` showed the same protected-route behavior for signed-out HTTP requests.
- `curl -I http://localhost:400/sign-in` returned `200 OK`.

Live approve/reject QA is blocked until an admin Clerk test account or admin test profile exists. The current development test account used for role onboarding is a customer and must not be self-promoted through UI. No production data was used.

## I. Commands run/results

- `npm test -- tests/role-onboarding.test.ts` failed first as expected because review helpers/page/action did not exist.
- `npm test -- tests/role-onboarding.test.ts` passed after implementation: 16 tests passed.
- `curl.exe -I -s http://localhost:400/admin/onboarding-requests` confirmed signed-out Clerk protection.
- `curl.exe -I -s http://localhost:400/sign-in` returned `200 OK`.
- `git diff --check` passed with line-ending warnings only.
- `npm test` passed: 21 test files, 109 tests.
- `npm run lint` passed.
- `npm run build` initially found a type mismatch between synced profile rows and app role unions; fixed by widening the helper input type while keeping exact role checks.
- `npm run build` passed after fix.
- `npm run typecheck` passed.

Final verification commands were rerun after this report was created.

## J. Secret scan result

- `.env.local` is ignored by Git.
- `supabase/.temp/` is ignored by Git.
- `.env.local` is not staged.
- No service-role helper import was added to app/components for this flow.
- No real Clerk, Supabase, service-role, bearer token, password, API secret, or production data was added to docs/source.

## K. Files changed

- `app/admin/onboarding-requests/actions.ts`
- `app/admin/onboarding-requests/page.tsx`
- `components/admin/AdminSidebar.tsx`
- `lib/auth/role-onboarding.ts`
- `tests/role-onboarding.test.ts`
- `docs/RISELLAR_ADMIN_ONBOARDING_REVIEW_UI_REPORT.md`

## L. Current git status

Working tree is intentionally dirty with the admin review UI implementation and this report. No files have been staged or committed.

## M. Whether safe to commit

Safe to commit after final verification remains green and the secret scan remains clean.

Live approve/reject QA should be completed later with a dedicated admin Clerk test account or admin development profile. Production remains out of scope.
