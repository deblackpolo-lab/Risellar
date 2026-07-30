# Risellar Checkout Phase C Order Creation Plan

## Purpose

Plan the real Pay on Delivery order creation backend boundary without implementing it yet. This document is planning-only: no migration, RPC, RLS, UI, or Supabase data mutation is included in this phase.

## Current Schema Findings

- `public.orders` already exists with `order_status public.order_status default 'placed_pending_confirmation'`.
- `public.order_items` already exists with immutable commercial snapshot columns:
  - `supplier_base_price_snapshot_amount`
  - `platform_margin_snapshot_amount`
  - `reseller_margin_snapshot_amount`
  - `reseller_cost_snapshot_amount`
  - `customer_product_price_snapshot_amount`
  - `line_total_amount`
  - `settlement_due_amount`
  - `commission_amount`
- `public.stock_reservations` already exists and references customer, reseller, listing, product, variant, and order.
- `public.product_variants` already tracks `total_stock_quantity`, `reserved_stock_quantity`, and `sold_stock_quantity` with a no-oversell constraint.
- `public.checkout_drafts` exists from Phase B and stores a server-calculated draft snapshot. It does not create orders or reserve stock.

## Recommended Boundary

Create a single audited database RPC in a later implementation group:

```sql
public.create_order_from_checkout_draft(
  p_checkout_draft_id uuid,
  p_idempotency_key text default null
)
```

The browser/server action should pass only the draft id and optional idempotency key. The RPC must resolve all customer, reseller, shop, supplier, product, variant, listing, price, contact, and address data server-side.

## Input Rules

Do not accept these from the client:

- customer id
- reseller id
- shop id
- supplier id
- product id
- variant id
- product price
- supplier base price
- platform margin
- reseller margin
- settlement amount
- commission amount
- order status
- payment collection status
- reservation status

The draft must already contain customer contact and delivery address snapshots before conversion.

## Draft-To-Order Conversion

Only `checkout_drafts.draft_status = 'review_pending'` should be convertible. `draft` means the customer has not attached required contact/address data. `abandoned` must be blocked.

Recommended post-conversion draft state for the future migration:

- Add `converted_order_id uuid references public.orders(id)` if traceability is needed.
- Add `converted_at timestamptz`.
- Extend the draft status check to include `converted`, or avoid changing `draft_status` and rely on `orders.checkout_draft_id unique`.

The cleaner idempotent approach is adding `orders.checkout_draft_id uuid unique references public.checkout_drafts(id)`.

## Initial Order State

Use existing enum values:

- `orders.order_status = 'placed_pending_confirmation'`
- `orders.payment_method = 'pay_on_delivery'`
- `orders.payment_collection_status = 'not_collected'`
- `orders.delivery_status = 'estimate_selected'`
- `orders.customer_confirmation_status = 'pending'`
- `orders.delivery_quote_status = 'pending'`

Online payment must remain deferred.

## Order Number

Add a database-side order number helper in the future migration. It should be generated inside the transaction and be unique, for example:

```text
RSR-YYYYMMDD-NNNNN
```

The implementation must handle unique conflicts by retrying a bounded number of times or by using a sequence-backed suffix.

## Required Transaction

The future RPC must complete these steps atomically:

1. Validate active customer context through `current_profile_id()` and the linked `customers` row.
2. Lock the checkout draft with `FOR UPDATE`.
3. Verify draft ownership and `review_pending` state.
4. Verify active listing, active shop, approved reseller, active approved product, active approved supplier, non-deleted rows.
5. Lock the selected `product_variants` row with `FOR UPDATE`.
6. Compute available stock as `total_stock_quantity - reserved_stock_quantity - sold_stock_quantity`.
7. Fail without side effects when stock is insufficient.
8. Insert `orders`.
9. Insert `order_items` from server-derived current pricing/listing/product data.
10. Increment `product_variants.reserved_stock_quantity`.
11. Insert `stock_reservations` with `reservation_status = 'reserved'`.
12. Insert `inventory_movements` with `movement_type = 'reservation_created'`.
13. Write an audit log entry.
14. Return a safe order summary.

## Snapshot Policy

Order snapshots should be calculated from current approved product/listing data at order creation, not from browser-submitted data. The Phase B draft snapshot is useful for display and review, but the final order should revalidate availability and capture authoritative order-time values.

## Side Effects Explicitly Deferred

Phase C order creation must not create:

- payment rows
- payment provider references
- delivery quote rows
- commission availability
- settlement rows
- withdrawal rows
- supplier preparation tasks
- delivery jobs

Settlement and commission amounts may be snapshotted on `order_items`, but release/ledger rows must wait for later approved phases.
