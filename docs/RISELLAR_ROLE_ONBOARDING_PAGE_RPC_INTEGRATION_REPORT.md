# Risellar Role Onboarding Page RPC Integration Report

## A. Summary

Connected the role onboarding request pages to the real `submit_role_onboarding_request` RPC through a server action. The integration is limited to role onboarding request submission only.

No checkout, orders, products, settlements, commissions, payments, inventory, admin approval UI, or live business workflow integration was started.

## B. Pages Connected

Connected pages:

- `/onboarding/reseller`
- `/onboarding/supplier`
- `/onboarding/pending`

Unchanged as an entry page:

- `/onboarding`

The reseller and supplier pages now render forms that submit optional:

- `business_name`
- `contact_phone`
- `notes`

## C. Server Action/Helper Created

Created:

- `app/onboarding/actions.ts`

Updated:

- `lib/supabase/server.ts`
- `lib/auth/role-onboarding.ts`

The server action:

- Requires a signed-in Clerk user.
- Ensures the Clerk user has a synced Supabase profile before submission.
- Gets a Clerk-issued Supabase token for user-context RPC execution.
- Calls only `submit_role_onboarding_request`.
- Redirects to `/onboarding/pending?request=<role>&status=submitted` on success.
- Redirects back to the relevant request form with a compact error code on failure.

The normal request submission RPC uses a user-context Supabase client with the public anon key and bearer token. The service role helper is not used for the RPC submission path.

## D. Security Protections

Role escalation protections:

- Reseller page submits only `reseller`.
- Supplier page submits only `supplier_owner`.
- No page exposes a `requested_role` input.
- `admin`, `super_admin`, and `supplier_inventory_manager` cannot be chosen by the client.
- The page does not mutate `profiles.primary_role`.
- Profile role changes remain gated by the separate admin review RPC.

Secret protections:

- No service role key is imported into onboarding pages or actions.
- No server-only secret is exposed to client components.
- Existing `createSupabaseAdminClient` remains server-only and is used by the existing profile sync path only.

## E. Error Handling

Mapped errors include:

- Unauthenticated user: prompts sign-in before submission.
- Duplicate pending request: clearly states a pending request already exists.
- Invalid requested role: clearly states the role cannot be requested from the page.
- Non-customer profile: clearly states only customers can request access.
- Profile sync/token preparation issue: asks the user to try again.
- Unknown RPC failure: generic retry message.

## F. Tests Added/Updated

Updated:

- `tests/role-onboarding.test.ts`

Added coverage for:

- Reseller request config maps only to `reseller`.
- Supplier request config maps only to `supplier_owner`.
- Admin role cannot be requested.
- Supplier inventory manager role cannot be requested.
- Duplicate request error handling.
- Unauthenticated error handling.
- Profile sync error handling.
- Service role helpers are not imported into onboarding pages/actions.
- No client-controlled `requested_role` field is present in onboarding pages/actions.

## G. Manual QA Notes

Manual browser submission was not performed in this task. Automated tests, build, typecheck, and static source scans passed.

The pages remain visually consistent with the existing mock onboarding style. The previous preview links were replaced with real submit forms while preserving the surrounding cards, icons, guidance copy, and pending state.

## H. Commands Run/Results

Commands run:

```bash
npm test -- tests/role-onboarding.test.ts
```

Initial focused run failed as expected before implementation because the new helper/action APIs did not exist. After implementation, the focused test passed: 12 tests.

```bash
git diff --check
```

Passed with line-ending warnings only.

```bash
npm test
```

Passed: 21 test files, 105 tests.

```bash
npm run lint
```

Passed.

```bash
npm run build
```

Passed.

```bash
npm run typecheck
```

Passed.

No Supabase migration or reset command was run.

## I. Secret Scan Result

Result:

- `.env.local` is ignored and not staged.
- `supabase/.temp/` is ignored.
- No secret values were printed.
- Filename-only scan found existing documentation/test files that mention secret-safety terms.
- No service role reference was found in `app` or `components`.
- Existing `SUPABASE_SERVICE_ROLE_KEY` source reference remains isolated to `lib/supabase/admin.ts`.
- No bearer tokens, passwords, API secrets, or production data were found in the changed onboarding source.

## J. Files Changed

- `app/onboarding/actions.ts`
- `app/onboarding/reseller/page.tsx`
- `app/onboarding/supplier/page.tsx`
- `app/onboarding/pending/page.tsx`
- `lib/auth/role-onboarding.ts`
- `lib/supabase/server.ts`
- `tests/role-onboarding.test.ts`
- `docs/RISELLAR_ROLE_ONBOARDING_PAGE_RPC_INTEGRATION_REPORT.md`

## K. Current Git Status

Local working tree has uncommitted role onboarding page/RPC integration changes and this report.

## L. Whether Safe To Commit

Safe to commit: yes, after review.

Production remains blocked from any new Supabase apply or production data use. This task only connected development-ready role onboarding request pages to the previously applied and tested RPC foundation.

