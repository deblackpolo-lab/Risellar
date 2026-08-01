# Risellar Dispute D5 Supplier Response Backend Report

## Summary

D5 added the supplier-only backend response RPC on top of the completed D5-A supplier/item scope foundation. No dispute UI, admin resolution, returns, refunds, finance holds, stock changes, order/payment changes, evidence uploads, notifications, settlements, commissions, wallets, or withdrawals were implemented.

## Development Project

The migration and tests were run only against the confirmed DEVELOPMENT Supabase project named Risellar. Production was not connected.

## Migration

- `supabase/migrations/20260801150000_supplier_dispute_response_rpc.sql`

The migration adds:

- `public.supplier_add_dispute_response(p_dispute_id uuid, p_body text, p_idempotency_key text)`
- `SECURITY DEFINER` with fixed `search_path = public`
- authenticated execute grant only
- safe audit events

No previously applied migration was edited.

## RPC Contract

The RPC returns only:

- `message_id`
- `dispute_id`
- `created`
- `status`
- `created_at`

The caller does not provide supplier ID, profile ID, author role, visibility, status, timestamps, or target fields.

## Authorization

Supplier identity is resolved server-side from the authenticated profile through `current_dispute_supplier_id()`, requiring:

- active profile
- `supplier_owner` primary role
- active supplier row
- approved supplier verification
- no active admin_staff membership shadowing the supplier context

Dispute authorization uses the D5-A target fields:

- `scope_type = supplier`: `affected_supplier_id` must equal the caller supplier.
- `scope_type = order_item`: `affected_supplier_id` must equal the caller supplier, and `affected_order_item_id` must belong to that supplier on the disputed order.
- `scope_type = order`: allowed only for single-supplier order-wide cases under the D5-A policy.

The old broad rule, "supplier owns any item on the order", is not used.

## Response Behavior

Supplier responses create immutable `dispute_messages` rows with:

- `author_role = supplier`
- `message_type = participant_response`
- `visibility = supplier_and_admin`
- `is_system_message = false`

The body is trimmed, bounded, plain text only, and rejects sensitive-token/payment/contact patterns. Audit metadata does not include the response body or complaint body.

## Status Behavior

Allowed response statuses:

- `open`
- `awaiting_supplier`
- `under_review`
- `return_review`
- `refund_review`

Blocked terminal statuses:

- `resolved_customer`
- `resolved_supplier`
- `partially_resolved`
- `rejected`
- `cancelled`
- `closed`

When the dispute is `awaiting_supplier`, the RPC atomically:

- inserts the supplier response
- moves status to `under_review`
- sets `supplier_action_required = false`
- writes one status-history row
- writes one status-change audit event

For all other allowed statuses, it inserts the response and updates only dispute `updated_at`.

## Idempotency

Idempotency is scoped to:

- dispute
- supplier author profile
- idempotency key

Same key and same normalized body returns the existing message. Same key with a different body raises a safe conflict. Retries do not duplicate messages, status history, or audit events.

## SQL Boundary Tests

`scripts/rpc/supplier-dispute-response-tests-dev-only.sql` passed:

- assertions: 67
- passed: 67
- failed: 0

Coverage included anonymous/customer/reseller/admin blocking, inactive/suspended/unapproved supplier blocking, supplier/item scope enforcement, multi-supplier isolation, single-supplier order-wide behavior, server-derived author fields, visibility, body/idempotency validation, retry idempotency, awaiting-supplier transition, terminal-state blocking, safe-read privacy, direct table-write denial, no business side effects, and rollback cleanup.

## Concurrency

A separate temporary two-session development concurrency runner verified:

- same-key concurrent calls create one message
- same-key concurrent calls create one response audit and one status-history transition
- different-key concurrent calls create separate valid responses without duplicate transitions
- terminal-state race blocks late supplier response
- cross-supplier race blocks the unrelated supplier
- no notification side effect

Temporary concurrency fixtures were cleaned up and not committed.

## Defects And Fixes

Initial D5 test failures were harness-only:

- duplicate fixture rows violated the D5-A target-aware active uniqueness rule
- owner-only assertions were run under simulated browser role context
- the temporary concurrency runner initially tried to read protected dispute tables after switching to browser role

No D5 migration/RPC/RLS/security defect was confirmed, so no forward fix migration was required.

## Commands And Results

- `git status --short`: baseline matched D5-A with only generated metadata files before D5 work
- `git diff --check`: passed
- `npx supabase db push --dry-run`: passed; only D5 migration pending
- `npx supabase db push`: passed; applied D5 to DEVELOPMENT only
- `npx supabase db query --linked --file scripts/rpc/supplier-dispute-response-tests-dev-only.sql`: passed 67/67
- temporary true-concurrency runner: passed 9/9 and cleaned up
- `npm test`: passed, 48 files / 289 tests
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed

## Security And Scope

- No direct dispute-table grants were added for browser roles.
- RLS posture remains intact.
- No service-role code was exposed in app/components.
- No UI was activated.
- No admin mutation exists.
- No return/refund/finance/order/payment/stock/reservation/settlement/commission/wallet/withdrawal/notification mutation was added.
- `.env.local` was ignored and not staged.

## Status

D5 supplier response backend is complete and ready for local commit. D6 admin/support investigation and non-financial resolution may begin after approval.
