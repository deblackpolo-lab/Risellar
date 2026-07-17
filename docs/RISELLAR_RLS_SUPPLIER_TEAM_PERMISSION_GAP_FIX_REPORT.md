# Risellar RLS Supplier Team Permission Gap Fix Report

Date: 2026-07-17

## A. Confirmed Failing Assertion

The development-only RLS boundary test failed with:

```text
inventory manager cannot read staff permission data - expected=0, observed=1
```

This means the `supplier_inventory_manager` fixture could read one `public.supplier_team_members` row where `permissions <> '{}'::jsonb`.

## B. Why This Was A Real RLS/Table-Exposure Gap

`supplier_team_members.permissions` is sensitive staff permission data. PostgreSQL RLS is row-level, so allowing a user to select a `supplier_team_members` row can expose every selectable column on that row, including `permissions`.

The failure reached an actual RLS visibility check. It was not a fixture/schema mismatch and not a test helper bug.

## C. Root Cause

The foundation policy:

```sql
create policy "supplier_team_select_members_or_admin"
  on public.supplier_team_members for select
  using (public.is_supplier_member(supplier_id) or public.has_admin_role('support_staff'));
```

allowed any supplier member, including `supplier_inventory_manager`, to directly select `supplier_team_members` rows for their supplier. Those rows include the sensitive `permissions` JSON column.

## D. Migration Created

Created:

```text
supabase/migrations/20260717184516_harden_supplier_team_member_permissions.sql
```

This is a patch migration. The already-applied foundation migration was not edited as the only fix.

## E. Policies Changed

The patch migration drops:

```text
supplier_team_select_members_or_admin
```

and creates:

```text
supplier_team_select_owner_support_admin
```

The new direct table SELECT policy allows only:

- supplier owners for their supplier
- support/admin roles represented by `public.has_admin_role('support_staff')`

It does not allow `supplier_inventory_manager` to directly select `supplier_team_members`.

## F. Safe View/RPC Created

Created safe RPC:

```text
public.get_supplier_operational_team_members(target_supplier_id uuid default null)
```

The RPC returns operational fields only:

- `id`
- `supplier_id`
- `profile_id`
- `supplier_role`
- `staff_status`
- `member_full_name`
- `created_at`
- `updated_at`

It intentionally excludes:

- `permissions`
- admin notes/internal notes if introduced later
- audit or sensitive risk fields

The function is `SECURITY DEFINER` because direct table SELECT is intentionally restricted. It locks `search_path = public` and filters rows to supplier-scoped callers or support/admin roles.

## G. Tests Updated

Updated:

```text
scripts/rls/rls-boundary-tests-dev-only.sql
```

The original failing assertion remains:

```text
inventory manager cannot read staff permission data
```

Added coverage:

- supplier owner can still read direct team permissions.
- admin can still read direct supplier team permissions.
- inventory manager can read safe own-supplier operational team data through the RPC.
- inventory manager cannot read safe other-supplier team data through the RPC.
- safe RPC does not expose a `permissions` column.

## H. Why The Fix Does Not Weaken RLS

- Direct access to the sensitive table is reduced, not expanded.
- The failing assertion is preserved.
- No client DELETE policies were added.
- No `USING (true)` or `WITH CHECK (true)` policies were added.
- The safe RPC excludes the sensitive `permissions` field.
- Supplier owner/admin legitimate direct access is preserved.
- Inventory manager operational access is routed through a narrower interface.

## I. Remaining Risks

- The patch migration has not yet been applied to the development Supabase project.
- The development-only RLS boundary test must be rerun after the migration is applied.
- The `SECURITY DEFINER` RPC should remain narrowly scoped and should not be expanded to include sensitive fields.
- Production remains blocked until development apply and RLS boundary tests pass.

## J. Commands Run/Results

- `git status --short` - showed the scoped migration, RLS test, and report changes.
- `git diff --check` - passed; Git reported line-ending normalization warnings only.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed with `--max-warnings=0`.
- `npm run build` - passed; Next.js generated 160 static pages.
- `npx supabase db push --dry-run` - passed.

Dry-run result:

```text
DRY RUN: migrations will *not* be pushed to the database.
Would push these migrations:
 • 20260717184516_harden_supplier_team_member_permissions.sql
```

No real `npx supabase db push` was run.

## K. Secret Scan Result

Secret scan passed:

- `.env.local` is ignored.
- `.env.local` is not staged.
- `supabase/.temp/` is ignored.
- No real Supabase, Clerk, service role, bearer token, password, or API secret values were found in docs/scripts/source.

## L. Current Git Status

Before commit:

```text
 M docs/RISELLAR_RLS_BOUNDARY_TEST_EXECUTION_REPORT.md
 M scripts/rls/rls-boundary-tests-dev-only.sql
?? docs/RISELLAR_RLS_SUPPLIER_TEAM_PERMISSION_GAP_FIX_REPORT.md
?? supabase/migrations/20260717184516_harden_supplier_team_member_permissions.sql
```

## M. Whether Migration Has Been Applied To Development

No. The patch migration has not been applied. The dry-run passed and showed the migration that would be applied.
