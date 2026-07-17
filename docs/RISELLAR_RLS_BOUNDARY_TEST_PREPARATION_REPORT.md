# Risellar RLS Boundary Test Preparation Report

## A. Summary

Created a development-only RLS boundary test plan, fixture plan, and SQL scaffolding for the current Supabase schema.

No RLS tests were executed.

No fixtures were inserted.

No production Supabase project was used.

Production remains blocked.

## B. RLS Identity Model Discovered

The migration does not use `auth.uid()`.

Identity is derived by:

1. `public.jwt_subject()` reads `auth.jwt() ->> 'sub'`.
2. `public.current_profile_id()` maps that subject to `profiles.clerk_user_id`.
3. RLS helper functions use relational ownership and role tables:
   - `public.has_admin_role(...)`
   - `public.is_supplier_member(...)`
   - `public.is_supplier_owner(...)`
   - `public.has_supplier_permission(...)`
   - `public.is_reseller_owner(...)`
   - `public.is_customer_owner(...)`
   - `public.is_order_participant(...)`
   - `public.can_insert_audit_log(...)`

Admin/support/finance/super-admin access is represented through `admin_staff.admin_role`, not through direct `profiles.primary_role` values. The `profiles` table intentionally prevents direct self-admin signup through a check constraint.

## C. Tables / Policies Reviewed

Reviewed migration:

- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`

Reviewed supporting reports and helpers:

- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FOUNDATION_REPORT.md`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_HARDENING_REPORT.md`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FINAL_QA_REPORT.md`
- `docs/RISELLAR_SUPABASE_DEV_MIGRATION_APPLY_REPORT.md`
- `lib/auth/role-policy.ts`
- `lib/supabase/client.ts`
- `lib/supabase/server.ts`
- `lib/supabase/admin.ts`

Static counts:

- 24 application tables.
- 24 RLS enable statements.
- 24 forced RLS statements.
- 68 policies.
- 10 helper functions.
- 1 `auth.jwt()` usage.
- 0 `auth.uid()` usages.

Protected tables:

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
- `inventory_movements`
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

## D. RLS Boundary Test Matrix Created

Created:

- `docs/RISELLAR_RLS_BOUNDARY_TEST_MATRIX.md`

The matrix covers:

- anonymous
- customer
- reseller
- supplier owner
- supplier inventory manager
- support operator
- finance operator
- admin
- super admin

Boundary classes covered:

- private-data denial for anonymous users
- customer/reseller/supplier tenant isolation
- supplier base-price/internal-table protection
- inventory manager limitations
- admin/support/finance read/write scaffolding
- sensitive direct update blocking
- direct delete blocking
- settlement/commission restrictions
- audit log restrictions
- ownership foreign key immutability
- immutable price snapshot protection

## E. Fixture Plan Created

Created:

- `docs/RISELLAR_RLS_TEST_FIXTURE_PLAN.md`

Fixture plan includes fake development-only records for:

- customer A/B
- reseller A/B
- supplier A/B
- supplier A inventory manager
- support/finance/admin/super-admin operator profiles plus `admin_staff` rows
- products, variants, images
- reseller listings
- orders and order items
- settlements
- commissions
- withdrawals
- disputes
- returns
- notifications
- audit logs

No fixture inserts were run.

## F. Test Scripts / Scaffolding Created

Created:

- `scripts/rls/README.md`
- `scripts/rls/rls-boundary-test-plan.sql`
- `scripts/rls/rls-fixtures-dev-only.sql`

All scripts are marked:

```text
DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
```

The SQL scaffolding includes:

- fake Clerk subject names only
- `example.invalid` email guidance
- transaction/rollback safety while scaffolding remains incomplete
- role/JWT simulation notes using `set local role ...` and `set local request.jwt.claims = ...`
- expected-result comments for boundary assertions

No real secrets, production refs, real emails, real phone numbers, real payout details, or production data were added.

## G. Whether Tests Were Run

RLS tests were not run.

Normal application checks were run after creating the plan/scaffolding.

## H. Why RLS Tests Were Not Run

RLS tests were not run because:

- The user has not approved inserting fake fixture data into the development database.
- The SQL files are scaffolding and still require fixture IDs to be filled after review.
- Docker/local Supabase is not available and the user does not want Docker installed.
- Remote SQL execution should be explicitly approved before running fixture/test scripts against the development Supabase project.

## I. Tooling Needed Without Docker

Recommended option:

1. Use Supabase SQL Editor manually on the confirmed development project for controlled review/execution.

Viable alternatives:

2. Use Supabase CLI remote SQL execution:

```bash
npx supabase db query --linked --file scripts/rls/rls-fixtures-dev-only.sql
npx supabase db query --linked --file scripts/rls/rls-boundary-test-plan.sql
```

3. Install PostgreSQL client tools only and use `psql` against the development database.

Do not use production.

Do not run destructive reset commands.

## J. Commands Run / Results

| Command | Result |
| --- | --- |
| `git status --short` | Showed pre-existing untracked `docs/RISELLAR_SUPABASE_DEV_MIGRATION_APPLY_REPORT.md` |
| Migration static count script | 24 tables, 68 policies, 24 RLS enabled, 24 RLS forced, 10 helper functions |
| `rg` over migration for tables/policies/functions/auth helpers | Reviewed identity and policy structure |
| `Get-Content` on required docs/helper files | Reviewed |
| `npx supabase db --help` | Confirmed `db query` subcommand exists |
| `npx supabase db query --help` | Confirmed `--linked` and `--file` options exist |
| `git diff --check` | Passed |
| `npm test` | Passed: 19 test files, 85 tests |
| `npm run typecheck` | Passed |
| `npm run lint` | Passed |
| `npm run build` | Initial attempts failed on missing generated `.next` modules for different pages; after removing only the ignored `.next` build cache, the clean-cache build passed |
| Secret scan | Passed; no real secrets found |

## K. Secret Scan Result

Result: passed.

Findings:

- `.env.local` remains ignored and unstaged.
- `.env.local` remains untracked.
- `supabase/.temp/` remains ignored.
- Source/docs/scripts contain no real secrets.
- No service-role values, bearer tokens, private keys, API secret assignments, or real password values were found.
- Pattern hits were limited to placeholder assignments in `.env.example` and existing setup documentation.
- No production data was added.

## L. Files Changed

Created:

- `docs/RISELLAR_RLS_BOUNDARY_TEST_MATRIX.md`
- `docs/RISELLAR_RLS_TEST_FIXTURE_PLAN.md`
- `docs/RISELLAR_RLS_BOUNDARY_TEST_PREPARATION_REPORT.md`
- `scripts/rls/README.md`
- `scripts/rls/rls-boundary-test-plan.sql`
- `scripts/rls/rls-fixtures-dev-only.sql`

Pre-existing untracked file still present:

- `docs/RISELLAR_SUPABASE_DEV_MIGRATION_APPLY_REPORT.md`

## M. Current Git Status

Expected after creation:

```text
?? docs/RISELLAR_RLS_BOUNDARY_TEST_MATRIX.md
?? docs/RISELLAR_RLS_TEST_FIXTURE_PLAN.md
?? docs/RISELLAR_RLS_BOUNDARY_TEST_PREPARATION_REPORT.md
?? docs/RISELLAR_SUPABASE_DEV_MIGRATION_APPLY_REPORT.md
?? scripts/rls/
```

Ignored local files include `.env.local`, `.next/`, `node_modules/`, `supabase/.temp/`, and `tsconfig.tsbuildinfo`.

## N. Recommendation For Next Step

Recommended next step:

1. Review and commit the development migration apply report plus RLS planning/scaffolding docs.
2. Approve development-only fixture insert execution only after reviewing `scripts/rls/rls-fixtures-dev-only.sql`.
3. Fill in fixture IDs or convert the fixture scaffold into a full generated fixture script.
4. Run RLS tests against the confirmed development Supabase project only.
5. Keep production blocked until RLS boundary tests pass and audited RPC/storage policies are implemented.
