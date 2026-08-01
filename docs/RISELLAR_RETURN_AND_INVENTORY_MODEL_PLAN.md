# Risellar Return and Inventory Model Plan

## Core Rule

Returned goods must not automatically increase available stock. A return request only starts an investigation. Sellable stock can be restored only after a physical receipt and inspection action by an authorised supplier inventory role or authorised admin.

## Return States

| State | Meaning |
| --- | --- |
| `return_not_required` | Refund/resolution does not require a physical return. |
| `return_requested` | Customer requested a return. |
| `return_approved` | Admin/support approved the return path. |
| `return_rejected` | Return request denied. |
| `return_in_transit` | Item is being returned outside Risellar delivery automation. |
| `return_received` | Supplier/admin acknowledges receipt. |
| `return_inspected` | Condition recorded. |
| `return_accepted` | Condition supports final resolution. |
| `return_declined` | Condition does not support refund/restock. |
| `return_completed` | Return workflow closed. |

## Return Methods

- `customer_returns_to_supplier`
- `supplier_pickup`
- `third_party_courier_outside_risellar`
- `no_return_refund`
- `disposal_required`

Phase 1 must not book couriers or delivery providers.

## Delivery Fee Responsibility

- `customer`
- `supplier`
- `platform`
- `shared`
- `not_applicable`

Responsibility must be explicit on the return/refund decision. Do not infer it from reason text alone.

## Inspection Conditions

- `unopened_sellable`
- `opened_sellable`
- `damaged`
- `defective`
- `used`
- `incomplete`
- `expired`
- `not_returned`
- `inspection_pending`

## Inventory Outcomes

- `restock_sellable`
- `move_to_damaged_stock`
- `move_to_quarantine`
- `dispose`
- `return_to_supplier_non_sellable`
- `no_stock_change`

## Stock Effects

No stock change:

- dispute opened
- return requested
- return approved
- return in transit
- refund approved without return

Possible stock change after inspection only:

- `restock_sellable`: increment sellable stock using a single audited inventory movement.
- `move_to_damaged_stock`: record damaged/non-sellable movement or location.
- `move_to_quarantine`: isolate pending further inspection.
- `dispose`: record disposal/no sellable stock increase.
- `return_to_supplier_non_sellable`: record supplier custody without sellable restock.

## Reservation and Sold Stock Rules

If stock was still reserved and the order is cancelled or supplier rejected, existing reservation release rules apply. If payment was reported and stock reservation was committed, a return does not undo historical sold stock automatically. A later inventory adjustment may add returned sellable stock as a separate movement.

Required invariants:

- `reserved_stock_quantity + sold_stock_quantity <= total_stock_quantity` remains true.
- No negative `reserved_stock_quantity`.
- Return restock movement is idempotent.
- Physical returned stock is not treated as new supplier stock until inspection.
- Damaged/defective/incomplete returns never appear as sellable without explicit authorised override.

## Evidence and Audit

Return inspection should capture:

- condition code
- inspected by
- inspection timestamp
- safe note
- optional private evidence references
- inventory outcome

Audit events should reference entity IDs internally but avoid exposing raw private evidence in public-safe reads, notifications, or logs.

## Deferred Work

- Delivery-provider return labels.
- Automatic courier booking.
- Automated stock recovery from return delivery events.
- Barcode/warehouse receiving.
- Supplier liability settlement automation.

## D7 Implemented Boundary

D7 implements return workflow tracking through `public.order_item_returns`, not the legacy `public.returns` table.

D7 records requested, approved/rejected, in-transit, received, inspected, accepted/declined, and completed return states. Supplier inspection can recommend an `inventory_outcome`, but this is only a marker. No product variant stock counters, stock reservations, or inventory movements are changed by D7.

Future inventory work must consume D7 return state through a separate audited inventory RPC. It must not treat `accepted` or `completed` as automatic sellable-stock restoration.
