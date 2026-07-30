# Risellar Checkout Phase C Migration History Reconciliation Report

## A. Executive summary

This read-only forensic pass investigated the migration-history mismatch that blocked Checkout Phase C Group 2 dry-run against the linked DEVELOPMENT Supabase project named "Risellar".

The mismatch is understood. Six Claude-era migration versions are recorded as applied remotely but are intentionally absent from active local `supabase/migrations/` because Recovery Phase 2 quarantined them under `.local-recovery/quarantine/unapproved-migrations/`.

This is not a history-only mismatch. The DEVELOPMENT database still contains schema effects from those migrations, including old order/supplier-preparation RPCs, order expiry/preparation/delivery columns, an order-expiry index, and the `delivery_person` enum value. Aggregate data checks also show 23 development `orders` rows with `expires_at` populated. No stock reservations, commissions, settlements, delivery quotes, or audit events from the old Claude-era order/supplier-preparation RPCs were found.

The safest next step is not to restore the original migrations and not to run migration repair immediately. The recommended path is a reviewed reconciliation plan that combines historical no-op tombstone migrations for the six remote-only versions with an explicitly approved forward compensating cleanup migration, after a preservation decision for the 23 development order rows that currently carry `expires_at`.

## B. Baseline commit and branch

- Baseline commit requested: `53a9daad399576d58dce54379db23f97ede9e30d`
- Current branch: `main`
- Current HEAD observed: `53a9daad399576d58dce54379db23f97ede9e30d`

## C. Exact dry-run blocker

The previous `npx supabase db push --dry-run` was not rerun during this task. The already-recorded blocker was:

```text
Remote migration versions not found in local migrations directory.
20260718210000
20260724000000
20260724010000
20260725000000
20260725020000
20260725030000
```

Supabase suggested migration repair/db pull commands in the earlier output. Those commands were not run.

## D. Local migration-history result

Local active migrations are present through the approved Checkout Phase B draft foundation at `20260718203000`.

The new local-only Phase C Group 2 migration exists but remains unapplied:

- `20260718213000_create_order_from_checkout_draft_rpc.sql`

No active local migration file exists for the six remote-only Claude-era versions.

## E. Remote migration-history result

Read-only migration listing and `supabase_migrations.schema_migrations` inspection confirmed the following remote-only versions are recorded as applied:

- `20260718210000` - `create_order_from_draft_rpc`
- `20260724000000` - `add_confirmation_fields`
- `20260724010000` - `prepare_supplier_for_order_rpc`
- `20260725000000` - `add_order_expires_index`
- `20260725020000` - `add_delivery_and_prepare_timestamps`
- `20260725030000` - `update_prepare_supplier_for_order_rpc`

Later approved migrations are also present remotely through `20260718203000`, and the remote history appears internally ordered and consistent.

## F. Six-version investigation

The six remote-only versions correspond to previously identified unapproved Claude-era checkout/order/delivery scope. Recovery Phase 2 removed them from active migrations and quarantined the original files. The remote development project still records them because they had already been applied before recovery.

## G. Quarantined original-file findings

All six original SQL files were found in ignored quarantine:

- `.local-recovery/quarantine/unapproved-migrations/supabase/migrations/20260718210000_create_order_from_draft_rpc.sql`
- `.local-recovery/quarantine/unapproved-migrations/supabase/migrations/20260724000000_add_confirmation_fields.sql`
- `.local-recovery/quarantine/unapproved-migrations/supabase/migrations/20260724010000_prepare_supplier_for_order_rpc.sql`
- `.local-recovery/quarantine/unapproved-migrations/supabase/migrations/20260725000000_add_order_expires_index.sql`
- `.local-recovery/quarantine/unapproved-migrations/supabase/migrations/20260725020000_add_delivery_and_prepare_timestamps.sql`
- `.local-recovery/quarantine/unapproved-migrations/supabase/migrations/20260725030000_update_prepare_supplier_for_order_rpc.sql`

The original migrations must remain quarantined. They should not be restored as executable source migrations because future clean environments would replay unapproved checkout/order/delivery behavior.

## H. Remote schema-object findings

Active Claude-era RPCs/functions found:

- `public.create_order_from_draft(p_draft_id uuid)` exists, `SECURITY DEFINER`, `search_path=public`.
- `public.prepare_supplier_for_order(p_order_id uuid, p_reason text)` exists, `SECURITY DEFINER`, `search_path=public`.

Execution-grant metadata reports `EXECUTE` for `anon`, `authenticated`, `postgres`, and `service_role` on both functions. This does not prove exploitability because the functions contain their own checks, but it is broader than the intended active source posture and should be cleaned up or revoked through an approved reconciliation migration.

Claude-era columns and enum values found:

- `orders.expires_at timestamptz`
- `orders.prepared_at timestamptz`
- `orders.ready_at timestamptz`
- `orders.dispatched_at timestamptz`
- `orders.out_for_delivery_at timestamptz`
- `orders.delivered_at timestamptz`
- `orders.delivery_person_id uuid`
- `user_role` enum value `delivery_person`

Claude-era index found:

- `idx_orders_expires_confirm_pending`

No triggers were found on `orders`, `order_items`, `stock_reservations`, `product_variants`, `settlements`, or `commissions`.

No policies attributable to the six quarantined migrations were found. Existing policies on checkout/order/stock/commission/settlement tables appear to come from the approved audited foundation, not from these six files.

## I. Development data-dependency findings

Aggregate-only counts found:

- `orders`: 23 rows
- `orders.expires_at is not null`: 23 rows
- `orders.prepared_at is not null`: 0 rows
- `orders.ready_at is not null`: 0 rows
- `orders.dispatched_at is not null`: 0 rows
- `orders.out_for_delivery_at is not null`: 0 rows
- `orders.delivered_at is not null`: 0 rows
- `orders.delivery_person_id is not null`: 0 rows
- `stock_reservations`: 0 rows
- `stock_reservations.order_id is not null`: 0 rows
- `audit_logs.action = create_order_from_draft`: 0 rows
- `audit_logs.action = prepare_supplier_for_order`: 0 rows
- `order_items`: 4 rows
- `delivery_quotes`: 0 rows
- `commissions`: 0 rows
- `settlements`: 0 rows

Order status aggregates:

- `orders.order_status = placed_pending_confirmation`: 23 rows
- `orders.customer_confirmation_status = pending`: 23 rows

Checkout draft aggregates:

- `checkout_drafts.draft_status = abandoned`: 2 rows

The development data dependency is limited but real: all 23 current order rows carry the unapproved `expires_at` column value. No evidence was found that old Claude-era RPCs created stock reservations or audit rows.

## J. Schema-effect matrix

| Version | Original filename | Remote applied | Original found | Actual schema effects present | Data dependency | Conflict with Phase C migration | Risk | Recommended treatment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `20260718210000` | `create_order_from_draft_rpc.sql` | Yes | Yes | `create_order_from_draft(uuid)` present; EXECUTE grants present. Referenced `orders_order_number_seq` was not found. | No audit rows and no stock reservations found. | Function name differs from approved `create_order_from_checkout_draft`, so no direct name collision, but stale order-creation RPC remains active. | High | Do not restore. Replace with no-op historical tombstone only after approved cleanup plan; cleanup should drop/revoke old RPC. |
| `20260724000000` | `add_confirmation_fields.sql` | Yes | Yes | `orders.expires_at` present with default. | Yes, 23 orders have `expires_at`. | New Phase C migration inserts into `expires_at`; current schema presence is assumed by new SQL. | Medium-high | Preserve/decide on dev order rows first; cleanup requires explicit decision because data is populated. |
| `20260724010000` | `prepare_supplier_for_order_rpc.sql` | Yes | Yes | `prepare_supplier_for_order(uuid,text)` present. Later replaced by `20260725030000`. | No audit rows found. | No direct name collision with new Phase C migration, but stale supplier-prep flow remains active. | High | Do not restore. Cleanup should drop/revoke old RPC. |
| `20260725000000` | `add_order_expires_index.sql` | Yes | Yes | `idx_orders_expires_confirm_pending` present. | Tied to 23 orders with `expires_at`. | No direct conflict, but depends on unapproved expiry flow. | Medium | Cleanup should remove if expiry flow is removed. |
| `20260725020000` | `add_delivery_and_prepare_timestamps.sql` | Yes | Yes | Preparation/delivery timestamp columns and `delivery_person_id` present; `delivery_person` enum value present. | No timestamp/person values populated. | No direct conflict, but unapproved delivery scope remains in schema. | Medium-high | Cleanup should remove columns if safe; enum cleanup needs special care because PostgreSQL enum value removal is non-trivial. |
| `20260725030000` | `update_prepare_supplier_for_order_rpc.sql` | Yes | Yes | Current `prepare_supplier_for_order` function body updates `prepared_at`. | No audit rows found. | No direct name collision, but stale supplier-prep flow remains active. | High | Cleanup should drop/revoke old RPC. |

## K. Conflicts with the new Phase C migration

New migration reviewed:

- `supabase/migrations/20260718213000_create_order_from_checkout_draft_rpc.sql`

Statement classification:

- Add `orders.checkout_draft_id`: safe as written; column absent remotely.
- Add `orders.idempotency_key`: safe as written; column absent remotely.
- Add `orders_idempotency_key_not_blank`: safe as written after dropping same-named constraint if present.
- Create `orders_checkout_draft_unique_idx`, `orders_customer_idempotency_key_unique_idx`, `orders_checkout_draft_created_idx`: safe as written; target columns absent until this migration.
- Add `checkout_drafts.converted_order_id`, `checkout_drafts.converted_at`: safe as written; columns absent remotely.
- Replace `checkout_drafts_status_check` to include converted state: safe because current check allows `draft`, `review_pending`, and `abandoned`; observed drafts are currently `abandoned`.
- Create `public.order_number_sequence`: safe by name; neither `order_number_sequence` nor the old `orders_order_number_seq` was found.
- Create `generate_order_number()`: safe by name.
- Create `checkout_order_safe_row(uuid)`: safe by name.
- Create `create_order_from_checkout_draft(uuid,text)`: safe by name; differs from stale `create_order_from_draft(uuid)`.
- Grant execute on approved Phase C RPCs: safe as written.

No direct object-name conflict requiring immediate edits to the new Phase C migration was found. However, the migration cannot be dry-run or applied until the remote-only history mismatch is reconciled, and the stale old RPCs should not remain active longer than necessary.

## L. Primary reconciliation case

Primary case: CASE C - Applied schema contamination with development data dependency.

Reason:

- Remote history contains six missing versions.
- Their schema effects remain active.
- At least one unapproved field, `orders.expires_at`, is populated on 23 development order rows.

The dependency appears limited to development order rows and does not show stock/payment/delivery/commission/settlement side effects, but it is still a data dependency.

## M. Options evaluated

### OPTION 1 - Restore original migrations locally

- Prerequisites: none technical, but would reintroduce quarantined SQL.
- Risks: future clean environments would execute unapproved order creation, supplier preparation, delivery timestamp, and role-expansion SQL.
- Data impact: none immediately on current remote, but unsafe for future environments.
- Migration-history impact: would make CLI history line up but by legitimizing unapproved source.
- Future-environment impact: bad; polluted migrations would run.
- Reversibility: poor once committed and applied elsewhere.
- Recommendation: do not use.

### OPTION 2 - Add no-op historical tombstone migrations using the six versions

- Prerequisites: explicit approval; files must be no-op and clearly documented as historical reconciliation markers.
- Risks: tombstones alone make history align but do not clean active remote schema contamination.
- Data impact: none if true no-op.
- Migration-history impact: likely aligns local/remote version lists without restoring unapproved SQL. Supabase CLI migration listing compares versions, not SQL checksums, in the observed output.
- Future-environment impact: future clean environments would not execute unapproved SQL for these versions.
- Reversibility: moderate; files can be reviewed, but removing them later would recreate the mismatch.
- Recommendation: use only with, or after, an approved cleanup strategy. Do not create yet.

### OPTION 3 - Run Supabase migration repair

- Prerequisites: explicit approval and a precise history plan.
- Risks: can make Supabase attempt to reapply or skip migrations in unsafe ways while schema effects still exist.
- Data impact: history mutation only, but future apply behavior can become dangerous.
- Migration-history impact: mutates remote migration history.
- Future-environment impact: can diverge from source if not paired with reviewed files.
- Reversibility: risky.
- Recommendation: do not use as the primary strategy.

### OPTION 4 - Create an approved compensating cleanup migration

- Prerequisites: explicit approval, preservation decision for 23 dev orders, dry-run, boundary tests.
- Risks: dropping columns/functions/indexes can break any unrecognized dev workflow that still references them.
- Data impact: must handle `orders.expires_at` deliberately because populated data exists.
- Migration-history impact: does not by itself fix missing-version history; should be paired with tombstones.
- Future-environment impact: good if cleanup uses guarded drops; no-op on clean future environments.
- Reversibility: moderate if planned and backed by report evidence.
- Recommendation: required if this development project is preserved.

### OPTION 5 - Replace/rebuild the development Supabase project

- Prerequisites: explicit approval, acceptance that development QA state is disposable or reproducible, reconfiguration of Clerk/Supabase development integration if needed.
- Risks: setup effort and loss of current dev QA records.
- Data impact: discards current development state.
- Migration-history impact: starts clean from approved local migration chain.
- Future-environment impact: cleanest.
- Reversibility: new project could coexist until verified.
- Recommendation: fallback, or primary if preserving the 23 development orders is not valuable.

## N. Recommended primary strategy

Primary strategy if the current development project must be preserved:

1. Do not restore the original Claude-era migration SQL.
2. Decide whether the 23 development `orders` rows with `expires_at` are disposable, should be archived, or need a data-preserving transition.
3. Create reviewed no-op historical tombstone migrations for:
   - `20260718210000`
   - `20260724000000`
   - `20260724010000`
   - `20260725000000`
   - `20260725020000`
   - `20260725030000`
4. Create a forward compensating cleanup migration that removes only verified Claude-era artifacts from the development schema:
   - drop/revoke `create_order_from_draft(uuid)`
   - drop/revoke `prepare_supplier_for_order(uuid,text)`
   - drop `idx_orders_expires_confirm_pending`
   - handle `orders.expires_at` only after the data decision
   - handle preparation/delivery timestamp columns only after confirming no active approved flow uses them
   - handle `delivery_person` enum carefully; direct enum-value removal may require a type rebuild and should probably be deferred unless necessary
5. Dry-run the reconciliation chain only after explicit approval.
6. Apply to DEVELOPMENT only after dry-run and report review.
7. Rerun dry-run for Phase C Group 2 only after migration history and schema contamination are reconciled.

## O. Recommended fallback strategy

Fallback strategy:

Replace/rebuild the DEVELOPMENT Supabase project from the approved local migration chain if the current development QA data is disposable or easier to recreate than clean. This avoids delicate cleanup of contaminated schema history. This must be explicitly approved and must not touch production.

## P. Whether original Claude migrations should remain quarantined

Yes. The originals should remain in ignored quarantine and should not be restored as executable migrations.

## Q. Whether historical tombstones are recommended

Yes, but only as reviewed no-op historical reconciliation markers, not as copies of the original SQL, and not as the only fix while active schema contamination remains.

## R. Whether migration repair is recommended

No. Migration repair is not recommended as the primary strategy because it mutates remote history while stale schema objects still exist and could cause unsafe future apply behavior.

## S. Whether compensating cleanup is required

Yes, if the current DEVELOPMENT project is preserved. The remote schema still contains active unapproved functions, columns, index, grants, and enum expansion.

## T. Whether replacing the development project is recommended

Not as the primary path if preserving current QA state matters. It is the clean fallback and may become preferable if the 23 development order rows are disposable.

## U. Whether Phase C migration must be revised

No immediate revision is required based on current evidence. The new Phase C migration uses distinct names and guarded additions for the objects inspected. It remains blocked by migration-history reconciliation, not by a direct SQL object-name conflict.

## V. Exact ordered next steps

1. Review this report and decide whether the current DEVELOPMENT project state must be preserved.
2. If preserving the project, approve creation of no-op tombstone migrations plus a forward cleanup migration plan.
3. Decide how to treat the 23 development orders with `expires_at`.
4. Create and review the reconciliation migrations locally.
5. Run `npx supabase db push --dry-run` only after the reconciliation files exist and are approved.
6. Apply reconciliation to DEVELOPMENT only after dry-run is reviewed.
7. Rerun the Phase C Group 2 dry-run only after the migration-history mismatch is resolved.

## W. Commands run/results

Read-only repository and Supabase commands run:

- `git status --short` - showed existing tracked metadata/source modifications and untracked Phase C planning/Group 2 files; nothing staged.
- `git rev-parse HEAD` - `53a9daad399576d58dce54379db23f97ede9e30d`.
- `git branch --show-current` - `main`.
- `git diff --name-status`, `git diff --numstat`, `git diff --summary`, `git diff --check` - no patch/check errors were reported during precheck.
- `npx supabase --version` - `2.109.1`.
- `npx supabase projects list` - confirmed linked DEVELOPMENT project named `Risellar`.
- `npx supabase migration list --linked` - confirmed six remote-only versions and one local-only Phase C migration.
- Read-only `supabase_migrations.schema_migrations` query - confirmed remote names/statements for the six versions.
- Read-only catalog queries for functions, grants, columns, constraints, indexes, triggers, policies, enum values, sequences, and aggregate counts - results summarized above.
- Quarantine/file inspection commands - confirmed all six originals are present under ignored `.local-recovery`.

Commands not run:

- `npx supabase db push`
- `npx supabase db push --dry-run`
- `npx supabase migration repair`
- `npx supabase db reset --linked`
- Phase C RPC test script

## X. Automated repository verification

- `git diff --check` - passed with no whitespace/conflict-marker errors.
- `npm test` - passed; 30 test files, 158 tests.
- `npm run lint` - passed with `eslint . --max-warnings=0`.
- `npm run build` - passed with `next build`; 168 static pages generated.
- `npm run typecheck` - passed with `tsc --noEmit`.
- `npx tsc --noEmit` - passed.

## Y. Security/scope scan result

Preliminary scan result:

- `.env.local` ignored: yes.
- `.local-recovery` ignored: yes.
- `supabase/.temp` ignored: yes.
- `.next` ignored: yes.
- `.codex-dev-server.*.log` ignored: yes.
- No database credentials, connection strings, tokens, JWTs, cookies, or environment values were printed.
- No production project was accessed; linked project was confirmed as DEVELOPMENT `Risellar`.
- No database mutation occurred.
- No migration-history mutation occurred.
- No migration file was activated or restored.
- No RPC was executed.
- No Phase C migration was applied.
- No test fixtures were created.
- No application source was changed by this task.

Post-report scan result:

- Staged files: none.
- Broad filename-only scan flagged existing docs/tests/server-only helper files that contain safety terms such as service-role wording or simulated dev-only auth strings; no values were printed.
- Value-shaped secret scan matched existing dev-only SQL test harnesses that simulate auth/JWT context; the new reconciliation report had no value-shaped secret matches.
- Service-role references in `app/` or `components/`: none.

## Z. Files changed

- `docs/RISELLAR_CHECKOUT_PHASE_C_MIGRATION_HISTORY_RECONCILIATION_REPORT.md`

## AA. Current Git status

Observed after creating this report and running verification:

```text
 M app/supplier/orders/[id]/page.tsx
 M app/supplier/orders/page.tsx
 M next-env.d.ts
 M package-lock.json
 M package.json
 M tsconfig.json
?? docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_1_PLANNING_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_2_BACKEND_FOUNDATION_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_IMPLEMENTATION_GROUPS.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_MIGRATION_HISTORY_RECONCILIATION_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_CREATION_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_STATE_MACHINE.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_RISK_REGISTER.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_RPC_TEST_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_SECURITY_AND_RLS_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_STOCK_RESERVATION_DESIGN.md
?? scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql
?? supabase/migrations/20260718213000_create_order_from_checkout_draft_rpc.sql
```

## AB. Whether migration history is understood

Yes. The six remote-only versions were applied to DEVELOPMENT before recovery, then their local source files were quarantined and removed from active migrations during Recovery Phase 2.

## AC. Whether it is safe to change migration history

No, not yet. Migration history should not be modified until a reviewed tombstone/cleanup strategy is approved.

## AD. Whether it is safe to rerun dry-run

No. Rerunning dry-run would hit the same migration-history mismatch until reconciliation files or a different approved strategy are in place.

## AE. Exact recommended next prompt

Approve creating a safe migration-history reconciliation plan for the DEVELOPMENT project: no-op tombstone migrations for the six remote-only Claude-era versions plus a forward compensating cleanup migration plan, without running db push, migration repair, or dry-run yet.

## AF. Group R2 implementation update

Checkout Phase C Reconciliation Group R2 created local-only implementation files for the approved reconciliation design:

- Six exact-version reviewed no-op tombstone migrations were created in active `supabase/migrations/`.
- The tombstones are comments-only and restore none of the quarantined Claude-era SQL.
- Guarded cleanup migration `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql` was created.
- The cleanup migration revokes/drops exact stale RPC signatures only when present:
  - `public.create_order_from_draft(uuid)`
  - `public.prepare_supplier_for_order(uuid,text)`
- The cleanup migration drops `idx_orders_expires_confirm_pending` if present.
- The cleanup migration guards `orders.expires_at` and raises `CLAUDE_EXPIRES_AT_DATA_REQUIRES_BACKUP` if populated values exist.
- The cleanup migration guards unused preparation/delivery columns and raises if unexpected populated values exist.
- The `delivery_person` enum value remains untouched.
- The Phase C migration was reviewed and annotated to clarify it does not use `orders.expires_at`.

No migration was applied, no migration history was modified, no dry-run result is recorded in this section, and no RPC test was run by this report update.

## AG. Group R2B include-all dry-run update

Group R2B ran exactly:

```text
npx supabase db push --dry-run --include-all
```

against the confirmed DEVELOPMENT project named `Risellar`.

Result: passed. The dry-run showed only:

1. `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`
2. `20260718213000_create_order_from_checkout_draft_rpc.sql`

The six tombstone versions were not pending because the remote project already records those migration versions as applied. No unexpected migration appeared. No real db push, migration repair, remote history change, migration apply, or RPC test occurred.
