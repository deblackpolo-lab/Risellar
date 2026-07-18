# Risellar Admin Test Profile Bootstrap Plan

## Summary

Prepared and executed a development-only bootstrap for a dedicated Clerk admin test account so `/admin/onboarding-requests` can be manually QA'd.

The bootstrap inserted only one `public.admin_staff` row in the confirmed development Supabase project. No `public.profiles` row was updated. No production Supabase project was contacted. No secrets, credentials, full email addresses, Clerk user ids, or database passwords were printed.

## Development project confirmation

- Supabase CLI version: `2.109.1`
- Linked Supabase project name: `Risellar`
- Linked project status: `ACTIVE_HEALTHY`
- Linked project ref matched `SUPABASE_PROJECT_REF` from `.env.local`.
- `.env.local` exists, is ignored by Git, is not tracked, and was not staged.
- `supabase/.temp/` is ignored by Git.

Per prior project confirmation, the linked `Risellar` Supabase project is being treated as the DEVELOPMENT project only.

## Profile discovery result

Read-only profile discovery found two development profiles.

Most recent profile candidate:

- Profile id: `50c02a70-be36-4d58-a206-103b44da7aef`
- Masked email: `ex***@gmail.com`
- Current role: `customer`
- Account status: `active`
- Created at: `2026-07-18 01:35:36.190637+00`
- Test-marker query: `false`

Earlier profile:

- Profile id: `86e88b08-7c4f-4090-a8e7-211f2997b900`
- Masked email: `de***@gmail.com`
- Current role: `customer`
- Account status: `active`
- Created at: `2026-07-17 22:37:53.117666+00`
- Test-marker query: `false`

The most recent profile was created after the user reported signing into the dedicated admin test Clerk account and visiting `/auth/qa-profile-sync`, so it is the likely admin test profile. However, the masked email/full-name metadata does not itself contain an obvious `admin`, `qa`, or `test` marker. Explicit user confirmation of the masked email/profile id is required before running any bootstrap SQL.

## Current role

The likely admin test profile currently has:

- `primary_role = customer`
- `account_status = active`

This is expected and should not be changed directly for admin QA.

## Schema requirement

The schema does not model admin access by setting `profiles.primary_role` to `admin`.

Relevant schema findings:

- `public.profiles.primary_role` defaults to `customer`.
- `profiles_no_self_admin_signup` blocks `primary_role` values in `admin`, `super_admin`, `finance_staff`, and `support_staff`.
- `public.has_admin_role(required_role)` checks `public.admin_staff`, not `profiles.primary_role`.
- `review_role_onboarding_request` requires `public.has_admin_role('admin')`.
- Active `admin_staff` rows with `admin` or `super_admin` privileges counted as `0` before bootstrap.
- After bootstrap, the confirmed development admin test profile has one active `admin_staff` row with `admin_role = 'admin'`.

Therefore, a development admin test bootstrap should create a dev-only `public.admin_staff` row for the confirmed test profile. It should not update `public.profiles.primary_role`.

## Admin gate alignment

The `/admin/onboarding-requests` page/action originally had an app-local helper gate that treated `profiles.primary_role === "admin"` as sufficient admin access.

That was corrected before any admin bootstrap SQL was run.

Current app behavior:

- `profiles.primary_role` may remain `customer` for the admin test account.
- Admin review access is based on active `public.admin_staff` membership.
- The server-only helper calls `public.has_admin_role('admin')` through the signed-in user's Supabase user-context token.
- A `profiles.primary_role = 'admin'` value alone is not accepted as admin review access by the app helper.
- `review_role_onboarding_request` remains the only approve/reject mutation path.
- No UI self-promotion path was added.

## Proposed development-only bootstrap SQL

This SQL was run only after explicit user confirmation that the masked profile id belonged to the intended development admin test account.

```sql
-- DEVELOPMENT ONLY -- DO NOT RUN AGAINST PRODUCTION.
-- Purpose: allow a dedicated Clerk admin test account to QA /admin/onboarding-requests.
-- Preconditions:
-- 1. Linked Supabase project is the confirmed DEVELOPMENT project named Risellar.
-- 2. Profile id belongs to the dedicated admin test Clerk account.
-- 3. Profile is active and currently primary_role = 'customer'.
-- 4. No real user profile is being modified.

begin;

insert into public.admin_staff (
  profile_id,
  admin_role,
  permissions,
  staff_status,
  assigned_by_profile_id
)
select
  p.id,
  'admin'::public.user_role,
  jsonb_build_object(
    'development_only', true,
    'purpose', 'manual admin onboarding request QA',
    'created_by', 'Risellar QA coordinator'
  ),
  'active'::public.staff_status,
  null
from public.profiles p
where p.id = '50c02a70-be36-4d58-a206-103b44da7aef'
  and p.primary_role = 'customer'
  and p.account_status = 'active'
  and p.deleted_at is null
on conflict (profile_id) do nothing
returning id, profile_id, admin_role, staff_status, created_at;

commit;
```

The bootstrap inserted one row. A follow-up read-only verification confirmed:

- `profiles.primary_role` remained `customer`.
- `admin_staff.admin_role = admin`.
- `admin_staff.staff_status = active`.
- Safe user-context simulation returned `public.has_admin_role('admin') = true`.

## Approval requirement

Explicit approval was received before running the development-only SQL bootstrap.

Before approval, the user should confirm:

- The intended masked profile is `ex***@gmail.com`.
- The intended profile id is `50c02a70-be36-4d58-a206-103b44da7aef`.
- This profile is a development-only Clerk test account.

## Commands run/results

- `git status --short; git branch --show-current; git log --oneline -3`
  - Branch: `main`
  - Latest commit: `1f3bce57 Add admin onboarding request review UI`
- `npx supabase --version`
  - `2.109.1`
- `.env.local` / `.gitignore` checks
  - `.env.local` exists, ignored, untracked, unstaged
  - `supabase/.temp/` ignored
- `npx supabase projects list`
  - Linked project: `Risellar`
  - Status: `ACTIVE_HEALTHY`
- Read-only schema inspection
  - Admin access uses `public.admin_staff` and `public.has_admin_role`.
- Read-only profile discovery query
  - Found two development profiles with masked emails only.
  - Most recent candidate role is `customer`.
- Read-only admin-staff count query before bootstrap
  - Active admin/super_admin staff count: `0`
- Development-only `admin_staff` insert
  - Inserted admin_staff rows: `1`
- Read-only verification after bootstrap
  - Active admin_staff row exists for the confirmed profile.
  - Profile role remained `customer`.
  - `public.has_admin_role('admin')` returned `true` under a safe simulated user-context claim.
- `npm test`
  - Passed: 21 test files, 109 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.
- `npm run typecheck`
  - Passed.

## Current git status

This report is modified/uncommitted. The execution report is also untracked. No files are staged.

## Recommendation

The development-only bootstrap is complete. Do not rerun it unless a later verification shows the test admin_staff row was removed or deactivated.

Next step:

1. Manually QA `/admin/onboarding-requests` approve/reject using the admin test account.
2. Commit the bootstrap execution report if accepted.
