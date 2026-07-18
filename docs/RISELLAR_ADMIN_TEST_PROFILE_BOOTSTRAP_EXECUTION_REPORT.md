# Risellar Admin Test Profile Bootstrap Execution Report

## A. Confirmed Development Project

- Supabase CLI version: `2.109.1`
- Linked project name: `Risellar`
- Linked project status: `ACTIVE_HEALTHY`
- Linked project ref matched local `.env.local` project ref.
- This was performed against the confirmed DEVELOPMENT Supabase project only.
- No production Supabase project was connected.

## B. Confirmed Admin Email

- Confirmed test account, masked: `ex***@gmail.com`
- No credentials, tokens, full Clerk identifiers, database passwords, or secret values were printed.

## C. Profile Id Used

- Profile id: `50c02a70-be36-4d58-a206-103b44da7aef`
- This matched the previously discovered candidate profile.

## D. Before State

- Profile existed: yes
- Email matched the confirmed test account: yes
- `profiles.account_status`: `active`
- `profiles.primary_role`: `customer`
- Active admin_staff row before bootstrap: no
- Existing admin_staff rows before bootstrap: `0`

## E. Insert Performed Or Existing Row Found

An insert-only development bootstrap was performed.

- Target profile count: `1`
- Inserted admin_staff rows: `1`
- Existing admin_staff rows before insert: `0`
- `admin_role`: `admin`
- `staff_status`: `active`

The insert used `on conflict (profile_id) do nothing` and did not duplicate an existing row.

## F. After State

Read-only verification after the insert confirmed:

- Profile id: `50c02a70-be36-4d58-a206-103b44da7aef`
- Masked email: `ex***@gmail.com`
- `profiles.account_status`: `active`
- `profiles.primary_role`: `customer`
- admin_staff rows for the profile: `1`
- active admin_staff row exists: yes
- `admin_staff.admin_role`: `admin`
- `admin_staff.staff_status`: `active`

## G. Confirmation profiles.primary_role Stayed Customer

Confirmed. `profiles.primary_role` remained `customer`.

No `public.profiles` update was run.

## H. Confirmation admin_staff Grants Admin Access

Confirmed with a safe user-context simulation:

- `public.current_profile_id()` matched the target profile.
- `public.has_admin_role('admin')` returned `true`.
- `public.has_admin_role('support_staff')` returned `true`.
- `public.has_admin_role('finance_staff')` returned `true`.

The support/finance results are expected because the schema treats `admin` as satisfying `support_staff`, `finance_staff`, and `admin` requirements.

## I. Commands Run/Results

- `git status --short`
  - Clean before this report update.
- `npx supabase --version`
  - `2.109.1`
- `.env.local` and `supabase/.temp/` checks
  - `.env.local` exists, ignored, untracked, unstaged.
  - `supabase/.temp/` ignored.
- `npx supabase projects list`
  - Linked project: `Risellar`, `ACTIVE_HEALTHY`.
- Read-only profile query
  - Found profile id `50c02a70-be36-4d58-a206-103b44da7aef`.
  - Confirmed masked email, `primary_role = customer`, `account_status = active`.
- `information_schema.columns` query for `public.admin_staff`
  - Confirmed required columns and defaults.
- Development-only admin_staff insert
  - Inserted `1` row.
- Read-only verification query
  - Confirmed one active admin row and profile role unchanged.
- Safe user-context `has_admin_role` verification
  - `has_admin_role('admin') = true`.
- `npm test`
  - Passed: 21 test files, 109 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.
- `npm run typecheck`
  - Passed.

## J. Secret Scan Result

- `.env.local` ignored: yes
- `.env.local` tracked: no
- `.env.local` staged: no
- `supabase/.temp/` ignored: yes
- Service-role imports in app/components: no
- Secret-pattern matches in source/docs/scripts: `0`
- No real Clerk/Supabase/service-role values, bearer tokens, passwords, API secrets, or production data were added.

## K. Current Git Status

- Modified: `docs/RISELLAR_ADMIN_TEST_PROFILE_BOOTSTRAP_PLAN.md`
- Untracked: `docs/RISELLAR_ADMIN_TEST_PROFILE_BOOTSTRAP_EXECUTION_REPORT.md`
- No files staged.

## L. Whether Safe To QA /admin/onboarding-requests

Yes. The development admin test profile now has active `public.admin_staff` membership with `admin_role = 'admin'`, while `profiles.primary_role` remains `customer`.

Admin review QA proceeded against the confirmed development project using the audited `review_role_onboarding_request` RPC under the admin test user context. A browser click-through spot-check can still be performed with the admin test account to confirm the page shows the reviewed/empty state.
