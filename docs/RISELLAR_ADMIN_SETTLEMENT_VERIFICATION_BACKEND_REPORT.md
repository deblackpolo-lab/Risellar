# Risellar Admin Settlement Verification Backend Report

## Summary

Implemented the development Admin Settlement Verification backend for supplier-reported Pay on Delivery orders. The transition is:

`payment_reported` / `supplier_reported` -> `completed` / `settlement_verified`

The RPC verifies a pending supplier settlement, marks the settlement paid/verified, unlocks reseller commission, credits reseller available balance exactly once, completes the order, and leaves stock/reservations untouched.

## Admin Authorization Model

Admin settlement verification uses active `public.admin_staff` membership only. The new helper `public.current_finance_admin_profile_id()` accepts only active `finance_staff` or `super_admin` rows.

General `admin`, `support_staff`, supplier, reseller, customer, inactive, and anonymous contexts are blocked. This intentionally avoids the broader existing `has_admin_role('finance_staff')` behavior because that helper also treats a general `admin` row as sufficient.

## Finance Schema Audit

Live development schema uses:

- `public.settlements` for supplier settlement obligations
- `public.commissions` for reseller commission rows
- stored reseller balance columns on `public.resellers`
- `public.supplier_payment_reports` for supplier-reported Pay on Delivery claims
- `public.audit_logs` for audit events

No separate wallet ledger table exists yet. The approved current model credits `resellers.commission_available_amount` and decreases `commission_pending_amount` in the same transaction.

## Migration Created

`supabase/migrations/20260731200000_admin_supplier_settlement_verification_rpc.sql`

The migration adds:

- `payment_collection_status = settlement_verified`
- `orders.completed_at`
- `orders.completed_by_profile_id`
- `orders.settlement_verified_idempotency_key`
- `settlements.verification_idempotency_key`
- reference/note safety constraints
- active settlement uniqueness indexes
- finance-only admin helper functions
- admin-safe settlement list/detail RPCs
- `admin_verify_supplier_settlement(...)`

## State Transitions

- order: `payment_reported` -> `completed`
- payment: `supplier_reported` -> `settlement_verified`
- settlement: `due` -> `paid`
- commission: `awaiting_supplier_settlement` -> `available`
- reservation: remains `committed`
- stock: unchanged
- withdrawal: not created

## Trusted Amount And Currency Validation

The RPC derives all amounts from immutable order/item/payment/settlement/commission rows. The browser does not send platform amount, commission amount, total amount, currency, supplier id, reseller id, or balance values.

Validation checks:

- supplier payment report matches order total/currency
- settlement due matches order item settlement snapshot
- reseller commission matches locked commission rows
- platform amount is derived as settlement due minus commission
- reservation is already committed
- no withdrawal exists for the commission

## Idempotency And Conflict Behavior

Same key plus same reference/note returns the durable verified/completed state without a second balance credit or audit event. A retry with different reference/note is blocked as `CONFLICTING_RETRY`.

## Audit Events

The RPC writes safe audit events:

- `supplier_settlement_verified`
- `platform_amount_verified_received`
- `reseller_commission_unlocked`
- `reseller_available_balance_credited`
- `order_completed`

Audit metadata stores safe status/amount/currency signals and presence booleans for reference/note. It does not expose full admin note content to non-admin views.

## Backend Tests

Created:

- `scripts/rpc/admin-settlement-verification-rpc-tests-dev-only.sql`
- `scripts/rpc/admin-settlement-verification-concurrency-tests-dev-only.sql`
- `tests/admin-settlement-verification.test.ts`

Results:

- SQL boundary tests passed after a dev-only harness context fix.
- Concurrency/idempotency tests passed.
- Unit contract test passed.
- Full app test suite passed after updating the Phase 9 admin navigation expectation for the new settlement queue.
- A route-boundary regression test was added so `finance_staff` can access `/admin/settlements` without broadening finance staff into every admin route.

## Commands Run

- `npx vitest run tests/admin-settlement-verification.test.ts` - failed first as expected, then passed.
- `git diff --check` - passed.
- `npm run typecheck` - passed after JSX/type fixes.
- `npx supabase db push --dry-run --include-all` - passed; only this migration was pending.
- `npx supabase db push --include-all` - applied migration to the linked development project.
- `npx supabase db query --linked --file scripts/rpc/admin-settlement-verification-rpc-tests-dev-only.sql` - passed.
- `npx supabase db query --linked --file scripts/rpc/admin-settlement-verification-concurrency-tests-dev-only.sql` - passed.
- `npm run lint` - passed.
- `npm test` - first rerun failed because Phase 9 expected Settlements to stay absent from admin nav; test updated to reflect the new finance queue, then passed with 42 files / 242 tests.
- `npm run build` - passed.
- `npm run typecheck` - passed when rerun sequentially after build.
- `npx tsc --noEmit` - passed when rerun sequentially after build.
- `git diff --check` - passed after report updates; Git reported LF-to-CRLF normalization warnings only.
- Development-only finance bootstrap query - updated the existing masked admin_staff row for `ex***@gmail.com` from general admin to active `finance_staff`; `profiles.primary_role` remained `customer`, no `super_admin` grant was made, and no duplicate admin_staff row was created.
- Live settlement verification browser QA - passed for one retained development payment-reported order.
- Same-key idempotency retry - passed.
- Conflicting retry - blocked safely as `CONFLICTING_RETRY`.
- Scoped post-verification database checks - passed.
- `npm test` - final run passed with 42 files / 243 tests.
- `npm run lint` - final run passed.
- `npm run build` - final run passed.
- `npm run typecheck` - final run passed.
- `npx tsc --noEmit` - final run passed.

Note: one intermediate typecheck/tsc attempt overlapped with `next build` while `.next/types` was being regenerated and produced transient `.next/types` missing-file errors. The commands were rerun sequentially after build and passed.

## Security And Scope

- No production Supabase connection was used.
- No destructive reset/repair command was used.
- No service role was imported into app/components.
- `.env.local`, `supabase/.temp`, `.next`, and `.codex-dev-server.*.log` are ignored and were not staged.
- No external payment/provider, withdrawal, payout, stock, refund, cancellation, delivery, or settlement proof upload integration was added.
- Direct client finance-table mutation was not added.
- No production data, bearer tokens, passwords, Clerk/Supabase keys, JWTs, cookies, profile IDs, supplier IDs, or private database identifiers were added to docs/source output.
- The finance bootstrap was development-only, reused the existing approved masked admin account, did not create a Clerk user, did not create a duplicate profile, did not update `profiles.primary_role`, and did not grant `super_admin`.
- The stale `.next` cache was moved out of the workspace after the post-build browser sweep exposed a stale Clerk vendor chunk error. A clean dev-server restart regenerated the cache; `.next` remains ignored and unstaged.

## Live QA Result

Live admin settlement verification QA passed after explicit approval for development-only finance_staff setup.

The existing base `has_admin_role('finance_staff')` helper treats general `admin` as sufficient. This phase intentionally does not rely on that broader behavior; settlement verification uses the new settlement-specific finance helper so only active `finance_staff` or `super_admin` can verify supplier settlement receipts.

Verified effects:

- order completed
- payment collection status became `settlement_verified`
- settlement status became `paid`
- verified timestamp and verifier were populated
- commission became `available`
- reseller available balance increased exactly once
- reseller pending balance remained safe
- reservation remained committed
- stock counts remained unchanged after verification
- no withdrawal was created
- no supplier payout/provider/refund/cancellation/delivery side effect was created
- expected audit events were created exactly once

## Safe To Commit

Yes, after final security scan and exact-path staging, this phase is safe to commit.
