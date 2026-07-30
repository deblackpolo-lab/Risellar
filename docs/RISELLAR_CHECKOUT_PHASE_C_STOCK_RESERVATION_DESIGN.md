# Risellar Checkout Phase C Stock Reservation Design

## Current Stock Model

`public.product_variants` is the current source of stock truth:

- `total_stock_quantity`
- `reserved_stock_quantity`
- `sold_stock_quantity`
- `returned_stock_quantity`
- `variant_status`

The table already enforces:

```text
reserved_stock_quantity + sold_stock_quantity <= total_stock_quantity
```

`public.stock_reservations` records reservation rows, and `public.inventory_movements` records stock movement audit history.

## Reservation Rule

The order creation RPC must reserve stock in the same database transaction that creates the order. Do not create an order first and reserve stock later.

Available stock:

```text
available = total_stock_quantity - reserved_stock_quantity - sold_stock_quantity
```

If `quantity > available`, the RPC must raise `INSUFFICIENT_STOCK` and leave no order, order item, stock reservation, inventory movement, payment, delivery, commission, settlement, or withdrawal side effects.

## Variant Locking

The RPC should lock the selected variant:

```sql
select *
from public.product_variants
where id = v_variant_id
  and product_id = v_product_id
  and deleted_at is null
  and variant_status in ('active', 'low_stock')
for update;
```

This prevents two customers from reserving the same final stock unit at the same time.

## Variant Requirement

`order_items.variant_id` and `stock_reservations.variant_id` are `not null`. Therefore Group C2 should require an active variant. If some current products have `reseller_products.variant_id is null`, the implementation must either:

- reject those listings until a default variant exists, or
- add a forward migration that creates a deterministic default variant pattern.

The safer first implementation is to require a non-null active variant for order creation.

## Reservation Creation

On success:

- increment `product_variants.reserved_stock_quantity` by quantity
- insert `stock_reservations` with `reservation_status = 'reserved'`
- set `expires_at = now() + interval '1 hour'`
- insert `inventory_movements` with `movement_type = 'reservation_created'`
- attach reservation to the newly created order
- write audit log entry

`quantity_delta` in `inventory_movements` should be recorded consistently with the existing stock movement convention. If movement rows represent total quantity changes only, document that reservation movement changes reserved quantity but leaves total unchanged.

## Release/Expiry Design

Future release RPC:

```sql
public.release_order_stock_reservation(
  p_order_id uuid,
  p_reason text default null
)
```

Release must:

- lock the reservation row
- lock the variant row
- only release `reservation_status = 'reserved'`
- decrement `reserved_stock_quantity` by reservation quantity
- mark reservation `released` or `expired`
- set `released_at`
- insert `inventory_movements` with `reservation_released` or `order_cancelled_release`
- write audit log entry

## Commit-To-Sold Design

Do not convert reserved stock into sold stock in Group C. Later, after Pay on Delivery collection is verified, a finance/operations RPC can:

- decrement reserved quantity
- increment sold quantity
- mark reservation `committed`
- set `committed_at`
- insert `sale_committed` movement
- continue settlement/commission workflow

## No Side Effects

Stock reservation must not create payments, settlements, commissions, withdrawals, delivery quotes, or delivery jobs.
