# Risellar Checkout Phase C Risk Register

## R1: Overselling Shared Supplier Stock

Risk: multiple resellers can sell the same supplier product, so two customers could try to reserve the final unit.

Mitigation: lock `product_variants` with `FOR UPDATE`, compute available stock inside the transaction, increment reserved stock only after validation, and rely on the existing no-oversell constraint as a final guard.

## R2: Duplicate Orders From Retry

Risk: browser retries or network errors create more than one order/reservation.

Mitigation: add `orders.checkout_draft_id unique`; repeated calls return the existing order and never reserve stock twice.

## R3: Trusting Browser Price

Risk: client manipulates price, margin, supplier, reseller, or commission fields.

Mitigation: RPC accepts only draft id and optional idempotency key. All commercial values are resolved server-side from approved current listing/product data and snapshotted.

## R4: Draft Snapshot Drift

Risk: draft shows one price but order captures a changed price.

Mitigation: order creation should revalidate and capture authoritative current values. UI should show a clear changed/unavailable error if listing price/status changed materially before placing order.

## R5: Variant Nullability

Risk: existing `reseller_products.variant_id` is nullable, but order items and reservations require variant id.

Mitigation: first implementation should require non-null active variant. Add a future default-variant migration only if product setup needs it.

## R6: Reservation Expiry Without Release Job

Risk: stock remains reserved if a customer never confirms.

Mitigation: include expiry timestamp in Group C2 and prioritize a release/expiry RPC in Group C6. Until then, QA should use limited fake data and document manual cleanup needs.

## R7: Premature Commission Or Settlement

Risk: order placement incorrectly creates withdrawable commission or settlement records before POD collection/verification.

Mitigation: snapshot expected amounts on order items only. Do not create commission, settlement, or withdrawal rows in Phase C order creation.

## R8: Payment Confusion

Risk: users interpret Pay on Delivery order placement as payment collected.

Mitigation: initialize `payment_collection_status = 'not_collected'`, keep online payment disabled, and use UI copy that explains payment is collected later.

## R9: Supplier Sees Too Much Customer Data

Risk: supplier order views expose data beyond operational fulfillment needs.

Mitigation: define role-specific safe order RPCs/views later. Supplier should receive only product, quantity, delivery/contact data needed for fulfillment and settlement obligations when that phase exists.

## R10: RLS Broadening

Risk: implementation opens direct table writes to users.

Mitigation: use `SECURITY DEFINER` RPCs with explicit checks. Keep direct `order_items`, `stock_reservations`, and `inventory_movements` writes blocked for normal users.

## R11: Incomplete Audit Trail

Risk: order/reservation events cannot be reconstructed.

Mitigation: every mutation RPC writes audit logs with before/after or structured metadata. Do not store secrets in audit logs.

## R12: Scope Creep Into Delivery/Payment

Risk: order creation accidentally connects payment provider, delivery quote, settlement, or commission workflows.

Mitigation: Group C2 tests must assert zero rows in those side-effect tables and code scans must confirm no payment/delivery integration references were added.
