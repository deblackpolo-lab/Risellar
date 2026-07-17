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

Result: failed with one RLS boundary assertion failure, but the exact assertion name was not returned by the Supabase Management API response.

Third approved execution after helper ambiguity fix:

```text
LegacyDbQueryUnexpectedStatusError
unexpected status 400
Failed to run sql query:
ERROR: P0001: RLS boundary tests failed: 1 failure(s). Review rls_test_results output above.
CONTEXT: PL/pgSQL function inline_code_block line 10 at RAISE
```

The script reached the final failure-count block, so the fixture/schema mismatch and helper ambiguity issues were cleared. However, the linked query error response did not include the earlier `rls_test_results` output, so the exact failing assertion is not visible from this run.

Second approved execution after fixture/schema alignment:

```text
LegacyDbQueryUnexpectedStatusError
unexpected status 400
Failed to run sql query:
ERROR: 42702: column reference "test_name" is ambiguous
DETAIL: It could refer to either a PL/pgSQL variable or a table column.
QUERY: insert into rls_test_results (test_name, passed, details)
  values (test_name, passed, coalesce(details, ''))
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details
CONTEXT: PL/pgSQL function pg_temp_29.rls_record_result(text,boolean,text) line 3 at SQL statement
SQL statement "SELECT pg_temp.rls_record_result(test_name, false, sqlstate || ': ' || sqlerrm)"
PL/pgSQL function pg_temp_29.rls_expect_count(text,text,integer) line 13 at PERFORM
```

This occurred inside the test helper function before any reliable RLS assertion result table could be produced.

First approved execution before fixture/schema alignment:

Supabase returned:

```text
LegacyDbQueryUnexpectedStatusError
unexpected status 400
Failed to run sql query:
ERROR: 42703: column "business_name" of relation "resellers" does not exist
LINE 187: insert into public.resellers (profile_id, business_name, approval_status, payout_status)
```

## D. Passed Assertions

No individual assertions can be counted as passed from the captured output.

The third run reached the final failure-count block, but the error response did not include the assertion result rows.

## E. Failed Assertions

One assertion failed.

The exact failing assertion was not included in the Supabase CLI/Management API error output.

## F. Test-Simulation Issue Or Real RLS Gap

Latest classification: unknown.

Reason: the third execution proves one pass/fail assertion failed, but the error response did not expose the `rls_test_results` row that names the failed assertion. This could be a real RLS policy gap, a role/JWT simulation issue, or a test assertion bug. It should not be treated as a confirmed RLS policy gap until the script reports the failed assertion details in the exception message or another approved diagnostic run captures them.

Follow-up diagnostic fix applied:

- The final failure block now aggregates failed `rls_test_results` rows with `string_agg`.
- The raised exception now includes failed assertion names and details directly, using the format `test_name - details`.
- Existing assertions were preserved.
- No RLS policies, migrations, or schema were changed.
- RLS tests still require explicit approval before another development-only rerun.

The first execution was a test fixture/schema mismatch. That was fixed in commit `5c937bb5`.

The second execution failed because the PL/pgSQL helper function uses `test_name` as a parameter name and also writes to a `test_name` table column without qualifying the parameter.

This is not yet evidence of a confirmed real RLS policy gap.

Follow-up helper fix applied:

- `rls_record_result` parameters were renamed to `p_test_name`, `p_passed`, and `p_details`.
- Assertion helper parameters were renamed to `p_test_name`, `p_sql_text`, and `p_expected_count` where applicable.
- Helper function bodies now pass prefixed parameter names to avoid collisions with `rls_test_results.test_name`, `passed`, and `details`.
- No RLS policies, migrations, or assertions were weakened.
- RLS tests still require explicit approval before another development-only rerun.

Historical first-run schema mismatch details: the applied migration defines `public.resellers` with these relevant columns:

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

No additional SQL was run to inspect or clean data after the third failure, to avoid repeated database execution without a clear fix.

## H. Commands Run/Results

- `git status --short` - clean before execution.
- `npx supabase --version` - `2.109.1`.
- Local precheck for `.env.local` and linked ref - passed without printing values.
- Static SQL safety check - passed; warning-language matches only.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - first approved run failed with missing `resellers.business_name` column.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - second approved run failed with ambiguous `test_name` reference in the PL/pgSQL test helper.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - third approved run failed with `RLS boundary tests failed: 1 failure(s)`; exact assertion row was not included in the returned error output.
- Normal repo verification (`npm test`, `npm run typecheck`, `npm run lint`, `npm run build`) was not run after the RLS failure because the instruction was to stop immediately if tests fail.
- Helper fix verification:
  - `git diff --check` - passed; Git reported line-ending normalization warnings only.
  - `npm test` - passed, 19 test files and 85 tests.
  - `npm run typecheck` - passed.
  - `npm run lint` - passed with `--max-warnings=0`.
  - `npm run build` - passed; Next.js generated 160 static pages.
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

At latest report update time, this execution report is modified in the working tree.

## L. Whether Production Remains Blocked

Production remains blocked.

Reasons:

- RLS boundary tests did not complete.
- Test helper parameter names were corrected after the second failure.
- One assertion failed on the third approved run, but the exact assertion name was not captured in the returned output.
- The test script diagnostic improvement has been applied so failed assertion names/details are included in the final raised exception.
- RLS tests must be rerun only after explicit development-only approval.
- RLS assertions still need to execute and pass against the development project.
- No production migration/apply should occur until development RLS testing is complete.

## Required Fix Prompt

```text
You are working on Risellar.

Task: improve the development-only RLS boundary test failure reporting after the third approved execution failed.

Do NOT weaken RLS policies.
Do NOT connect to production Supabase.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT run npm audit fix --force.

Context:
The first approved development-only RLS test execution failed because public.resellers.business_name did not exist. That fixture/schema mismatch was fixed in commit 5c937bb5.

The second approved development-only RLS test execution failed because the PL/pgSQL helper had an ambiguous test_name reference. That was fixed in commit 6c135dcb.

The third approved development-only RLS test execution reached the final assertion summary and failed with:
ERROR P0001: RLS boundary tests failed: 1 failure(s). Review rls_test_results output above.

The Supabase linked query error response did not include the rls_test_results rows, so the failing assertion is unknown.

Fix only development-only test diagnostics. Do not change RLS policies or migrations.

Review:
- scripts/rls/rls-boundary-tests-dev-only.sql
- scripts/rls/rls-fixtures-dev-only.sql
- supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql

Required:
1. Update the final failure block to include failed assertion names and details directly in the raised exception message.
2. Keep the existing pass/fail assertions intact.
3. Do not remove, weaken, or invert any failing assertion.
4. Keep scripts DEVELOPMENT ONLY.
5. Keep rollback cleanup.
6. Do not disable RLS, DROP, TRUNCATE, or add real data/secrets.
7. Run git diff --check, npm test, npm run typecheck, npm run lint, npm run build, and secret scan.
8. Update the RLS execution report with the fix notes.

Do not rerun the RLS script unless explicitly approved.
```
