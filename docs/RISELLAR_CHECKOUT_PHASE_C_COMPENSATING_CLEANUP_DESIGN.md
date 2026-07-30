# Risellar Checkout Phase C Compensating Cleanup Design

## Summary

This design defines the future forward cleanup migration needed after six no-op tombstones reconcile migration history. It is planning-only. No migration file was created and no SQL was executed.

Recommended future migration filename:

`supabase/migrations/20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`

The timestamp should be after the six historical tombstones and before `20260718213000_create_order_from_checkout_draft_rpc.sql`.

## Approved Target Schema

### Keep As Approved

- Approved Phase B checkout draft schema and RPCs.
- Approved audited foundation order/order-item/stock-reservation base tables.
- Existing checkout/order status fields that are part of the approved foundation.
- `stock_reservations.expires_at` and `delivery_quotes.expires_at`, because those are baseline-approved fields unrelated to `orders.expires_at`.
- Future Phase C approved RPC `public.create_order_from_checkout_draft(uuid,text)`.
- Future Phase C approved helpers `generate_order_number()` and `checkout_order_safe_row(uuid)`.

### Remove

- `public.create_order_from_draft(uuid)`.
- `public.prepare_supplier_for_order(uuid,text)`.
- Execute grants on those stale RPCs.
- `idx_orders_expires_confirm_pending`.
- `orders.prepared_at`.
- `orders.ready_at`.
- `orders.dispatched_at`.
- `orders.out_for_delivery_at`.
- `orders.delivered_at`.
- `orders.delivery_person_id`.

### Migrate Then Remove

- `orders.expires_at`, because 23 development rows have values populated.

### Leave Temporarily

- `public.user_role` enum value `delivery_person`, because PostgreSQL enum-value removal requires risky type recreation. Current aggregate counts show zero rows using it.

### Unknown

- None requiring immediate stop. Cleanup migration should still include precondition checks and fail on unexpected dependency counts.

## Proposed Statement Outline

The future cleanup migration should use guarded statements and precondition checks. The outlines below are not executable migration files in this task.

### 1. Precondition block for stale order RPC

Prerequisite check:

- Function `public.create_order_from_draft(uuid)` exists in contaminated DEVELOPMENT or is absent in clean environments.
- No approved local source references it.
- Audit count for `create_order_from_draft` remains zero or is explicitly reviewed.

Statement outline:

```sql
-- in a DO block: verify if function exists, signature is exactly uuid, and no unexpected dependencies are present
revoke all on function public.create_order_from_draft(uuid) from public;
drop function if exists public.create_order_from_draft(uuid);
```

Data impact:

- None.

Dependency impact:

- Removes stale order creation entry point.

Rollback strategy:

- Do not restore original function. If rollback is required, revert the cleanup migration in DEVELOPMENT backup/restore only.

Clean-environment behavior:

- `drop function if exists` is no-op.

Contaminated-development behavior:

- Revokes and drops the stale function.

### 2. Precondition block for stale supplier-prep RPC

Prerequisite check:

- Function `public.prepare_supplier_for_order(uuid,text)` exists or is absent.
- `orders.prepared_at` and supplier-prep audit counts remain unpopulated or reviewed.

Statement outline:

```sql
revoke all on function public.prepare_supplier_for_order(uuid, text) from public;
drop function if exists public.prepare_supplier_for_order(uuid, text);
```

Data impact:

- None if aggregate counts remain unchanged.

Dependency impact:

- Removes stale supplier-preparation entry point.

Rollback strategy:

- Prefer restore from development backup over recreating unapproved function.

Clean-environment behavior:

- No-op if absent.

Contaminated-development behavior:

- Revokes and drops stale function.

### 3. Drop obsolete index

Prerequisite check:

- Index name is exactly `idx_orders_expires_confirm_pending`.

Statement outline:

```sql
drop index if exists public.idx_orders_expires_confirm_pending;
```

Data impact:

- None.

Dependency impact:

- Removes index tied to unapproved order-confirmation expiry workflow.

Rollback strategy:

- Recreate only if the approved schema later defines order expiry semantics.

Clean-environment behavior:

- No-op.

Contaminated-development behavior:

- Drops stale index.

### 4. Preserve 23-order expiry evidence before column removal

Prerequisite check:

- Aggregate count of `orders.expires_at is not null` is the expected reviewed count or the migration stops.
- No future `expires_at` values exist.
- No confirmed/prepared/delivery fields are populated.

Statement outline:

```sql
-- optional approved archive table, or audit/comment-only evidence in docs
-- preferred R1 strategy: do not create a data archive table unless the team wants persistent DB evidence.
-- if preserving in DB: create a narrow reconciliation evidence table with aggregate counts only, not private row data.
```

Data impact:

- Depends on selected `expires_at` strategy; see preservation plan.

Dependency impact:

- Avoids silent loss of evidence.

Rollback strategy:

- Use pre-apply backup and aggregate snapshots.

Clean-environment behavior:

- No-op or empty evidence row if implemented.

Contaminated-development behavior:

- Preserves reviewed aggregate evidence before cleanup.

### 5. Drop obsolete order expiry column

Prerequisite check:

- Selected strategy is to remove `orders.expires_at`.
- No active approved Phase C migration depends on `orders.expires_at`.
- New Phase C migration must be adjusted before implementation if it still inserts into `orders.expires_at`.

Statement outline:

```sql
alter table public.orders drop column if exists expires_at;
```

Data impact:

- Removes 23 expired, unapproved dev-only values.

Dependency impact:

- Requires Phase C Group 2 migration update to stop writing `orders.expires_at`.

Rollback strategy:

- Restore from development backup if needed.

Clean-environment behavior:

- No-op.

Contaminated-development behavior:

- Removes unapproved column after evidence is recorded.

### 6. Drop obsolete preparation/delivery columns

Prerequisite check:

- All affected columns have zero populated rows.
- No active approved app/source references these columns.

Statement outline:

```sql
alter table public.orders
  drop column if exists prepared_at,
  drop column if exists ready_at,
  drop column if exists dispatched_at,
  drop column if exists out_for_delivery_at,
  drop column if exists delivered_at,
  drop column if exists delivery_person_id;
```

Data impact:

- None expected; aggregate counts are zero.

Dependency impact:

- Removes unapproved delivery/preparation schema.

Rollback strategy:

- Restore from backup; do not recreate unless future approved delivery phase defines these fields.

Clean-environment behavior:

- No-op.

Contaminated-development behavior:

- Drops unapproved columns.

### 7. Enum handling

Prerequisite check:

- `delivery_person` has zero rows across `profiles.primary_role`, `admin_staff.admin_role`, `audit_logs.actor_role`, and `role_onboarding_requests.requested_role`.

Statement outline:

```sql
-- no enum mutation in R2 cleanup
-- leave public.user_role value 'delivery_person' temporarily
```

Data impact:

- None.

Dependency impact:

- Avoids risky PostgreSQL enum type recreation.

Rollback strategy:

- Not needed because no mutation.

Clean-environment behavior:

- On clean environments, tombstones do not add `delivery_person`; the cleanup migration does not add it either.

Contaminated-development behavior:

- Leaves a harmless unused enum value temporarily, documented for a later enum-normalization group or project rebuild.

## Ordering Decision

Recommended order:

1. Six no-op tombstones using exact remote versions.
2. Cleanup migration `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`.
3. Revised approved Phase C migration `20260718213000_create_order_from_checkout_draft_rpc.sql`.

Rationale:

- Tombstones fix version mismatch without running Claude SQL.
- Cleanup removes stale remote entry points before approved order creation is introduced.
- Phase C then creates the approved order creation boundary from a cleaner schema.

## Required Phase C Migration Adjustment

If cleanup removes `orders.expires_at`, the existing uncommitted Phase C Group 2 migration must be revised before implementation because it currently inserts into `orders.expires_at`.

Approved replacement:

- Use `stock_reservations.expires_at` for reservation expiry.
- Do not add or write `orders.expires_at` unless a later approved order-expiry design defines it.

## Preconditions And Assertions

Inside migration SQL:

- Assert stale function signatures before dropping when present.
- Assert prep/delivery columns are either absent or have zero populated rows.
- Assert no stock reservations depend on stale order flow.
- Assert no delivery quotes, commissions, settlements, or payment tables/rows create dependency.

Pre-apply read-only script:

- Re-run aggregate counts for the 23 orders.
- Re-run enum usage counts.
- Re-run function/grant inventory.
- Confirm linked project is DEVELOPMENT `Risellar`.

Post-apply boundary test:

- Confirm stale functions are absent.
- Confirm stale index is absent.
- Confirm dropped columns are absent or preserved exactly as planned.
- Confirm approved Phase C dry-run/apply sees only approved pending migrations.

Documentation only:

- Preserve aggregate evidence of the 23 rows.
- Document why enum value remains temporarily.

## Backup And Rollback Requirements

Before future apply:

- Git checkpoint commit.
- Development database backup/export handled outside Git.
- Schema-only snapshot.
- Aggregate count snapshot.
- Migration-history export.
- Affected-object inventory.
- Rollback plan: restore development backup if cleanup has unintended effects.

No rollback migration should recreate unapproved Claude-era RPC behavior.
