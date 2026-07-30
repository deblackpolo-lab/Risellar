# Risellar Checkout Phase C Reconciliation Group R3 Backup And Data Plan Report

## A. Executive summary

Checkout Phase C Reconciliation Group R3 resumed after PostgreSQL client tooling became available. This task created a secure ignored DEVELOPMENT backup/evidence package, verified the 23 `orders.expires_at` rows using aggregate-only read-only queries, confirmed no active app/source dependency on `orders.expires_at`, and selected the next data-handling strategy.

No migration was applied. No Supabase `db push`, dry-run, migration repair, migration-history mutation, RPC test, stale Claude-era RPC execution, schema mutation, data mutation, app source change, or commit/push occurred.

Primary recommendation: proceed with Option C in a future R4 implementation group. R4 should revise the cleanup migration to assert the reviewed count and dependencies, null exactly the reviewed DEVELOPMENT-only `orders.expires_at` values after verified backup preconditions, then drop `orders.expires_at`.

## B. Baseline commit and branch

- Expected commit: `c1f16679309d8ad9ad2a1926af8f23316b22f1c2`
- Observed commit: `c1f16679309d8ad9ad2a1926af8f23316b22f1c2`
- Branch: `main`
- Staged files during precheck: none
- Existing worktree note: `app/supplier/orders/[id]/page.tsx`, `app/supplier/orders/page.tsx`, `next-env.d.ts`, `package-lock.json`, `package.json`, and `tsconfig.json` still show metadata/no-content-diff modified status. `git diff --name-status`, `git diff --numstat`, and `git diff --summary` produced no meaningful source diff.

## C. Tooling verification

- `pg_dump --version`: PostgreSQL 18.4
- `psql --version`: PostgreSQL 18.4
- `pg_restore`: available through the same PostgreSQL installation
- `npx supabase --version`: 2.109.1

## D. Development-project confirmation

The linked Supabase project was confirmed by name as DEVELOPMENT `Risellar`. Project identifiers, connection strings, credentials, tokens, and environment values were suppressed and were not written to this report.

Connection for backup/read-only evidence used local environment values internally and the Supabase session-pooler endpoint. No connection string was printed or persisted.

## E. Full backup result

- Backup type: PostgreSQL custom-format archive created with `pg_dump -Fc`
- Ignored path: `.local-recovery/phase-c-r3-backup/risellar-development-before-phase-c-cleanup-20260730-1707.dump`
- Timestamp: `20260730-1707`
- File size: 673,657 bytes
- Creation result: succeeded
- Archive inspection: `pg_restore --list` succeeded
- Archive listing path: `.local-recovery/phase-c-r3-backup/risellar-development-before-phase-c-cleanup-20260730-1707.archive-list.txt`
- Archive listing size: 82,064 bytes
- Restore was not executed.

## F. Schema snapshot result

- Snapshot type: PostgreSQL schema-only SQL dump
- Ignored path: `.local-recovery/phase-c-r3-backup/risellar-development-schema-before-phase-c-cleanup-20260730-1707.sql`
- Timestamp: `20260730-1707`
- File size: 507,507 bytes
- Creation result: succeeded
- Contents were not printed or committed.

## G. Migration-history snapshot result

Safe migration metadata was stored under the ignored backup directory:

- CLI migration list: `.local-recovery/phase-c-r3-backup/migration-list-linked-20260730-1710.txt`
- CLI stderr/status note: `.local-recovery/phase-c-r3-backup/migration-list-linked-20260730-1710.stderr.txt`
- Remote `supabase_migrations.schema_migrations` metadata CSV: `.local-recovery/phase-c-r3-backup/remote-schema-migrations-20260730-1710.csv`

Only version/name/ordering-style metadata was captured. Migration history was not modified.

## H. Affected-object inventory

Ignored inventory path:

- `.local-recovery/phase-c-r3-backup/affected-object-inventory-20260730-1711.csv`

Verified object names include:

- `public.create_order_from_draft(p_draft_id uuid)`
- `public.prepare_supplier_for_order(p_order_id uuid, p_reason text)`
- `public.orders.expires_at`
- `public.idx_orders_expires_confirm_pending`
- `public.orders.prepared_at`
- `public.orders.ready_at`
- `public.orders.dispatched_at`
- `public.orders.out_for_delivery_at`
- `public.orders.delivered_at`
- `public.orders.delivery_person_id`
- `public.orders_delivery_person_id_fkey`
- `public.user_role.delivery_person`
- function execute grants for the two stale RPCs

The enum value remains a deferred cleanup decision and should not be removed in the Phase C cleanup.

## I. Aggregate expires_at analysis

Ignored aggregate evidence path:

- `.local-recovery/phase-c-r3-backup/orders-expires-at-aggregate-evidence-20260730-1712.md`

Aggregate-only results:

- `orders.expires_at` non-null count: 23
- Status counts: `placed_pending_confirmation=23`
- Earliest/latest `expires_at`: `2026-07-24 20:44:56.639907+00` to `2026-07-26 15:03:43.521023+00`
- Past/future counts: 23 past, 0 future
- Confirmation-related fields populated: 0
- Supplier-preparation fields populated: 0
- Delivery-related fields populated: 0
- Linked to `stock_reservations`: 0
- Linked to `order_items`: 4
- Linked to `commissions`: 0
- Linked to `settlements`: 0
- Linked to withdrawals: table or column absent
- Linked to payments/payment-related table: table or column absent
- Stale Claude-flow audit events: 0
- Created before/after first Claude timestamp: 0 before `2026-07-18T21:00Z`, 23 after or equal
- Non-sensitive QA classification evidence: one status group, 23 pending confirmations, 23 expired rows

No row IDs, customer IDs, names, emails, phone numbers, addresses, product names, supplier/reseller/shop details, or payment references were captured.

## J. Active-code dependency analysis

Ignored search evidence:

- `.local-recovery/phase-c-r3-backup/active-dependency-search-20260730-1713.txt`
- `.local-recovery/phase-c-r3-backup/active-dependency-classification-20260730-1714.md`

Classification:

- `app/`, `components/`, and `lib/`: no active references to `orders.expires_at` or the stale Claude RPCs were found.
- Cleanup migration references: CLEANUP-ONLY.
- Phase C migration references: APPROVED AND REQUIRED where they refer to approved Phase C RPCs; the migration comment explicitly says it does not use `orders.expires_at`.
- Tombstones: HISTORICAL DOCUMENTATION.
- Phase C/R1/R2/R2B docs: HISTORICAL DOCUMENTATION and planning.
- Development-only SQL test script: TEST-ONLY and not executed.

Conclusion: the current application and approved Phase C migration do not need `orders.expires_at`.

## K. Selected primary strategy

Primary strategy: OPTION C.

Rely on the verified full DEVELOPMENT backup plus aggregate evidence, then in a future guarded R4 migration null exactly the reviewed DEVELOPMENT-only `orders.expires_at` values and drop the column.

Reason:

- The data is confirmed DEVELOPMENT-only through operational project confirmation.
- The 23 values have no approved current business meaning.
- No active app/source or approved Phase C functionality depends on `orders.expires_at`.
- Backup and schema/migration/evidence snapshots now exist outside Git.
- Dependency aggregates show no stock reservation, payment, settlement, commission, delivery, confirmation, or stale audit dependency.
- Clean environments should not inherit unapproved Claude-era order expiry semantics.

## L. Selected fallback

Fallback strategy: OPTION D.

Preserve `orders.expires_at` temporarily while removing stale RPCs, stale index, and zero-populated preparation/delivery fields, then schedule a later dedicated expiry-column cleanup. Use this only if the team wants more time to inspect the 23 QA rows or if R4 preconditions differ from the reviewed evidence.

## M. Whether cleanup migration requires revision

Yes.

Current cleanup migration intentionally stops when `orders.expires_at` contains non-null rows. Since backup/evidence now exists and Option C is selected, R4 should revise the cleanup migration rather than applying the current stop-guard version as-is.

## N. Exact recommended R4 revision

Revise `supabase/migrations/20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql` in R4 to:

1. Keep stale RPC signature checks and exact drops.
2. Keep `idx_orders_expires_confirm_pending` cleanup.
3. Keep zero-population checks for prep/delivery fields.
4. Add an exact `orders.expires_at` count assertion: expected count `23`.
5. Assert all 23 rows are development QA-compatible by aggregate conditions:
   - all are `placed_pending_confirmation`
   - all have pending customer confirmation
   - all are expired
   - zero confirmation/prep/delivery fields populated
   - zero stock reservation dependency
   - zero commission/settlement/payment/delivery dependency
   - zero stale Claude-flow audit events
6. After the assertions pass, update only the reviewed set:
   - `update public.orders set expires_at = null where expires_at is not null;`
7. Assert the post-update non-null count is zero.
8. Drop `orders.expires_at`.
9. Drop zero-populated prep/delivery columns as currently designed.
10. Leave `public.user_role.delivery_person` untouched.

Stable future stop errors should include:

- `CLAUDE_EXPIRES_AT_COUNT_CHANGED`
- `CLAUDE_EXPIRES_AT_DEPENDENCY_REQUIRES_REVIEW`
- `CLAUDE_PREP_DELIVERY_DATA_REQUIRES_REVIEW`
- `CLAUDE_STALE_RPC_SIGNATURE_MISMATCH`
- `CLAUDE_BACKUP_PRECONDITION_NOT_MET` as an operational/report gate, not an unsafe SQL environment guess

Do not implement these changes in R3.

## O. SQL preconditions

Future SQL should stop unless:

- `public.orders.expires_at` exists when the data-handling path runs.
- `orders.expires_at is not null` count equals 23.
- All affected rows remain `placed_pending_confirmation`.
- All affected rows remain customer confirmation `pending`.
- No confirmation, preparation, delivery, or delivery-person fields are populated.
- No order-linked stock reservations exist for affected rows.
- No payment, settlement, commission, delivery, or withdrawal dependency exists where those tables/columns exist.
- No stale Claude-flow audit events exist.
- `public.idx_orders_expires_confirm_pending` is either present and exact or absent.
- Stale RPC signatures match exactly before dropping:
  - `public.create_order_from_draft(uuid)`
  - `public.prepare_supplier_for_order(uuid,text)`
- No unexpected indexes, constraints, triggers, or defaults depend on `orders.expires_at`.
- Prep/delivery columns have zero populated rows before dropping.

## P. Operational preconditions

Future R4/apply process should require:

- Manual confirmation that the linked project is DEVELOPMENT `Risellar`.
- No production connection.
- Git checkpoint containing the approved R3 report.
- Full custom-format backup exists outside Git.
- `pg_restore --list` succeeds for that backup.
- Schema-only snapshot exists outside Git.
- Migration-history snapshot exists outside Git.
- Affected-object inventory exists outside Git.
- Aggregate evidence exists outside Git.
- `.env.local`, `.local-recovery`, `.next`, and `supabase/.temp` are ignored and not staged.
- No private row-level data is added to Git.
- No final checkout confirmation UI is enabled.

## Q. Backup verification

Verified:

- Full custom-format backup exists and is non-zero size.
- `pg_restore --list` can inspect the backup archive.
- Schema snapshot exists and is non-zero size.
- Migration-history snapshots exist.
- Affected-object inventory exists.
- Aggregate evidence exists.
- Dependency classification exists.

Two zero-byte files from the earlier failed Docker-based dump attempt remain ignored in `.local-recovery/phase-c-r3-backup/`; they are not backup artifacts and must not be committed.

## R. Restore-plan summary

Restore only into a separate temporary/local PostgreSQL database, never directly into the linked DEVELOPMENT project without separate approval.

Command pattern without credentials:

```text
createdb risellar_phase_c_restore_check
pg_restore --list <ignored-backup-file>
pg_restore --dbname risellar_phase_c_restore_check --clean --if-exists <ignored-backup-file>
psql --dbname risellar_phase_c_restore_check --command "<aggregate validation query>"
```

Validation after restore:

- Confirm `public.orders` exists.
- Confirm the 23 aggregate `orders.expires_at` count is restored.
- Confirm stale RPCs, stale index, and reviewed columns are restored in the temporary database.
- Confirm no production connection is used.

If cleanup fails after a future approved apply, recover by restoring the verified backup to a separate database first, comparing schema/data aggregates, and only then deciding whether to restore DEVELOPMENT or rebuild it. Do not recreate unapproved Claude-era migrations in source.

## S. R4 implementation scope

R4 should:

- Revise `supabase/migrations/20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`.
- Update Phase C reconciliation reports.
- Add exact count and dependency assertions.
- Add the reviewed development-only `expires_at` nulling step.
- Keep enum cleanup deferred.
- Run `git diff --check`, tests, lint, build, typecheck, and `npx tsc --noEmit`.
- Run `npx supabase db push --dry-run --include-all` only if explicitly approved in the R4 prompt.
- Do not apply migrations in R4 unless a later prompt explicitly approves apply after review.

R4 stop conditions:

- Count differs from 23.
- Any dependency count becomes non-zero unexpectedly.
- Active source dependency on `orders.expires_at` appears.
- Backup files are missing or archive inspection fails.
- Linked project is not confirmed DEVELOPMENT.

Commit boundary:

- Commit only the revised cleanup migration and updated reports after verification, if explicitly asked.

Apply boundary:

- Apply to DEVELOPMENT only in a later explicit apply prompt after R4 dry-run/report review.

## T. Commands and results

- `pg_dump --version`: passed, PostgreSQL 18.4.
- `psql --version`: passed, PostgreSQL 18.4.
- `where.exe pg_dump`: passed.
- `where.exe psql`: passed.
- `where.exe pg_restore`: passed.
- `git status --short`: showed known metadata/no-content-diff modified entries and no staged files.
- `git rev-parse HEAD`: `c1f16679309d8ad9ad2a1926af8f23316b22f1c2`.
- `git branch --show-current`: `main`.
- `git diff --name-status`, `git diff --numstat`, `git diff --summary`: no meaningful source diff.
- `git diff --check`: passed during precheck.
- `npx supabase --version`: 2.109.1.
- Supabase project list: linked project confirmed as DEVELOPMENT `Risellar`; identifiers suppressed.
- `psql` connection probe: passed using session-pooler endpoint; identifiers suppressed.
- `pg_dump -Fc`: created full backup.
- `pg_restore --list`: inspected backup archive successfully.
- `pg_dump --schema-only`: created schema snapshot.
- `npx supabase migration list --linked`: captured safe migration-list evidence under ignored recovery storage.
- Read-only `supabase_migrations.schema_migrations` query: captured version/name/ordering metadata.
- Read-only affected-object inventory query: passed.
- Read-only aggregate evidence query: passed.
- Static dependency search: passed.

Commands intentionally not run:

- `npx supabase db push`
- `npx supabase db push --dry-run`
- `npx supabase db push --dry-run --include-all`
- `npx supabase migration repair`
- `npx supabase db reset --linked`
- Phase C RPC boundary test
- stale Claude-era RPCs
- any restore command

## U. Automated verification

Automated verification was run after this report was created:

- `git diff --check`: passed
- `npm test`: passed; 30 test files, 158 tests
- `npm run lint`: passed with `eslint . --max-warnings=0`
- `npm run build`: passed with `next build`; 168 static pages generated
- `npm run typecheck`: passed with `tsc --noEmit`
- `npx tsc --noEmit`: passed

## V. Security/privacy scan

Security/privacy scan result:

- `.env.local` ignored and not staged.
- `.local-recovery` ignored and not staged.
- `.next` ignored and not staged.
- `supabase/.temp` ignored and not staged.
- Backup files ignored and not staged.
- Schema snapshot ignored and not staged.
- Migration-history evidence ignored and not staged.
- Aggregate evidence ignored and not staged.
- No credentials, connection strings, project IDs, JWTs, cookies, tokens, or environment values printed or added to Git files.
- No private row data included in reports.
- No production project accessed.
- No database mutation occurred.
- No schema mutation occurred.
- No migration-history mutation occurred.
- No RPC executed.
- No migration applied.
- No application source changed.
- New R3 report has no value-shaped secret matches.
- No service-role references were found in `app/` or `components/`.
- Privacy-term scan found only generic planning words in the report, not private row identifiers or values.

## W. Files changed

- `docs/RISELLAR_CHECKOUT_PHASE_C_RECONCILIATION_GROUP_R3_BACKUP_AND_DATA_PLAN_REPORT.md`

Ignored local evidence created under:

- `.local-recovery/phase-c-r3-backup/`

The ignored evidence directory must not be staged or committed.

## X. Current Git status

Current status after R3:

```text
 M app/supplier/orders/[id]/page.tsx
 M app/supplier/orders/page.tsx
 M next-env.d.ts
 M package-lock.json
 M package.json
 M tsconfig.json
?? docs/RISELLAR_CHECKOUT_PHASE_C_RECONCILIATION_GROUP_R3_BACKUP_AND_DATA_PLAN_REPORT.md
```

Nothing is staged. The existing modified tracked entries continue to have no meaningful diff output and were not changed by R3.

## Y. Whether R3 is complete

Yes. R3 backup, evidence, aggregate analysis, dependency analysis, data-handling strategy selection, restore plan, R4 scope, automated verification, and security/privacy scan are complete.

## Z. Whether R4 may begin

Yes, with explicit approval. R4 may revise the cleanup migration and run dry-run only according to the selected Option C strategy. R4 must still not apply migrations unless a later prompt explicitly approves apply.

## AA. Whether any migration is safe to apply now

No. No migration is safe to apply now. The cleanup migration still requires R4 revision, review, dry-run, and a later explicit DEVELOPMENT apply approval.

## AB. Exact recommended next prompt

Proceed with Checkout Phase C Reconciliation Group R4: revise the cleanup migration to use the verified R3 backup/evidence, assert exactly 23 DEVELOPMENT `orders.expires_at` rows with no dependencies, null only those reviewed values, drop `orders.expires_at`, keep `delivery_person` enum untouched, run validation and `npx supabase db push --dry-run --include-all` only, and do not apply migrations or run RPC tests.

## AC. Group R4 cleanup-revision update

Group R4 implemented the approved Option C migration revision locally. The cleanup migration now checks the exact reviewed DEVELOPMENT state before any data update:

- `orders.expires_at` non-null count must equal 23.
- All affected rows must be `placed_pending_confirmation`.
- All affected rows must have pending customer confirmation.
- All affected values must already be expired.
- Confirmation, preparation, and delivery fields must be unpopulated.
- Stock reservation, delivery quote, commission, settlement, withdrawal, payment, and stale Claude-flow audit dependencies must be absent where those tables/columns exist.
- Unexpected index, constraint, trigger, or active function dependencies on `orders.expires_at` must be absent.

Only after those assertions pass, the migration nulls `public.orders.expires_at` where it is non-null, requires exactly 23 updated rows, verifies zero non-null values remain, then drops `orders.expires_at`. The migration still preserves all orders and order items, keeps `delivery_person` enum untouched, and does not apply in R4.
