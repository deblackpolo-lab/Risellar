# Risellar Supplier Order Safe Read Model Plan

## Purpose

Define a supplier-safe read contract for future supplier order list and detail RPCs. This plan does not create RPCs or application code.

## Ownership Rule

Suppliers may read only order items where `order_items.supplier_id` belongs to the active supplier account resolved from the signed-in profile. Ownership must be resolved server-side from `suppliers.owner_profile_id` and, if later approved, active `supplier_team_members` rows with an explicit order-read permission.

Do not accept supplier id from the client.

## Supplier-Safe Order List RPC

Planned RPC:

```sql
public.list_supplier_orders_safe(
  p_status text default null,
  p_limit integer default 50,
  p_cursor timestamptz default null
)
```

Inputs:

- optional status filter from an allowlist
- optional limit capped server-side, recommended maximum 100
- optional created-at cursor

Required behavior:

- require authenticated active supplier actor
- resolve supplier id server-side
- return only orders containing that supplier's order item
- filter out deleted orders/items
- sort by newest `orders.created_at`
- paginate with deterministic tie-breaker if needed
- never mutate rows
- never expose private reseller, internal finance, or cross-supplier fields

Recommended return shape:

- `order_id`
- `order_number`
- `created_at`
- `updated_at`
- `order_status`
- `order_status_label`
- `payment_method_label`
- `payment_collection_label`
- `delivery_status_label`
- `reservation_status_label`
- `reservation_expires_at`
- `product_name`
- `product_slug`
- `product_image_snapshot`
- `quantity`
- `supplier_amount_expected`
- `customer_product_price_amount` only if operationally useful
- `line_total_amount`
- `currency_code`
- `recipient_name`
- `recipient_phone` only after supplier visibility rules approve fulfilment use
- `delivery_area`
- `landmark`
- `ghana_post_gps`

## Supplier-Safe Order Detail RPC

Planned RPC:

```sql
public.get_supplier_order_safe(p_order_id uuid)
```

Required behavior:

- require authenticated supplier actor
- require active supplier account or approved staff access
- return no rows for missing or unauthorized orders
- avoid distinguishable not-found versus not-owned responses
- return only the supplier-owned item slice
- no service-role app dependency
- no broad direct table read grants
- no write behavior

Detail may include:

- list fields above
- delivery address snapshot fields needed for fulfilment
- customer contact snapshot fields needed for fulfilment
- Pay on Delivery and payment-not-collected labels
- reservation id only if required for support, preferably omitted from UI
- safe confirmation deadline
- safe audit/display timestamps

Detail must not include:

- reseller login identity
- reseller private contact
- reseller margin
- platform margin unless a later operations policy requires it
- supplier payout data
- settlement verification controls
- commission data
- customer account metadata beyond fulfilment snapshot
- admin/risk/internal notes
- another supplier's order items

## Supplier Amount Rule

Prefer showing `supplier_amount_expected` derived from `supplier_base_price_snapshot_amount * quantity`. Avoid exposing platform margin and reseller margin in supplier order operations. If a later finance/settlement phase needs the supplier to see settlement obligations, add that through a separate supplier settlement read contract.
