# Risellar Checkout Phase C Group 1 Planning Report

## A. Summary

Completed planning for the real order creation and atomic stock reservation backend foundation. This phase created documentation only.

No migrations, RPCs, RLS changes, app wiring, Supabase data mutations, commits, or pushes were performed.

## B. Existing Order/Schema Findings

The current schema already contains:

- `orders`
- `order_items`
- `stock_reservations`
- `product_variants`
- `inventory_movements`
- `delivery_quotes`
- `settlements`
- `commissions`
- `withdrawals`
- `checkout_drafts`

The current `order_status` enum includes `placed_pending_confirmation`, which is the recommended initial order state. The current `product_variants` table includes total/reserved/sold quantities and a constraint preventing reserved plus sold quantity from exceeding total quantity.

## C. Recommended Order Boundary

The next implementation should add one atomic RPC:

```text
create_order_from_checkout_draft(p_checkout_draft_id uuid, p_idempotency_key text default null)
```

The RPC should create the order, order item, stock reservation, inventory movement, and audit log in one database transaction.

## D. Recommended Stock Reservation Design

Use the existing variant stock fields. Lock the variant row, compute available stock, reject insufficient stock, then increment reserved stock and insert a reservation row. Do not decrement total stock at order placement.

## E. Security And Scope

The plan keeps order creation customer-owned and server/database-calculated. It does not trust browser prices, margins, supplier ids, reseller ids, order status, or payment state. It keeps payment, delivery, settlement, commission, withdrawal, and purchase-flow side effects deferred.

## F. Documents Created

- `docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_CREATION_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_STATE_MACHINE.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_STOCK_RESERVATION_DESIGN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_SECURITY_AND_RLS_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_RPC_TEST_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_IMPLEMENTATION_GROUPS.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_RISK_REGISTER.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_1_PLANNING_REPORT.md`

## G. Commands Run/Results

- `git status --short` - showed pre-existing modified metadata/source files plus the new Phase C planning docs.
- `git diff --check` - passed.
- `npm test` - passed: 30 test files, 158 tests.
- `npm run lint` - passed with `eslint . --max-warnings=0`.
- `npm run build` - passed.
- `npm run typecheck` - passed with `tsc --noEmit`.
- `npx tsc --noEmit` - passed.

## H. Secret/Scope Scan Result

- `.env.local` is ignored.
- `.env.local` is not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No new migration files were created or changed.
- No source implementation files were changed by this planning task.
- No Supabase CLI db push/query/reset command was run.
- No real Supabase data was read or mutated.
- No service role token/JWT-shaped value was found in source.
- No service-role references were added to `app/` or `components/`.
- Existing secret-pattern hits are confined to older documentation wording that names env variables or reports that bearer tokens were not found; the new Phase C docs contain no secret values.
- Existing checkout/order/stock/payment/delivery wording in source is from prior mock/planning/test surfaces; this task added docs only and did not add order, stock, payment, delivery, commission, settlement, or withdrawal implementation.

## I. Current Git Status

Current working tree after planning:

- Pre-existing modified files:
  - `app/supplier/orders/[id]/page.tsx`
  - `app/supplier/orders/page.tsx`
  - `next-env.d.ts`
  - `package-lock.json`
  - `package.json`
  - `tsconfig.json`
- New planning docs:
  - `docs/RISELLAR_CHECKOUT_PHASE_C_GROUP_1_PLANNING_REPORT.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_IMPLEMENTATION_GROUPS.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_CREATION_PLAN.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_ORDER_STATE_MACHINE.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_RISK_REGISTER.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_RPC_TEST_PLAN.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_SECURITY_AND_RLS_PLAN.md`
  - `docs/RISELLAR_CHECKOUT_PHASE_C_STOCK_RESERVATION_DESIGN.md`

## J. Safe To Begin Group C2

Recommended after local verification passes. Group C2 should create a forward migration and development-only RPC boundary test script, run dry-run only, and still avoid applying migrations until explicit approval.
