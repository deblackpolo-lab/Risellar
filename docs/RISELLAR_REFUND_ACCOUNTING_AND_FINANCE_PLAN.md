# Risellar Refund Accounting and Finance Plan

## Current Finance Baseline

Risellar's current development model is Pay on Delivery:

1. Customer pays supplier directly.
2. Supplier reports payment.
3. Stock reservation is committed and sold stock increases.
4. Supplier settlement obligation is created.
5. Reseller commission remains locked.
6. Finance admin verifies settlement.
7. Reseller commission becomes available.
8. Reseller requests withdrawal.
9. Finance admin records manual payout.

Risellar does not currently hold the original payment, does not process automatic refunds, and does not have a withdrawal-items allocation model proving exactly which commission funded a paid withdrawal.

## Refund Types

- `full_refund`
- `partial_refund`
- `delivery_fee_refund_only`
- `item_value_refund_only`
- `goodwill_credit`
- `no_refund`

## Refund Channels

- `cash`
- `mobile_money`
- `bank_transfer`
- `original_manual_method`
- `platform_credit_later`
- `other_manual_method`

Do not represent provider refunds until a provider is actually integrated and tested.

## Responsibility Codes

- `supplier_responsible`
- `customer_responsible`
- `delivery_partner_responsible`
- `platform_responsible`
- `reseller_responsible`
- `shared_responsibility`
- `no_financial_adjustment`

Do not assume supplier responsibility by default. The final decision must be a controlled code with an audited explanation.

## Refund Amount Authority

Trusted maximums must come from immutable order and order item snapshots:

- item customer price snapshot
- quantity
- line total
- delivery fee if recorded
- total payable
- currency code

The browser must not provide authoritative:

- maximum refund
- supplier amount
- platform amount
- commission amount
- reseller margin
- settlement impact
- currency

Admin may submit an approved amount, but the backend must enforce:

- amount >= 0
- amount <= permitted maximum
- currency matches original order
- partial refund requires reason
- full accounting breakdown exists

## Finance Holds

Use a non-destructive hold model instead of deleting finance records.

Future table concept: `finance_holds`

- `dispute_id`
- `order_id`
- `reseller_id` nullable
- `supplier_id` nullable
- `amount`
- `currency_code`
- `hold_type`
- `status`
- `created_at`
- `released_at`
- `applied_at`

Hold types:

- `commission_available_hold`
- `commission_pending_withdrawal_hold`
- `supplier_settlement_hold`
- `platform_goodwill_hold`
- `paid_withdrawal_recovery`

Statuses:

- `active`
- `released`
- `applied`
- `cancelled`

## Settlement Effects

Settlement pending:

- Block or flag admin settlement verification when the dispute affects payment, delivery, received condition, wrong item, damaged item, or refund amount.
- Keep supplier settlement due/under review.

Settlement verified:

- Do not silently reverse.
- Create supplier liability, platform liability, reseller liability, or shared responsibility record if resolution requires recovery.
- Keep original audit trail.

## Commission Effects

Commission pending/locked:

- Keep locked until dispute closes.
- Do not release while dispute blocks settlement.

Commission available:

- Create hold if responsibility might reduce reseller balance.
- Do not delete the commission row.

Commission pending withdrawal:

- Hold or reject pending withdrawal only through a finance RPC.
- Without withdrawal-items allocation, do not claim an exact commission-to-withdrawal mapping.

Commission withdrawn:

- Do not silently reverse paid withdrawal.
- Create recoverable reseller liability only if the approved business policy supports it.

## Wallet Effects

Wallet balances must stay ledger-like:

- available
- pending withdrawal
- withdrawn
- held/disputed, if schema is extended

Never let available balance become negative. Any adjustment must be idempotent and audited.

## Refund Completion

Because the supplier may refund the customer directly, the system should track:

- approved refund amount
- responsible party
- channel
- reported sent by
- proof reference, if required
- verified by finance/support
- verified timestamp
- customer-safe status

Do not mark `payment_collection_status = refunded` until refund completion is verified by an authorised role.

## Missing Withdrawal Allocation Caveat

The present withdrawal model can reserve/pay reseller withdrawal balances without a durable per-commission withdrawal-items allocation model. Dispute design must either:

- add allocation before commission reversals from withdrawals, or
- treat paid withdrawal impacts as separate liabilities/recovery records.

Do not build a refund system that assumes exact commission reversals are provable when they are not.

## D8 Implemented Boundary

D8 implements manual refund obligations only. `public.order_refunds` records the approved amount, responsibility, manual sent report, customer confirmation, finance verification/rejection, and completion state. `public.refund_actions` records idempotency fingerprints for state-changing refund actions.

D8 keeps the following deferred:

- finance holds
- settlement reversals
- commission reversals
- reseller wallet adjustments
- withdrawal recovery
- provider refunds
- automatic payouts
- refund notifications

Goodwill refunds are also deferred in D8 because no approved platform-liability cap exists yet.

The backend derives currency and caps from immutable order/order-item snapshots and enforces cumulative item, delivery-fee, and order caps across active, verified, and completed refund obligations.
## D9 Implementation Update

D9 backend finance holds are now implemented for the development project. Dispute-linked finance review uses append-only `finance_holds`, `finance_adjustments`, and `finance_actions`.

Implemented:

- Settlement verification blockers for unresolved dispute/refund finance review.
- Commission availability holds that reduce reseller withdrawable projection without mutating historical commission rows.
- Supplier/platform liability records as review/accounting records, not collection workflows.
- Withdrawal review guard for outstanding requested withdrawals.

Still deferred:

- Paid-withdrawal reversal.
- Negative wallet balances.
- Future-earnings offsets.
- Provider refund/payment integration.
- Stock mutation.
- Notification sending.
