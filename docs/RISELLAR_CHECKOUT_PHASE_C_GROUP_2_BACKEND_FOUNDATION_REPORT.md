# Risellar Checkout Phase C Group 2 Backend Foundation Report

## A. Executive Summary

Created the forward-only backend foundation for converting an eligible checkout draft into one Pay on Delivery order with one order item and one atomic stock reservation. This task also created a development-only SQL boundary test script.

This Group C2 task did not apply the migration, did not run a real Supabase db push, did not run the new RPC boundary test, did not enable checkout confirmation UI, and did not connect payment, delivery, supplier preparation, commission release, settlement completion, withdrawal, or refund flows.

## B. Baseline Commit

Expected baseline:

- `53a9daad399576d58dce54379db23f97ede9e30d`

Precheck confirmed the repository was on branch `main` at that commit before Group C2 edits began.

## C. Existing Schema Reused

The migration reuses:

- `public.orders`
- `public.order_items`
- `public.stock_reservations`
- `public.product_variants`
- `public.inventory_movements`
- `public.checkout_drafts`
- `public.customer_delivery_addresses`
- `public.reseller_products`
- `public.products`
- `public.suppliers`
- `public.create_audit_log_entry`
- `public.checkout_draft_current_customer_context`

No existing table was recreated.

## D. Migration Created

- `supabase/migrations/20260718213000_create_order_from_checkout_draft_rpc.sql`

## E. Schema Extensions Added

Small forward-only extensions:

- `orders.checkout_draft_id uuid`
- `orders.idempotency_key text`
- `checkout_drafts.converted_order_id uuid`
- `checkout_drafts.converted_at timestamptz`
- checkout draft status check extended to include `converted`
- order/draft/idempotency indexes
- `public.order_number_sequence`

No payment provider, delivery provider, supplier preparation, commission release, settlement completion, withdrawal, or refund columns were added.

## F. Idempotency Constraints

Implemented:

- unique partial index on `orders.checkout_draft_id where checkout_draft_id is not null`
- unique partial index on `(orders.customer_id, orders.idempotency_key) where idempotency_key is not null`

The RPC checks for an existing order for the draft before creating a new one. Duplicate retries return the existing order safely and do not reserve stock twice.

## G. RPC Contract

Created:

```text
public.create_order_from_checkout_draft(
  p_checkout_draft_id uuid,
  p_idempotency_key text default null
)
```

The RPC accepts only the draft id and optional idempotency key. It does not accept customer id, address id, product id, variant id, listing id, supplier id, reseller id, price, base price, margins, quantity, status, payment state, or stock values from the caller.

## H. Draft Eligibility Rules

The RPC requires:

- authenticated active customer profile
- owned checkout draft
- `draft_status = 'review_pending'`
- attached delivery address id
- delivery address still belongs to the signed-in customer
- non-empty delivery address snapshot

`draft`, `abandoned`, unknown, and converted-without-existing-order states are blocked.

## R4B cleanup dependency-scan compatibility note

Before applying this Phase C migration to DEVELOPMENT, R4B corrected the preceding cleanup migration's routine dependency scan so `pg_get_functiondef` is only evaluated for ordinary functions/procedures in non-system namespaces. This prevents PostgreSQL aggregate entries from blocking the cleanup migration before Phase C can apply.

The Phase C migration itself remains unchanged. The dry-run still shows the guarded cleanup migration first and this Phase C migration second.

## I. Stock-Locking/Reservation Behavior

The RPC:

- resolves variant from trusted draft/listing data
- requires listing and draft variant ids to match
- locks the `product_variants` row with `FOR UPDATE`
- requires `variant_status in ('active', 'low_stock')`
- calculates available stock as total minus reserved minus sold
- raises `INSUFFICIENT_STOCK` if unavailable
- increments `reserved_stock_quantity`
- creates a `stock_reservations` row with one-hour expiry
- writes an `inventory_movements` row with `reservation_created`

## J. Snapshot Calculations

The order item stores server-calculated snapshots:

- supplier base price from `products.base_price_amount`
- platform margin from `products.platform_margin_amount`
- reseller margin from `reseller_products.reseller_margin_amount`
- reseller cost from `products.reseller_cost_amount`
- customer product price from `reseller_products.customer_product_price_amount`
- line total from customer price times draft quantity
- settlement due from platform margin plus reseller margin times quantity
- commission from reseller margin times quantity

The safe RPC return omits supplier base price, platform margin, reseller margin, settlement due, and commission.

## K. Initial Order/Payment State

The RPC creates orders with:

- `order_status = 'placed_pending_confirmation'`
- `payment_method = 'pay_on_delivery'`
- `payment_collection_status = 'not_collected'`
- `delivery_status = 'estimate_selected'`
- `customer_confirmation_status = 'pending'`
- `delivery_quote_status = 'pending'`

No payment is collected at order creation.

## L. Audit Events

The RPC writes:

- `order_created`
- `order_item_created`
- `stock_reserved`
- `checkout_draft_converted`
- optional `duplicate_confirmation_reused` on idempotent retry

Audit metadata uses ids and safe state metadata only.

## M. RLS/Direct-Write Protections

No broad RLS weakening was added. Direct writes to order items, stock reservations, inventory movements, payment, delivery, commission, settlement, and withdrawal flows remain outside the browser path.

The new RPC is `SECURITY DEFINER`, sets `search_path = public`, performs explicit auth/ownership/status checks, revokes public execution, and grants execution to `authenticated`.

## N. Development-Only Test Script

Created:

- `scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql`

The script is development-only, uses fake fixture data inside `begin`/`rollback`, grants only temporary table permissions to simulated roles, and was not run in Group C2.

## O. Concurrency Test Plan

The script documents a separate Group C3 concurrency procedure using two database sessions:

- same variant
- two customers/drafts
- available stock set to 1
- simultaneous RPC calls
- exactly one success
- exactly one `INSUFFICIENT_STOCK` failure
- exactly one order/reservation
- reserved stock remains 1
- cleanup through rollback/dev-only fixtures

True concurrency was not executed in Group C2.

## P. Dry-Run Result

`npx supabase db push --dry-run` failed before previewing the new migration.

Exact Supabase CLI output:

```text
DRY RUN: migrations will *not* be pushed to the database.
Connecting to remote database...
Remote migration versions not found in local migrations directory.

Make sure your local git repo is up-to-date. If the error persists, try repairing the migration history table:
supabase migration repair --status reverted 20260718210000 20260724000000 20260724010000 20260725000000 20260725020000 20260725030000

And update local migrations to match remote database:
supabase db pull
```

Classification: migration history mismatch / remote has migration versions that are not present in the local migrations directory. This is not a SQL/RPC/RLS implementation error from the new Group C2 migration because the dry-run did not reach migration preview or SQL execution.

## P2. Reconciliation Group R2 Update

Checkout Phase C Reconciliation Group R2 implemented local migration-history reconciliation files but did not apply them:

- six reviewed no-op tombstones for the remote-only Claude-era versions
- guarded forward cleanup migration `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`
- explicit Phase C migration comment clarifying that reservation expiry uses `stock_reservations.expires_at`, not `orders.expires_at`

The Phase C order-creation migration was reviewed for `orders.expires_at` dependency. No executable dependency was found. The only expiry write remains the approved stock reservation expiry on `public.stock_reservations.expires_at`.

The development-only RPC test script was also annotated to clarify that its expiry assertion targets `stock_reservations.expires_at`, not `orders.expires_at`.

The guarded cleanup migration intentionally raises `CLAUDE_EXPIRES_AT_DATA_REQUIRES_BACKUP` if applied to a database where `orders.expires_at` exists with populated rows. This protects the 23 known DEVELOPMENT order rows until backup/data-handling approval occurs.

## P3. Reconciliation Group R2B dry-run update

`npx supabase db push --dry-run --include-all` was run against the confirmed DEVELOPMENT project named `Risellar`.

Result: passed. The dry-run did not apply migrations and showed exactly these pending migrations in order:

1. `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`
2. `20260718213000_create_order_from_checkout_draft_rpc.sql`

The six no-op tombstones were not listed as pending, which confirms the remote-only history versions are reconciled for dry-run purposes. No real db push, migration repair, or Phase C RPC test was run.

## P4. Reconciliation Group R4 cleanup-revision update

Group R4 revised the cleanup migration locally after R3 verified backup and aggregate evidence for the 23 DEVELOPMENT `orders.expires_at` rows.

The Phase C order-creation migration remains compatible because it does not reference `orders.expires_at`; reservation expiry remains on `stock_reservations.expires_at`. The development-only RPC test script still checks `stock_reservations.expires_at` and was not run in R4.

The cleanup migration now performs exact reviewed assertions, nulls only `orders.expires_at` values after those assertions pass, verifies zero remain, and drops the obsolete column. It does not delete orders, change order status, alter order items, execute stale RPCs, enable confirmation UI, or connect payment/delivery/supplier-prep/finance flows.

## Q. Real db Push

Real `npx supabase db push` was not run.

## R. RPC Tests

The new development-only RPC boundary test script was not run.

## S. Deferred Scope

Still deferred:

- checkout confirmation UI enablement
- order confirmation server action
- payment provider/payment collection
- delivery quote/provider/tracking
- supplier preparation
- commission release
- settlement completion
- withdrawals
- refunds

## T. Commands Run/Results

- `git status --short` - showed pre-existing modified metadata/source markers, the 8 untracked Phase C Group 1 planning docs, and no staged files.
- `git rev-parse HEAD` - `53a9daad399576d58dce54379db23f97ede9e30d`.
- `git branch --show-current` - `main`.
- `git diff --name-status` - no output.
- `git diff --numstat` - no output.
- `git diff --summary` - no output.
- `git diff --check` - passed.
- Ignore checks - `.env.local`, `.local-recovery`, `.next`, and `supabase/.temp` are ignored.
- `npx supabase db push --dry-run` - failed with the migration-history mismatch shown in section P.

Per the stop condition, normal verification commands were not run after the dry-run failure:

- `npm test` - not run after dry-run failure.
- `npm run lint` - not run after dry-run failure.
- `npm run build` - not run after dry-run failure.
- `npm run typecheck` - not run after dry-run failure.
- `npx tsc --noEmit` - not run after dry-run failure.

## U. Security/Scope Scan Result

Partial pre-dry-run safety checks completed:

- `.env.local` is ignored.
- `.local-recovery` is ignored.
- `.next` is ignored.
- `supabase/.temp` is ignored.
- Nothing was staged.
- No real `npx supabase db push` was run.
- The new RPC boundary test script was not run.
- No app source or UI file was changed in Group C2.
- Checkout confirmation UI was not enabled.
- Payment, delivery, supplier preparation, commission release, settlement completion, withdrawal, and refund flows remain deferred.

Full post-change secret/scope scan was not run because the dry-run failed and the instruction was to stop immediately.

## V. Files Changed

Expected Group C2 files:

- `supabase/migrations/20260718213000_create_order_from_checkout_draft_rpc.sql`
- `scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql`
- `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_2_BACKEND_FOUNDATION_REPORT.md`

Group C1 planning docs remain untracked from the previous planning task unless committed separately.

## W. Current Git Status

Current status at the stop point includes:

- Pre-existing modified/no-meaningful-diff markers:
  - `app/supplier/orders/[id]/page.tsx`
  - `app/supplier/orders/page.tsx`
  - `next-env.d.ts`
  - `package-lock.json`
  - `package.json`
  - `tsconfig.json`
- Untracked Phase C Group 1 planning docs:
  - `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_1_PLANNING_REPORT.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_IMPLEMENTATION_GROUPS.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_CREATION_PLAN.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_STATE_MACHINE.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_RISK_REGISTER.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_RPC_TEST_PLAN.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_SECURITY_AND_RLS_PLAN.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_STOCK_RESERVATION_DESIGN.md`
- New Group C2 files:
  - `supabase/migrations/20260718213000_create_order_from_checkout_draft_rpc.sql`
  - `scripts/rpc/create-order-from-draft-rpc-tests-dev-only.sql`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_2_BACKEND_FOUNDATION_REPORT.md`

## X. Whether Group C2 Is Complete

Not complete. The migration and dev-only test script were created, but Supabase dry-run failed before previewing the migration because the remote migration history contains versions missing locally.

## Y. Whether Safe To Commit The Foundation

Not yet. The foundation should not be committed until the migration history mismatch is resolved or explicitly classified as an accepted environment issue, and the required validation/secret scan can run.

## Z. Whether Safe To Apply To Development After Commit

Not yet. The dry-run did not pass, so development apply is blocked.

## AA. Exact Recommended Next Prompt

```text
Diagnose the Supabase migration-history mismatch blocking Checkout Phase C Group 2 dry-run.

Do NOT apply migrations.
Do NOT run real supabase db push.
Do NOT connect production Supabase.
Do NOT run destructive reset commands.
Do NOT print secrets.

Context:
Checkout Phase C Group 2 migration exists locally:
supabase/migrations/20260718213000_create_order_from_checkout_draft_rpc.sql

Dry-run failed before previewing SQL because remote migration versions are missing locally:
20260718210000
20260724000000
20260724010000
20260725000000
20260725020000
20260725030000

Goal:
Inspect local git history/docs/migrations to determine whether these were reverted/quarantined/recovery migrations and propose the safest non-destructive repair plan. Do not run repair/db pull/db push without explicit approval.
```
