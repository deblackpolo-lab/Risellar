# Risellar Checkout Phase C C4 Test And Browser QA Plan

## Summary

This plan defines tests and manual QA for future checkout order-confirmation UI wiring. It does not run RPC boundary tests, migrations, production checks, or live order creation.

## Unit And Source Tests

Future tests should verify:

- final confirmation action only accepts `checkout_draft_id`, acknowledgement, and optional idempotency key
- client cannot submit price, product id, reseller id, supplier id, stock, margin, status, settlement, commission, withdrawal, payment, or delivery fields
- missing acknowledgement is blocked before the RPC call
- invalid draft id is blocked before the RPC call
- server action calls `create_order_from_checkout_draft`
- server action does not use service role
- server action uses user-context Supabase auth
- duplicate submit uses idempotency safely
- `INSUFFICIENT_STOCK` maps to a clear no-order-created message
- errors do not expose SQL details, table names, internal ids, tokens, or stack traces
- final CTA remains disabled until the implementation group explicitly enables it

## Customer Order Read Tests

C5 tests should verify:

- customer can read own order through the safe read contract
- customer cannot read another customer's order
- reseller cannot read a customer order through customer routes
- supplier cannot read a customer order through customer routes
- unauthenticated user is blocked
- sensitive supplier/reseller/admin/finance fields are not mapped
- order list, if implemented, returns only the signed-in customer's own orders

## Browser QA Plan

Future browser QA should use development-only accounts and data:

1. Sign in as a development customer.
2. Open a public shop product with an active approved listing.
3. Start a checkout draft.
4. Attach a saved customer delivery address.
5. Confirm the final button is disabled before the approved implementation group.
6. After implementation, check the acknowledgement is required.
7. Place one order through the UI.
8. Verify success route loads through customer-safe order read.
9. Verify customer order detail loads.
10. Verify duplicate click or refresh does not create a second order.
11. Verify insufficient stock shows a clear error and no order is created.
12. Verify unauthenticated users redirect to Clerk.
13. Verify reseller/supplier/admin route isolation remains unchanged.

## Database Side-Effect Verification

Expected side effects only after the future final submit is intentionally enabled:

- one order row
- one order item row
- one stock reservation row
- one inventory movement row
- expected audit rows
- checkout draft marked converted or no longer active according to the RPC contract

Must remain zero or untouched:

- payments
- delivery quotes
- delivery tracking
- supplier preparation rows
- supplier notifications, unless a future phase explicitly adds them
- commissions
- settlements
- withdrawals
- refunds

## Manual QA Stop Conditions

Stop and report if:

- any production project is detected
- any secret/token would need to be printed
- final order button becomes enabled before approved implementation
- browser exposes price or margin fields from the client
- any payment, delivery, commission, settlement, or withdrawal side effect appears
- direct table mutation from a client component is found
- concurrency or idempotency behavior differs from R7 expectations

## Current C4 Verification Scope

C4 validation is limited to:

- source audit
- planning documents
- normal local verification commands
- secret/scope scan

C4 intentionally does not run:

- `npx supabase db push`
- `npx supabase migration repair`
- RPC boundary tests
- true concurrency tests
- browser order creation
