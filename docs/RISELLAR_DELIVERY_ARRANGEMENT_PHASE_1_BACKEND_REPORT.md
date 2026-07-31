# Risellar Delivery Arrangement Phase 1 Backend Report

## A. Summary

Implemented the Supplier Delivery Arrangement Phase 1 backend for ready Pay on Delivery orders. The flow records a manual delivery arrangement and transitions an order from `ready_for_delivery` to `delivery_arranged`.

Risellar still does not operate delivery, book couriers, assign riders, track GPS, collect delivery fees, collect payment, mark delivered, or trigger finance workflows in this phase.

## B. Schema Audit

The existing development schema had no dedicated delivery-arrangement storage table. The MVP storage decision was to add `public.delivery_arrangements` as a narrow order-scoped table with one active arrangement row per order.

Existing delivery/provider concepts remain untouched. No rider, courier-provider, tracking, payment, settlement, commission, withdrawal, refund, cancellation, stock release, or stock commit behavior was added.

## C. Migration Created

Created and applied to the confirmed DEVELOPMENT Supabase project named Risellar:

- `supabase/migrations/20260730180000_supplier_order_delivery_arrangement_rpc.sql`
- `supabase/migrations/20260730183000_fix_delivery_arrangement_conflict_target.sql`
- `supabase/migrations/20260730184000_fix_delivery_arrangement_customer_enum_labels.sql`
- `supabase/migrations/20260730185000_fix_delivery_arranged_supplier_list_label.sql`

Runtime patches were forward migrations because the first migration had already been applied to development before live boundary tests exposed implementation defects.

## D. RPC Created

Created:

- `public.supplier_arrange_order_delivery(...)`

The RPC accepts only:

- `p_order_id`
- `p_delivery_method`
- optional agreed fee
- optional expected date
- optional expected time window
- optional courier/rider display name
- optional courier/rider phone
- optional customer instruction
- optional supplier private note
- optional idempotency key

It does not accept supplier ID, customer ID, reseller ID, product ID, variant ID, order status, order total, currency override, stock values, payment values, commission values, settlement values, or delivery provider data from the client.

## E. Validation And Security

Allowed delivery methods:

- `supplier_rider`
- `third_party_courier`
- `ride_hailing`
- `customer_pickup`
- `manually_arranged`
- `other`

The RPC verifies:

- authenticated supplier-owner context
- active approved supplier ownership
- no admin-staff bypass
- order belongs to exactly that supplier
- order is `ready_for_delivery`
- `ready_for_delivery_at` is set
- Pay on Delivery payment remains `not_collected`
- stock reservation exists, is reserved, and is not expired
- delivery fee is non-negative and capped
- expected date is not in the past
- text fields stay within safe bounds
- courier phone format is bounded and validated

The RPC uses row locks and an order-unique arrangement row for idempotency. Same-key retries return the same state without duplicate rows or duplicate audit events. Conflicting retries are blocked.

## F. Safe Reads

Supplier safe read now includes arrangement details, including the supplier private note, for the owning supplier only.

Customer safe read now includes customer-safe arrangement details:

- method label
- agreed fee
- arrangement currency
- expected date/window
- courier/rider display name and phone
- customer instruction
- customer notice

Customer safe read does not expose supplier private notes, idempotency keys, reviewer/internal IDs, supplier private/contact/payout fields, stock internals, finance internals, or platform margins.

Supplier order list safe read was patched so `delivery_arranged` displays as `Delivery arranged`.

## G. Backend Tests

Added:

- `tests/supplier-order-delivery-arrangement.test.ts`
- `scripts/rpc/supplier-order-delivery-arrangement-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-delivery-arrangement-concurrency-tests-dev-only.sql`

The backend boundary test verifies:

- supplier can arrange own ready order
- status becomes `delivery_arranged`
- arrangement row is created once
- method, fee, currency, expected date/window, courier fields, customer instruction, and private note are stored safely
- customer/reseller/admin/anonymous/cross-supplier access is blocked
- invalid methods, invalid fee, excessive fee, past dates, long fields, inactive reservation, expired reservation, missing reservation, and non-ready statuses are blocked
- customer safe read hides supplier private note
- reservation, stock, payment, order totals, delivery quote rows, provider rows, audit behavior, and finance side effects are protected

The concurrency test verifies:

- one arrangement row
- one status transition
- one arranged timestamp
- one audit event
- reservation unchanged
- stock unchanged
- payment unchanged
- conflicting retry cannot mix arrangement fields

## H. Development Apply/Test Result

Dry-run before the main migration showed only:

- `20260730180000_supplier_order_delivery_arrangement_rpc.sql`

Development `db push` succeeded.

The first boundary test exposed a runtime implementation bug:

- `on conflict (order_id)` was ambiguous inside the PL/pgSQL function because `order_id` also existed as a returned column.

Fix:

- `20260730183000_fix_delivery_arrangement_conflict_target.sql`
- changed conflict target to `on conflict on constraint delivery_arrangements_order_id_key do nothing`

The next boundary test exposed a customer-safe read enum label bug:

- enum `CASE` comparisons needed `::text` casts.

Fix:

- `20260730184000_fix_delivery_arrangement_customer_enum_labels.sql`

Live UI QA later exposed a supplier list label gap:

- `delivery_arranged` listed as `Order status unavailable`.

Fix:

- `20260730185000_fix_delivery_arranged_supplier_list_label.sql`

After these forward patches, the delivery-arrangement RPC boundary test and concurrency test passed.

## I. Commands Run/Results

- `npx vitest run tests/supplier-order-delivery-arrangement.test.ts` - passed
- `npx supabase db push --dry-run` - passed before each migration apply
- `npx supabase db push` - applied development migrations only
- `npx supabase db query --linked --file scripts/rpc/supplier-order-delivery-arrangement-rpc-tests-dev-only.sql` - passed
- `npx supabase db query --linked --file scripts/rpc/supplier-order-delivery-arrangement-concurrency-tests-dev-only.sql` - passed

Final full repository command results are recorded in the UI/live QA report. The full verification sequence passed before commit.

## J. Secret/Scope Result

No secrets were printed or committed in this report. No production Supabase connection was used. `.env.local` remains ignored and unstaged.

No provider booking, rider assignment, live tracking, map/GPS, payment collection, out-for-delivery, delivered, stock release/commit, commission, settlement, withdrawal, refund, cancellation, or notification behavior was implemented.

## K. Files Changed

Backend/migration/test files:

- `supabase/migrations/20260730180000_supplier_order_delivery_arrangement_rpc.sql`
- `supabase/migrations/20260730183000_fix_delivery_arrangement_conflict_target.sql`
- `supabase/migrations/20260730184000_fix_delivery_arrangement_customer_enum_labels.sql`
- `supabase/migrations/20260730185000_fix_delivery_arranged_supplier_list_label.sql`
- `scripts/rpc/supplier-order-delivery-arrangement-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-delivery-arrangement-concurrency-tests-dev-only.sql`
- `tests/supplier-order-delivery-arrangement.test.ts`

## L. Current Git Status

Current git status is recorded in the UI/live QA report after final verification.

## M. Safe To Commit

Backend is safe to commit together with the UI/live QA work. The final verification sequence and secret/privacy scan passed.
