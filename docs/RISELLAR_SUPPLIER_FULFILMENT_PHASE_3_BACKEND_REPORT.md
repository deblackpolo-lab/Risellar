# Risellar Supplier Fulfilment Phase 3 Backend Report

## Summary

Supplier Fulfilment Phase 3 adds the audited supplier transition from `supplier_preparing` to `ready_for_delivery` for preparing Pay on Delivery orders.

This phase does not implement delivery booking, rider assignment, delivery fees, out-for-delivery, delivered, payment collection, stock commitment, commissions, settlements, withdrawals, refunds, cancellations, notifications, or admin transitions.

## Real Status Findings

The development `public.order_status` enum had `supplier_preparing` and the older `ready_for_pickup_or_dispatch`, but it did not have the requested `ready_for_delivery` value.

The `public.orders` table already had preparation metadata:

- `supplier_preparing_at`
- `supplier_preparation_by_profile_id`
- `supplier_preparation_idempotency_key`

It did not have ready-for-delivery metadata before this phase.

## Schema Extension

Created forward migration:

- `supabase/migrations/20260730163000_supplier_order_ready_for_delivery_rpc.sql`

The migration adds:

- `ready_for_delivery` enum value
- `orders.ready_for_delivery_at`
- `orders.ready_for_delivery_by_profile_id`
- `orders.ready_for_delivery_idempotency_key`
- `public.supplier_mark_ready_for_delivery(p_order_id uuid, p_idempotency_key text default null)`

## Actionability

`supplier_mark_ready_for_delivery` requires:

- authenticated user context
- active `supplier_owner` profile
- active approved supplier resolved server-side
- single-supplier order ownership
- `order_status = supplier_preparing`
- existing `supplier_preparing_at`
- `payment_collection_status = not_collected`
- matching stock reservation
- reservation status `reserved`
- unexpired reservation

Blocked cases verified by the rollback harness include pending, confirmed-but-not-preparing, rejected, missing preparation timestamp, expired/released/failed/missing reservation, cross-supplier, customer, reseller, admin staff, and anonymous.

## Effects

The RPC changes only:

- `orders.order_status` to `ready_for_delivery`
- `orders.ready_for_delivery_at`
- `orders.ready_for_delivery_by_profile_id`
- `orders.ready_for_delivery_idempotency_key`
- one audit event: `supplier_order_ready_for_delivery`

The RPC preserves:

- `supplier_preparing_at`
- reservation status and quantity
- reserved stock
- total stock
- sold stock
- payment collection status

## Security Protections

- No caller-supplied supplier ID.
- No caller-supplied status, stock, price, delivery, or payment input.
- Supplier ownership is resolved server-side.
- Function is `SECURITY DEFINER` with explicit `search_path`.
- Execute is granted only to `authenticated`.
- Public and anon execute are revoked.
- No direct table-write grant was added.
- No RLS, RPC, or storage policy was weakened.
- No service role is used in app/components.

## Safe-Read Mappings

Supplier-safe reads now map:

- `supplier_preparing` -> `Preparing order`
- `ready_for_delivery` -> `Ready for delivery`

Customer-safe reads now map:

- `supplier_preparing` -> `Supplier is preparing your order`
- `ready_for_delivery` -> `Your order is ready for delivery arrangement`
- delivery status -> `Delivery has not been arranged yet`
- payment -> `Payment not collected`
- reservation -> stock reserved wording

No ready actor, idempotency key, supplier private data, or delivery-provider details are exposed.

## Migration Result

Dry-run passed and showed only:

- `20260730163000_supplier_order_ready_for_delivery_rpc.sql`

Development apply succeeded against the confirmed Risellar development Supabase project.

No production Supabase connection was used.

No destructive reset command was used.

## Backend Tests

Added:

- `scripts/rpc/supplier-order-ready-for-delivery-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-ready-for-delivery-concurrency-tests-dev-only.sql`
- `tests/supplier-order-ready-for-delivery.test.ts`

Boundary test result:

- all assertions passed
- fixture data rolled back

Concurrency/idempotency test result:

- two mark-ready calls converged
- one ready audit event
- ready timestamp populated once
- reservation unchanged
- stock unchanged
- confirmed state remained blocked from ready

## Commands Run

- `git status --short`
- `git rev-parse --short HEAD`
- `git branch --show-current`
- `npx supabase --version`
- live enum/column/RPC audit queries
- `npx vitest run tests/supplier-order-ready-for-delivery.test.ts`
- `npx vitest run tests/supplier-order-ready-for-delivery.test.ts tests/supplier-order-ui.test.tsx`
- `git diff --check`
- `npx supabase db push --dry-run --include-all`
- `npx supabase db push --include-all`
- `npx supabase db query --linked --file scripts/rpc/supplier-order-ready-for-delivery-rpc-tests-dev-only.sql`
- `npx supabase db query --linked --file scripts/rpc/supplier-order-ready-for-delivery-concurrency-tests-dev-only.sql`
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- `npx tsc --noEmit`

## Verification Result

- `npm test`: passed, 37 files / 205 tests
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed

## Current Status

Backend Phase 3 is implemented and verified at the migration/RPC/test level.

The final broad runtime route sweep initially exposed a stale local dev-server `.next` chunk issue on unrelated routes after `next build`. The stale local server was identified by the exact port-400 PID, confirmed as the Risellar Next development server, stopped, and replaced with a fresh dev server after clearing only the ignored `.next` generated cache.

The final fresh-server route sweep passed for `/`, `/sign-in`, `/sign-up`, the known public shop/product routes, `/supplier/orders`, and the supplier ready order detail. No stale vendor chunk, missing module, RSC manifest, hydration, or HTTP 500 failure remained.

Safe to commit the intentional Phase 3 backend, UI, test, script, and report files.
