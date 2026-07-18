# Risellar Supplier Product RPC UUID Fix Report

## A. Original Failure

The development-only supplier product RPC boundary test did not reach meaningful assertions after the product management foundation migration was applied to development.

Original full test command:

`npx supabase db query --linked --file scripts/rpc/product-management-rpc-tests-dev-only.sql`

Initial surfaced error:

```text
LegacyDbQueryExecError: failed to execute query: HttpClientError: Transport error
```

A reduced rollback diagnostic then exposed the underlying SQL runtime failure:

```text
ERROR: 42883: function min(uuid) does not exist
CONTEXT: PL/pgSQL function current_verified_supplier_owner_id() line 13 at SQL statement
PL/pgSQL function create_supplier_product(text,text,text,numeric,integer,jsonb,jsonb) line 18 at assignment
```

## B. Root Cause

`public.current_verified_supplier_owner_id()` used:

```sql
select count(*), min(s.id)
```

`s.id` is a UUID. PostgreSQL does not support `min(uuid)`, so the function failed when `create_supplier_product()` tried to resolve the current supplier owner.

## C. Why It Was Not A Transport Issue

A tiny linked query passed:

`npx supabase db query --linked "select 1 as linked_query_ok;"`

The reduced diagnostic reached SQL execution and returned a specific PostgreSQL error. That means linked query works generally; the original generic transport-style error masked the SQL runtime failure inside the larger script.

## D. Why It Was Not A Confirmed Security Gap

The failure happened before authorization boundary assertions could run.

No evidence showed that:

- customers could create supplier products
- resellers could create supplier products
- supplier owners could edit another supplier product
- supplier owners could self-approve products
- audit logging was bypassed

The issue is a product RPC implementation bug, not a confirmed product RPC/security authorization gap.

## E. Migration Created

Created forward patch migration:

- `supabase/migrations/20260718102000_fix_supplier_owner_uuid_selection.sql`

The already-applied migration was not edited as the only fix.

## F. Function Fixed

Fixed:

- `public.current_verified_supplier_owner_id()`

The patch removes `min(uuid)` and uses a UUID-safe deterministic selection pattern:

- count matching active approved supplier-owner records
- require at least one match
- select `s.id` ordered by `s.created_at asc, s.id::text asc`
- return the selected supplier id

If multiple active approved suppliers exist for the same supplier owner profile, the function now chooses deterministically by oldest `created_at`, then UUID text. This is documented in the function comment until explicit supplier selection is added.

## G. Security Checks Preserved

The patch preserves:

- `security definer`
- `set search_path = public`
- authenticated active profile requirement
- `profiles.primary_role = 'supplier_owner'`
- `profiles.account_status = 'active'`
- non-deleted profile requirement
- supplier owner relationship via `suppliers.owner_profile_id`
- `supplier_status = 'active'`
- `verification_status = 'approved'`
- non-deleted supplier requirement

The patch does not:

- broaden access to other suppliers
- allow `supplier_inventory_manager` to act as owner
- use service role
- weaken RLS/RPC/storage policies
- connect supplier UI to live products

## H. Dry-Run Result

Command:

`npx supabase db push --dry-run`

Result:

- passed
- no migration was applied
- preview showed only:
  - `20260718102000_fix_supplier_owner_uuid_selection.sql`

## I. Commands Run/Results

- `git status --short` - showed uncommitted diagnostic reports before patch
- inspected existing `current_verified_supplier_owner_id()` - confirmed unsupported `min(s.id)` on UUID
- created `supabase/migrations/20260718102000_fix_supplier_owner_uuid_selection.sql`
- `npx supabase db push --dry-run` - passed; would apply only the UUID fix migration
- `git diff --check` - passed
- `npm test` - passed
- `npm run lint` - passed
- `npm run build` - passed
- `npm run typecheck` - passed
- secret scan - passed

## J. Secret Scan Result

- `.env.local` is ignored
- `.env.local` is not staged
- `supabase/.temp/` is ignored
- no real Clerk/Supabase/service-role values found in docs/scripts/source
- no service role values exposed in app/components
- no bearer tokens, passwords, API secrets, or production data found

## K. Files Changed

- `supabase/migrations/20260718102000_fix_supplier_owner_uuid_selection.sql`
- `docs/RISELLAR_SUPABASE_LINKED_QUERY_TRANSPORT_DIAGNOSTIC_REPORT.md`
- `docs/RISELLAR_SUPPLIER_PRODUCT_MANAGEMENT_DEV_APPLY_AND_TEST_REPORT.md`
- `docs/RISELLAR_SUPPLIER_PRODUCT_RPC_UUID_FIX_REPORT.md`

## L. Current Git Status

Working tree contains the UUID fix migration and related reports. Nothing was committed.

## M. Whether Safe To Apply To Development

Safe to request approval for development apply: yes.

Safe to apply to production: no.

Production remains blocked until:

- the UUID fix migration is applied to development
- the full product management RPC boundary tests pass
- fixture rollback is confirmed
- supplier UI integration is separately planned and reviewed
