# Risellar Role Onboarding Requests RPC Report

## A. Summary

Created a real role onboarding request table and audited RPC foundation for customer-to-reseller and customer-to-supplier-owner onboarding. The implementation is code/schema foundation only and was not applied with a real database push.

## B. Files Created Or Updated

- `supabase/migrations/20260717210000_role_onboarding_requests_rpc_foundation.sql`
- `scripts/rpc/role-onboarding-rpc-tests-dev-only.sql`
- `scripts/rpc/README.md`
- `lib/auth/role-onboarding.ts`
- `tests/role-onboarding.test.ts`
- `docs/RISELLAR_ROLE_ONBOARDING_REQUESTS_RPC_REPORT.md`

## C. Migration Created

Migration:

- `20260717210000_role_onboarding_requests_rpc_foundation.sql`

The migration adds `public.role_onboarding_requests` with:

- `id`
- `profile_id`
- `requested_role`
- `status`
- `business_name`
- `contact_phone`
- `notes`
- `submitted_at`
- `reviewed_by`
- `reviewed_at`
- `review_notes`
- `created_at`
- `updated_at`

## D. Table And Constraint Review

Requested roles are constrained to:

- `reseller`
- `supplier_owner`

Blocked requested roles include:

- `admin`
- `super_admin`
- `supplier_inventory_manager`
- `customer`

Statuses are constrained to:

- `pending`
- `approved`
- `rejected`
- `cancelled`

Duplicate pending requests are blocked by a partial unique index on `(profile_id, requested_role)` where `status = 'pending'`.

## E. RLS Review

RLS is enabled and forced on `public.role_onboarding_requests`.

Policies added:

- User can select own requests.
- Admin can select the review queue.
- Customer can insert their own valid pending request.

No update or delete policy was added. Direct status/review mutation is intentionally blocked and must go through the review RPC.

Static check result:

- No `FOR ALL` policies.
- No `USING (true)`.
- No `WITH CHECK (true)`.
- No direct delete policy.
- No direct update policy.

## F. RPC Review

Created:

- `public.submit_role_onboarding_request(public.user_role, text, text, text)`
- `public.review_role_onboarding_request(uuid, text, text)`

Submit RPC:

- Requires an authenticated active profile.
- Requires current primary role `customer`.
- Allows only `reseller` or `supplier_owner`.
- Blocks duplicate pending requests for the same role.
- Writes an audit row through `public.create_audit_log_entry`.

Review RPC:

- Requires admin role through `public.has_admin_role('admin')`.
- Allows only `approved` or `rejected`.
- Blocks self-review.
- Requires requester to still be an active customer before approval.
- Updates profile primary role only after admin approval.
- Creates a reseller foundation row for approved reseller requests.
- Creates a supplier foundation row for approved supplier owner requests.
- Writes an audit row through `public.create_audit_log_entry`.

## G. Role Self-Promotion Review

Role self-promotion is blocked.

Normal users cannot request admin, super admin, supplier inventory manager, or customer roles through the RPC. Customers can only request `reseller` or `supplier_owner`, and the profile role is not changed until an admin reviews and approves the request.

## H. Direct Mutation Review

Clients receive only `select` and `insert` grants on `public.role_onboarding_requests`.

No direct client path was added for:

- Updating `status`
- Updating `reviewed_by`
- Updating `reviewed_at`
- Updating `review_notes`
- Deleting requests

## I. Development-Only Test Script

Created:

- `scripts/rpc/role-onboarding-rpc-tests-dev-only.sql`

The script is marked development-only, uses fake `example.invalid` identities, uses a transaction with rollback, and was not run.

Coverage includes:

- Anonymous request blocking
- Customer request submission
- Duplicate pending request blocking
- Admin/supplier inventory manager self-request blocking
- Direct status update blocking
- Direct delete blocking
- Normal user audit log blocking
- Non-admin review blocking
- Admin review queue access
- Reseller approval path
- Supplier owner approval path
- Rejection path
- Audit row assertions

## J. Dry-Run Result

Supabase CLI version:

- `2.109.1`

Dry-run command:

- `npx supabase db push --dry-run`

Result:

- Passed.
- No real migration was applied.
- Dry-run showed only this migration would be pushed:
  - `20260717210000_role_onboarding_requests_rpc_foundation.sql`

Note:

- `npx supabase status` attempted to inspect local Docker container health and failed because Docker was not available. This did not block the remote dry-run, which connected to the linked remote development database and completed successfully.

## K. Normal Verification

Commands run:

- `npm test -- tests/role-onboarding.test.ts`
  - First run failed as expected because the helper still returned `pending_review`.
  - After the helper update, passed: 8 tests.
- `git diff --check`
  - Passed with line-ending warnings only.
- `npm test`
  - Passed: 21 test files, 101 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.
- `npm run typecheck`
  - Passed.

## L. Secret And Env Scan

Result:

- `.env.local` is ignored.
- `.env.local` is not staged.
- `supabase/.temp/` is ignored.
- No secret patterns were found in the new migration or new role onboarding RPC test script.
- Filename-only scan found expected placeholder/keyword references in existing docs, `.env.example`, and the server-only Supabase admin helper.
- No real Clerk/Supabase/service-role values were printed.
- No bearer tokens, passwords, API secrets, or production data were found in the new files.

## M. Remaining Blockers

Before applying beyond code/schema foundation:

- Apply this migration to the confirmed development Supabase project only after explicit approval.
- Run `scripts/rpc/role-onboarding-rpc-tests-dev-only.sql` against the confirmed development project after migration apply.
- Confirm audit rows and role transitions in development.
- Production remains blocked until development migration execution and boundary tests pass.

## N. Recommendation

Safe to request approval for a real development-only `npx supabase db push`: yes.

Safe to apply to production Supabase: no.

Recommended next prompt:

```text
I approve applying the role onboarding requests/RPC migration to the confirmed DEVELOPMENT Supabase project named "Risellar", then running the development-only role onboarding RPC boundary tests.

Do NOT connect to production Supabase.
Do NOT use production data.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS/RPC/storage policies.
Do NOT run npm audit fix --force.

Run:
git status --short
npx supabase db push
npx supabase db query --linked --file scripts/rpc/role-onboarding-rpc-tests-dev-only.sql
npm test
npm run lint
npm run build
npm run typecheck

Create/update the role onboarding RPC execution report and stop on the first failure.
```

