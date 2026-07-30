# Risellar Checkout Phase C Tombstone Migration Design

## Summary

This design defines six future no-op historical tombstone migrations for the six remote-only Claude-era migration versions recorded in the DEVELOPMENT Supabase project. This document is planning-only. It does not create migration files and does not restore the original SQL.

The tombstones exist to make local source migration history line up with the already-applied remote versions without reintroducing unapproved checkout/order/delivery behavior into future environments.

## Compatibility Basis

Observed Supabase CLI behavior:

- `supabase migration list --linked` reports local and remote migration rows by migration version.
- Local versions are derived from migration filenames in `supabase/migrations`.
- Remote versions are stored in `supabase_migrations.schema_migrations`.
- The installed CLI help describes `migration list` as listing local and remote migrations; it does not expose checksum enforcement in the listing output.

Design conclusion:

- Pure no-op SQL files with exact matching timestamp versions are suitable as a reconciliation design.
- A comment-only SQL file is syntactically valid SQL and has no DDL/DML/RPC side effects.
- Future Group R2 must still verify this with an approved `npx supabase db push --dry-run`; this task did not run dry-run.

The exact version prefix is required. The suffix can be a reviewed tombstone name; it does not need to preserve the original unapproved filename.

## Tombstone Rules

Every tombstone should:

- Use the exact remote version timestamp.
- Contain comments only.
- Recreate no Claude-era function, table, column, index, enum, trigger, policy, grant, or data update.
- Mutate no schema or data.
- Be safe in a clean future environment.
- Be safe in the existing contaminated DEVELOPMENT project because it will already be marked applied remotely.
- Point readers to the approved forward cleanup migration.

## Proposed Files And Content

### 20260718210000

Future filename:

`supabase/migrations/20260718210000_reviewed_tombstone_create_order_from_draft.sql`

Intended content:

```sql
-- Reviewed historical tombstone for remote-only DEVELOPMENT migration 20260718210000.
-- Original quarantined file: 20260718210000_create_order_from_draft_rpc.sql.
-- The original SQL was unapproved Claude-era checkout/order scope and must not be restored.
-- This tombstone intentionally performs no DDL, DML, grants, RLS changes, RPC creation, or data mutation.
-- Approved schema reconciliation is handled by a later forward cleanup migration.
```

Original purpose:

- Created `public.create_order_from_draft(uuid)`.
- Created order, order item, stock reservation, inventory movement, and audit side effects.
- Granted execute to `authenticated`.

Clean-environment behavior:

- No-op; no order creation RPC appears.

Existing-development behavior:

- Not executed because remote history already records the version.

### 20260724000000

Future filename:

`supabase/migrations/20260724000000_reviewed_tombstone_order_confirmation_expiry.sql`

Intended content:

```sql
-- Reviewed historical tombstone for remote-only DEVELOPMENT migration 20260724000000.
-- Original quarantined file: 20260724000000_add_confirmation_fields.sql.
-- The original SQL added and backfilled an unapproved orders.expires_at confirmation-expiry field.
-- This tombstone intentionally performs no DDL, DML, grants, RLS changes, or data mutation.
-- Approved data handling for existing development orders is handled by a later forward cleanup migration.
```

Original purpose:

- Added `orders.expires_at`.
- Backfilled existing orders with `created_at + interval '1 hour'`.
- Set a default expiry.

Clean-environment behavior:

- No-op; does not add `orders.expires_at`.

Existing-development behavior:

- Not executed remotely; the already-present column is addressed by cleanup design.

### 20260724010000

Future filename:

`supabase/migrations/20260724010000_reviewed_tombstone_supplier_prepare_rpc.sql`

Intended content:

```sql
-- Reviewed historical tombstone for remote-only DEVELOPMENT migration 20260724010000.
-- Original quarantined file: 20260724010000_prepare_supplier_for_order_rpc.sql.
-- The original SQL created unapproved supplier order-preparation behavior.
-- This tombstone intentionally performs no DDL, DML, grants, RLS changes, RPC creation, or data mutation.
-- Stale remote RPC cleanup is handled by a later forward cleanup migration.
```

Original purpose:

- Created `public.prepare_supplier_for_order(uuid,text)`.
- Mutated order status/preparation state.
- Wrote audit events.
- Granted execute to `authenticated`.

Clean-environment behavior:

- No-op; no supplier preparation RPC appears.

Existing-development behavior:

- Not executed remotely; stale RPC is addressed by cleanup design.

### 20260725000000

Future filename:

`supabase/migrations/20260725000000_reviewed_tombstone_order_expiry_index.sql`

Intended content:

```sql
-- Reviewed historical tombstone for remote-only DEVELOPMENT migration 20260725000000.
-- Original quarantined file: 20260725000000_add_order_expires_index.sql.
-- The original SQL created an index for the unapproved order confirmation-expiry workflow.
-- This tombstone intentionally performs no DDL, DML, index creation, grants, RLS changes, or data mutation.
-- Obsolete remote index cleanup is handled by a later forward cleanup migration.
```

Original purpose:

- Created `idx_orders_expires_confirm_pending`.

Clean-environment behavior:

- No-op; index does not appear.

Existing-development behavior:

- Not executed remotely; stale index is addressed by cleanup design.

### 20260725020000

Future filename:

`supabase/migrations/20260725020000_reviewed_tombstone_delivery_prepare_fields.sql`

Intended content:

```sql
-- Reviewed historical tombstone for remote-only DEVELOPMENT migration 20260725020000.
-- Original quarantined file: 20260725020000_add_delivery_and_prepare_timestamps.sql.
-- The original SQL added unapproved preparation/delivery columns and a delivery_person role value.
-- This tombstone intentionally performs no DDL, DML, enum changes, grants, RLS changes, or data mutation.
-- Remote schema cleanup and enum strategy are handled by a later forward cleanup migration/design.
```

Original purpose:

- Added `orders.prepared_at`, `ready_at`, `dispatched_at`, `out_for_delivery_at`, `delivered_at`, and `delivery_person_id`.
- Added enum value `delivery_person` to `public.user_role`.

Clean-environment behavior:

- No-op; no delivery/preparation schema appears.

Existing-development behavior:

- Not executed remotely; stale columns and enum value are addressed by cleanup design.

### 20260725030000

Future filename:

`supabase/migrations/20260725030000_reviewed_tombstone_update_supplier_prepare_rpc.sql`

Intended content:

```sql
-- Reviewed historical tombstone for remote-only DEVELOPMENT migration 20260725030000.
-- Original quarantined file: 20260725030000_update_prepare_supplier_for_order_rpc.sql.
-- The original SQL replaced unapproved supplier order-preparation behavior.
-- This tombstone intentionally performs no DDL, DML, grants, RLS changes, RPC replacement, or data mutation.
-- Stale remote RPC cleanup is handled by a later forward cleanup migration.
```

Original purpose:

- Replaced `public.prepare_supplier_for_order(uuid,text)`.
- Updated `orders.prepared_at`.
- Wrote audit events.
- Granted execute to `authenticated`.

Clean-environment behavior:

- No-op; no supplier preparation RPC appears.

Existing-development behavior:

- Not executed remotely; stale RPC is addressed by cleanup design.

## Safety Decision

Pure no-op tombstones are the recommended design, provided Group R2 confirms with dry-run before any apply. They prevent future clean environments from executing unapproved Claude-era SQL while allowing the existing DEVELOPMENT migration-history versions to line up by exact timestamp.
