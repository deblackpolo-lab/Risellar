# Risellar Delivery Phase 2 Out For Delivery Backend Report

## A. Summary

Delivery Phase 2 adds the audited supplier out-for-delivery boundary for Pay on Delivery orders that already have a recorded manual delivery arrangement.

The only transition implemented is:

- `delivery_arranged` -> `out_for_delivery`

Risellar records manual dispatch only. No delivered state, payment collection, proof of delivery, GPS tracking, provider booking, rider marketplace, notifications, refund, cancellation, commission, settlement, or withdrawal workflow was implemented.

## B. Migration Applied

Created and applied to the confirmed development Supabase project:

- `supabase/migrations/20260730190000_supplier_order_out_for_delivery_rpc.sql`

Dry-run result:

- `npx supabase db push --dry-run --include-all` passed
- only `20260730190000_supplier_order_out_for_delivery_rpc.sql` was listed

Development apply result:

- `npx supabase db push --include-all` succeeded
- Supabase noted the `out_for_delivery` enum label already existed and skipped re-adding it

No production Supabase connection was used.

## C. RPC Created

Created:

- `public.supplier_mark_order_out_for_delivery(p_order_id uuid, p_dispatch_reference text default null, p_customer_dispatch_instruction text default null, p_idempotency_key text default null)`

The RPC:

- resolves the supplier owner from the authenticated Clerk/Supabase user context
- requires an active approved supplier owner
- blocks admin/customer/reseller context
- requires the order to belong to the supplier
- requires `delivery_arranged`
- requires an existing active manual delivery arrangement
- requires reserved, unexpired stock reservation state
- requires Pay on Delivery payment status to remain `not_collected`
- is idempotent for matching retry payloads
- blocks conflicting retries
- rejects live tracking/GPS/verified delivery claims in dispatch text

## D. Safe Read Updates

Supplier-safe reads now expose:

- `out_for_delivery_at`
- `dispatch_reference`
- `customer_dispatch_instruction`

Customer-safe reads expose only:

- `out_for_delivery_at`
- `customer_dispatch_instruction`
- a Pay on Delivery dispatch notice

Customer-safe reads do not expose supplier private notes, supplier dispatch reference, tracking links, internal IDs, finance data, or admin fields.

## E. Security Protections Preserved

The migration preserves:

- RLS/RPC boundary checks
- server-side supplier ownership resolution
- server-side order status validation
- server-side reservation validation
- idempotent retry behavior
- `SECURITY DEFINER` with explicit `search_path = public`

The implementation does not:

- use service role from app/components
- expose supplier/customer/profile IDs to browser input
- mutate stock, payment, commercial, delivery quote, preparation, commission, settlement, withdrawal, refund, or cancellation rows
- create live tracking/provider/rider records
- weaken RLS/RPC/storage policy boundaries

## F. Dev-Only RPC Tests

Created:

- `scripts/rpc/supplier-order-out-for-delivery-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-out-for-delivery-concurrency-tests-dev-only.sql`

Both scripts run inside transactions and end with `rollback`.

Passed assertions include:

- supplier can mark a delivery-arranged order out for delivery
- timestamp and safe dispatch fields are stored
- customer cannot mark supplier order out for delivery
- ready orders cannot skip delivery arrangement
- live tracking/GPS dispatch text is blocked
- matching idempotent retry does not create duplicate audit
- conflicting retry is blocked
- customer-safe read shows safe status and instruction
- reservation remains reserved
- stock remains unchanged
- payment remains not collected
- commercial snapshots remain unchanged
- no delivery quote/payment/finance side effects are created

## G. Commands Run And Results

- `npx vitest run tests/supplier-order-out-for-delivery.test.ts`: passed
- `npx supabase db push --dry-run --include-all`: passed
- `npx supabase db push --include-all`: succeeded against development
- `npx supabase db query --linked --file scripts/rpc/supplier-order-out-for-delivery-rpc-tests-dev-only.sql`: passed
- `npx supabase db query --linked --file scripts/rpc/supplier-order-out-for-delivery-concurrency-tests-dev-only.sql`: passed

Full project verification is recorded in the UI/live QA report and passed:

- `git diff --check`
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- `npx tsc --noEmit`

## H. Files Changed

- `supabase/migrations/20260730190000_supplier_order_out_for_delivery_rpc.sql`
- `scripts/rpc/supplier-order-out-for-delivery-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-out-for-delivery-concurrency-tests-dev-only.sql`
- `tests/supplier-order-out-for-delivery.test.ts`
- supplier/customer order helpers and UI files

## I. Current Status

Backend migration, boundary tests, and concurrency/idempotency tests passed in development. Production remains untouched.
