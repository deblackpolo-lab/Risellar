# Risellar RLS Boundary Test Execution Report

Date: 2026-07-17

## A. Development Project Confirmation

The linked Supabase project was confirmed as the intended development project named `Risellar`.

Precheck results:

- `.env.local` exists.
- `.env.local` is ignored by Git.
- `.env.local` is not staged.
- `supabase/.temp/` is ignored.
- `SUPABASE_PROJECT_REF` is present in `.env.local`.
- `SUPABASE_DB_PASSWORD` is present in `.env.local`.
- The `.env.local` project ref matches the linked Supabase project ref.

No secret values were printed.

## B. Script Executed

Executed:

```bash
npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql
```

The script was reviewed before execution:

- Marked `DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION`.
- Contains rollback strategy.
- Does not contain `DROP`.
- Does not contain `TRUNCATE`.
- Does not disable RLS.
- Uses fake `example.invalid` contacts and fake development fixture names.

## C. RLS Test Execution Result

Result: failed before RLS assertions ran.

Supabase returned:

```text
LegacyDbQueryUnexpectedStatusError
unexpected status 400
Failed to run sql query:
ERROR: 42703: column "business_name" of relation "resellers" does not exist
LINE 187: insert into public.resellers (profile_id, business_name, approval_status, payout_status)
```

## D. Passed Assertions

No RLS assertions ran. The failure happened during fixture insertion.

## E. Failed Assertions

No RLS assertion failed.

The execution failed on fixture setup because the test script expected a `public.resellers.business_name` column.

## F. Test-Simulation Issue Or Real RLS Gap

Classification: test fixture/schema mismatch.

This is not yet evidence of a real RLS policy gap. The applied migration defines `public.resellers` with these relevant columns:

- `profile_id`
- `reseller_type`
- `approval_status`
- `risk_level`
- `payout_status`
- commission and payout metadata fields

It does not define `business_name`.

Follow-up fix applied:

- `scripts/rls/rls-fixtures-dev-only.sql` now inserts `public.resellers.reseller_type` instead of `business_name`.
- `scripts/rls/rls-boundary-tests-dev-only.sql` now inserts `public.resellers.reseller_type` instead of `business_name`.
- The reseller B visibility assertion now filters by `reseller_type = 'dev_social_reseller_b'`.
- No RLS policy gap is confirmed yet because assertions have still not run after the fixture/schema fix.

## G. Fixture Data Rollback/Cleanup

The script uses an explicit transaction and rollback strategy, and the query failed before completion. Because the failed statement occurred inside the transaction submitted by the script, fixture data is expected not to be permanently committed.

No additional SQL was run to inspect or clean data after the failure, to avoid repeated database execution without a clear fix.

## H. Commands Run/Results

- `git status --short` - clean before execution.
- `npx supabase --version` - `2.109.1`.
- Local precheck for `.env.local` and linked ref - passed without printing values.
- Static SQL safety check - passed; warning-language matches only.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - failed with missing `resellers.business_name` column.
- Normal repo verification (`npm test`, `npm run typecheck`, `npm run lint`, `npm run build`) was not run after the RLS failure because the instruction was to stop immediately if tests fail.
- Secret scan - passed.

## I. Secret Scan Result

Secret scan result:

- `.env.local` ignored: yes.
- `.env.local` staged: no.
- `supabase/.temp/` ignored: yes.
- Real Clerk/Supabase/service role values in source/docs/scripts: none found.
- Bearer tokens, passwords, API secrets: none found.

## J. Files Changed

- `docs/RISELLAR_RLS_BOUNDARY_TEST_EXECUTION_REPORT.md`

## K. Current Git Status

At report creation time, this execution report is untracked.

## L. Whether Production Remains Blocked

Production remains blocked.

Reasons:

- RLS boundary tests did not complete.
- Fixture script must be corrected to match the applied schema.
- RLS assertions still need to execute and pass against the development project.
- No production migration/apply should occur until development RLS testing is complete.

## Required Fix Prompt

```text
You are working on Risellar.

Task: fix the development-only RLS boundary test fixture script after the first execution failed.

Do NOT weaken RLS policies.
Do NOT connect to production Supabase.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT run npm audit fix --force.

Context:
The approved development-only RLS test execution failed before assertions ran:
ERROR 42703: column "business_name" of relation "resellers" does not exist.

Fix only the test fixtures/scripts to match the applied schema.

Review:
- scripts/rls/rls-boundary-tests-dev-only.sql
- scripts/rls/rls-fixtures-dev-only.sql
- supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql

Required:
1. Remove invalid references to public.resellers.business_name.
2. Use existing schema fields such as reseller_type, profile_id, approval_status, and payout_status.
3. Search the RLS test scripts for any other fixture columns/statuses that do not exist in the migration.
4. Keep scripts DEVELOPMENT ONLY.
5. Keep rollback cleanup.
6. Do not disable RLS, DROP, TRUNCATE, or add real data/secrets.
7. Run git diff --check, npm test, npm run typecheck, npm run lint, npm run build, and secret scan.
8. Update the RLS execution/prep report with the fix notes.

Do not rerun the RLS script unless explicitly approved.
```
