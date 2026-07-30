# Risellar Recovery Phase 4 Route Boundary Policy

Date: 2026-07-30

## Boundary

Phase 4 keeps currently proven foundations live and blocks any unapproved business workflow from behaving like it is connected.

## Allowed Live Surface

- Clerk auth and profile sync.
- Customer Phase A contact and delivery address management.
- Reseller approved product catalog browsing.
- Reseller add-to-shop and listing management foundations already tested.
- Public reseller shop read-only browsing.
- Supplier product management through tested product RPCs.
- Admin onboarding request review.
- Admin supplier product approval review.

## Blocked Until Later Approval

- Checkout order creation.
- Customer purchase flow.
- Stock reservation.
- Supplier order preparation.
- Delivery quotes or delivery dispatch.
- Payments or payment proof submission.
- Settlements.
- Commission release.
- Withdrawals.

## UI Rule

Routes for blocked workflows may exist only as static, mock-only, or coming-soon pages. Buttons that imply irreversible or live business actions must be disabled or clearly labelled as coming soon.

## Navigation Rule

Primary navigation should only promote proven live routes. Mock-only order, settlement, commission, withdrawal, payment, and supplier-preparation routes should not be linked as active workflows from role dashboards or tab bars.

## Customer Fallback Rule

Completed customer profiles should land on `/customer/addresses` while checkout/order UI is deferred. They should not land on `/customer/orders`.

## Backend Rule

No migration, Supabase db push, RPC change, RLS change, service-role exposure, or live business data integration is allowed in Phase 4.

## Reintroduction Rule

Checkout draft UI can be reintroduced only after this cleanup holds:

- Customer order routes are not the role fallback.
- Checkout action buttons are disabled or draft-only.
- Admin and role dashboards do not advertise unapproved order/finance workflows.
- Tests verify the route boundary.
- Browser QA confirms live pages still render after cleanup.
