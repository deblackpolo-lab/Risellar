# Risellar Dispute D5 Supplier Privacy Security Review

## Summary

D5 supplier response is scoped to D5-A target fields and keeps supplier responses private to the supplier and admin/support context. Customer and reseller safe reads do not automatically expose supplier-private responses.

## Authorization Model

The trusted path is:

`authenticated profile -> active approved supplier -> affected_supplier_id -> optional affected_order_item_id`

The implementation rejects caller-supplied supplier identity and never authorizes by checking whether the supplier owns any item on the disputed order.

## Scope Rules

Supplier-scoped disputes require `affected_supplier_id` to match the caller supplier.

Item-scoped disputes require both:

- `affected_supplier_id` equals the caller supplier
- `affected_order_item_id` belongs to the caller supplier on the disputed order

Order-scoped disputes are respondable by suppliers only for the D5-A single-supplier order-wide exception. Multi-supplier order-wide disputes remain blocked from supplier response.

## Message Privacy

Supplier response messages are written as:

- author role: `supplier`
- message type: `participant_response`
- visibility: `supplier_and_admin`

Customer safe reads exclude `supplier_and_admin` messages. Reseller safe reads remain impact-only and do not include messages. Other suppliers cannot detail unrelated scoped disputes.

## Audit Privacy

Audit events record safe metadata only:

- status
- scope type
- target presence booleans
- idempotency-key presence

Audit metadata does not include:

- supplier response body
- customer complaint body
- customer contact data
- supplier contact or payout data
- internal notes
- evidence
- refund, settlement, commission, wallet, or withdrawal values

## Direct Grant Posture

No `SELECT`, `INSERT`, `UPDATE`, or `DELETE` grant on `order_disputes`, `dispute_messages`, or `dispute_status_history` was added for `anon` or `authenticated`.

Browser roles receive only `EXECUTE` on `supplier_add_dispute_response(uuid, text, text)`.

## RLS Posture

D5 does not disable or weaken RLS. Existing forced RLS remains on the dispute tables, and mutation remains through audited SECURITY DEFINER RPCs only.

## Business Boundary

D5 does not mutate:

- orders or order items
- payment reports or payment statuses
- settlements
- commissions
- wallets
- withdrawals
- products or stock
- stock reservations
- delivery arrangements
- notification outbox or provider events
- returns, refunds, finance holds, or evidence records

Allowed D5 changes are limited to supplier response messages, optional dispute status/action-field transition, dispute status history, audit logs, and dispute `updated_at`.

## Verification Result

The development SQL test passed 67 assertions and the separate two-session concurrency runner passed 9 assertions. No production data was used, no secrets were printed, and temporary fixtures were cleaned up.
