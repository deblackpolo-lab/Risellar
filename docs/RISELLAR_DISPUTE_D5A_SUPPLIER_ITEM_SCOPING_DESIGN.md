# Risellar Dispute D5-A Supplier/Item Scoping Design

## Summary

D5 was blocked because `public.order_disputes` was scoped only to `order_id`. Risellar orders can contain items from multiple suppliers, so supplier access based on "any item on the order belongs to this supplier" was too broad.

D5-A adds one immutable target per dispute:

- `scope_type = order`
- `scope_type = supplier`
- `scope_type = order_item`

The MVP deliberately avoids grouped multi-target disputes. Multiple affected items should be opened as separate cases until grouped-case rules are approved.

## Trusted Ownership Path

The trusted path is:

`authenticated customer -> customer-owned order -> order_items -> order_items.supplier_id`

`order_items.supplier_id` is the immutable supplier attribution used by the order workflow. D5-A does not derive supplier access from mutable current product ownership.

## Target Fields

`public.order_disputes` now has:

- `scope_type text not null`
- `affected_supplier_id uuid null`
- `affected_order_item_id uuid null`

Rules:

- `order`: no affected supplier and no affected order item
- `supplier`: affected supplier required and affected order item null
- `order_item`: affected supplier and affected order item required

## Reason-To-Scope Matrix

Item-scoped reasons require an order item:

- `wrong_item_received`
- `damaged_item_received`
- `incomplete_order`
- `item_not_as_described`
- `product_quality_issue`
- `return_requested`
- `refund_requested`

Supplier-operational reasons use a supplied order item to derive the supplier target, without storing an item target:

- `supplier_not_responding`
- `supplier_rejected_status_incorrect`
- `order_stuck_in_preparation`
- `customer_paid_not_reported`
- `supplier_reported_customer_disagrees`

For multi-supplier orders, supplier-operational reasons require an order item. Single-supplier order-wide supplier-operational cases remain allowed where existing order-state rules allow the reason.

Order-wide reasons do not accept an item target.

## Customer RPC Contract

D5-A adds:

`public.customer_open_order_dispute(p_order_id uuid, p_order_item_id uuid, p_dispute_category text, p_reason_code text, p_requested_outcome text, p_description text, p_idempotency_key text)`

The customer never supplies a supplier ID. The backend verifies customer order ownership, verifies any order item belongs to that order, derives scope, derives supplier from `order_items.supplier_id`, and writes the dispute, initial message, status history, and audit row in one transaction.

The old six-argument open-dispute signature is revoked from browser roles.

## Immutability And Uniqueness

A trigger validates target shape and cross-table consistency. It rejects updates to `order_id`, opener identity, opener role, `scope_type`, `affected_supplier_id`, and `affected_order_item_id`.

The old active uniqueness rule is replaced with a target-aware partial unique index.

## Safe Reads

Supplier safe reads now require an explicit affected supplier match, except that single-supplier order-wide disputes are visible to the only supplier on that order. Multi-supplier order-wide disputes are not broadly exposed to suppliers in D5-A.

Customer reads include scope and safe target summary without internal supplier IDs. Reseller reads remain impact-only. Admin/support reads include safe target context and a multi-supplier warning. Finance context remains finance-role gated.

## Deferred

D5-A does not implement supplier responses, admin mutations, returns, refunds, finance holds, stock/reservation/order/payment changes, evidence uploads, notifications, or UI.
