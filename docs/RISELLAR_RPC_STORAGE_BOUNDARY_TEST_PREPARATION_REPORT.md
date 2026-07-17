# Risellar RPC and Storage Boundary Test Preparation Report

## A. RPCs/functions reviewed

Reviewed Backend Security Phase 1 migration:

- `public.create_audit_log_entry`
- `public.admin_manual_override_record`
- `public.confirm_customer_order`
- `public.release_expired_reservation`
- `public.mark_order_ready_for_delivery`
- `public.record_delivery_quote`
- `public.approve_delivery_quote`
- `public.submit_supplier_settlement_proof`
- `public.verify_supplier_settlement`
- `public.mark_settlement_overdue`
- `public.restrict_supplier_for_overdue_settlement`
- `public.mark_commission_pending`
- `public.release_commission_after_settlement`
- `public.request_commission_withdrawal`
- `public.approve_or_reject_withdrawal`
- `public.storage_path_supplier_id`

Reviewed safe views:

- `public.supplier_settlement_summary`
- `public.reseller_commission_summary`
- `public.supplier_product_image_review_queue`

## B. Storage policies reviewed

Reviewed product image storage foundation from:

- `supabase/migrations/20260717194000_audited_rpcs_views_grants_storage_foundation.sql`

Reviewed policies:

- `product_images_storage_select_supplier_admin`
- `product_images_storage_insert_supplier`
- `product_images_storage_update_supplier`

The migration keeps `product-images` private and limits SQL-visible object metadata access to authenticated supplier members or support/admin. Insert/update checks parse the supplier UUID from `supplier_id/product_id/file_name` paths and call `public.has_supplier_permission`.

No storage DELETE policy was added.

## C. Test scripts created

Created:

- `scripts/rpc/README.md`
- `scripts/rpc/rpc-boundary-tests-dev-only.sql`
- `scripts/storage/README.md`
- `scripts/storage/storage-boundary-tests-dev-only.sql`

All scripts are marked `DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION`.

## D. What can be tested automatically

`scripts/rpc/rpc-boundary-tests-dev-only.sql` can automatically test:

- anonymous users cannot use authenticated audit RPCs
- customer can confirm only own order
- customer can approve only own delivery quote
- customer cannot directly mutate price totals or order item snapshots
- reseller cannot release own commission
- reseller cannot approve own withdrawal
- reseller cannot request more than available commission
- supplier owner cannot verify own settlement
- supplier owner can submit private settlement proof path
- supplier owner cannot submit public proof URL
- supplier owner cannot directly mutate settlement verification status
- inventory manager cannot verify settlement or release commission
- support can release expired reservation and record delivery quote
- support cannot perform finance-only settlement verification
- finance can verify settlement, release commission, and approve withdrawal
- admin can record manual override with reason
- implemented audited RPCs write audit rows
- safe views do not expose deferred/sensitive columns such as product base price

`scripts/storage/storage-boundary-tests-dev-only.sql` can automatically test:

- `product-images` bucket exists and is private
- anonymous SQL reads cannot see product image objects
- customer cannot insert product image object metadata
- supplier owner can insert/update only own supplier product image object metadata
- supplier owner cannot insert/update another supplier path
- permitted supplier inventory manager can insert own supplier product image object metadata
- permitted inventory manager cannot insert another supplier path
- inventory manager cannot read another supplier object metadata
- sensitive proof bucket object insertion is blocked without explicit bucket/policy
- product image object DELETE remains blocked

Both scripts use fake data and explicit transaction rollback.

## E. What needs manual testing

Storage API behavior still needs manual development-only validation after SQL tests pass:

- browser/client upload through the Supabase Storage API
- binary object content upload/download behavior
- public URL behavior for the private `product-images` bucket
- signed URL behavior, if added later
- CDN/public cache behavior
- whether product image approval metadata can be safely coupled to public reads
- proof buckets for settlement, supplier verification, dispute, and return evidence

The scripts intentionally do not test with a service-role key and do not require service role on the client.

## F. Whether tests were run

The new RPC and storage boundary scripts were not run.

They require explicit approval before execution against the confirmed development Supabase project.

## G. Safety notes

- No production Supabase connection was used.
- No migrations were applied.
- No destructive reset commands were run.
- No frontend buttons were connected to live database operations.
- No RLS or storage policy was weakened.
- No `.env.local` content was printed or committed.
- The scripts use fake `example.invalid` email addresses, fake names, fake order numbers, and rollback.
- The scripts do not contain secrets.

## H. Commands run/results

Preparation commands:

- `git status --short` - clean at start.
- Source review of Phase 1 migration and reports - completed.
- Source review of existing RLS test README/script - completed.

Verification commands after creating the scripts:

- `git diff --check` - passed.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed with `--max-warnings=0`.
- `npm run build` - passed; Next.js generated 160 static pages.
- Secret scan - passed.

## I. Secret scan result

- `.env.local` is ignored and not staged.
- `supabase/.temp/` is ignored.
- No real Clerk/Supabase/service role values were found in docs/scripts/source.
- No bearer tokens, passwords, or API secrets were found.
- No production data was found.
- Production-data scan hits were safety instructions and existing dev-only warnings, not real records.

## J. Files changed

Created:

- `scripts/rpc/README.md`
- `scripts/rpc/rpc-boundary-tests-dev-only.sql`
- `scripts/storage/README.md`
- `scripts/storage/storage-boundary-tests-dev-only.sql`
- `docs/RISELLAR_RPC_STORAGE_BOUNDARY_TEST_PREPARATION_REPORT.md`

## K. Current git status

At report creation time, the files above are untracked in the working tree.

## L. Exact next prompt to run tests if safe

```text
I approve running the development-only Backend Security Phase 1 RPC and storage boundary tests against the confirmed DEVELOPMENT Supabase project named "Risellar".

Do NOT connect to production Supabase.
Do NOT use production data.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS or storage policies.
Do NOT run npm audit fix --force.

Run:
git status --short
npx supabase --version

Confirm:
- working tree contains only the expected uncommitted test/report files, or is clean if they have been committed
- project is linked to the confirmed development Supabase project named "Risellar"
- .env.local exists, is ignored, and is not staged
- supabase/.temp/ is ignored

Then run once:
npx supabase db query --linked --file scripts/rpc/rpc-boundary-tests-dev-only.sql
npx supabase db query --linked --file scripts/storage/storage-boundary-tests-dev-only.sql

If either script fails, stop immediately, report the exact assertion/error, classify the failure, and do not rerun without a fix.

If both pass, run:
npm test
npm run typecheck
npm run lint
npm run build

Run secret scan and create:
docs/RISELLAR_RPC_STORAGE_BOUNDARY_TEST_EXECUTION_REPORT.md

Do not commit unless asked.
```
