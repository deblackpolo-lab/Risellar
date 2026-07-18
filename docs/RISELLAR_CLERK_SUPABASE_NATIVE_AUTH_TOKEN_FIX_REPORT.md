# Risellar Clerk Supabase Native Auth Token Fix Report

## A. Root Cause

Role onboarding page submit no longer failed as `UNKNOWN`, but it still failed as `SUPABASE_AUTH_TOKEN_MISSING`.

Safe development diagnostics showed:

- Clerk user existed.
- Profile sync succeeded.
- No Supabase user-context token was returned.
- The app requested a deprecated Clerk JWT template with `getToken({ template: "supabase" })`.
- Clerk returned safe metadata `api_response_error` with message summary `Not Found`.

The root cause was the app asking for a named Clerk JWT template instead of using the native Clerk + Supabase third-party auth token path.

## B. Dashboard Prerequisite

Manual prerequisite supplied by the user:

- Clerk dashboard has native Supabase third-party auth configured.
- Supabase development project has the corresponding Clerk third-party auth integration configured.

No dashboard values, tokens, or secrets were printed or stored in this report.

## C. Code Changes

Updated `app/onboarding/actions.ts`:

- Replaced `getToken({ template: "supabase" })` with `getToken()`.
- Kept the normal user-context Supabase client path:
  - Supabase URL from public env.
  - Supabase anon key from public env.
  - Clerk session token as the `Authorization` bearer token.
- Kept profile sync before submit.
- Kept fixed server-side request roles:
  - reseller page submits `reseller`.
  - supplier page submits `supplier_owner`.

No migration was created or applied.

## D. Token Strategy Change

Previous strategy:

- Request a named Clerk JWT template token: `getToken({ template: "supabase" })`.

New strategy:

- Request the default Clerk session token: `getToken()`.
- Pass that token to `createSupabaseUserServerClient(accessToken)`.
- The Supabase user-context client still uses anon key plus Clerk session token.

Service role remains server-only and is not used for normal onboarding request submission.

## E. Tests Added/Updated

Updated `tests/role-onboarding.test.ts`:

- Added a regression check that `app/onboarding/actions.ts` uses `getToken()`.
- Added a regression check that onboarding submit does not contain `template: "supabase"` or `template: 'supabase'`.
- Existing tests still confirm:
  - missing token maps to `SUPABASE_AUTH_TOKEN_MISSING`.
  - token fetch errors map safely.
  - service role is not imported into onboarding pages/actions.
  - reseller/supplier request roles remain fixed server-side.
  - admin and `supplier_inventory_manager` cannot be requested from the public onboarding path.

Focused TDD result:

```bash
npm test -- tests/role-onboarding.test.ts
```

Result:

- Failed before the code change because the action still used the named template.
- Passed after replacing the named template with the default Clerk session token.

## F. Secret Safety

Safety result:

- No `.env.local` changes.
- No secret values printed.
- No `CLERK_SECRET_KEY` client usage added.
- No `SUPABASE_SERVICE_ROLE_KEY` client usage added.
- No service role use added to normal onboarding request submission.
- `lib/supabase/admin.ts` remains server-only and is used for profile sync/admin paths only.

## G. Commands Run/Results

```bash
git status --short
```

Result:

- Working tree contained only expected local changes after this update.

```bash
npm test -- tests/role-onboarding.test.ts
```

Result:

- Red phase failed on the old named template token request.
- Green phase passed after switching to `getToken()`: 13 tests passed.

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

Secret scan result:

- `.env.local` ignored and not staged.
- `supabase/.temp/` ignored and not staged.
- Service role import count in `app` and `components`: `0`.
- Filename-only secret pattern scan found existing documentation/test/source files with secret-safety terminology, not printed secret values.

## H. Current Git Status

Expected local changes:

- `app/onboarding/actions.ts`
- `tests/role-onboarding.test.ts`
- `docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md`
- `docs/RISELLAR_ROLE_ONBOARDING_UNKNOWN_ERROR_FIX_REPORT.md`
- `docs/RISELLAR_CLERK_SUPABASE_NATIVE_AUTH_TOKEN_FIX_REPORT.md`

## I. Ready For Manual Onboarding Submit QA Rerun

Manual onboarding submit QA rerun result: passed.

The native Clerk + Supabase dashboard configuration now lets the server action obtain a valid user-context token and create pending `role_onboarding_requests` rows.

Verified:

- Reseller submit succeeded.
- Reseller pending row exists in development.
- Duplicate reseller submit returns `DUPLICATE_PENDING_REQUEST`, not `UNKNOWN`.
- Duplicate reseller submit did not create a second pending row.
- Supplier submit succeeded.
- Supplier pending row exists in development.
- Profile role remains `customer`.
- Server-side safe duplicate diagnostics showed `hasSupabaseToken: true`.

## J. Manual QA Evidence

Reseller marker:

- `native-qa-reseller-1784336427244`

Read-only development verification:

- Matching request count: `1`
- `requested_role = reseller`: true
- `status = pending`: true
- request profile joins to signed-in profile row: true
- joined profile role remains `customer`: true

Duplicate reseller marker:

- `native-qa-reseller-duplicate-1784336476352`

Read-only development verification:

- Original reseller marker count: `1`
- Pending reseller count for that profile: `1`
- Duplicate marker count: `0`

Supplier marker:

- `native-qa-supplier-1784336521335`

Read-only development verification:

- Matching request count: `1`
- `requested_role = supplier_owner`: true
- `status = pending`: true
- request profile joins to signed-in profile row: true
- joined profile role remains `customer`: true

## K. Final Verification

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

Secret scan result:

- `.env.local` ignored and not staged.
- `supabase/.temp/` ignored and not staged.
- Service role import count in `app` and `components`: `0`.
- Filename-only secret pattern scan found existing documentation/test/source files with secret-safety terminology, not printed secret values.

Safe to commit: yes.

## Exact Next Prompt

```text
Commit the Clerk native Supabase token update and role onboarding manual QA reports.

Do NOT connect checkout, orders, products, settlements, commissions, payments, or inventory to live Supabase data.
Do NOT apply migrations.
Do NOT connect production Supabase.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT run destructive reset commands.
Do NOT run npm audit fix --force.

Files to commit:
- app/onboarding/actions.ts
- tests/role-onboarding.test.ts
- docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md
- docs/RISELLAR_ROLE_ONBOARDING_UNKNOWN_ERROR_FIX_REPORT.md
- docs/RISELLAR_CLERK_SUPABASE_NATIVE_AUTH_TOKEN_FIX_REPORT.md

Before commit, rerun git status --short, git diff --check, npm test, npm run lint, npm run build, npm run typecheck, and secret scan.

Commit with:
git commit -m "Use Clerk native Supabase auth for onboarding requests"

Push:
git push origin main
```
