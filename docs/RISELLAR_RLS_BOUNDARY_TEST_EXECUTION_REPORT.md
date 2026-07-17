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

Result: passed.

Sixth approved execution after the safe other-supplier RPC test assertion fix:

```text
npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql
```

The development-only RLS boundary test returned result rows with every assertion marked `passed: true`.

Key passing assertions included:

- `inventory manager cannot read staff permission data - expected=0, observed=0`
- `inventory manager can read safe own team operational data - expected=1, observed=1`
- `inventory manager cannot read safe other supplier team data - expected=0, observed=0`
- `safe team RPC does not expose permissions column - blocked with 42703: column "permissions" does not exist`
- `supplier owner A can read direct team permissions - expected=1, observed=1`
- `admin can read direct supplier team permissions - expected>0, observed=1`

The original `supplier_inventory_manager` direct `supplier_team_members.permissions` exposure gap is fixed in the development project.

Fifth approved execution after applying the supplier team permission patch migration:

```text
LegacyDbQueryUnexpectedStatusError
unexpected status 400
Failed to run sql query:
ERROR: P0001: RLS boundary tests failed: 1 failure(s): inventory manager cannot read safe other supplier team data - expected=0, observed=1
CONTEXT: PL/pgSQL function inline_code_block line 16 at RAISE
```

The previously confirmed direct permission exposure assertion did not reappear. The failing assertion is now:

- `inventory manager cannot read safe other supplier team data`
- Expected visible row count: `0`
- Observed visible row count: `1`

Current classification: test assertion bug.

Reason: the test calls `public.get_supplier_operational_team_members((select id from public.suppliers where business_name = 'Dev Supplier B'))` while running as the inventory manager. Because RLS hides supplier B from the inventory manager, that subquery returns `NULL`. The RPC interprets `NULL` as "no supplier filter" and returns the caller's own visible supplier-team row. The test therefore did not actually pass supplier B's ID into the RPC.

Follow-up test fix applied:

- The test now reads Supplier B's fixture UUID from the temporary `rls_fixture_ids` table instead of querying `public.suppliers` under the Supplier A inventory-manager context.
- A guard assertion was added: `test setup has supplier B fixture id`.
- The safe own-supplier RPC assertion also uses the fixture UUID for consistency.
- No RLS policy or migration was changed.
- No assertion was removed or weakened.
- RLS tests still require explicit approval before rerun.

Fourth approved execution after failure diagnostics were improved:

```text
LegacyDbQueryUnexpectedStatusError
unexpected status 400
Failed to run sql query:
ERROR: P0001: RLS boundary tests failed: 1 failure(s): inventory manager cannot read staff permission data - expected=0, observed=1
CONTEXT: PL/pgSQL function inline_code_block line 16 at RAISE
```

The failing assertion is now visible:

- `inventory manager cannot read staff permission data`
- Expected visible row count: `0`
- Observed visible row count: `1`

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

The latest approved run returned all assertions as passed. The output included anonymous, customer, reseller, supplier owner, supplier inventory manager, support, finance, and admin boundary assertions.

## E. Failed Assertions

None in the latest approved run.

## F. Test-Simulation Issue Or Real RLS Gap

Final latest-run classification: no active failure.

Prior confirmed classification: real RLS policy/table-exposure gap.

Reason: the `supplier_inventory_manager` development fixture can read one row from `public.supplier_team_members where permissions <> '{}'::jsonb`. Since `supplier_team_members.permissions` is sensitive staff permission data, exposing that table/column to an inventory manager violates the intended boundary. This is not a fixture/schema mismatch; the assertion reached the actual RLS visibility check.

Important implementation note: PostgreSQL RLS is row-level, not column-level. If inventory managers need to see team membership rows but not the `permissions` JSON, the secure fix should likely use one of these patterns:

- tighten direct `supplier_team_members` table access so only supplier owners/admins can read rows containing permission data; or
- expose a safe view/RPC for inventory managers that omits sensitive permission fields; or
- split sensitive staff permission data into an owner/admin-only table.

Do not weaken the assertion to pass.

Patch migration prepared:

- `supabase/migrations/20260717184516_harden_supplier_team_member_permissions.sql`
- Drops and replaces the direct `supplier_team_members` SELECT policy.
- Direct `supplier_team_members` SELECT is now limited to supplier owners and support/admin roles.
- Adds `public.get_supplier_operational_team_members(uuid)` as a safe authenticated RPC that omits `permissions`.
- RLS boundary tests were updated to keep the direct permission-data denial and add safe RPC coverage.
- Development apply was completed for this patch migration. The next failing assertion is a test assertion bug in the safe-other-supplier RPC test.

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

The script uses an explicit transaction and rollback strategy. The latest approved run completed successfully and reached the final `rollback`, so development fixture data was not permanently committed.

## H. Commands Run/Results

- `git status --short` - clean before execution.
- `npx supabase --version` - `2.109.1`.
- Local precheck for `.env.local` and linked ref - passed without printing values.
- Static SQL safety check - passed; warning-language matches only.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - first approved run failed with missing `resellers.business_name` column.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - second approved run failed with ambiguous `test_name` reference in the PL/pgSQL test helper.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - third approved run failed with `RLS boundary tests failed: 1 failure(s)`; exact assertion row was not included in the returned error output.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - fourth approved run failed with exact assertion: `inventory manager cannot read staff permission data - expected=0, observed=1`.
- `npx supabase db push` - applied `20260717184516_harden_supplier_team_member_permissions.sql` to the confirmed development project.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - fifth approved run failed with exact assertion: `inventory manager cannot read safe other supplier team data - expected=0, observed=1`.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - sixth approved run passed; all returned assertion rows had `passed: true`.
- Normal repo verification after latest pass:
  - `npm test` - passed, 19 test files and 85 tests.
  - `npm run typecheck` - passed.
  - `npm run lint` - passed with `--max-warnings=0`.
  - `npm run build` - passed; Next.js generated 160 static pages.
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

Production remains blocked until an explicit production migration plan/approval exists.

Reasons:

- The patch migration has been applied to development only.
- Development RLS boundary tests now pass.
- No production Supabase apply has been requested or approved.
- Production migration/apply still requires separate production-readiness review and explicit approval.

## Required Fix Prompt

```text
You are working on Risellar.

Task: rerun the development-only RLS boundary tests after the safe other-supplier RPC assertion fix.

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

The fourth approved development-only RLS test execution failed with:
ERROR P0001: RLS boundary tests failed: 1 failure(s): inventory manager cannot read staff permission data - expected=0, observed=1.

The supplier team permission patch migration was applied to development. The fifth approved development-only RLS test execution failed with:
ERROR P0001: RLS boundary tests failed: 1 failure(s): inventory manager cannot read safe other supplier team data - expected=0, observed=1.

Classification: test assertion bug.

The test tried to look up supplier B through public.suppliers while running as supplier A's inventory manager. RLS hid supplier B, so the subquery returned NULL. The safe RPC treated NULL as no supplier filter and returned the caller's own supplier team row.

The test has been fixed to pass Supplier B's fixture UUID directly from the temp fixture table. RLS tests still need an approved rerun.

Review:
- scripts/rls/rls-boundary-tests-dev-only.sql
- supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql
- docs/RISELLAR_RLS_BOUNDARY_TEST_EXECUTION_REPORT.md

Required:
1. Confirm development project and clean git state.
2. Run the development-only RLS boundary test once.
3. If it fails, stop immediately and report the exact assertion/error.
4. If it passes, confirm fixture rollback and that the supplier_inventory_manager permissions exposure remains fixed.

Do not connect to production Supabase. Do not run destructive reset commands.
```
