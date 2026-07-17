# Risellar RLS Patch Migration Apply Report

Date: 2026-07-17

## A. Development Project Confirmation

The linked Supabase project was confirmed as the intended development project named `Risellar`.

Precheck results:

- Working tree was clean before apply.
- Supabase CLI version: `2.109.1`.
- `.env.local` exists.
- `.env.local` is ignored by Git.
- `.env.local` is not staged.
- `supabase/.temp/` is ignored.
- `SUPABASE_PROJECT_REF` is present in `.env.local`.
- `SUPABASE_DB_PASSWORD` is present in `.env.local`.
- The `.env.local` project ref matches the linked Supabase project ref.

No secret values were printed.

## B. Patch Migration Applied

Applied to the confirmed development Supabase project:

```text
20260717184516_harden_supplier_team_member_permissions.sql
```

## C. DB Push Result

`npx supabase db push` succeeded.

Output summary:

```text
Applying migration 20260717184516_harden_supplier_team_member_permissions.sql...
NOTICE (00000): function public.get_supplier_operational_team_members(uuid) does not exist, skipping
Finished supabase db push.
```

The notice is expected for a first-time patch migration because it uses `DROP FUNCTION IF EXISTS` before creating the safe RPC.

No production Supabase project was used. No destructive reset command was run.

## D. RLS Test Execution Result

The development-only RLS boundary test was rerun once:

```bash
npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql
```

Result: failed with one assertion.

## E. Failed Assertion/Error

```text
RLS boundary tests failed: 1 failure(s): inventory manager cannot read safe other supplier team data - expected=0, observed=1
```

Classification: test assertion bug.

The test obtains supplier B's ID using a query against `public.suppliers` while running as supplier A's inventory manager. RLS correctly hides supplier B from that role, so the subquery returns `NULL`. The safe RPC treats `NULL` as no supplier filter and returns the caller's own supplier team row, producing `observed=1`.

Follow-up test fix applied:

- The safe other-supplier assertion now uses Supplier B's fixture UUID from the temporary fixture table.
- A setup guard verifies Supplier B's fixture UUID is present before the RPC assertion.
- No RLS policy or migration was changed.
- RLS tests were not rerun as part of this fix.

## F. Whether Supplier Inventory Manager Permission Exposure Is Fixed

Partially validated.

The original failing assertion was:

```text
inventory manager cannot read staff permission data - expected=0, observed=1
```

That assertion did not reappear after the patch migration was applied. The new failure is in the safe other-supplier RPC test path. The direct `supplier_team_members.permissions` exposure appears addressed, but the full RLS boundary suite has not passed yet.

## G. Whether Fixture Data Was Rolled Back/Cleaned Up

The RLS test script uses an explicit transaction and rollback strategy. Because the test failed inside that transaction, fixture data is expected not to be permanently committed.

No additional SQL inspection or cleanup was run after the failure, to avoid repeated database execution without a clear fix.

## H. Commands Run/Results

- `git status --short` - clean before apply.
- `npx supabase --version` - `2.109.1`.
- Local development link and ignore precheck - passed without printing secret values.
- `npx supabase db push` - passed and applied `20260717184516_harden_supplier_team_member_permissions.sql`.
- `npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql` - failed with the safe other-supplier test assertion above.
- `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build` were not run after the RLS test failure because the instruction was to stop immediately if tests fail.

## I. Secret Scan Result

Secret scan passed:

- `.env.local` is ignored.
- `.env.local` is not staged.
- `supabase/.temp/` is ignored.
- No real Supabase, Clerk, service role, bearer token, password, or API secret values were found in docs/scripts/source.

## J. Current Git Status

At report creation time:

```text
 M docs/RISELLAR_RLS_BOUNDARY_TEST_EXECUTION_REPORT.md
?? docs/RISELLAR_RLS_PATCH_MIGRATION_APPLY_REPORT.md
```

## K. Whether Production Remains Blocked

Production remains blocked.

Reasons:

- The development patch migration was applied, but the RLS boundary suite still does not pass.
- The latest failure is classified as a test assertion bug in the safe other-supplier RPC check.
- The test assertion bug has been fixed, but the RLS suite still needs an approved rerun against development before any production apply is considered.
