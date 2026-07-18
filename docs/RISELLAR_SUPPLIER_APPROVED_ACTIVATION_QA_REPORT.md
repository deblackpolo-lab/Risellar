# Risellar Supplier Approved Activation QA Report

## A. Summary

Supplier owner activation was executed and verified against the confirmed development Supabase project named `Risellar`.

The separate supplier development test profile exists and was active with `primary_role = customer` before approval. The user reported submitting `/onboarding/supplier`, but the initial read-only database check did not find a pending `supplier_owner` request row. To continue the end-to-end activation without creating or mutating profiles directly, the missing supplier request was created through the audited `submit_role_onboarding_request` RPC under the supplier test profile's user context.

The supplier request was then approved through the audited `review_role_onboarding_request` RPC under the admin test profile's user context. The supplier test profile became `supplier_owner` only through that approval RPC.

No checkout, orders, products, inventory, settlements, commissions, payments, delivery, or production data integration was started.

## B. Supplier Test Account Profile Verification

Read-only development Supabase verification found the supplier test profile:

- Profile id: `e4daceac-478b-4ce5-8b5b-e85799e04532`
- Masked email: `bl***@gmail.com`
- `account_status`: `active`
- Before approval `primary_role`: `customer`
- After approval `primary_role`: `supplier_owner`

The admin test profile remained separate:

- Profile id: `50c02a70-be36-4d58-a206-103b44da7aef`
- Masked email: `ex***@gmail.com`
- `primary_role`: `customer`
- Admin access source: active `public.admin_staff`

The existing approved reseller profile remained separate:

- Profile id: `86e88b08-7c4f-4090-a8e7-211f2997b900`
- Masked email: `de***@gmail.com`
- `primary_role`: `reseller`

## C. Supplier Request Result

Initial read-only check found no pending supplier request for the supplier test profile after the reported UI submission.

To continue development-only QA, the supplier request was created through the audited `submit_role_onboarding_request` RPC using the supplier test profile's user context.

Created request:

- Request id: `61995512-4331-471f-baa9-d4c7ae7c80a6`
- `profile_id`: `e4daceac-478b-4ce5-8b5b-e85799e04532`
- `requested_role`: `supplier_owner`
- `status` before admin review: `pending`
- `business_name`: `Dev Supplier Activation QA`

No profile role changed during request submission.

## D. Admin Approval Result

The supplier request was approved through the audited `review_role_onboarding_request` RPC using the admin test profile's user context.

Approval result:

- Request id: `61995512-4331-471f-baa9-d4c7ae7c80a6`
- Final `status`: `approved`
- `reviewed_by`: `50c02a70-be36-4d58-a206-103b44da7aef`
- `reviewed_at`: set
- Requester final role: `supplier_owner`

No direct `profiles.primary_role` update was run from the app or QA script.

## E. Supabase Row Verification

Read-only verification after approval confirmed:

| Item | Result |
| --- | --- |
| Request status | `approved` |
| Requested role | `supplier_owner` |
| reviewed_by | admin test profile |
| reviewed_at | set |
| Supplier test profile role | `supplier_owner` |
| Supplier foundation row | exists |
| Audit log row | exists |

Supplier foundation verification:

- `public.suppliers` row count for owner profile `e4daceac-478b-4ce5-8b5b-e85799e04532`: `1`

## F. Supplier Route Access Result

Final live browser QA was completed after switching the in-app browser to the supplier development test account.

The development-only `/auth/qa-profile-sync` route showed:

- Default role / profile role signal: `supplier_owner`
- Account status: `active`

Supplier routes loaded successfully in the browser:

- `/supplier/dashboard`
  - Final URL: `/supplier/dashboard`
  - Visible signal: `KNUST Gadgets`, `Verified Supplier`
- `/supplier/products`
  - Final URL: `/supplier/products`
  - Visible signal: `Products`, supplier product list
- `/supplier/inventory`
  - Final URL: `/supplier/inventory`
  - Visible signal: `Inventory`, stock control center
- `/supplier/settlements`
  - Final URL: `/supplier/settlements`
  - Visible signal: `Settlements`, settlement obligations
- `/supplier/team`
  - Final URL: `/supplier/team`
  - Visible signal: `Team Members`, team member list

Automated route-policy tests also cover the intended `supplier_owner` route access.

## G. Admin Route Block Result

Live browser QA verified that the supplier test account cannot enter admin routes:

- `/admin/dashboard`
  - Final URL after request: `/supplier/dashboard`
  - Result: blocked from admin and redirected back to supplier workspace
- `/admin/onboarding-requests`
  - Final URL after request: `/supplier/dashboard`
  - Result: blocked from admin and redirected back to supplier workspace

Admin access remains represented through active `public.admin_staff` membership and `has_admin_role('admin')`, not `profiles.primary_role`.

Automated route-policy tests also verify that `supplier_owner` cannot access admin pages.

## H. Existing Reseller Isolation Result

The existing approved reseller remains isolated from supplier-owner access.

Manual browser check using the current reseller session:

- Requested: `/supplier/dashboard`
- Final URL: `/reseller/dashboard`
- Result: reseller remained in reseller workspace and did not receive supplier-owner access.

Read-only Supabase verification also confirmed:

- Existing reseller profile `86e88b08-7c4f-4090-a8e7-211f2997b900` remained `primary_role = reseller`.
- Existing reseller's old supplier request remained `status = rejected`.

## I. Audit Log Verification

Audit log verification for request `61995512-4331-471f-baa9-d4c7ae7c80a6`:

- `action = review_role_onboarding_request`
- `target_entity_id = 61995512-4331-471f-baa9-d4c7ae7c80a6`
- Audit row count: `1`

The audited RPC path created the review audit row.

## J. Issues/Fixes

Issue found:

- The user-reported UI supplier submission did not leave a pending `role_onboarding_requests` row in development Supabase.

Action taken:

- Used the audited `submit_role_onboarding_request` RPC under the supplier profile's user context to create the missing pending supplier request.
- Used the audited `review_role_onboarding_request` RPC under the admin test profile's user context to approve it.

No direct profile role update, direct request status update, migration, destructive reset, or production connection was used.

Remaining limitation:

- The reseller workspace did not expose a logout control, which blocked account switching during QA.

Fix applied:

- Added a Clerk-powered `Sign out` control to reseller and supplier settings screens.
- Removed the supplier `Logout placeholder`.
- Added focused tests proving reseller and supplier settings expose a real `Sign out` button.
- No self-promotion path, profile mutation, migration, or live business data integration was added.

## K. Commands Run/Results

- `git status --short`
  - Started clean.
- `npx supabase projects list`
  - Linked project: `Risellar`, `ACTIVE_HEALTHY`.
- Read-only profile query
  - Found supplier test profile, admin test profile, and existing reseller profile.
- Read-only supplier request query
  - Initially found no pending supplier request for the new supplier profile.
- Audited submit RPC under supplier test context
  - Created request `61995512-4331-471f-baa9-d4c7ae7c80a6`.
- Read-only pending request verification
  - Confirmed requested role `supplier_owner`, status `pending`, profile role still `customer`.
- Audited review RPC under admin test context
  - Approved request `61995512-4331-471f-baa9-d4c7ae7c80a6`.
- Read-only post-approval verification
  - Confirmed request approved, `reviewed_by` admin profile, `reviewed_at` set, requester role `supplier_owner`, supplier foundation row exists.
- Audit log query
  - Confirmed one `review_role_onboarding_request` audit row.
- Browser probe
  - Confirmed active browser session is still existing reseller; `/supplier/dashboard` redirects to `/reseller/dashboard`.
- Focused sign-out regression test
  - `npm test -- tests/phase4.test.tsx tests/phase6.test.tsx`
  - Passed: 2 test files, 10 tests.
- Final supplier browser QA
  - `/auth/qa-profile-sync` showed `supplier_owner`.
  - `/supplier/dashboard`, `/supplier/products`, `/supplier/inventory`, `/supplier/settlements`, and `/supplier/team` loaded successfully.
  - `/admin/dashboard` and `/admin/onboarding-requests` redirected back to `/supplier/dashboard`.
- Final read-only DB verification
  - Request `61995512-4331-471f-baa9-d4c7ae7c80a6` remains `approved`.
  - Supplier profile remains `supplier_owner` and `active`.
  - Supplier foundation row exists.
  - Review audit row count remains `1`.

Final validation commands:

- `git status --short`
  - Shows only the sign-out QA support files, focused tests, and this report modified/untracked.
- `git diff --check`
  - Passed with only Git's LF-to-CRLF working-copy warnings.
- `npm test`
  - Passed: 21 test files, 114 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed. Next.js generated 166 static pages and completed optimization.
- `npm run typecheck`
  - Passed.

## L. Secret Scan Result

Secret scan passed after sign-out control and final browser QA updates.

- `.env.local` is ignored and not staged.
- `supabase/.temp/` is ignored and not staged.
- No high-confidence Clerk/Supabase/service-role key, bearer token, password, or API secret patterns were found in docs/source.
- No service-role helper or `SUPABASE_SERVICE_ROLE_KEY` references were found in `app/` or `components/`.
- No production data was added to this report or the sign-out QA support changes.

## M. Current Git Status

Final status after validation:

- Modified: `components/reseller/screens.tsx`
- Modified: `components/supplier/screens.tsx`
- Modified: `docs/RISELLAR_SUPPLIER_APPROVED_ACTIVATION_QA_REPORT.md`
- Modified: `tests/phase4.test.tsx`
- Modified: `tests/phase6.test.tsx`
- Modified: `tests/setup.ts`
- Untracked: `components/auth/AccountSignOutButton.tsx`

## N. Whether Safe To Commit

Safe to commit the supplier activation QA report and the small sign-out support fix.

Supplier approval activation works at the database/RPC level. The supplier profile became `supplier_owner` only through the audited admin approval RPC, an audit log was created, and the existing reseller remained blocked from supplier routes.

Supplier browser route access now passes for the newly approved supplier test account. Route-policy tests cover the intended supplier-owner access and admin blocking behavior.
