# Risellar RLS Fixture Schema Alignment Report

Date: 2026-07-17

## A. Original Failure

The first approved development-only RLS boundary test execution failed before any assertions ran.

Failure:

```text
ERROR: 42703: column "business_name" of relation "resellers" does not exist
LINE 187: insert into public.resellers (profile_id, business_name, approval_status, payout_status)
```

## B. Why It Was Not An RLS Policy Failure

The failure happened while inserting fake fixture rows, before the script reached role simulation or RLS assertions.

The applied migration defines `public.resellers` without a `business_name` column. This makes the failure a fixture/schema mismatch, not evidence of a policy boundary failure.

## C. Tables Reviewed

Reviewed fixture and assertion references against `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql` for:

- `profiles`
- `admin_staff`
- `customers`
- `resellers`
- `reseller_shops`
- `suppliers`
- `supplier_team_members`
- `products`
- `product_variants`
- `product_images`
- `reseller_products`
- `orders`
- `order_items`
- `stock_reservations`
- `delivery_quotes`
- `settlements`
- `commissions`
- `withdrawals`
- `disputes`
- `returns`
- `notifications`
- `audit_logs`
- `admin_actions`

No `manual_overrides` table exists in the migration.

## D. Columns Fixed

Fixed invalid references to:

- `public.resellers.business_name`

Replacement:

- `public.resellers.reseller_type`

The reseller visibility assertion was also updated to filter by `reseller_type = 'dev_social_reseller_b'` instead of a nonexistent business name.

## E. Scripts Changed

- `scripts/rls/rls-fixtures-dev-only.sql`
- `scripts/rls/rls-boundary-tests-dev-only.sql`
- `docs/RISELLAR_RLS_BOUNDARY_TEST_EXECUTION_REPORT.md`
- `docs/RISELLAR_RLS_FIXTURE_SCHEMA_ALIGNMENT_REPORT.md`

`scripts/rls/README.md` and `scripts/rls/rls-boundary-test-plan.sql` were reviewed and did not need changes.

## F. Remaining Risks

- The RLS boundary test has not been rerun after the schema-alignment fix.
- Runtime role simulation with `set local role` and `request.jwt.claims` still needs to be proven in the development Supabase execution context.
- The intentional `supplier_inventory_manager` permission-data visibility assertion may still expose a real RLS/table-design gap when assertions run.
- Fixture inserts may still reveal runtime constraints or grant issues that static review cannot fully prove.

## G. Ready For Another Approved Execution

Yes, the fixture scripts are ready for another explicitly approved development-only execution attempt.

Do not run against production. Do not run with production data. Do not rerun without explicit approval.

## H. Commands Run/Results

- `git status --short` - showed the untracked execution report before script fixes.
- Static schema/script review - completed.
- Targeted schema column check - passed after replacing `resellers.business_name` with `reseller_type`.
- `git diff --check` - passed; Git reported line-ending normalization warnings only.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed with `--max-warnings=0`.
- `npm run build` - passed; Next.js generated 160 static pages.

## I. Secret Scan Result

Secret scan passed:

- `.env.local` is ignored.
- `.env.local` is not staged.
- `supabase/.temp/` is ignored.
- No real Supabase, Clerk, service role, bearer token, password, or API secret values were found in docs/scripts/source.

## J. Current Git Status

Before commit:

```text
 M scripts/rls/rls-boundary-tests-dev-only.sql
 M scripts/rls/rls-fixtures-dev-only.sql
?? docs/RISELLAR_RLS_BOUNDARY_TEST_EXECUTION_REPORT.md
?? docs/RISELLAR_RLS_FIXTURE_SCHEMA_ALIGNMENT_REPORT.md
```
