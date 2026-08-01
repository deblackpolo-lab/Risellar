# Risellar Disputes, Returns, and Refunds Phase 1 Plan

## Summary

This phase defines the implementation-ready plan for disputes, returns, and refunds after Risellar's Pay on Delivery order and finance foundations. It does not implement schema, RPCs, RLS, UI, stock movement, payment movement, settlement changes, commission changes, withdrawals, provider refunds, or notification extensions.

The current verified order path is:

`placed_pending_confirmation -> supplier_confirmed -> supplier_preparing -> ready_for_delivery -> delivery_arranged -> out_for_delivery -> delivered -> payment_reported -> completed`

The current rejected path is:

`placed_pending_confirmation -> supplier_rejected`

The current money model is manual Pay on Delivery: the customer pays the supplier directly, the supplier reports payment, finance verifies supplier settlement, reseller commission unlocks, reseller withdrawal reserves available balance, and finance records manual payout. Risellar does not currently hold the original customer payment, does not have provider refunds, and does not have a withdrawal-items allocation model that proves which commission funded a paid withdrawal.

## Baseline Audit

Existing docs and migrations already contain useful vocabulary:

- `order_status` includes `disputed`, with later order phases added by forward migrations.
- `payment_collection_status` includes `refunded`, `disputed`, `supplier_reported`, and `settlement_verified`.
- `settlement_status` includes `disputed`.
- `commission_status` includes `held`, `disputed`, and `adjusted`.
- `reservation_status` supports `reserved`, `committed`, `released`, and `expired`.
- `stock_movement_type` includes `return_restock`, `damage`, and `correction`.
- Earlier planning docs mention `support_tickets`, `disputes`, `returns`, and `refunds`.
- Existing support/dispute/return/refund routes and components are Phase 13 mock-only artifacts. They are incomplete as backend integrations and must not be treated as approved live workflows without new backend/RLS/RPC work.

## Dispute Categories

Use controlled reason codes, not arbitrary text as the only classification.

Pre-delivery:

- `supplier_not_responding`
- `supplier_rejected_but_status_incorrect`
- `order_stuck_in_preparation`
- `delivery_not_arranged`
- `delivery_delay`
- `customer_wants_cancellation`

Delivery:

- `order_not_received`
- `wrong_item_received`
- `damaged_item_received`
- `incomplete_order`
- `unsafe_delivery_issue`
- `delivery_fee_disagreement`

Payment:

- `customer_paid_supplier_but_payment_not_reported`
- `supplier_reported_payment_customer_disagrees`
- `duplicate_payment_claim`
- `wrong_amount_collected`
- `unauthorised_extra_charge`

Post-completion:

- `item_not_as_described`
- `product_quality_issue`
- `return_requested`
- `refund_requested`
- `commission_or_settlement_investigation`

Other:

- `other`

Each open action may allow a short description with length limits, abuse controls, and no HTML.

## Who May Open Cases

Customer:

- Delivery failure, wrong item, damaged item, incomplete order, payment disagreement, unauthorised extra charge, item not as described, return request, refund request.

Supplier:

- Customer refused delivery, customer unreachable, payment not received, delivery issue, return condition disagreement, suspected fraudulent customer claim.

Reseller:

- Commission attribution issue, completed order commission missing, settlement verification issue affecting commission, future withdrawal allocation issue.

Finance admin:

- Supplier settlement discrepancy, payout discrepancy, commission/wallet accounting investigation.

Support/admin:

- Platform-detected inconsistency, duplicate finance rows, order state mismatch, stock/reservation inconsistency.

No role may open a case while impersonating another role.

## Open Windows

Recommended Ghana-MVP defaults requiring business approval:

- Supplier non-response: from `placed_pending_confirmation` until supplier decision or reservation expiry.
- Preparation delay: after supplier confirmation and after a configurable SLA, default 24 hours.
- Delivery not arranged: after `ready_for_delivery` and after a configurable SLA, default 24 hours.
- Out-for-delivery delay: while `out_for_delivery` and after a configurable SLA, default same day plus 24 hours.
- Not received: from `out_for_delivery` or `delivered`, default 72 hours after delivered.
- Wrong/damaged/incomplete: default 48 hours after delivered.
- Payment disagreement: from delivered/payment_reported until 7 days after completion.
- Return request: default 3 days after delivered for returnable categories.
- Commission/accounting: default 14 days after commission availability or withdrawal event.

Category-specific returnability must be configurable. Beauty/skincare, perishables, custom/preorder, electronics, clothing, and accessories need different rules.

## Order-State Interaction

Prefer a separate dispute model over moving every disputed order to `order_status = disputed`. The original fulfilment state should remain auditable.

Use `order_status = disputed` only if the business needs a broad order-level terminal or interrupting state. Otherwise, add `orders.active_dispute_count` or read it from dispute rows and keep customer-safe labels separate.

Opening a dispute should not directly mutate payment, settlement, commission, withdrawal, stock, reservation, delivery, or order status. Finance/stock effects must happen through later explicit audited RPCs.

## Finance Freeze Rules

Before supplier payment report:

- No commission is available.
- No settlement verification exists.
- Dispute may block progress but should not mutate wallet.

After supplier payment report and before settlement verification:

- Settlement verification should be blocked or flagged depending on reason.
- Commission remains locked.
- Finance staff must see the active dispute before verification.

After settlement verification and before withdrawal request:

- Commission may need a hold.
- Do not delete commission history.
- Track held amount separately.

After withdrawal request but before paid:

- Pending withdrawal may need to be held, reduced, rejected, or split.
- Current missing withdrawal-items allocation means exact commission-level reversal is not provable without new allocation schema.

After withdrawal paid:

- Do not silently reverse withdrawn balance.
- Use explicit liability or recovery record if approved by business policy.

## Return and Refund Principles

A return is not a refund. A refund may happen with or without return, and a return may be rejected after inspection.

Returned items must not automatically re-enter sellable stock. Only an authorised supplier/admin inventory action after inspection can restore sellable stock.

Refunds must derive maximum amounts from immutable order snapshots. Browser/admin input cannot be authoritative for the max refund, platform amount, supplier amount, reseller margin, commission, or currency.

Because customers pay suppliers directly, Phase 1 refunds are manual/admin-tracked. No provider refund should be claimed or implied.

## Implementation Staging

Use safe implementation groups D1-D13 from `docs/RISELLAR_DISPUTE_IMPLEMENTATION_GROUPS.md`. Do not combine refund accounting, commission holds, and withdrawal interaction until the required business decisions are approved.

## Hard Stop Rules

Stop implementation if:

- A refund would exceed order snapshots.
- A paid withdrawal would be reversed silently.
- A returned item would auto-restock before inspection.
- A supplier can resolve its own dispute.
- A general admin can perform finance adjustment without `finance_staff` or stronger role.
- A customer/supplier/reseller can see another actor's private data.
- Any dispute RPC mutates payment, stock, settlement, commission, or withdrawal state outside its explicit contract.

## Related Documents

- `docs/RISELLAR_DISPUTE_STATE_MACHINE.md`
- `docs/RISELLAR_RETURN_AND_INVENTORY_MODEL_PLAN.md`
- `docs/RISELLAR_REFUND_ACCOUNTING_AND_FINANCE_PLAN.md`
- `docs/RISELLAR_DISPUTE_SECURITY_AND_RLS_PLAN.md`
- `docs/RISELLAR_DISPUTE_ROLE_AND_PRIVACY_MATRIX.md`
- `docs/RISELLAR_DISPUTE_TEST_AND_QA_PLAN.md`
- `docs/RISELLAR_DISPUTE_IMPLEMENTATION_GROUPS.md`
- `docs/RISELLAR_DISPUTE_RISK_REGISTER.md`
- `docs/RISELLAR_DISPUTE_BUSINESS_DECISIONS_REQUIRED.md`
