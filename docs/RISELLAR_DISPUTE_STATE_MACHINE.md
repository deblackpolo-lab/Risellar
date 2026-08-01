# Risellar Dispute State Machine

## Design Choice

Disputes should use their own state machine. The order's fulfilment state remains the factual fulfilment record. The dispute state expresses the investigation and resolution workflow.

## Proposed Dispute States

| State | Meaning | Allowed next states |
| --- | --- | --- |
| `open` | Case created and awaiting triage. | `awaiting_customer`, `awaiting_supplier`, `under_review`, `rejected`, `cancelled` |
| `awaiting_customer` | Admin/support needs customer input. | `under_review`, `awaiting_supplier`, `rejected`, `cancelled` |
| `awaiting_supplier` | Admin/support needs supplier input. | `under_review`, `awaiting_customer`, `rejected`, `cancelled` |
| `under_review` | Admin/support is investigating. | `awaiting_customer`, `awaiting_supplier`, `return_review`, `refund_review`, `resolved_customer`, `resolved_supplier`, `partially_resolved`, `rejected`, `cancelled` |
| `return_required` | Customer must return item before final refund/stock action. | `return_in_transit`, `cancelled`, `rejected` |
| `return_in_transit` | Return is moving outside Risellar provider automation. | `returned`, `awaiting_customer`, `under_review` |
| `returned` | Supplier/admin has received returned item. | `refund_pending`, `resolved_customer`, `resolved_supplier`, `partially_resolved`, `rejected` |
| `refund_pending` | Refund obligation approved but not verified complete. | `resolved_customer`, `partially_resolved`, `under_review` |
| `resolved_customer` | Customer-favouring resolution complete. | `closed`, `appeal_opened` |
| `resolved_supplier` | Supplier-favouring resolution complete. | `closed`, `appeal_opened` |
| `partially_resolved` | Split responsibility or partial adjustment complete. | `closed`, `appeal_opened` |
| `rejected` | Case rejected after review. | `closed`, `appeal_opened` |
| `cancelled` | Opened in error or withdrawn before action. | `closed` |
| `closed` | Final inactive state. | none |

## Resolution Codes

- `customer_full_refund`
- `customer_partial_refund`
- `return_and_full_refund`
- `return_and_partial_refund`
- `replacement_agreed`
- `redelivery_agreed`
- `delivery_fee_refund`
- `no_refund_supplier_favoured`
- `no_refund_customer_fault`
- `goodwill_resolution`
- `accounting_correction`
- `case_rejected`
- `case_closed_no_action`

## Order-State Interaction

Opening a dispute should not automatically change `orders.order_status`. A future implementation may add an `active_dispute_count`, `current_dispute_status`, or safe read label, but the order state should remain useful for fulfilment and finance history.

Potential order-level effects must be explicit:

- Pre-acceptance cancellation: later cancellation RPC may release stock.
- Supplier rejected: dispute may verify that rejection/status is correct.
- Preparing/ready/delivery: dispute pauses or flags next action, not automatic status mutation.
- Delivered/payment_reported/completed: dispute may create finance holds or refund obligations through separate RPCs.
- Final resolution may add `disputed` only if business approves order-level disputed state as a terminal/reporting flag.

## Payment-State Interaction

Payment state must not be changed by opening a dispute. Payment changes require finance/refund RPCs:

- `not_collected`: dispute can record payment not yet collected.
- `supplier_reported`: payment disagreement can freeze settlement verification.
- `settlement_verified`: dispute can create refund/adjustment obligations, not silently reverse.
- `refunded`: only after approved manual refund verification.
- `disputed`: only through an audited finance/payment-state RPC.

## Settlement Interaction

For active dispute reasons that affect delivered/payment_reported orders:

- Pending settlement verification should be blocked or flagged.
- Settlement `disputed` can be used for finance-visible cases.
- Verified settlement must not be reversed silently.
- Supplier liability should be recorded separately if a verified settlement requires recovery.

## Commission and Withdrawal Interaction

Commission states `held`, `disputed`, and `adjusted` are useful, but Phase 1 must not delete commission rows or pretend paid withdrawals are commission-specific without allocation evidence.

Use future finance-hold rows for:

- available commission hold
- pending withdrawal hold/reduction
- adjustment pending
- paid-withdrawal liability

## Idempotency

Every state-changing action needs a stable idempotency key:

- dispute opening
- response creation
- information request
- return approval/rejection
- return received
- inspection classification
- refund approval
- refund sent report
- refund verification
- finance hold creation/release/application
- stock adjustment
- final resolution
- appeal open/resolution

Repeated calls must return durable existing results without duplicate audit events, notifications, holds, refund obligations, wallet adjustments, or stock movements.

## Audit Events

Minimum events:

- `dispute_opened`
- `dispute_response_added`
- `dispute_information_requested`
- `return_requested`
- `return_approved`
- `return_rejected`
- `return_received`
- `returned_item_inspected`
- `refund_approved`
- `refund_sent_reported`
- `refund_verified`
- `commission_hold_created`
- `commission_hold_released`
- `commission_adjustment_applied`
- `supplier_liability_created`
- `platform_revenue_adjusted`
- `wallet_adjustment_created`
- `stock_returned_to_sellable`
- `stock_moved_to_damaged`
- `dispute_resolved`
- `dispute_rejected`
- `dispute_closed`
- `appeal_opened`
- `appeal_resolved`

Audit payloads must not contain raw evidence files, private notes, secrets, cookies, tokens, or unmasked payout data.
