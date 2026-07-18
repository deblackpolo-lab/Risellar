# Risellar Role Onboarding UNKNOWN Error Fix Report

## A. Root Cause Of UNKNOWN Error

The page submit path collapsed expected server-action/RPC failures into `UNKNOWN`.

The wiring review found:

- The server action calls the correct RPC name: `submit_role_onboarding_request`.
- RPC parameter names match the migration: `p_requested_role`, `p_business_name`, `p_contact_phone`, and `p_notes`.
- The user-context Supabase client uses the anon key plus the Clerk Supabase token, not the service role.
- The RPC resolves the actor through `public.current_profile_id()`, which expects `auth.jwt()->>'sub'` to match `profiles.clerk_user_id`.

The follow-up manual QA rerun preserved the actual safe failure class.

Confirmed remaining submit blocker:

- Clerk user exists.
- Profile sync succeeds.
- `getToken({ template: "supabase" })` does not return a Supabase user token.
- Clerk returns a safe error class `api_response_error` with message summary `Not Found`.
- The page now maps this to `SUPABASE_AUTH_TOKEN_MISSING`.
- No `role_onboarding_requests` row is created.

This points to development Clerk/Supabase JWT template or auth-token configuration, not a role onboarding RPC parameter mismatch.

The expected classes are now explicit instead of hidden:

- `PROFILE_NOT_FOUND` if the JWT subject does not match an active synced profile.
- `RPC_PERMISSION_DENIED` if the Supabase session is not treated as `authenticated`.
- `SUPABASE_AUTH_TOKEN_MISSING` if Clerk does not return the Supabase JWT template token or the configured Clerk token template is not found.
- `DUPLICATE_PENDING_REQUEST` if a pending request already exists.

## B. Classification

The confirmed bug was server-action/error-mapping related.

No evidence was found that the UI exposed privileged roles or client-side `requested_role` input. No migration/RPC/RLS policy was changed.

## C. Fix Applied

Updated `app/onboarding/actions.ts`:

- Verifies the signed-in Clerk user exists before submit.
- Verifies `getCurrentSyncedProfile()` returns a profile before calling the RPC.
- Separates profile sync failure from missing Supabase auth token.
- Preserves the structured Supabase RPC error object instead of throwing only `error.message`.
- Emits development-only safe diagnostics with no token, password, service role key, or database password values.

Updated `lib/auth/role-onboarding.ts`:

- Added safe error codes:
  - `AUTH_REQUIRED`
  - `PROFILE_SYNC_FAILED`
  - `PROFILE_NOT_FOUND`
  - `DUPLICATE_PENDING_REQUEST`
  - `INVALID_ROLE`
  - `RPC_PERMISSION_DENIED`
  - `RPC_VALIDATION_FAILED`
  - `SUPABASE_AUTH_TOKEN_MISSING`
  - `UNKNOWN`
- Added safe error metadata construction for development diagnostics.
- Added mapping for Clerk token-template lookup failure: `api_response_error` plus message summary `Not Found` maps to `SUPABASE_AUTH_TOKEN_MISSING`.

Updated onboarding pages:

- `/onboarding/reseller`
- `/onboarding/supplier`

Both pages now show clear messages for the safe error codes instead of falling back to `UNKNOWN`.

## D. Error Mapping Improvements

Known expected failures no longer collapse to `UNKNOWN`.

Mapped examples:

- Missing auth: `AUTH_REQUIRED`
- Missing Supabase token: `SUPABASE_AUTH_TOKEN_MISSING`
- Synced profile unavailable: `PROFILE_SYNC_FAILED`
- RPC cannot find active profile: `PROFILE_NOT_FOUND`
- Duplicate pending request: `DUPLICATE_PENDING_REQUEST`
- Unsupported role: `INVALID_ROLE`
- RPC permission denied: `RPC_PERMISSION_DENIED`
- RPC validation failure: `RPC_VALIDATION_FAILED`

## E. Tests Added/Updated

Updated `tests/role-onboarding.test.ts` to cover:

- Auth-required mapping.
- Missing Supabase token mapping.
- Active profile not found mapping.
- Duplicate pending request mapping.
- Invalid role mapping.
- Profile sync failure mapping.
- RPC permission denied mapping.
- RPC validation failure mapping.
- Clerk token-template not found mapping.

Focused TDD check:

```bash
npm test -- tests/role-onboarding.test.ts
```

Result:

- Initially failed because known errors mapped to `UNKNOWN`.
- Failed again when Clerk `api_response_error: Not Found` was added as a regression.
- Passed after the token-template missing mapper fix.

## F. Migration Result

No migration was needed.

No `npx supabase db push`, dry-run, reset, or production Supabase command was run.

## G. Commands Run/Results

```bash
git status --short
```

Result before fix:

- Modified files were limited to onboarding action/pages, role-onboarding helper, tests, plus the untracked manual QA report.

```bash
npm test -- tests/role-onboarding.test.ts
```

Result:

- Red phase failed as expected when known submit failures still mapped to `UNKNOWN`.
- Green phase passed after the fix: 12 tests passed.
- Follow-up red phase failed as expected for Clerk `api_response_error: Not Found`.
- Follow-up green phase passed after mapping that error to `SUPABASE_AUTH_TOKEN_MISSING`.

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

## H. Secret Scan Result

Result:

- `.env.local` exists, is ignored by Git, and is not staged.
- `supabase/.temp/` exists, is ignored by Git, and is not staged.
- Filename-only secret pattern scan found existing docs/test/source files with secret-safety terminology, not printed secret values.
- No service role references were found in `app` or `components`.
- No token, service role key, bearer token, password, or API secret value was printed.

## I. Files Changed

- `app/onboarding/actions.ts`
- `app/onboarding/reseller/page.tsx`
- `app/onboarding/supplier/page.tsx`
- `lib/auth/role-onboarding.ts`
- `tests/role-onboarding.test.ts`
- `docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md`
- `docs/RISELLAR_ROLE_ONBOARDING_UNKNOWN_ERROR_FIX_REPORT.md`

## J. Current Git Status

Expected local changes after this fix:

- Modified onboarding action/pages.
- Modified role-onboarding helper.
- Modified role onboarding tests.
- Updated manual QA report.
- New UNKNOWN error fix report.

## K. Ready For Another Manual QA Run

Ready for another manual QA run: after Clerk/Supabase JWT template configuration is fixed.

The latest manual QA run confirmed:

- The request no longer returns `UNKNOWN`.
- The specific safe error is `SUPABASE_AUTH_TOKEN_MISSING`.
- Request creation is still blocked before the RPC can run as an authenticated Supabase user.

The next run should confirm one of two outcomes after development auth-token configuration is repaired:

- The request succeeds and creates a pending `role_onboarding_requests` row.
- The request returns a different specific safe code that identifies the next remaining backend/auth issue.

## Exact Next Prompt

```text
Fix the development Clerk/Supabase JWT template integration, then rerun role onboarding page manual QA.

Do NOT connect checkout, orders, products, settlements, commissions, payments, or inventory to live Supabase data.
Do NOT apply migrations.
Do NOT connect production Supabase.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT run destructive reset commands.
Do NOT run npm audit fix --force.

Context:
Role onboarding submit no longer returns UNKNOWN.
It now fails with SUPABASE_AUTH_TOKEN_MISSING.
Safe diagnostics show Clerk user exists, profile sync succeeds, but getToken({ template: "supabase" }) returns Clerk api_response_error / Not Found and no Supabase token.

Goal:
Repair only the development Clerk/Supabase JWT template or auth-token configuration so the server action can obtain a Supabase user token.

After the configuration fix, use the signed-in Clerk test account on http://localhost:400.

Verify:
1. /onboarding opens while signed in.
2. /onboarding/reseller submits a reseller request.
3. If it succeeds, confirm a pending development role_onboarding_requests row exists and profile.role remains customer.
4. If it fails, report the exact safe error code and page message.
5. Try duplicate reseller request only if the first reseller request succeeds.
6. Check /onboarding/supplier behavior.
7. Confirm no admin/super_admin/supplier_inventory_manager request can be made.
8. Confirm no client requested_role field is exposed.
9. Run npm test, npm run lint, npm run build, npm run typecheck, and secret scan.

Update docs/RISELLAR_ROLE_ONBOARDING_PAGE_MANUAL_QA_REPORT.md.
Do not commit unless asked.
```
