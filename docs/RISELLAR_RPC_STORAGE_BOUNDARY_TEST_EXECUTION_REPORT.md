# Risellar RPC and Storage Boundary Test Execution Report

## A. Development Project Confirmation

The linked Supabase project was confirmed as the intended development project named `Risellar`.

Precheck results:

- Working tree was clean before execution.
- Supabase CLI version was `2.109.1`.
- `.env.local` exists.
- `.env.local` is ignored by Git.
- `.env.local` was not staged.
- `supabase/.temp/` is ignored.
- Supabase CLI project list returned a linked project named `Risellar`.

No secret values were printed.

## B. RPC Test Result

Result: failed.

Command executed:

```bash
npx supabase db query --linked --file scripts/rpc/rpc-boundary-tests-dev-only.sql
```

The RPC script reached the final assertion summary and failed with 8 assertion failures.

## C. Storage Test Result

Result: not run.

The storage test was intentionally not executed because the RPC test failed first and the approved instructions required stopping immediately on the first failure.

## D. Passed Assertions

The RPC script progressed far enough to execute multiple RPC paths and reach final assertion aggregation. The returned error only included failed assertion rows, not the full result table.

No storage assertions were run.

## E. Failed Assertion/Error

Exact RPC failure returned by Supabase:

```text
ERROR: P0001: RPC boundary tests failed: 8 failure(s): commission release writes audit row - expected=1, observed=0
customer confirmation RPC writes audit row - expected=1, observed=0
delivery quote approval writes audit row - expected=1, observed=0
reseller withdrawal request writes audit row - expected=1, observed=0
reservation release writes audit row - expected=1, observed=0
settlement proof submission writes audit row - expected=1, observed=0
settlement verification writes audit row - expected=1, observed=0
withdrawal approval writes audit row - expected=1, observed=0
CONTEXT: PL/pgSQL function inline_code_block line 16 at RAISE
```

## F. Failure Classification

Classification: test assertion bug.

Reason:

- The failing assertions count rows in `public.audit_logs` while the session is still acting as customer, reseller, supplier, support, or finance users.
- Existing RLS intentionally restricts `audit_logs` SELECT to admin roles.
- Therefore an audited RPC can write an audit row successfully while the non-admin caller still observes `0` rows when querying `audit_logs`.
- The failure does not currently prove a real RPC/security gap.

Required fix:

- Update the RPC boundary test so audit-row existence is checked from an admin context after the audited action, or through a dedicated development-only verification block that does not weaken production RLS.
- Do not grant normal users audit-log read access.
- Do not weaken audited RPC authorization or audit logging.

Fix status:

- `scripts/rpc/rpc-boundary-tests-dev-only.sql` was updated so audit-log existence checks run from the admin verification context.
- Normal-user audit-log denial assertions were added/preserved for customer, reseller, and supplier-owner contexts.
- A guard assertion was added: `test setup/admin verification context cannot read audit logs`.
- Existing audit-log assertions were preserved.
- No RLS policy, RPC function, grant, or migration was changed.
- The RPC and storage boundary tests still require explicit approval before rerun.

## G. Whether Fixture/Test Data Was Rolled Back/Cleaned Up

The RPC script uses an explicit transaction and rollback strategy. It failed by raising an exception inside that transaction before reaching the explicit `rollback`.

Because the query failed inside the open transaction, the transaction was aborted and should not commit fixture/test data. A follow-up rerun after fixing the test assertion should still confirm cleanup behavior.

The storage script was not run, so it created no fixture data.

## H. Commands Run/Results

- `git status --short` - clean before test execution.
- `npx supabase --version` - `2.109.1`.
- `.env.local` / `supabase/.temp/` precheck - passed without printing values.
- `npx supabase projects list` - confirmed linked project named `Risellar`.
- `npx supabase db query --linked --file scripts/rpc/rpc-boundary-tests-dev-only.sql` - failed with 8 audit-row visibility assertions.

Not run because RPC test failed first:

- `npx supabase db query --linked --file scripts/storage/storage-boundary-tests-dev-only.sql`
- `npm test`
- `npm run typecheck`
- `npm run lint`
- `npm run build`
- final secret scan

## I. Secret Scan Result

Final secret scan was not run because execution stopped immediately after the RPC failure.

Precheck confirmed:

- `.env.local` is ignored.
- `.env.local` was not staged.
- `supabase/.temp/` is ignored.

No secret values were printed.

## J. Current Git Status

After creating this report, the working tree contains one untracked file:

- `docs/RISELLAR_RPC_STORAGE_BOUNDARY_TEST_EXECUTION_REPORT.md`

## K. Whether Production Remains Blocked

Production remains blocked.

Reasons:

- RPC boundary tests did not pass.
- Storage boundary tests were not run.
- The current failure appears to be a test assertion bug, but it still requires correction and an approved rerun before production can advance.

## Required Fix Prompt

```text
You are working on Risellar.

Task: fix the development-only RPC boundary test audit-row visibility assertions.

Do NOT connect to production Supabase.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS policies.
Do NOT weaken RPC/storage policies to make tests pass.
Do NOT grant normal users audit log read access.
Do NOT run npm audit fix --force.

Context:
The development-only RPC boundary test failed with 8 audit-row assertions:

- commission release writes audit row - expected=1, observed=0
- customer confirmation RPC writes audit row - expected=1, observed=0
- delivery quote approval writes audit row - expected=1, observed=0
- reseller withdrawal request writes audit row - expected=1, observed=0
- reservation release writes audit row - expected=1, observed=0
- settlement proof submission writes audit row - expected=1, observed=0
- settlement verification writes audit row - expected=1, observed=0
- withdrawal approval writes audit row - expected=1, observed=0

Classification:
This appears to be a test assertion bug, not a confirmed RPC/security gap.

Reason:
The test checks `public.audit_logs` while running as non-admin roles. RLS correctly hides audit logs from those roles, so observed count is 0 even if the SECURITY DEFINER RPC inserted the audit row.

Required:
1. Update `scripts/rpc/rpc-boundary-tests-dev-only.sql` only.
2. Keep all audited RPC/action assertions.
3. Move audit-log existence checks into an admin context, or add a safe development-only admin verification block after the audited actions.
4. Do not weaken production RLS, RPC authorization, grants, or audit-log policies.
5. Do not remove audit assertions just to pass.
6. Update `docs/RISELLAR_RPC_STORAGE_BOUNDARY_TEST_EXECUTION_REPORT.md` with the failure classification and fix status.
7. Run normal repo checks and secret scan.
8. Do not rerun RPC/storage boundary scripts until explicitly approved.

Commit after verification if requested.
```
