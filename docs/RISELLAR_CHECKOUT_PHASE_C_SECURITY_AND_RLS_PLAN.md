# Risellar Checkout Phase C Security and RLS Plan

## R6 direct-write hardening update

R6 added a forward DEVELOPMENT-applied migration that revokes direct `insert`, `update`, `delete`, and `truncate` privileges from `anon` and `authenticated` on the checkout-created commercial order/stock tables:

- `orders`
- `order_items`
- `stock_reservations`
- `product_variants`

Controlled writes remain through audited SECURITY DEFINER RPCs. RLS was not weakened, no broad `USING (true)` or `WITH CHECK (true)` policy was added, and final checkout confirmation UI remains disabled.

## Core Principle

Order creation and stock reservation must be done through audited server/database boundaries. The browser must not write order, order item, reservation, inventory movement, payment, delivery, commission, settlement, or withdrawal records directly.

## Current RLS Findings

Existing policies already indicate the intended direction:

- `orders_select_participants_or_admin` uses `is_order_participant(id)` or admin support role.
- `orders_insert_customer_or_admin` allows customer/admin insert as a foundation, but production order creation should use a validated RPC.
- `orders_update_support_admin_until_order_rpc` blocks normal user updates.
- `order_items_insert_admin_only` blocks customer direct item creation.
- `stock_reservations_insert_admin_only_until_rpc` blocks customer direct reservation creation.
- `inventory_movements_insert_stock_permission_or_admin` does not grant customer stock movement writes.

Phase C should preserve or tighten these boundaries through RPC validation, not broaden direct table policies.

## Planned RPC Security

The order creation RPC should be:

- `SECURITY DEFINER`
- `set search_path = public`
- granted to `authenticated`
- implemented with explicit actor/customer ownership checks
- audited with `create_audit_log_entry`
- free of service-role dependency

It must resolve `current_profile_id()` and require:

- active `profiles` row
- `primary_role = 'customer'`
- active linked `customers` row
- draft belongs to that customer

## Listing And Product Validation

The RPC must verify:

- checkout draft is non-deleted
- checkout draft is `review_pending`
- reseller listing is `active` and non-deleted
- reseller shop is `active`, public/valid as appropriate, and non-deleted
- reseller approval is `approved`
- product is `active`
- product approval is `approved`
- supplier is `active`
- supplier verification is `approved`
- variant is active/low-stock, non-deleted, and belongs to the product

## Sensitive Field Handling

Do not expose these to customer-facing order creation responses:

- supplier base price
- platform margin
- reseller margin
- supplier payout data
- supplier private contact
- reseller private margin strategy
- risk scores
- admin/internal notes
- settlement data
- commission ledger data

Snapshot values can exist in `order_items` for future admin/reseller/supplier accounting, but response shapes must be role-safe.

## Role Visibility

Customer:

- own order only
- final product price
- delivery address/contact snapshot
- Pay on Delivery status
- reservation/confirmation status

Reseller:

- orders attributed to own reseller listing/shop
- expected commission snapshot
- customer-safe order status
- no supplier payout/private contact

Supplier:

- orders for own products
- product/variant/quantity and operational customer delivery/contact data needed for fulfillment
- supplier amount and settlement obligation only when settlement phase is implemented
- no reseller private strategy beyond required order attribution

Admin/support:

- full operational visibility according to `admin_staff` role and audited admin RPCs.

## Idempotency

Future migration should add `orders.checkout_draft_id uuid unique`. A repeated call for the same converted draft should return the existing order summary and write either no second audit row or a clear reuse audit row.

Optional `p_idempotency_key` can be accepted, but it is secondary. The durable safety rule is one order per checkout draft.

## No Direct Role/Policy Weakening

Do not:

- grant customer direct inserts to `order_items`
- grant customer direct inserts to `stock_reservations`
- grant customer direct inserts to `inventory_movements`
- allow client-set status values
- use service role in app/components
- bypass RLS from client code
- add self-promotion paths

## Audit Requirements

Audit every meaningful mutation:

- order created from draft
- stock reserved
- duplicate/idempotent order reuse if recorded
- reservation release/expiry
- customer confirmation
- cancellation
- future delivery quote approval/rejection
- future payment/settlement/commission transitions
