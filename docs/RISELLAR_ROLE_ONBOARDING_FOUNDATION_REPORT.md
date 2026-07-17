# Risellar Role Onboarding Foundation Report

## A. Summary

Implemented a safe role onboarding foundation for customers to request reseller or supplier access without self-promoting their profile role.

This work does not connect checkout, orders, products, settlements, commissions, payments, or production Supabase data to live backend flows. It does not apply migrations or weaken RLS/RPC/storage policies.

## B. Role Onboarding Model

Current role model:

- every Clerk-synced user starts as `customer`;
- customers can start a reseller access request;
- customers can start a supplier access request;
- reseller requests map to a pending `reseller` target role;
- supplier requests map to a pending `supplier_owner` target role;
- admin, support, finance, and supplier inventory manager access remain outside public request flows;
- supplier inventory manager remains invite-only for later supplier team flows;
- role transitions remain future audited backend work.

The implementation returns request drafts only. It does not update `public.profiles.primary_role`.

## C. Pages/Helpers Created Or Updated

Created:

- `lib/auth/role-onboarding.ts`
- `app/onboarding/page.tsx`
- `app/onboarding/reseller/page.tsx`
- `app/onboarding/supplier/page.tsx`
- `app/onboarding/pending/page.tsx`
- `tests/role-onboarding.test.ts`

Updated:

- `lib/auth/role-policy.ts`
- `middleware.ts`

New pages are Clerk-protected by middleware and modeled in route guard policy as customer-only request surfaces. They are mock/request-prep pages only and do not write to Supabase.

## D. Role Escalation Protections

Protections implemented:

- `buildProfileInsert()` still defaults synced profiles to `customer`;
- `buildRoleOnboardingRequestDraft()` only accepts customer profiles;
- public request kinds are limited to `reseller` and `supplier`;
- `supplier` maps to a pending `supplier_owner` request, not an assigned role;
- `admin` cannot be requested through the public helper;
- `supplier_inventory_manager` cannot be requested through the public helper;
- reseller/supplier/admin workspaces remain protected;
- no client component or page writes profile roles;
- no frontend-only role trust was added.

## E. Migration Needed Or Not

No migration was created or applied.

The existing schema supports `profiles`, `resellers`, `suppliers`, approval statuses, and pending supplier/reseller records, but it does not include a generic `role_onboarding_requests` table. This foundation intentionally stops at typed request drafts and protected mock pages.

Recommended future migration, after dry-run approval:

- `public.role_onboarding_requests`
- fields: `id`, `profile_id`, `requested_role`, `status`, `business_name`, `contact_phone`, `notes`, `reviewed_by`, `reviewed_at`, `created_at`, `updated_at`
- RLS: customer can create/read their own request; customer cannot approve; admin can review through audited RPCs.

## F. Tests Added

Added `tests/role-onboarding.test.ts` covering:

- default customer role remains safe;
- customer can draft reseller onboarding request;
- customer can draft supplier onboarding request;
- admin cannot be publicly requested;
- supplier inventory manager cannot be publicly requested;
- already-promoted or privileged roles cannot submit public onboarding requests;
- role redirects remain predictable;
- `/onboarding/*` route policy is customer-only and auth-dependent;
- request paths are fixed and do not support client-side role escalation.

## G. Commands Run/Results

Commands run:

- `git status --short`: showed expected role-onboarding files only.
- `git diff --check`: passed with line-ending normalization warnings for touched files.
- `npm test -- tests/role-onboarding.test.ts`: passed, 8 tests.
- `npm test`: passed, 21 test files / 101 tests.
- `npm run lint`: passed with `eslint . --max-warnings=0`.
- `npm run build`: passed; Next generated 165 app routes including `/onboarding`, `/onboarding/reseller`, `/onboarding/supplier`, and `/onboarding/pending`.
- `npm run typecheck`: passed.
- secret scan: passed.

No Supabase migration dry-run was needed because no migration was created. No real `supabase db push`, destructive reset, or production connection was used.

## H. Secret Scan Result

Passed.

- `.env.local` exists locally, is ignored by Git, is not tracked, and is not staged.
- `supabase/.temp/` is ignored by Git.
- no high-confidence real Clerk/Supabase/service-role values were found in docs/source/scripts/tests.
- no bearer tokens, passwords, API secrets, or production data were detected by the value-suppressing scan.
- no client component imports `SUPABASE_SERVICE_ROLE_KEY`, `CLERK_SECRET_KEY`, `SUPABASE_DB_PASSWORD`, `createSupabaseAdminClient`, or the server-only profile sync helper.
- no files are staged.

## I. Files Changed

- `app/onboarding/page.tsx`
- `app/onboarding/reseller/page.tsx`
- `app/onboarding/supplier/page.tsx`
- `app/onboarding/pending/page.tsx`
- `docs/RISELLAR_ROLE_ONBOARDING_FOUNDATION_REPORT.md`
- `lib/auth/role-onboarding.ts`
- `lib/auth/role-policy.ts`
- `middleware.ts`
- `tests/role-onboarding.test.ts`

## J. Current Git Status

```text
 M lib/auth/role-policy.ts
 M middleware.ts
?? app/onboarding/
?? docs/RISELLAR_ROLE_ONBOARDING_FOUNDATION_REPORT.md
?? lib/auth/role-onboarding.ts
?? tests/role-onboarding.test.ts
```

## K. Safe To Commit

Yes.

This is safe to commit as a role onboarding foundation because it adds protected request-model helpers and mock/request-prep pages only. It does not create a persistence table, apply a migration, mutate profile roles, or connect business workflows to live Supabase data.

## L. Recommended Next Step

After this foundation is committed, plan the `role_onboarding_requests` migration and audited review RPCs as a separate backend step. Run dry-run before any migration apply.
