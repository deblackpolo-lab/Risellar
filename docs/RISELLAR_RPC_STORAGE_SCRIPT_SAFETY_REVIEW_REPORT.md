# Risellar RPC and Storage Script Safety Review Report

## A. Scripts reviewed

Reviewed:

- `scripts/rpc/README.md`
- `scripts/rpc/rpc-boundary-tests-dev-only.sql`
- `scripts/storage/README.md`
- `scripts/storage/storage-boundary-tests-dev-only.sql`
- `supabase/migrations/20260717194000_audited_rpcs_views_grants_storage_foundation.sql`

## B. Safety result

Safety result: ready to run against the confirmed development Supabase project only, after explicit approval.

The scripts are clearly marked development-only, use fake development fixture data, do not contain secrets, do not apply migrations, do not run reset/destructive commands, and end with `rollback`.

The scripts were not executed during this review.

## C. Dangerous SQL or unsafe commands found

No dangerous SQL or unsafe commands were found.

Review checks:

- `DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION` markings are present.
- No `TRUNCATE` statements were found.
- No RLS-disable statements were found.
- No migration apply commands were found.
- No `supabase db push` or `supabase db reset` commands are executed by the scripts.
- No real user/customer/supplier records were found.
- No real emails or phone numbers were found; scripts use fake `example.invalid` addresses and fake `000...` contact snapshots.
- No secrets were found.

Notes:

- The Phase 1 migration contains `DROP POLICY IF EXISTS` statements for policy replacement during migration, but the reviewed test scripts do not drop policies or tables.
- The storage script uses `insert into storage.objects` only for fake object metadata inside a transaction that rolls back. It does not upload binary files.

## D. Whether scripts are ready to run

Yes, with these constraints:

- Run only against the confirmed development Supabase project named `Risellar`.
- Run only after explicit approval.
- Do not run against production.
- Do not run destructive reset commands.
- Stop immediately if either script fails.
- Do not weaken RLS, RPC authorization, grants, or storage policies to make a test pass.

## E. Recommended execution order

Recommended order:

1. Run the RPC boundary script:
   `npx supabase db query --linked --file scripts/rpc/rpc-boundary-tests-dev-only.sql`

2. If the RPC script passes, run the storage SQL boundary script:
   `npx supabase db query --linked --file scripts/storage/storage-boundary-tests-dev-only.sql`

Reason: RPC boundaries cover the core audited mutation paths first. Storage SQL metadata policy checks are then run separately so any failure is easier to classify.

## F. What must be manual vs automatic

Automatic SQL tests cover:

- RPC role restrictions.
- RPC audit row creation.
- blocked direct sensitive field mutation.
- safe view visibility.
- product image storage bucket privacy metadata.
- storage object SQL metadata insert/update/read boundaries.
- no direct storage object delete path.

Manual development-only storage checks still required:

- browser/client upload behavior through Supabase Storage API.
- binary file upload/download behavior.
- public URL behavior for the private `product-images` bucket.
- signed URL behavior if later enabled.
- CDN/cache behavior.
- proof bucket behavior for settlement, supplier verification, dispute, and return evidence after explicit policies exist.
- confirming the browser/client never receives a service-role key.

## G. Commands run/results

- `git status --short` - clean before creating this report.
- `git diff --check` - passed.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed with `--max-warnings=0`.
- `npm run build` - passed; Next.js generated 160 static pages.
- Static script safety scan for development markers, DROP/TRUNCATE/RLS-disable/reset/migration commands, and secrets - passed.
- Secret scan - passed.

The RPC and storage boundary scripts were not run.

## H. Secret scan result

Secret scan result: passed.

Confirmed:

- `.env.local` is ignored and not staged.
- `supabase/.temp/` is ignored.
- no real Clerk/Supabase/service-role values were found in docs/scripts/source.
- no bearer tokens, passwords, or API secrets were found.
- no production data was found.

Production-data scan hits were safety text and existing development-only warnings, not real records.

## I. Current git status

After creating this report, the working tree contains one untracked file:

- `docs/RISELLAR_RPC_STORAGE_SCRIPT_SAFETY_REVIEW_REPORT.md`

## J. Exact next prompt to run tests if safe

```text
I approve running the development-only Backend Security Phase 1 RPC and storage boundary tests against the confirmed DEVELOPMENT Supabase project named "Risellar".

Do NOT connect to production Supabase.
Do NOT use production data.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS, RPC authorization, grants, or storage policies.
Do NOT run npm audit fix --force.

Run:
git status --short
npx supabase --version

Confirm:
- working tree contains only the expected uncommitted safety review report, or is clean if it has been committed
- project is linked to the confirmed development Supabase project named "Risellar"
- .env.local exists, is ignored, and is not staged
- supabase/.temp/ is ignored

Run once:
npx supabase db query --linked --file scripts/rpc/rpc-boundary-tests-dev-only.sql

If it passes, run once:
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
