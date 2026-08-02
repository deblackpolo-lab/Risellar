# Risellar Dispute Security and RLS Plan

## Principles

- RLS must be enabled and forced on all future dispute, return, refund, evidence, response, hold, and adjustment tables.
- Mutations must go through narrow audited RPCs.
- Direct table grants must remain minimal.
- Admin authority must use active `admin_staff` membership and role helpers, not `profiles.primary_role = 'admin'` alone.
- Service role must not be imported or used in app/components or normal user flows.
- Frontend inputs must never be trusted for role, owner IDs, prices, max refund, commission, settlement, stock, or status transitions.

## Actor Model

Customer:

- Own profile/order/dispute only.
- Can open/respond to own order disputes within allowed windows.
- Cannot see supplier private notes, admin private notes, finance internals, or reseller commission.

Supplier owner/staff:

- Supplier-scoped disputes only.
- Can respond, confirm return receipt, report condition, and report refund sent only for own supplier orders.
- Cannot final-resolve own disputes or perform finance verification.

Reseller:

- Own commission-impact summaries only.
- Cannot see private customer claim details, supplier evidence, admin notes, settlement proof, or payout data.
- Cannot resolve disputes.

Support/admin:

- Active `admin_staff` with `support_staff`, `admin`, or `super_admin` may handle non-finance dispute actions according to permission.
- Finance adjustment requires active `finance_staff` or `super_admin`.
- Sensitive override requires `super_admin`.

Inventory:

- Supplier owner or authorised inventory staff may classify returned item condition for own supplier items.
- Admin inventory override requires audited admin role.

## Future Tables

Potential tables:

- `order_disputes`
- `dispute_messages`
- `dispute_status_history`
- `dispute_evidence`
- `return_requests`
- `return_inspections`
- `refund_obligations`
- `refund_proofs`
- `finance_holds`
- `dispute_finance_adjustments`
- `dispute_appeals`

D2 drafts `order_disputes`, `dispute_messages`, and `dispute_status_history` as a separate core foundation. Earlier `disputes`, `returns`, and `refunds` planning names remain compatible concepts, not a mandate to activate dormant structures.

## RPC Boundaries

Customer RPCs:

- `customer_open_order_dispute`
- `get_customer_dispute_safe`
- `list_customer_disputes_safe`
- `customer_add_dispute_response`

Supplier RPCs:

- `list_supplier_disputes_safe`
- `get_supplier_dispute_safe`
- `supplier_add_dispute_response`
- `supplier_confirm_return_received`
- `supplier_report_return_condition`
- `supplier_report_refund_sent`

Reseller RPCs:

- `list_reseller_dispute_impacts_safe`
- `get_reseller_dispute_impact_safe`

Admin/support RPCs:

- `list_admin_disputes_safe`
- `get_admin_dispute_safe`
- `admin_request_dispute_information`
- `admin_approve_return`
- `admin_reject_return`
- `admin_set_dispute_resolution`
- `admin_close_dispute`

Finance RPCs:

- `admin_approve_refund_obligation`
- `admin_record_refund_completion`
- `admin_apply_dispute_finance_hold`
- `admin_release_dispute_finance_hold`
- `admin_apply_dispute_finance_adjustment`

Inventory RPCs:

- `supplier_classify_returned_item`
- `admin_verify_return_inventory_adjustment`

Avoid one broad update RPC.

## Storage and Evidence

Evidence should use private Supabase Storage with:

- file-type allowlist
- size limits
- signed URLs
- role-scoped access checks
- no public buckets
- no executable uploads
- no raw object paths in client-safe responses
- malware/content scanning plan before broad launch
- audit of uploads, downloads, and admin evidence access
- retention and deletion policy

Phase 1 implementation may start text-only if evidence storage expands scope too much.

## Safe Reads

Safe read RPCs must return role-specific shapes:

- customer safe read: status, next action, own messages, approved public messages, return/refund progress.
- supplier safe read: order context needed to respond, customer claim, no private customer account metadata.
- reseller safe read: commission impact only.
- admin safe read: full authorised case, with finance details only for finance roles and payout data masked.

## RLS Test Requirements

Tests must prove:

- anonymous blocked
- customer cannot access another customer's dispute/order/address
- supplier cannot access another supplier's dispute/order/evidence
- reseller cannot access raw case details
- support cannot perform finance adjustment
- finance_staff cannot bypass customer/supplier ownership for non-finance actions unless explicitly approved
- super_admin sensitive overrides are audited
- private evidence cannot be downloaded by unauthorised actors

## No Self-Promotion

No dispute, finance, or support UI may let users grant themselves customer/supplier/reseller/admin/finance roles.

## D8 Refund Workflow Security Addendum

D8 implements `public.order_refunds` and `public.refund_actions` with RLS enabled and forced. Direct table privileges are revoked from `public`, `anon`, and `authenticated`; browser roles mutate refund state only through explicit RPCs and read only through role-shaped safe-read RPCs.

Finance-only refund mutations require active `admin_staff` membership with `finance_staff` or `super_admin`. Support/admin investigation roles cannot approve or verify monetary refunds. Supplier refund-sent reporting is scoped to the affected active approved supplier. Customer confirmation is scoped to the refund owner.

D8 also adds a SECURITY DEFINER cumulative-cap trigger that rechecks immutable item, delivery-fee, and order caps on cap-bearing refund rows. It does not grant direct table access and does not weaken RLS, RPC, storage, settlement, commission, wallet, withdrawal, stock, notification, order, or payment boundaries.
