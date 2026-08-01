# Risellar Dispute D7 Return State Machine Report

## Return States

D7 introduces `public.order_item_returns.status` values:

- `requested`
- `under_review`
- `approved`
- `rejected`
- `in_transit`
- `received`
- `inspected`
- `accepted`
- `declined`
- `completed`
- `cancelled`

`cancelled` is reserved for a later controlled cancellation RPC; no cancellation RPC was added in D7.

## Transitions Implemented

Customer:

- eligible item-scoped dispute -> `requested`
- approved physical return -> `in_transit`

Admin/support:

- `requested` or `under_review` -> `approved`
- `requested` or `under_review` -> `rejected`
- `inspected` -> `accepted`
- `inspected` -> `declined`
- `accepted`, `declined`, `rejected`, or `cancelled` -> `completed`

Supplier owner:

- `approved` or `in_transit` physical return -> `received`
- `received` -> `inspected`

## Dispute Interaction

Customer return request can set the related dispute to `return_review` only when the existing D6 transition matrix allows it. Otherwise it records `return_review_required = true` without forcing an invalid dispute status transition.

Status-history reason codes align to the existing dispute allowlist through the `return_review` reason.

## Deferred

D7 does not close disputes, resolve refunds, apply finance holds, restock inventory, book delivery, or notify users. Those remain separate future groups.
