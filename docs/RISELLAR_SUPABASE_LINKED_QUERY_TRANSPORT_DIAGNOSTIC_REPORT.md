# Risellar Supabase Linked Query Transport Diagnostic Report

## A. Original Failure

The development-only supplier product RPC boundary test failed before SQL assertion rows were returned.

Command:

`npx supabase db query --linked --file scripts/rpc/product-management-rpc-tests-dev-only.sql`

Original error:

```text
LegacyDbQueryExecError: failed to execute query: HttpClientError: Transport error
```

No product RPC pass/fail assertions were recorded from that run.

## B. Whether Tiny Linked Query Passed

Tiny read-only linked query was run:

`npx supabase db query --linked "select 1 as linked_query_ok;"`

Result:

- passed
- returned `linked_query_ok = 1`

This confirms linked query works generally for the confirmed development Supabase project.

## C. Whether Full Product Test Appears Too Large/Complex

The full product RPC boundary script is moderately complex:

- 409 lines
- about 17 KB
- one long transaction
- temporary tables
- temporary assertion helper functions
- multiple role/JWT context switches
- multiple fixture inserts
- multiple RPC calls
- final raised exception aggregation
- final rollback

This complexity may have contributed to the initial linked-query endpoint returning only a generic transport-style error. However, a reduced diagnostic script isolated a concrete SQL runtime failure in the applied product RPC foundation.

## D. Diagnosis Classification

Classification: product RPC implementation bug.

Linked query itself works generally. The reduced diagnostic script failed at the first product creation RPC call with:

```text
ERROR: 42883: function min(uuid) does not exist
CONTEXT: PL/pgSQL function current_verified_supplier_owner_id() line 13 at SQL statement
PL/pgSQL function create_supplier_product(text,text,text,numeric,integer,jsonb,jsonb) line 18 at assignment
```

Root cause:

`public.current_verified_supplier_owner_id()` uses `min(s.id)` while `s.id` is a UUID. PostgreSQL does not provide `min(uuid)`.

This is not a confirmed authorization/security gap. It is a runtime bug in the product RPC foundation that prevents boundary tests from reaching meaningful assertions.

## E. Recommended Execution Method

Recommended path:

1. Create a forward fix migration that replaces the unsupported `min(s.id)` pattern in `public.current_verified_supplier_owner_id()`.
2. Use a UUID-safe pattern, such as selecting the single matching supplier ID after counting matches, or using an ordered subquery with `limit 1`.
3. Dry-run the fix migration.
4. After explicit approval, apply the fix migration to the confirmed development project.
5. Rerun the full development-only product management RPC boundary test once.

Execution method after the fix:

- Continue using `npx supabase db query --linked --file scripts/rpc/product-management-rpc-tests-dev-only.sql`.

Reason:

- tiny linked query passed
- reduced linked query reached database SQL execution and returned a concrete SQL error
- no need to switch to production, service-role client code, or manual UI paths

If the full script still hits response-size/transport behavior after the UUID aggregate fix, split the script into smaller development-only scripts:

- product create/default-state tests
- product update/image tests
- product archive/delete tests
- negative role/cross-supplier tests

## F. Script Changes Made

Temporary diagnostic file was created and deleted:

- `scripts/rpc/tmp-product-management-linked-query-diagnostic.sql`

No permanent test script changes were made.

No RLS/RPC/storage policies were weakened.

No supplier UI was connected to live products.

## G. Commands Run/Results

- `git status --short` - showed existing untracked product apply/test report at start
- `npx supabase --version` - `2.109.1`
- `npx supabase projects list` - confirmed linked development project named `Risellar`
- `npx supabase db query --help` - confirmed SQL is accepted as a positional argument and `--file` is supported
- `.env.local`/`supabase/.temp/` precheck - `.env.local` exists, ignored, not staged; `supabase/.temp/` ignored
- `npx supabase db query --linked "select 1 as linked_query_ok;"` - passed
- `npx supabase db query --linked "select count(*) ... dev_product_%"` - passed; returned zero leftover fake product fixture profiles
- temporary reduced diagnostic linked-query script - failed with `ERROR: 42883: function min(uuid) does not exist`
- temporary diagnostic file deletion - completed

## H. Secret Scan Result

Secret scan completed after report updates:

- `.env.local` is ignored
- `.env.local` is not staged
- `supabase/.temp/` is ignored
- no real Clerk/Supabase/service-role values found in docs/scripts/source
- no service role values exposed in app/components
- no bearer tokens, passwords, API secrets, or production data found

## I. Current Git Status

Expected changed/untracked files after this diagnostic:

- `docs/RISELLAR_SUPPLIER_PRODUCT_MANAGEMENT_DEV_APPLY_AND_TEST_REPORT.md`
- `docs/RISELLAR_SUPABASE_LINKED_QUERY_TRANSPORT_DIAGNOSTIC_REPORT.md`

## J. Whether Product RPC Boundary Tests Still Need Execution

Yes.

The product RPC boundary tests still need execution after a forward fix migration corrects `current_verified_supplier_owner_id()`.

Production remains blocked.

## K. UUID Selection Patch Prepared

A forward patch migration was prepared:

- `supabase/migrations/20260718102000_fix_supplier_owner_uuid_selection.sql`

The patch replaces the unsupported `min(uuid)` selection in `public.current_verified_supplier_owner_id()` with UUID-safe logic:

- count matching active approved supplier-owner records
- reject when no active approved supplier owner record exists
- select the supplier deterministically by `created_at asc, id::text asc`

Dry-run result:

- `npx supabase db push --dry-run` passed
- would apply only `20260718102000_fix_supplier_owner_uuid_selection.sql`
- real `supabase db push` was not run
