# Risellar Dispute D4 Customer Open/Response Backend Report

## Summary

D4 added customer-only backend mutation RPCs for opening an order dispute and adding a customer response. No UI, supplier mutation, admin mutation, return, refund, finance hold, order mutation, payment mutation, stock mutation, delivery mutation, evidence upload, or notification flow was activated.

## Migration

Created and applied to the confirmed DEVELOPMENT project:

- `supabase/migrations/20260801130000_customer_dispute_open_and_response_rpcs.sql`

The already-applied D2/D3 migrations were not edited.

## RPCs

- `public.customer_open_order_dispute(p_order_id uuid, p_dispute_category text, p_reason_code text, p_requested_outcome text, p_description text, p_idempotency_key text)`
- `public.customer_add_dispute_response(p_dispute_id uuid, p_body text, p_idempotency_key text)`

Both RPCs are `SECURITY DEFINER`, use a fixed `search_path = public`, resolve the caller server-side, and are granted only to `authenticated`.

## Eligibility Matrix

D4 validates category, reason, requested outcome, description, idempotency key, customer ownership, and reason/order-state compatibility. The live implementation preserves the existing D2 active-case uniqueness rule by order, opener profile, and reason code.

Allowed state mappings include:

- `supplier_not_responding`: `placed_pending_confirmation`
- `supplier_rejected_status_incorrect`: `supplier_rejected`
- `order_stuck_in_preparation`: `supplier_confirmed`, `supplier_preparing`
- `delivery_not_arranged`: `ready_for_delivery`, `ready_for_pickup_or_dispatch`
- `delivery_delay`: `delivery_arranged`, `out_for_delivery`
- `order_not_received`: `out_for_delivery`, `delivered`, `delivered_payment_pending`
- item/quality/return/refund reasons: delivered or later safe states
- payment/accounting reasons: payment-reported/completed states where relevant
- `other`: operational and completed states only

Unknown, cancelled, deleted, cross-customer, inactive, and suspended contexts are rejected.

## Initial Records

Opening a valid customer dispute creates one transactionally consistent set of:

- `order_disputes` row with backend-derived status `open`
- initial `dispute_messages` customer message
- initial `dispute_status_history` row
- `audit_logs` row with safe metadata only

Audit metadata intentionally excludes the full customer description, response body, contact details, evidence, private notes, and financial internals.

## Response Behavior

Customer responses append an immutable customer message. Responses are allowed only for active customer-meaningful states: `open`, `awaiting_customer`, `under_review`, `return_review`, and `refund_review`.

When the case is `awaiting_customer`, the RPC atomically moves it to `under_review`, clears `customer_action_required`, writes one status-history row, and writes one status-change audit event. Closed, rejected, and cancelled cases are blocked.

## Idempotency

Open idempotency is scoped to the authenticated opener profile and key. A same-key/same-payload retry returns the existing safe result without duplicate message, history, or audit rows. Same-key/different-payload attempts fail with an idempotency conflict.

Response idempotency is scoped to dispute, author profile, and key. A same-key/same-body retry returns the existing message without duplicate audit rows. Same-key/different-body attempts fail with an idempotency conflict.

## Grants And RLS

No direct table privileges were granted to browser roles for dispute tables. Direct table writes remain blocked. Browser roles get `EXECUTE` only on the two customer RPCs. The RPCs do not rely on caller-supplied profile IDs, customer IDs, author IDs, status, role, timestamps, or private flags.

## Verification

The development-only rollback SQL test passed with 51 assertions:

- `scripts/rpc/customer-dispute-open-response-tests-dev-only.sql`

Verified areas include anonymous blocking, inactive/suspended blocking, cross-customer isolation, direct table-write denial, validation failures, valid open, valid response, idempotent retries, duplicate active-case behavior, safe reads, audit rows, no notification rows, and no business-table side effects.

## Defects And Fixes

The first D4 SQL test run exposed a development-only harness issue: after simulating the authenticated customer role, the script queried protected dispute/audit tables without resetting the role for verification. The test harness was fixed to run RPC calls under simulated browser roles and protected-table assertions under the owner context. No applied migration, RPC, RLS policy, or grant was changed for this harness fix.

No D4 product/security defect was confirmed.

## Commands And Results

- `git status --short`: showed pre-existing `next-env.d.ts` and `tsconfig.json` metadata modifications plus D4 files.
- `git diff --check`: passed; line-ending warnings only for edited docs.
- `npx supabase db push --dry-run`: passed; only `20260801130000_customer_dispute_open_and_response_rpcs.sql` was pending.
- `npx supabase db push`: passed; applied only the D4 migration to DEVELOPMENT.
- `npx supabase db query --linked --file scripts/rpc/customer-dispute-open-response-tests-dev-only.sql --output table`: passed; 51 assertions, 0 failed.
- True-concurrency linked-query probe: passed for same-key open, active-fingerprint open, and same-key response.
- Concurrency cleanup check: passed; zero matching fixture profiles, orders, or disputes remained.
- `npm test`: passed; 48 test files and 289 tests.
- `npm run lint`: passed.
- `npm run build`: passed; Next.js build completed and generated 174 static pages.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## Secret And Scope Scan

- `.env.local`, `.next`, `.local-recovery`, `supabase/.temp`, and local Codex dev-server logs are ignored and not staged.
- Targeted high-confidence secret scan of D4 migration, SQL script, and D4 docs found no real keys, bearer tokens, private keys, connection strings, or production data.
- No `SUPABASE_SERVICE_ROLE_KEY`, service-role helper, or Supabase admin client import was found in `app/` or `components/`.
- No D4 customer mutation RPC references were added to `app/`, `components/`, or live UI helper code.
- No checkout/order/payment/delivery/finance/stock mutation UI integration was added.

## Scope Protection

D4 did not activate mock Phase 13 dispute UI or add forms/buttons. It did not implement supplier response, admin resolution, returns, refunds, finance holds, stock changes, reservation changes, settlement changes, commission changes, wallet changes, withdrawal changes, evidence uploads, or notifications.

## Current Status

D4 backend is ready for the next approved dispute implementation group after local commit. D5 may begin only after explicit request.
