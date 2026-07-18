# Risellar Reseller Catalog Development Apply And Test Report

## A. Development Project Confirmation

The migration was applied only to the previously confirmed DEVELOPMENT Supabase project named `Risellar`.

Precheck confirmed without printing secret values:

- working tree was clean before apply
- `.env.local` exists
- `.env.local` is ignored by Git
- `.env.local` was not staged
- `SUPABASE_PROJECT_REF` is present
- `SUPABASE_DB_PASSWORD` is present
- `supabase/.temp/` is ignored
- local linked project metadata exists
- `.env.local` project ref matches the linked Supabase project ref

No production Supabase project was connected.

## B. Migration Applied

Applied to development:

- `20260718150000_reseller_approved_product_catalog_rpc.sql`

Command:

```text
npx supabase db push
```

Result:

- succeeded
- applied only `20260718150000_reseller_approved_product_catalog_rpc.sql`
- no destructive reset command was run

## C. Reseller Catalog RPC Test Result

Command:

```text
npx supabase db query --linked --file scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql
```

Result:

- failed before reliable reseller catalog assertions could be recorded

Exact error:

```text
ERROR: 42501: permission denied for table reseller_catalog_test_results
HINT: Grant the required privileges to the current role with:
GRANT SELECT, INSERT, UPDATE ON pg_temp_22.reseller_catalog_test_results TO authenticated;
CONTEXT: SQL statement "insert into reseller_catalog_test_results(test_name, passed, details)
  values (p_test_name, p_passed, p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details"
PL/pgSQL function pg_temp_22.record_result(text,boolean,text) line 3 at SQL statement
SQL statement "SELECT pg_temp.record_result(
    'approved reseller can see approved active product',
    v_visible_count = 1,
    'expected=1 observed=' || v_visible_count
  )"
PL/pgSQL function inline_code_block line 61 at PERFORM
```

## D. Failure Classification

Classification:

- test assertion bug

Reason:

- the test harness switches into the simulated `authenticated` role before recording assertion results
- the temporary `reseller_catalog_test_results` table did not grant the simulated role permission to insert/update result rows
- this matches a harness permission issue, not a confirmed reseller catalog RPC implementation bug or security gap

## D1. Harness Fix Applied

Applied a dev-only test harness fix in:

- `scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql`

Change:

```sql
grant select, insert, update on reseller_catalog_test_results to authenticated;
```

This grant applies only to the temporary `reseller_catalog_test_results` table created inside the development-only rollback test transaction.

No grants were added to real application tables.

No migration, RPC, RLS policy, or storage policy was changed.

No assertions were removed or weakened.

The reseller catalog RPC boundary test was not rerun after this fix. Rerun still requires explicit approval.

## E. Security Result

No real reseller catalog security gap is confirmed yet.

The migration apply succeeded, but the boundary test did not reach meaningful pass/fail assertions for:

- approved reseller can see approved active products
- pending/rejected/archived products are hidden
- customer cannot call reseller catalog RPC
- supplier cannot call reseller catalog RPC

These still require rerun after explicit approval. The test harness permission fix has been applied.

## F. Add-To-Shop / Flow Scope

No add-to-shop/listing RPC was run or added during this apply step.

The committed UI still keeps add-to-shop disabled/deferred.

No checkout, customer catalog, public shop, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or reseller checkout flow was connected.

## G. Commands Run / Results

- `git status --short` - clean before apply.
- `npx supabase --version` - `2.109.1`.
- local precheck script - passed; `.env.local` ignored/not staged and linked ref matched configured development ref.
- `npx supabase db push` - passed; applied `20260718150000_reseller_approved_product_catalog_rpc.sql` to development.
- `npx supabase db query --linked --file scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql` - failed with temp result table permission error before reliable assertions.

The normal repo verification commands were not run after the RPC test failure because the instruction was to stop immediately on test failure.

After the harness fix:

- `git status --short` - showed only the expected script/report changes.
- `git diff --check` - passed with line-ending warnings only.
- `npm test` - passed.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- reseller catalog RPC boundary test - not rerun, per instruction.

## H. Secret Scan Result

The explicit post-test secret scan was not run because the test failed and execution stopped immediately.

Precheck confirmed:

- `.env.local` is ignored
- `.env.local` was not staged
- `supabase/.temp/` is ignored
- no secret values were printed

After the harness fix, secret/scope scan confirmed:

- `.env.local` is ignored and not staged
- `supabase/.temp/` is ignored
- no real Clerk/Supabase/service-role values were added to docs/scripts/source
- no service role references exist in `app/` or `components/`
- no bearer tokens, passwords, API secrets, or production data were found in changed files
- no reseller catalog RPC references exist in checkout/customer/shop flows

## I. Current Git Status

This report has been updated with the harness fix status and is ready to commit with the script/report changes.

## J. Production Status

Production remains blocked.

No production Supabase connection was used.

No destructive reset command was used.

## K. Required Fix Prompt

```text
Fix the development-only reseller catalog RPC boundary test harness temp-table permission bug.

Do NOT connect production Supabase.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS/RPC/storage policies.
Do NOT connect checkout, customer catalog, public shop, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or reseller checkout flow.
Do NOT rerun the reseller catalog RPC test yet.
Do NOT run npm audit fix --force.

Context:
The development db push succeeded and applied:
20260718150000_reseller_approved_product_catalog_rpc.sql

But the reseller catalog RPC boundary test failed before reliable assertions with:
ERROR: 42501: permission denied for table reseller_catalog_test_results
HINT: GRANT SELECT, INSERT, UPDATE ON pg_temp_22.reseller_catalog_test_results TO authenticated;

Classification:
Test assertion/harness bug.

Goal:
Fix only scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql so the temporary result table can be written while the test simulates authenticated roles.

Required fix:
1. Grant the minimum needed permissions on the temp table to authenticated, for example SELECT, INSERT, UPDATE if the upsert helper needs all three.
2. Do not grant permissions on real application tables.
3. Do not weaken get_reseller_approved_products().
4. Do not remove or weaken assertions.
5. Update docs/RISELLAR_RESELLER_CATALOG_DEV_APPLY_AND_TEST_REPORT.md noting the harness fix and that tests still need explicit approval before rerun.

Run:
git status --short
git diff --check
npm test
npm run lint
npm run build
npm run typecheck

Run secret scan.

Do not run:
npx supabase db query --linked --file scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql

Commit only when asked.
```
