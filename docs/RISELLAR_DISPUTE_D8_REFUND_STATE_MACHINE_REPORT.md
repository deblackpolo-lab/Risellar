# Risellar D8 Refund State Machine Report

## Refund Statuses

D8 supports the following refund lifecycle:

- `approved`
- `awaiting_responsible_party`
- `reported_sent`
- `awaiting_customer_confirmation`
- `under_verification`
- `verified`
- `rejected`
- `failed_manual_payment`
- `cancelled`
- `completed`

The implemented approval path creates refund obligations in `awaiting_responsible_party`.

## Main Flow

1. Finance staff or super admin approves a refund obligation.
2. The responsible supplier or finance/admin reports a manual refund as sent.
3. The customer may confirm receipt or dispute non-receipt.
4. Finance verifies or rejects the reported refund.
5. Finance completes a verified refund.

Verification and completion do not close the dispute automatically and do not mutate order/payment state.

## Dispute Interaction

Refund approval may move an eligible dispute to `refund_review` and set finance review flags. Disputes in terminal states cannot receive new refund obligations. D8 does not silently close, cancel, or resolve disputes.

## Return Interaction

Refunds may reference an accepted or completed return when supplied. The return must belong to the same dispute/order/item. D8 does not create returns, complete returns, alter return inventory outcome, or restock products.

## Idempotency

Each state-changing RPC records a fingerprint in `refund_actions`. Same-key same-payload retries return the existing result. Same-key different-payload retries fail safely. Conflicting races allow one valid final outcome.
