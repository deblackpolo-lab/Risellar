# Risellar Role Onboarding Page Manual QA Report

## A. Summary

Manual QA was run against the connected role onboarding pages on `http://localhost:400` using a signed-in Clerk test account.

Initial result:

- Unauthenticated `/onboarding` redirects to Clerk sign-in.
- Signed-in `/onboarding` opens successfully.
- Reseller and supplier request pages render correctly.
- No privileged role selector or client `requested_role` field is exposed.
- Reseller and supplier form submissions fail with the app's generic `UNKNOWN` error state.
- No matching `role_onboarding_requests` row was created in the development Supabase database for either submitted fake QA marker.
- The signed-in profile still appears to be `customer`.

Follow-up result after the UNKNOWN error mapping fix:

- Signed-in `/onboarding`, `/onboarding/reseller`, and `/onboarding/supplier` render.
- Reseller submit no longer collapses to `UNKNOWN`.
- Reseller submit now returns `SUPABASE_AUTH_TOKEN_MISSING`.
- Supplier submit now returns `SUPABASE_AUTH_TOKEN_MISSING`.
- Development-only safe server diagnostics show:
  - Clerk user exists.
  - Profile sync succeeded.
  - Supabase user token was not returned.
  - Clerk token request failed with safe code `api_response_error` and message summary `Not Found`.
- No matching reseller or supplier request row was created.
- Profile QA still shows the default role as `customer`.

This is not safe to proceed to admin review UI yet because request creation from the page was blocked by Clerk/Supabase user-token configuration at the time of the manual QA run.

Follow-up code update:

- The app has now been updated to use Clerk native Supabase third-party auth token retrieval with `getToken()`.
- The deprecated named JWT template request is no longer used by the onboarding submit action.
- Manual submit QA still needs to be rerun after this code update.

## B. Test Account Used

Used a manually signed-in Clerk test account in the in-app browser.

No credentials, email address, tokens, or secret values were printed or stored in this report.

## C. Reseller Request Result

Route:

- `/onboarding/reseller`

Fake dev-only form data used:

- Business marker: `Dev Manual QA Reseller manual-qa-1784333757855`
- Contact phone: fake dev-only phone value
- Notes marker: `Dev-only role onboarding manual QA reseller manual-qa-1784333757855`

Observed result:

- Form submitted.
- Browser redirected back to `/onboarding/reseller?error=UNKNOWN`.
- Page displayed: `We could not submit this request. Please try again.`
- It did not navigate to `/onboarding/pending`.

Follow-up result after the UNKNOWN error fix:

- Fake dev-only marker: `manual-qa-reseller-1784334912463`
- Form submitted.
- Browser redirected to `/onboarding/reseller?error=SUPABASE_AUTH_TOKEN_MISSING`.
- Page displayed: `We could not prepare your secure session. Please sign in again.`
- It did not navigate to `/onboarding/pending`.
- Server-side safe diagnostics recorded no token value and no secret value.

Conclusion:

- Reseller request does not yet succeed.
- The failure is now specific and not `UNKNOWN`.

## D. Duplicate Request Behavior

Duplicate pending reseller behavior could not be tested because reseller submission did not create a pending request.

Expected future check after fixing submission:

- Submit reseller request once.
- Submit reseller request again with the same signed-in customer.
- Confirm a clear duplicate pending request message appears.

## E. Supplier Request Result

Route:

- `/onboarding/supplier`

Fake dev-only form data used:

- Business marker: `Dev Manual QA Supplier manual-qa-supplier-1784333851455`
- Contact phone: fake dev-only phone value
- Notes marker: `Dev-only role onboarding manual QA supplier manual-qa-supplier-1784333851455`

Observed result:

- Form submitted.
- Browser redirected back to `/onboarding/supplier?error=UNKNOWN`.
- Page displayed: `We could not submit this request. Please try again.`
- It did not navigate to `/onboarding/pending`.

Follow-up result after the UNKNOWN error fix:

- Fake dev-only marker: `manual-qa-supplier-1784334963243`
- Form submitted.
- Browser redirected to `/onboarding/supplier?error=SUPABASE_AUTH_TOKEN_MISSING`.
- Page displayed: `We could not prepare your secure session. Please sign in again.`
- It did not navigate to `/onboarding/pending`.

Supplier page security shape:

- No `requested_role` field was present in the DOM.
- No `super_admin` or `supplier_inventory_manager` request option was visible.
- The only `admin` wording observed is descriptive copy about later admin approval.
- The visible submit action is fixed to supplier request UI.

## F. Supabase Row Verification

Read-only linked development queries were run against the confirmed development Supabase project.

Reseller marker query result:

- Matching request count: `0`
- `requested_role = reseller`: not observed
- `status = pending`: not observed
- joined profile still customer: not observed because no matching request row existed

Supplier marker query result:

- Matching request count: `0`
- `requested_role = supplier_owner`: not observed
- `status = pending`: not observed
- joined profile still customer: not observed because no matching request row existed

Follow-up reseller marker query result:

- Matching request count: `0`
- `requested_role = reseller`: not observed
- `status = pending`: not observed
- joined profile still customer: not observed because no matching request row existed

Follow-up supplier marker query result:

- Matching request count: `0`
- `requested_role = supplier_owner`: not observed
- `status = pending`: not observed
- joined profile still customer: not observed because no matching request row existed

No production Supabase connection was used.

## G. Profile Role Verification

The signed-in profile QA page was checked for non-sensitive role/status signals only.

Observed:

- Profile sync page was accessible.
- Page text indicated a customer-role signal.
- No reseller or supplier-owner role signal was observed.
- No error signal was observed on the profile sync page.

Conclusion:

- No evidence that submitting either request changed the profile role.
- Profile role appears to remain `customer`.
- Follow-up profile QA still shows default role `customer`, active status, and no reseller/supplier-owner signal.

## H. Security Checks

Passed checks:

- Unauthenticated `/onboarding` redirected to Clerk sign-in.
- Signed-in `/onboarding` rendered role onboarding choices.
- No client `requested_role` field was exposed on reseller or supplier pages.
- No admin, super admin, or supplier inventory manager request path was exposed from the UI.
- Service role references were not present in `app` or `components`.
- No checkout, orders, products, settlements, commissions, payments, or inventory integration was touched during QA.
- No migration, destructive reset, or production Supabase command was run.

Blocked checks:

- Successful reseller request creation.
- Duplicate reseller pending request behavior.
- Successful supplier request creation.
- Pending page success redirect after real request submission.
- `profile_id` match between inserted request and signed-in profile, because no request row was inserted.

## I. Issues/Fixes

Issue found:

- Role onboarding page submissions return `error=UNKNOWN` and create no matching development database row.

Likely area to investigate:

- The server action's user-context Supabase RPC call or Clerk Supabase token setup.
- Current UI error mapping hides the underlying error as `UNKNOWN`, so the next fix should improve safe diagnostics without printing tokens or secrets.

Fixes applied in this QA task:

- Follow-up fix applied in the UNKNOWN error debug pass:
  - The server action now verifies profile sync returns a profile before calling the RPC.
  - The action now distinguishes a missing Clerk/Supabase token from profile sync failure.
  - Supabase RPC error objects are preserved instead of being flattened to `Error(error.message)`.
  - Known submit failures now map to safe user-facing codes:
    - `AUTH_REQUIRED`
    - `PROFILE_SYNC_FAILED`
    - `PROFILE_NOT_FOUND`
    - `DUPLICATE_PENDING_REQUEST`
    - `INVALID_ROLE`
    - `RPC_PERMISSION_DENIED`
    - `RPC_VALIDATION_FAILED`
    - `SUPABASE_AUTH_TOKEN_MISSING`
  - Development-only diagnostics now record safe metadata only: mapped code, Postgres/Supabase error code, short message summary, RPC name, whether a Clerk user existed, whether profile sync succeeded, and whether a Supabase token existed.
  - Reseller/supplier pages now show specific safe messages for those codes.
  - Regression tests were added for the known error mappings.

No migration was created or applied.
The follow-up manual QA rerun confirmed the remaining blocker was Clerk/Supabase user-token configuration, not a generic page error.

Native auth code update applied after the rerun:

- `app/onboarding/actions.ts` now requests the default Clerk session token with `getToken()`.
- This matches the native Clerk + Supabase third-party auth setup configured in the dashboards.
- No migration was created or applied.
- No service role was added to onboarding submit.

Required fix prompt:

```text
You are working on Risellar.

Task: diagnose and fix the role onboarding page submission UNKNOWN error.

Do NOT connect checkout, orders, products, settlements, commissions, payments, or inventory to live Supabase data.
Do NOT apply migrations.
Do NOT connect production Supabase.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT run destructive reset commands.
Do NOT run npm audit fix --force.
Do NOT weaken RLS/RPC policies.
Do NOT use service role for normal request submission.

Context:
Manual QA with a signed-in Clerk test account showed:
- /onboarding opens when signed in.
- /onboarding/reseller submits but redirects to /onboarding/reseller?error=UNKNOWN.
- /onboarding/supplier submits but redirects to /onboarding/supplier?error=UNKNOWN.
- Development Supabase queries found 0 matching role_onboarding_requests rows for both fake QA markers.
- Profile role still appears to be customer.
- No client requested_role field is exposed.

Goal:
Find the exact safe root cause of the UNKNOWN submit failure and fix only the role onboarding request submission path.

Requirements:
1. Do not expose tokens or secrets in logs or UI.
2. Keep requested_role fixed server-side to reseller or supplier_owner.
3. Keep admin/super_admin/supplier_inventory_manager blocked.
4. Keep profile.primary_role mutation out of the page.
5. Do not touch checkout/orders/products/settlements/commissions/payments/inventory.
6. Do not use service role for normal request submission unless explicitly approved after documenting why anon/RLS/RPC cannot work.
7. Improve safe error diagnostics so Clerk-token/RPC/RLS failures do not collapse to UNKNOWN.
8. Add/update tests for the diagnosed failure.

Run:
git status --short
git diff --check
npm test
npm run lint
npm run build
npm run typecheck

Run secret scan and update docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md.
Do not commit unless asked.
```

## J. Commands Run/Results

Browser/manual checks:

- Opened `/onboarding` unauthenticated: redirected to Clerk sign-in.
- Opened `/onboarding` signed in: rendered role onboarding choices.
- Submitted `/onboarding/reseller`: failed with `error=UNKNOWN`.
- Queried development database for reseller QA marker: `0` matching rows.
- Submitted `/onboarding/supplier`: failed with `error=UNKNOWN`.
- Queried development database for supplier QA marker: `0` matching rows.
- Checked profile sync page for non-sensitive role signals: customer signal present, reseller/supplier-owner signals absent.

Commands:

```bash
npm test
```

Result:

- Passed: 21 test files, 105 tests.

```bash
npm run lint
```

Result:

- Passed.

```bash
npm run build
```

Result:

- Passed.

```bash
npm run typecheck
```

Result:

- Passed.

Read-only Supabase development queries:

- Reseller marker lookup: passed, returned `0` matching rows.
- Supplier marker lookup: passed, returned `0` matching rows.

Follow-up browser/manual checks after UNKNOWN fix:

- Opened signed-in `/onboarding`: rendered reseller and supplier request links.
- Opened `/onboarding/reseller`: rendered form fields and no `requested_role` input.
- Submitted reseller marker `manual-qa-reseller-1784334912463`: failed with `SUPABASE_AUTH_TOKEN_MISSING`, not `UNKNOWN`.
- Opened `/onboarding/supplier`: rendered form fields and no `requested_role` input.
- Submitted supplier marker `manual-qa-supplier-1784334963243`: failed with `SUPABASE_AUTH_TOKEN_MISSING`, not `UNKNOWN`.
- Checked `/auth/qa-profile-sync`: customer role signal present, no reseller/supplier-owner role signal.

Follow-up read-only Supabase development queries:

- Reseller marker lookup: passed, returned `0` matching rows.
- Supplier marker lookup: passed, returned `0` matching rows.

Follow-up commands:

```bash
git status --short
```

Result:

- Working tree contains only the expected onboarding UNKNOWN fix files and reports.

```bash
git diff --check
```

Result:

- Passed. Git reported line-ending normalization warnings only.

```bash
npm test
```

Result:

- Passed: 21 test files, 105 tests.

```bash
npm run lint
```

Result:

- Passed.

```bash
npm run build
```

Result:

- Passed.

```bash
npm run typecheck
```

Result:

- Passed.

## K. Secret Scan Result

Result:

- `.env.local` is ignored and not staged.
- `supabase/.temp/` is ignored.
- No credentials, token values, or secret values were printed.
- Filename-only scan found existing documentation/test files that mention secret-safety terms.
- No service role references were found in `app` or `components`.
- Existing `SUPABASE_SERVICE_ROLE_KEY` reference remains isolated to `lib/supabase/admin.ts`.
- No bearer tokens, passwords, API secrets, or production data were exposed in command output.
- Follow-up secret scan result:
  - `.env.local` ignored and not staged.
  - `supabase/.temp/` ignored and not staged.
  - Service role import count in `app` and `components`: `0`.
  - Filename-only secret pattern scan found existing documentation/test/source files with secret-safety terminology, not printed secret values.

## L. Current Git Status

At report creation time, the only intended new local file is:

- `docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md`

After the UNKNOWN fix and follow-up manual QA rerun, expected local changes are:

- `app/onboarding/actions.ts`
- `app/onboarding/reseller/page.tsx`
- `app/onboarding/supplier/page.tsx`
- `lib/auth/role-onboarding.ts`
- `tests/role-onboarding.test.ts`
- `docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md`
- `docs/RISELLAR_ROLE_ONBOARDING_UNKNOWN_ERROR_FIX_REPORT.md`

## M. Whether Safe To Proceed To Admin Review UI

Safe to proceed to admin review UI: yes, after committing the verified native auth update.

Reason:

- The original manual run did not create pending onboarding requests in development.
- The UNKNOWN collapse is fixed.
- Native Clerk/Supabase token retrieval has been updated in code.
- Pending request rows are now created after the native Clerk/Supabase token update.
- Profile role remains `customer` until admin review.

Recommended next step:

- Commit the native Clerk/Supabase token update and QA reports, then proceed to admin review UI foundation.

## N. Clerk Native Supabase Token Manual QA Rerun

### A. Reseller Submit Result

Result: passed.

- Fake dev-only marker: `native-qa-reseller-1784336427244`
- Browser redirected to `/onboarding/pending?request=reseller&status=submitted`.
- The pending page displayed reseller request submitted copy.
- No `UNKNOWN` error appeared.
- No `SUPABASE_AUTH_TOKEN_MISSING` error appeared.

### B. Supabase Pending Row Verification

Read-only development Supabase query result for the reseller marker:

- Matching request count: `1`
- `requested_role = reseller`: true
- `status = pending`: true
- request `profile_id` joins to the signed-in profile row: true
- joined profile role remains `customer`: true

### C. Duplicate Request Behavior

Result: passed.

- Fake duplicate marker: `native-qa-reseller-duplicate-1784336476352`
- Browser redirected to `/onboarding/reseller?error=DUPLICATE_PENDING_REQUEST`.
- Page displayed: `You already have a pending reseller request.`
- The duplicate error was clear and did not show `UNKNOWN`.
- Read-only development query confirmed:
  - Original reseller marker count: `1`
  - Pending reseller count for that profile: `1`
  - Duplicate marker count: `0`

### D. Supplier Request Behavior

Result: passed.

- Fake dev-only marker: `native-qa-supplier-1784336521335`
- Browser redirected to `/onboarding/pending?request=supplier&status=submitted`.
- The pending page displayed supplier request submitted copy.
- Read-only development Supabase query result:
  - Matching request count: `1`
  - `requested_role = supplier_owner`: true
  - `status = pending`: true
  - request `profile_id` joins to the signed-in profile row: true
  - joined profile role remains `customer`: true

### E. Profile Role Verification

Profile QA page result:

- Profile row was created or found.
- Clerk user id is stored.
- Email is stored.
- Default role remains `customer`.
- Account status remains `active`.
- No reseller role signal was shown.
- No supplier-owner role signal was shown.
- Submitting reseller/supplier requests did not mutate `profile.primary_role`.

### F. Clerk/Supabase Native Token Result

Result: passed.

- `app/onboarding/actions.ts` uses `getToken()`.
- The deprecated `getToken({ template: "supabase" })` call is no longer used by the onboarding submit path.
- Reseller and supplier RPC submissions succeeded through the Supabase user-context client.
- Server-side duplicate diagnostics showed `hasSupabaseToken: true`.
- The user-context client still uses anon key plus the Clerk session token.

### G. Security Checks

Passed checks:

- No `requested_role` field is exposed on reseller or supplier forms.
- No `super_admin` or `supplier_inventory_manager` request option is visible.
- Supplier page contains only descriptive admin-approval copy, not a requestable admin role.
- Service role references are not present in `app` or `components`.
- No profile role mutation was added.
- No checkout, orders, products, settlements, commissions, payments, or inventory integration was touched.
- No migration, destructive reset, or production Supabase command was run.

### H. Commands Run/Results

```bash
git status --short
```

Result:

- Working tree contains only expected Clerk native token update files and reports.

```bash
git diff --check
```

Result:

- Passed. Git reported line-ending normalization warnings only.

```bash
npm test
```

Result:

- Passed: 21 test files, 106 tests.

```bash
npm run lint
```

Result:

- Passed.

```bash
npm run build
```

Result:

- Passed.

```bash
npm run typecheck
```

Result:

- Passed.

### I. Secret Scan Result

Result:

- `.env.local` ignored and not staged.
- `supabase/.temp/` ignored and not staged.
- Service role import count in `app` and `components`: `0`.
- Filename-only secret pattern scan found existing documentation/test/source files with secret-safety terminology, not printed secret values.
- No bearer tokens, passwords, API secrets, or production data were printed.

### J. Current Git Status

Expected local changes:

- `app/onboarding/actions.ts`
- `tests/role-onboarding.test.ts`
- `docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md`
- `docs/RISELLAR_ROLE_ONBOARDING_UNKNOWN_ERROR_FIX_REPORT.md`
- `docs/RISELLAR_CLERK_SUPABASE_NATIVE_AUTH_TOKEN_FIX_REPORT.md`

### K. Whether Safe To Commit

Safe to commit: yes.
