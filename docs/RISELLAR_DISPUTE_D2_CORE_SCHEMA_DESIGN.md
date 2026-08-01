# Risellar Dispute D2 Core Schema Design

## Scope

D2 drafts the core dispute case foundation only. The migration is not applied in this phase.

Included:

- `public.order_disputes`
- `public.dispute_messages`
- `public.dispute_status_history`
- controlled text/check values
- RLS enablement
- direct table access revocation
- read-only safe RPCs
- indexes
- idempotency-ready fields

Excluded:

- refunds
- returns
- finance holds
- wallet adjustments
- commission adjustments
- withdrawal allocation
- settlement mutation
- payment status mutation
- order status mutation
- stock/reservation mutation
- evidence uploads
- notifications
- provider refunds

## Existing Artifact Audit

The repository already has broad earlier `public.disputes` and `public.returns` foundation tables plus Phase 13 mock-only support/dispute/return/refund screens. D2 does not activate those artifacts. The new draft uses `public.order_disputes` so a future live implementation can proceed without depending on old broad placeholder semantics.

Existing reusable schema vocabulary:

- `orders`
- `order_items`
- `customers`
- `suppliers`
- `resellers`
- `admin_staff`
- `audit_logs`
- order/payment/settlement/commission statuses that already include dispute/held/refunded concepts

## Dependency Map

Trusted ownership and attribution path:

```text
order_disputes.order_id
  -> orders.id
  -> orders.customer_id -> customers.id -> customers.profile_id
  -> orders.reseller_id -> resellers.id -> resellers.profile_id
  -> order_items.order_id -> order_items.supplier_id -> suppliers.id -> suppliers.owner_profile_id
```

The draft derives customer, supplier, and reseller authorization from this path. It does not trust caller-supplied customer, supplier, reseller, or profile IDs.

## Table: public.order_disputes

Purpose: one order-linked dispute case.

Key fields:

- `id`: case identifier.
- `order_id`: immutable link to the order.
- `opened_by_profile_id`: authenticated opener profile.
- `opened_by_role`: controlled role label at open time.
- `dispute_category`: broad controlled category.
- `reason_code`: controlled reason.
- `description`: bounded text, no HTML or credential-like terms.
- `requested_outcome`: requested non-binding outcome.
- `status`: core dispute status, separate from order status.
- `priority`: `normal`, `high`, or `urgent`.
- `assigned_admin_profile_id`: optional assignment.
- action flags: customer, supplier, finance, and return review flags.
- timestamps: opened, first response, resolved, closed, created, updated.
- resolution fields: non-financial D2 outcome context only.
- `internal_resolution_notes`: admin-only safe text.
- `idempotency_key`: future open-action retry key.
- `deleted_at`: soft deletion marker for future admin cleanup policy.

D2 intentionally does not store refund amounts, settlement amounts, commission amounts, wallet amounts, return shipment state, evidence JSON, payment-provider state, or stock mutation data.

## Table: public.dispute_messages

Purpose: append-only case communication records.

Key fields:

- `dispute_id`
- `author_profile_id`
- `author_role`
- `message_type`
- `body`
- `visibility`
- `is_system_message`
- `created_at`
- `edited_at`
- `deleted_at`

Participant messages should be immutable in future mutation RPCs. Corrections should be new messages. D2 allows `edited_at` only for future admin policy compatibility, not for direct table updates.

## Table: public.dispute_status_history

Purpose: append-only status transition timeline.

Key fields:

- `dispute_id`
- `previous_status`
- `new_status`
- `changed_by_profile_id`
- `changed_by_role`
- `reason_code`
- `public_note`
- `internal_note`
- `created_at`

Future mutation RPCs must write status history in the same transaction as the case status update.

## Controlled Values

The draft uses text plus CHECK constraints instead of new PostgreSQL enums. This avoids conflicts with earlier broad `dispute_status` enum values and keeps the D2 migration forward-only.

Controlled categories:

- `pre_delivery`
- `delivery`
- `payment`
- `post_completion`
- `accounting`
- `other`

Controlled statuses:

- `open`
- `awaiting_customer`
- `awaiting_supplier`
- `under_review`
- `return_review`
- `refund_review`
- `resolved_customer`
- `resolved_supplier`
- `partially_resolved`
- `rejected`
- `cancelled`
- `closed`

Return transit and refund execution states remain excluded from core dispute status because future return/refund records should own those details.

## Idempotency

The draft adds:

- `idempotency_key`
- unique index on `(opened_by_profile_id, idempotency_key)` when non-null and active
- unique active duplicate guard on `(order_id, opened_by_profile_id, reason_code)` while the case is not closed/cancelled/rejected

Future open RPC should create the dispute, first message, first status-history row, audit event, and notification event in one transaction.

## Indexes

Planned indexes match read patterns:

- order detail lookup
- opener/customer list lookup
- status/priority admin queue
- assignment queue
- category filters
- message timeline
- status timeline
- idempotency retry lookup

The design avoids speculative indexes for finance/return/refund tables because those tables are not part of D2.

## Stop Conditions For D3

D3 should stop before apply if:

- order ownership cannot be derived through the map above
- supplier ownership path changes
- reseller attribution is not immutable enough for safe impact reads
- admin_staff role semantics change
- direct table access cannot remain denied
- old placeholder tables conflict with `order_disputes`
