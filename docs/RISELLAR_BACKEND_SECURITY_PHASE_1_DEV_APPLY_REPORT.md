# Risellar Backend Security Phase 1 Development Apply Report

## A. Development Project Confirmation

The migration was applied only to the confirmed development Supabase project named `Risellar`.

Precheck confirmed:

- Working tree was clean before applying the migration.
- Supabase CLI version was `2.109.1`.
- `.env.local` exists.
- `.env.local` is ignored by Git.
- `.env.local` was not staged.
- `supabase/.temp/` is ignored by Git.
- The Supabase CLI account returned a linked project named `Risellar`.

No production Supabase project was intentionally contacted, and no production data was used.

## B. Migration Applied

Applied migration:

- `20260717194000_audited_rpcs_views_grants_storage_foundation.sql`

This is the Backend Security Phase 1 audited RPC/storage foundation migration.

## C. db push Result

`npx supabase db push` succeeded.

The CLI prompted for confirmation and showed exactly one migration:

- `20260717194000_audited_rpcs_views_grants_storage_foundation.sql`

The approved migration was then applied to the linked development project.

## D. SQL Warnings/Errors

No blocking SQL errors occurred.

Non-blocking notices:

- `policy "product_images_storage_select_supplier_admin" for relation "storage.objects" does not exist, skipping`
- `policy "product_images_storage_insert_supplier" for relation "storage.objects" does not exist, skipping`
- `policy "product_images_storage_update_supplier" for relation "storage.objects" does not exist, skipping`

These notices came from `DROP POLICY IF EXISTS` statements for policies that had not previously existed.

## E. Commands Run/Results

- `git status --short` - clean before migration apply.
- `npx supabase --version` - `2.109.1`.
- `.env.local` and `supabase/.temp/` Git-ignore precheck - passed.
- `npx supabase projects list` - confirmed a linked project named `Risellar`.
- `npx supabase db push` - passed and applied `20260717194000_audited_rpcs_views_grants_storage_foundation.sql`.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed.
- `npm run build` - passed.
- Secret scan - passed.

No `supabase db reset --linked` or destructive reset command was run.

## F. Secret Scan Result

Secret scan result: passed.

Confirmed:

- `.env.local` is ignored.
- `.env.local` was not staged.
- `supabase/.temp/` is ignored.
- No real Clerk, Supabase, service-role values, bearer tokens, passwords, or API secrets were found in docs/scripts/source scans.
- No secret values were printed in this report.

## G. Current Git Status

After creating this report, the working tree contains one untracked file:

- `docs/RISELLAR_BACKEND_SECURITY_PHASE_1_DEV_APPLY_REPORT.md`

## H. Whether Production Remains Blocked

Production remains blocked.

This migration has been applied to development only. Production should not receive it until the RPC/storage boundary tests are prepared, executed, and reviewed.

## I. Next Required Boundary Tests

Required next boundary tests:

- customer cannot create or mutate fake price snapshots
- customer can only confirm own order
- customer can only approve own delivery quote
- reseller cannot release own commission
- reseller withdrawal request cannot exceed available commission
- supplier cannot verify own settlement
- supplier inventory manager cannot access payout, settlement verification, or staff permission data
- support/admin-only reservation release blocks normal users
- finance/admin-only settlement verification, commission release, and withdrawal approval block normal users
- audited RPCs write audit rows for sensitive transitions
- product image storage paths are supplier-scoped
- supplier cannot overwrite another supplier's product image object
- no client DELETE paths are created

Recommended next step: create development-only RPC/storage boundary test scripts and dry-run/review them before execution.
