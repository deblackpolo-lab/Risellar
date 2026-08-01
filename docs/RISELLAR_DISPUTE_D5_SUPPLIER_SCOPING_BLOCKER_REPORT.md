# Risellar Dispute D5 Supplier Scoping Blocker Report

## Summary

D5 supplier response backend is blocked before implementation. The current live dispute schema links disputes to a full order but does not identify the affected supplier, order item, or affected supplier set. Because Risellar orders support multiple suppliers through `order_items`, adding `supplier_add_dispute_response` now could allow a supplier on the same order to view/respond to a dispute that concerns another supplier's item.

No migration, RPC, grant, UI, return, refund, finance, stock, order, payment, settlement, commission, wallet, withdrawal, evidence, or notification change was made.

## Verified Baseline

- Branch: `main`
- Baseline HEAD: `f2c0896df121de8f17aae911b4ba1fa6a10030fb`
- D4 customer open/response backend is complete and applied to DEVELOPMENT.
- Current modified files before D5 work were the recurring generated metadata files: `next-env.d.ts` and `tsconfig.json`.

## Trusted Supplier Ownership Path Reviewed

The intended safe path is:

```text
authenticated profile
-> active approved supplier identity
-> supplier-owned order item
-> order
-> dispute
```

The current live supplier safe-read RPCs resolve active approved supplier identity server-side, then authorize by checking whether the order has at least one `order_items` row for that supplier.

## Multi-Supplier Scoping Result

The schema supports multiple supplier-owned `order_items` per order. `order_disputes` currently stores only `order_id`, `opened_by_profile_id`, category, reason, requested outcome, and status fields. It does not store:

- affected supplier id
- affected order item id
- affected product/variant id
- dispute participant/scope rows

Therefore D5 cannot safely decide that supplier A is the intended participant for a full-order dispute when supplier B also has items in the order.

## Why Implementation Stopped

The D5 prompt requires stopping if the schema cannot safely scope a dispute to one affected supplier/item. Implementing `supplier_add_dispute_response` against the current order-only scope would broaden supplier access beyond the complaint target.

This is a schema/authorization design gap, not a confirmed RLS bypass. The existing supplier safe reads should be treated as acceptable only for single-supplier orders or cases where every supplier in the order is intentionally a participant.

## Required Forward Extension

Before D5 can proceed safely, create a forward migration that adds a narrow supplier dispute scope model. Recommended options:

1. Add `affected_supplier_id` to `order_disputes`, derived server-side during dispute creation.
2. Add `affected_order_item_id` to `order_disputes`, derived server-side during dispute creation.
3. Add a `dispute_supplier_participants` or `dispute_order_items` table for multi-item/multi-supplier disputes.

Recommended D5-safe path:

- add an affected supplier/order-item relation
- update customer open RPC to derive scope from a controlled selected order item or safe order-level reason
- update supplier safe-read RPCs to use the affected scope, not any order item on the order
- add regression tests for supplier A/B multi-supplier isolation
- only then add `supplier_add_dispute_response`

## Security Requirements For The Extension

- Do not trust browser-supplied supplier IDs.
- Do not let any supplier on an order respond by default.
- Do not expose customer private fields, supplier-private messages, reseller finance data, or admin internal notes.
- Do not grant direct table writes to browser roles.
- Do not mutate orders, payment, stock, reservation, settlement, commission, wallet, withdrawal, delivery, return, refund, evidence, or notification records.

## Verification Performed

- Repository baseline precheck confirmed branch `main`, D4 HEAD, and no staged files.
- Static schema review confirmed `order_disputes` is order-scoped.
- Static supplier safe-read review confirmed supplier authorization is currently through `exists order_items where order_id = dispute order and supplier_id = current supplier`.
- No D5 migration was created.
- No D5 SQL test was created.
- No Supabase migration was applied.
- No push was performed.

## Current Status

D5 is blocked pending a supplier/item dispute-scope extension. The next safe task is a D5-A scoping migration and test plan, not the supplier response mutation itself.

## Recommended Next Prompt

"Create the D5-A supplier/item dispute scoping forward migration and tests. Do not add supplier response RPC yet. Update customer open/safe-read behavior only as needed to derive and enforce affected supplier/order-item scope safely."

## D5-A Resolution Addendum

D5-A resolved this blocker with a forward-only target scoping foundation:

- `scope_type`
- `affected_supplier_id`
- `affected_order_item_id`
- backend-derived supplier target selection in `customer_open_order_dispute`
- target immutability enforcement
- target-aware active uniqueness
- repaired supplier safe reads

Supplier response mutations remain unimplemented and should resume only against the D5-A target-aware model.
