# Risellar Supplier Order Security and RLS Plan

## Security Boundary

Supplier Order Phase 1 must preserve the existing role boundaries:

- customer reads own customer order detail only
- reseller reads reseller-scoped commerce data only
- supplier reads only supplier-owned fulfillment slices
- admin uses separate admin contracts
- anonymous users cannot read supplier order data

All supplier writes must happen through audited RPCs. No client component may import service-role helpers or write directly to order, order item, stock reservation, variant, payment, delivery, commission, settlement, or withdrawal tables.

## Supplier Actor Rule

The future RPCs should authorize:

- active `supplier_owner` profile owning the supplier row
- optionally active `supplier_team_members` with `supplier_role = 'supplier_inventory_manager'` and explicit permission such as `orders.read` for reads or `orders.decide` for accept/reject

The first implementation can restrict accept/reject to supplier owners only if staff permissions are not ready. If inventory manager support is added, it must be permission-based and supplier-scoped.

## Data Privacy

Supplier may see:

- supplier-owned product snapshot
- quantity
- supplier amount expected
- Pay on Delivery status
- payment not collected
- fulfilment delivery snapshot
- customer recipient name and phone only when needed to fulfil the order
- reservation status and deadline

Supplier must not see:

- reseller private contact
- reseller login identity
- reseller margin strategy
- platform margin unless later operationally required
- supplier payout/KYC/private internal data not relevant to the order
- settlement verification controls
- reseller commission release controls
- payment provider data
- admin/risk notes
- unrelated customer account metadata
- another supplier's order item

## RLS and Grants

Recommended pattern:

- keep base table write access restricted
- expose supplier reads through `SECURITY DEFINER` safe RPCs with fixed return columns
- grant execute only to `authenticated`
- use `current_profile_id()` and supplier-membership helpers server-side
- return no rows for unauthorized reads instead of leaking existence
- avoid broad `USING (true)` or `WITH CHECK (true)`
- never grant suppliers direct write access to order status or stock counters

## Direct Mutation Blocks

Suppliers must not be able to:

- set arbitrary `orders.order_status`
- mutate `orders.payment_collection_status`
- mutate delivery status or quote status
- alter order-item commercial snapshots
- change final customer price
- release commission
- create settlement rows
- create withdrawals
- directly decrement or increment stock counters

## Audit Requirements

Decision RPCs should write audit events for:

- `supplier_order_accepted`
- `supplier_order_rejected`
- `stock_reservation_released`
- `reserved_stock_decremented`
- `duplicate_supplier_action_reused`
- `invalid_supplier_transition_blocked`

Read auditing, if approved, may record `supplier_order_viewed`, but it should not log full customer contact/address snapshots.

## Production Safety

Development implementation and QA must use the confirmed development Supabase project only. No production Supabase connection, production data, migration repair, destructive reset, or secret printing is allowed.
