# Risellar Checkout Phase C Reconciliation Group R1 Report

## A. Executive summary

Group R1 produced an implementation-ready design for reconciling six remote-only Claude-era migrations and the 23 DEVELOPMENT order rows that carry `orders.expires_at`. No migrations, tombstones, cleanup files, schema changes, data changes, dry-runs, RPC tests, commits, or pushes were performed.

Recommended path:

1. Create six exact-version comment-only tombstones in Group R2.
2. Create a forward cleanup migration after the tombstones and before Phase C.
3. Archive aggregate evidence and back up DEVELOPMENT before removing `orders.expires_at`.
4. Revise the uncommitted Phase C migration so it does not write `orders.expires_at`.
5. Leave `delivery_person` enum value temporarily rather than doing risky enum type recreation.

## B. Baseline commit and branch

- Expected commit: `53a9daad399576d58dce54379db23f97ede9e30d`
- Observed commit: `53a9daad399576d58dce54379db23f97ede9e30d`
- Branch: `main`

## C. Six-migration structural map

| Version | Quarantined filename | Purpose | Functions | Columns | Indexes | Enum | Grants | Data updates | Active effects | Treatment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `20260718210000` | `20260718210000_create_order_from_draft_rpc.sql` | Unapproved order creation from draft | Created `create_order_from_draft(uuid)` | None directly | None | None | Execute to authenticated | Created data only when RPC executed | Function/grants present; no audit/stock evidence | Tombstone; cleanup drop/revoke |
| `20260724000000` | `20260724000000_add_confirmation_fields.sql` | Unapproved order confirmation expiry | None | Added `orders.expires_at` | None | None | None | Backfilled existing orders | Column/default present; 23 rows populated | Tombstone; archive aggregate evidence; remove column |
| `20260724010000` | `20260724010000_prepare_supplier_for_order_rpc.sql` | Unapproved supplier preparation | Created `prepare_supplier_for_order(uuid,text)` | Used `prepared_at` | None | None | Execute to authenticated | Only via RPC execution | Function present; no audit evidence | Tombstone; cleanup drop/revoke |
| `20260725000000` | `20260725000000_add_order_expires_index.sql` | Index for unapproved expiry workflow | None | None | `idx_orders_expires_confirm_pending` | None | None | None | Index present | Tombstone; cleanup drop index |
| `20260725020000` | `20260725020000_add_delivery_and_prepare_timestamps.sql` | Unapproved prep/delivery schema | None | Added prep/delivery timestamps and `delivery_person_id` | None | Added `delivery_person` | None | None | Columns and enum value present; no row usage | Tombstone; cleanup drop columns; leave enum temporarily |
| `20260725030000` | `20260725030000_update_prepare_supplier_for_order_rpc.sql` | Replaced unapproved supplier-prep RPC | Replaced `prepare_supplier_for_order(uuid,text)` | Used `prepared_at` | None | None | Execute to authenticated | Only via RPC execution | Current function present; no audit evidence | Tombstone; cleanup drop/revoke |

No triggers or Claude-era policies were found.

## D. Tombstone design per version

The six tombstones should be comment-only SQL files:

- `20260718210000_reviewed_tombstone_create_order_from_draft.sql`
- `20260724000000_reviewed_tombstone_order_confirmation_expiry.sql`
- `20260724010000_reviewed_tombstone_supplier_prepare_rpc.sql`
- `20260725000000_reviewed_tombstone_order_expiry_index.sql`
- `20260725020000_reviewed_tombstone_delivery_prepare_fields.sql`
- `20260725030000_reviewed_tombstone_update_supplier_prepare_rpc.sql`

Each should state the original filename, explain the original SQL is quarantined/unapproved, perform no DDL/DML/grants/RLS/RPC/data mutation, and point to the forward cleanup migration.

## E. Whether pure no-op tombstones are supported

Supported as a design. Supabase CLI local/remote migration listing is version-based in observed output, and comment-only SQL is valid SQL. Final operational confirmation must happen in Group R2 with an explicitly approved dry-run after the tombstones and cleanup migration are created.

## F. Approved target schema

Remove:

- `create_order_from_draft(uuid)`
- `prepare_supplier_for_order(uuid,text)`
- grants on those stale RPCs
- `idx_orders_expires_confirm_pending`
- `orders.expires_at` after evidence/backup and Phase C revision
- `orders.prepared_at`, `ready_at`, `dispatched_at`, `out_for_delivery_at`, `delivered_at`, `delivery_person_id`

Keep:

- approved checkout draft/order/stock baseline tables
- `stock_reservations.expires_at`
- `delivery_quotes.expires_at`
- approved Phase C `create_order_from_checkout_draft(uuid,text)` after its migration is applied

Leave temporarily:

- `user_role.delivery_person`

## G. 23-order aggregate findings

- 23 orders have `expires_at`.
- All 23 are `placed_pending_confirmation`.
- All 23 are confirmation `pending`.
- All 23 are expired.
- 0 have confirmation, preparation, delivery, or delivery-person fields populated.
- 0 link to stock reservations, delivery quotes, commissions, or settlements.
- 4 link to order items.

Classification: useful development QA rows needing aggregate preservation, not production-looking data.

## H. Selected expires_at strategy

Selected strategy: archive aggregate evidence, back up DEVELOPMENT outside Git, revise Phase C not to write `orders.expires_at`, then remove the old column in cleanup.

## I. Stale-function cleanup design

Future cleanup migration should:

- Revoke all on `create_order_from_draft(uuid)` from public, then drop exact signature if present.
- Revoke all on `prepare_supplier_for_order(uuid,text)` from public, then drop exact signature if present.
- Include precondition checks for exact signatures and unexpected dependencies.

## J. Column/index cleanup design

Future cleanup migration should:

- Drop `idx_orders_expires_confirm_pending` if present.
- Drop `orders.expires_at` after data strategy approval and Phase C revision.
- Drop prep/delivery columns only if aggregate counts remain zero.
- Preserve unrelated order/order-item/stock/draft/product/supplier/reseller/customer/audit data.

## K. Enum cleanup decision

Decision: keep `delivery_person` temporarily.

Reason:

- The enum type is `public.user_role`.
- Current values include `customer`, `reseller`, `supplier_owner`, `supplier_inventory_manager`, `support_staff`, `finance_staff`, `admin`, `super_admin`, and `delivery_person`.
- Enum-backed columns are `profiles.primary_role`, `admin_staff.admin_role`, `audit_logs.actor_role`, and `role_onboarding_requests.requested_role`.
- Aggregate usage of `delivery_person` is zero across those columns.
- Removing a PostgreSQL enum value safely requires type recreation and table rewrites; this is too risky for this cleanup group.

## L. Proposed cleanup migration ordering

Recommended order:

1. Six tombstones.
2. `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`.
3. Revised `20260718213000_create_order_from_checkout_draft_rpc.sql`.

## M. Existing-development behavior

The six tombstones are already recorded remotely and will not execute. The cleanup migration runs once, removes contaminated objects, and Phase C then applies approved order creation.

## N. Clean-environment behavior

The tombstones execute as no-ops. The cleanup migration guarded drops no-op because Claude-era objects are absent. Phase C creates the approved schema.

## O. CI/local migration-chain behavior

Local migration-chain verification should apply tombstones, no-op cleanup, and Phase C without ever creating Claude-era RPCs.

## P. Preconditions and assertions

Pre-apply:

- Confirm DEVELOPMENT `Risellar`.
- Confirm no production connection.
- Confirm six originals remain quarantined.
- Confirm aggregate counts and enum usage.
- Confirm backup exists outside Git.

Migration assertions:

- Exact stale function signatures.
- Zero preparation/delivery field population.
- Zero `delivery_person` row usage.
- No stock/payment/delivery/settlement/commission dependencies.

Post-apply:

- Stale functions absent.
- Stale index absent.
- Columns removed or preserved according to approved plan.
- No unintended rows created.

## Q. Backup and rollback requirements

Required before future apply:

- Git checkpoint commit.
- Development database backup/export outside Git.
- Schema-only snapshot.
- Aggregate row-count snapshot.
- Migration-history export.
- Affected-object inventory.

Rollback:

- Restore development backup if cleanup has unexpected effects.
- Do not recreate unapproved Claude-era functions as rollback source.

## R. Preserve-versus-rebuild decision

Recommendation: preserve current DEVELOPMENT as primary.

Why:

- Current QA profiles/products/listings/addresses/drafts are useful.
- Contamination appears bounded.
- Data dependency is limited and aggregate-preservable.

Fallback:

- Rebuild DEVELOPMENT if cleanup dry-run reveals broader contamination or if QA state is declared disposable.

## S. Risks

- Phase C migration currently references `orders.expires_at`; must be revised before cleanup/apply if the column is removed.
- Enum value cleanup is deferred, so DEVELOPMENT may retain one unused enum value longer than clean environments.
- Migration-history tombstone compatibility must be confirmed with future dry-run.
- Any hidden application reference to stale columns/functions would surface during tests/build or post-cleanup QA.

## T. Documents created

- `docs/RISELLAR_CHECKOUT_PHASE_C_TOMBSTONE_MIGRATION_DESIGN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_COMPENSATING_CLEANUP_DESIGN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_DEV_ORDER_DATA_PRESERVATION_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_MIGRATION_CONVERGENCE_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_RECONCILIATION_GROUP_R1_REPORT.md`

## U. Commands run/results

- `git status --short` - showed known modified metadata/source markers and untracked Phase C planning/Group 2/R1 files; nothing staged.
- `git rev-parse HEAD` - `53a9daad399576d58dce54379db23f97ede9e30d`.
- `git branch --show-current` - `main`.
- `git diff --name-status`, `git diff --numstat`, `git diff --summary` - no patch output during precheck.
- `git diff --check` - passed before and after document creation.
- `npx supabase migration list --help` and `npx supabase db --help` - read-only CLI help only.
- Read-only aggregate Supabase queries - counted order expiry/dependency data and enum usage without exposing row details.
- `npm test` - passed; 30 test files and 158 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- `npx tsc --noEmit` - passed.

Commands intentionally not run:

- `npx supabase db push`
- `npx supabase db push --dry-run`
- `npx supabase migration repair`
- Phase C RPC test script
- Any Claude-era RPC

## V. Security/scope scan result

- `.env.local` ignored: yes.
- `.local-recovery` ignored: yes.
- `supabase/.temp` ignored: yes.
- `.next` ignored: yes.
- `.codex-dev-server.*.log` ignored: yes.
- Staged files: none.
- New R1 documents had no value-shaped secret matches.
- Service-role references in `app/` or `components/`: none.
- No private development row details were documented.
- No connection strings, tokens, cookies, JWTs, database passwords, environment values, or secrets were printed.
- No migration file, tombstone file, or cleanup migration file was created.
- No database mutation occurred.
- No migration-history mutation occurred.
- No RPC was executed.
- No application source was changed by this task.
- No Phase C migration was applied.
- No original Claude migration was restored.
- No production project was accessed.

## W. Files changed

- `docs/RISELLAR_CHECKOUT_PHASE_C_TOMBSTONE_MIGRATION_DESIGN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_COMPENSATING_CLEANUP_DESIGN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_DEV_ORDER_DATA_PRESERVATION_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_MIGRATION_CONVERGENCE_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_RECONCILIATION_GROUP_R1_REPORT.md`

## X. Current Git status

```text
 M app/supplier/orders/[id]/page.tsx
 M app/supplier/orders/page.tsx
 M next-env.d.ts
 M package-lock.json
 M package.json
 M tsconfig.json
?? docs/RISELLAR_CHECKOUT_PHASE_C_COMPENSATING_CLEANUP_DESIGN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_DEV_ORDER_DATA_PRESERVATION_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_1_PLANNING_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_2_BACKEND_FOUNDATION_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_IMPLEMENTATION_GROUPS.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_MIGRATION_CONVERGENCE_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_MIGRATION_HISTORY_RECONCILIATION_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_CREATION_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_STATE_MACHINE.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_RECONCILIATION_GROUP_R1_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_RISK_REGISTER.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_RPC_TEST_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_SECURITY_AND_RLS_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_STOCK_RESERVATION_DESIGN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_TOMBSTONE_MIGRATION_DESIGN.md
?? scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql
?? supabase/migrations/20260718213000_create_order_from_checkout_draft_rpc.sql
```

## Y. Whether reconciliation design is complete

Yes, subject to final verification.

## Z. Whether it is safe to begin implementation Group R2

Yes, if verification passes and the user explicitly approves Group R2. R2 should create tombstones and cleanup migration only; it should not apply them without later approval.

## AA. Exact recommended next prompt

Implement Checkout Phase C Reconciliation Group R2 by creating the six no-op tombstone migrations and the forward cleanup migration, revising the uncommitted Phase C migration to avoid `orders.expires_at`, then run validation and dry-run only if explicitly approved in that prompt.

## AB. Group R2 implementation update

Group R2 implemented the R1 design locally:

- Six comment-only tombstones were created with exact remote-only versions.
- A guarded cleanup migration was created at `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`.
- The cleanup migration leaves `delivery_person` enum value untouched.
- The cleanup migration intentionally blocks silent removal of populated `orders.expires_at` data by raising `CLAUDE_EXPIRES_AT_DATA_REQUIRES_BACKUP`.
- The Phase C migration was reviewed and annotated so `stock_reservations.expires_at` is the only reservation-expiry field.
- The Phase C boundary test script was annotated with the same expiry distinction.

No original Claude SQL was restored.
