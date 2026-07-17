# Risellar RLS Safe RPC Test Fix Report

Date: 2026-07-17

## A. Failed Assertion

After applying the supplier team permission patch migration, the development-only RLS boundary test failed with:

```text
inventory manager cannot read safe other supplier team data - expected=0, observed=1
```

## B. Why It Was A Test Assertion Bug

The assertion tried to get Supplier B's ID by querying `public.suppliers` while simulating Supplier A's inventory manager.

That role should not see Supplier B, so RLS correctly filtered Supplier B out and the subquery returned `NULL`. The safe RPC accepts `NULL` as no supplier filter, so it returned the caller's own supplier team row. The assertion therefore failed for the wrong reason.

This was not a confirmed new RLS policy gap.

## C. How The Test Was Fixed

The development-only RLS test now:

- grants simulated roles read access to the temporary `rls_fixture_ids` table,
- verifies Supplier B's fixture UUID exists with `test setup has supplier B fixture id`,
- passes Supplier A and Supplier B fixture UUIDs directly from `rls_fixture_ids` into `public.get_supplier_operational_team_members(...)`,
- keeps the safe other-supplier assertion expecting `0` rows.

The test no longer relies on an RLS-filtered `public.suppliers` lookup while acting as Supplier A's inventory manager.

## D. Whether Any RLS Policy/Migration Was Changed

No RLS policy or migration was changed in this test assertion fix.

## E. Whether The Original Permissions Exposure Gap Appears Fixed

The original direct permission exposure assertion did not reappear after the patch migration was applied:

```text
inventory manager cannot read staff permission data
```

The full RLS boundary suite still needs an approved rerun before the fix can be considered fully validated.

## F. Whether RLS Tests Were Rerun

No. The RLS boundary test was not rerun as part of this test assertion fix.

## G. Commands Run/Results

- `git status --short` - showed the scoped RLS test/report changes.
- `git diff --check` - passed; Git reported line-ending normalization warnings only.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed with `--max-warnings=0`.
- `npm run build` - passed; Next.js generated 160 static pages.

The development-only RLS boundary test was not rerun.

## H. Secret Scan Result

Secret scan passed:

- `.env.local` is ignored.
- `.env.local` is not staged.
- `supabase/.temp/` is ignored.
- No real Supabase, Clerk, service role, bearer token, password, or API secret values were found in docs/scripts/source.

## I. Current Git Status

Before commit:

```text
 M docs/RISELLAR_RLS_BOUNDARY_TEST_EXECUTION_REPORT.md
 M scripts/rls/rls-boundary-tests-dev-only.sql
?? docs/RISELLAR_RLS_PATCH_MIGRATION_APPLY_REPORT.md
?? docs/RISELLAR_RLS_SAFE_RPC_TEST_FIX_REPORT.md
```
