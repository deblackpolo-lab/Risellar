# Risellar Storage Bucket Diagnostic Report

## A. Scope

This diagnostic reviewed the development-only storage boundary failure:

```text
ERROR: P0001: Storage boundary tests failed: 1 failure(s): product-images bucket is private - expected=1, observed=0
```

Reviewed files:

- `supabase/migrations/20260717194000_audited_rpcs_views_grants_storage_foundation.sql`
- `scripts/storage/storage-boundary-tests-dev-only.sql`
- `scripts/storage/README.md`
- `docs/RISELLAR_BACKEND_SECURITY_PHASE_1_AUDITED_RPC_STORAGE_REPORT.md`
- `docs/RISELLAR_BACKEND_SECURITY_PHASE_1_DEV_APPLY_REPORT.md`
- `docs/RISELLAR_RPC_STORAGE_BOUNDARY_TEST_EXECUTION_REPORT.md`

No production Supabase project was used.

## B. Intended Storage Design

The Phase 1 migration and reports define `product-images` as a private bucket for now:

- `product-images` is inserted or updated with `public = false`.
- `storage.objects` SELECT is limited to authenticated supplier members for the supplier path or support/admin roles.
- INSERT and UPDATE are limited to authenticated users with supplier product permissions for the path supplier.
- No DELETE policy is created for client roles.
- Public-read behavior for approved product images is explicitly deferred until an approval-aware object or metadata contract exists.
- Sensitive proof buckets remain deferred/private and were not introduced as public buckets by Phase 1.

## C. Development Bucket State

Read-only linked development metadata query result:

```text
storage.buckets:
- id: product-images
- name: product-images
- public: false
- file_size_limit: null
- allowed_mime_types: null
```

No rows were returned for:

- `supplier-verification`
- `settlement-proofs`
- `dispute-proofs`
- `return-proofs`

This matches the documented Phase 1 design: `product-images` exists and is private, while sensitive proof buckets remain deferred.

## D. Policy State

Read-only policy inspection found the expected `storage.objects` policies for `product-images`:

- `product_images_storage_select_supplier_admin`
- `product_images_storage_insert_supplier`
- `product_images_storage_update_supplier`

The policy definitions constrain access to `bucket_id = 'product-images'` and supplier path permissions or admin/support read paths.

## E. Root Cause

Classification: test context bug.

The failed assertion checked `storage.buckets` after the script switched into anonymous role context:

```sql
set local role anon;
select count(*) from storage.buckets where id = 'product-images' and public = false;
```

The bucket exists and is private in development, but bucket metadata is not reliably visible from the anonymous SQL context. The assertion was therefore testing anonymous visibility into bucket metadata, not the actual bucket privacy state.

## F. Fix Applied

Updated `scripts/storage/storage-boundary-tests-dev-only.sql` so the `product-images bucket is private` assertion runs before role impersonation, in the setup/verification context that can inspect bucket metadata.

The anonymous boundary assertions were preserved under `anon`:

- anonymous cannot read `product-images` objects through SQL
- anonymous cannot insert product image object metadata

No storage policy, RLS policy, RPC function, grant, migration, or production configuration was changed.

## G. Migration Status

No migration was created.

No migration was applied.

No `supabase db push` command was run.

## H. Storage Test Status

The full storage boundary test was not rerun during the original diagnostic, per instruction.

After explicit approval, the development-only storage boundary test was rerun against the confirmed development project named `Risellar`:

```bash
npx supabase db query --linked --file scripts/storage/storage-boundary-tests-dev-only.sql
```

Result: passed. All returned assertion rows had `passed: true`.

The passing assertions confirmed:

- `product-images` bucket is private.
- anonymous/customer roles cannot read or insert product image object metadata.
- supplier owner and permitted inventory manager can insert only allowed own-supplier product image metadata.
- supplier owner and permitted inventory manager cannot write another supplier's product image metadata.
- supplier owner cannot overwrite another supplier's product image metadata.
- supplier owner cannot insert settlement proof object metadata without an explicit bucket policy.
- admin can read product image object metadata.
- no direct delete path exists for product image objects.

The script uses a transaction and reached its final `rollback`, so fixture/test data should not have been committed.

## I. Commands Run/Results

- `rg ... supabase/migrations/20260717194000_audited_rpcs_views_grants_storage_foundation.sql` - reviewed product image bucket and policy migration lines.
- `rg ... scripts/storage docs/...` - reviewed storage test, storage README, and related reports.
- `npx supabase db query --help` - confirmed safe linked read query support.
- `npx supabase db query --linked "select id, name, public, file_size_limit, allowed_mime_types from storage.buckets ..."` - passed; returned `product-images` with `public: false`.
- `npx supabase db query --linked --file <temporary diagnostic sql>` - passed; returned expected `storage.objects` product-image policies.
- `npx supabase --version` - `2.109.1`.
- Linked project precheck - confirmed project name `Risellar`.
- `.env.local` / `supabase/.temp/` precheck - passed without printing values.
- `npx supabase db query --linked --file scripts/storage/storage-boundary-tests-dev-only.sql` - approved rerun passed; all returned assertion rows had `passed: true`.

Verification commands are recorded in the RPC/storage execution report after this diagnostic update.

Verification after this diagnostic update:

- `git status --short` - showed modified storage test/report files and this new diagnostic report.
- `git diff --check` - passed with line-ending warnings only.
- `npm test` - passed; 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed.
- `npm run build` - passed.

## J. Secret Scan Result

No secret values were printed during diagnostic queries.

The final repository secret scan passed:

- `.env.local` is ignored and not tracked.
- `supabase/.temp/` is ignored.
- No high-confidence real Clerk/Supabase/service-role values, bearer tokens, passwords, API keys, or production data were found in tracked docs/scripts/source files by the scan.

## K. Current Git Status

This report was created and `scripts/storage/storage-boundary-tests-dev-only.sql` plus `docs/RISELLAR_RPC_STORAGE_BOUNDARY_TEST_EXECUTION_REPORT.md` were updated.

## L. Next Prompt

```text
Commit the passing RPC/storage boundary execution and diagnostic reports.

Do NOT connect to production Supabase.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS, RPC, or storage policies.
Do NOT run npm audit fix --force.

Files to commit:
- scripts/storage/storage-boundary-tests-dev-only.sql
- docs/RISELLAR_RPC_STORAGE_BOUNDARY_TEST_EXECUTION_REPORT.md
- docs/RISELLAR_STORAGE_BUCKET_DIAGNOSTIC_REPORT.md

Run:
git status --short
git diff --check
npm test
npm run typecheck
npm run lint
npm run build
secret scan

Stage only the files listed above.
Commit:
git commit -m "Document passing RPC and storage boundary tests"
Push:
git push origin main
```
