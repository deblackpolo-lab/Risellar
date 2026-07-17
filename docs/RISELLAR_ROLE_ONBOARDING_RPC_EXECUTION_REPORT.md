# Risellar Role Onboarding RPC Execution Report

## A. Development Project Confirmation

The migration and test attempt targeted the previously confirmed DEVELOPMENT Supabase project named `Risellar`.

No production Supabase project was intentionally connected.
No production data was used.
No destructive reset command was run.
No `.env.local` values or secret values were printed.

## B. Migration Applied

Applied migration:

- `20260717210000_role_onboarding_requests_rpc_foundation.sql`

## C. db Push Result

Command:

```bash
npx supabase db push
```

Result:

- Succeeded.
- Applied `20260717210000_role_onboarding_requests_rpc_foundation.sql`.
- Did not run `supabase db reset --linked`.
- Did not run any destructive reset command.

Supabase CLI output showed:

```text
Applying migration 20260717210000_role_onboarding_requests_rpc_foundation.sql...
Finished supabase db push.
```

## D. Role Onboarding RPC Test Result

Command:

```bash
npx supabase db query --linked --file scripts/rpc/role-onboarding-rpc-tests-dev-only.sql
```

Result:

- Failed before reliable assertions could be recorded.
- The test script stopped on a temp fixture table permission error.

Exact error:

```text
ERROR: 42501: permission denied for table role_onboarding_fixture_ids
HINT: Grant the required privileges to the current role with: GRANT INSERT ON pg_temp_57.role_onboarding_fixture_ids TO authenticated;
```

## E. Passed Assertions

No pass/fail assertions were reliably recorded because the script failed before the assertion summary.

## F. Failed Assertion/Error If Any

No role/RPC boundary assertion failure was recorded.

The observed failure was:

```text
permission denied for table role_onboarding_fixture_ids
```

## G. Failure Classification

Classification:

- `test assertion bug`

More specifically, this is a development test harness permission bug. The script switches into `authenticated` role context and later attempts to insert into the temporary fixture-id table, but the temp table was only granted `select` to public.

This is not evidence of a real role/RPC security gap.

## H. Role Escalation Protections Verified

The migration has been applied to development, but the boundary test suite did not complete.

Static protections in the applied migration include:

- Customers can only request `reseller` or `supplier_owner`.
- Admin, super admin, supplier inventory manager, and customer self-request roles are blocked by RPC validation and table constraints.
- Profile role changes require `review_role_onboarding_request`.
- Review requires `public.has_admin_role('admin')`.
- Self-review is blocked.
- Direct client update/delete policies were not added for `public.role_onboarding_requests`.

Runtime verification remains blocked until the test harness permission issue is fixed and the script is rerun.

## I. Fixture/Test Data Rollback Or Cleanup

The script is wrapped in a transaction and intended to end with rollback.

Because execution failed before completion, the linked query did not report the final rollback assertion summary. The failing script execution should not be treated as a passing cleanup verification. A rerun after fixing the test harness should explicitly confirm rollback/cleanup.

## J. Commands Run/Results

Commands run:

```bash
git status --short
```

Result:

- Clean before execution.

```bash
npx supabase --version
```

Result:

- `2.109.1`

```bash
npx supabase db push
```

Result:

- Succeeded.
- Applied `20260717210000_role_onboarding_requests_rpc_foundation.sql`.

```bash
npx supabase db query --linked --file scripts/rpc/role-onboarding-rpc-tests-dev-only.sql
```

Result:

- Failed with `ERROR: 42501: permission denied for table role_onboarding_fixture_ids`.

Normal verification commands were not run after the failed boundary test because the instruction was to stop immediately on first failure.

## K. Secret Scan Result

Result:

- `.env.local` is ignored and not staged.
- `supabase/.temp/` is ignored.
- No secret values were printed.
- Filename-only scan found existing documentation and server-helper files that contain secret-safety keywords.
- No real Clerk/Supabase/service-role values, bearer tokens, passwords, API secrets, or production data were exposed in command output.

## L. Current Git Status

At report creation time, the only intended new local file is:

- `docs/RISELLAR_ROLE_ONBOARDING_RPC_EXECUTION_REPORT.md`

## M. Whether Production Remains Blocked

Production remains blocked.

The migration was applied to development, but role onboarding RPC boundary tests did not pass. The test harness permission bug must be fixed and the development-only test suite must pass before production can be considered.

## N. Harness Fix Update

The first runtime role onboarding RPC test failed before assertions because `role_onboarding_fixture_ids` was created as a temporary table with `select` granted, but the script later switched to the simulated `authenticated` role and inserted request IDs into that fixture table.

Fix applied:

- `scripts/rpc/role-onboarding-rpc-tests-dev-only.sql` now grants `select, insert` on the temporary `role_onboarding_fixture_ids` table to `authenticated`.

No migration, RPC, or RLS policy was changed.
No role escalation or security assertion was removed or weakened.
No real role/RPC security gap has been confirmed yet.

The role onboarding RPC boundary tests still require explicit approval before rerun.

## Required Fix Prompt

```text
You are working on Risellar.

Task: fix the development-only role onboarding RPC test harness temp-table permission bug.

Do NOT connect to production Supabase.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS/RPC/storage policies.
Do NOT run the role onboarding RPC test yet.
Do NOT run npm audit fix --force.

Context:
The role onboarding requests/RPC migration was applied to the confirmed DEVELOPMENT Supabase project named "Risellar".
The development-only RPC test failed before assertions with:
ERROR: 42501: permission denied for table role_onboarding_fixture_ids
HINT: Grant the required privileges to the current role with: GRANT INSERT ON pg_temp_57.role_onboarding_fixture_ids TO authenticated;

Classification:
This is a test harness permission bug, not a confirmed real RPC/security gap.

Goal:
Fix only scripts/rpc/role-onboarding-rpc-tests-dev-only.sql so the simulated authenticated role can use the temporary fixture table safely.

Requirements:
1. Keep the script marked DEVELOPMENT ONLY.
2. Do not weaken RLS or RPC policies.
3. Do not change the database migration.
4. Do not remove assertions.
5. Grant only the needed temp table privileges to the simulated roles, likely insert/select/update where needed for role_onboarding_fixture_ids.
6. Preserve rollback behavior.
7. Update docs/RISELLAR_ROLE_ONBOARDING_RPC_EXECUTION_REPORT.md to record that the harness bug was fixed and tests still require explicit approval before rerun.

Run:
git status --short
git diff --check
npm test
npm run lint
npm run build
npm run typecheck

Run secret scan:
- .env.local ignored and not staged
- supabase/.temp/ ignored
- no real secrets in docs/scripts/source
- no service role values exposed
- no bearer tokens, passwords, API secrets, or production data

Do not run:
npx supabase db query --linked --file scripts/rpc/role-onboarding-rpc-tests-dev-only.sql

Commit after verification if clean.
```
