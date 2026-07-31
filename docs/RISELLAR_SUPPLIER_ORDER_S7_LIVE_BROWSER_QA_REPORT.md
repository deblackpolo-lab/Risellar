# Risellar Supplier Order Handling S7 Live Browser QA Report

## A. Summary

Live browser QA was completed in the confirmed development environment with the approved supplier_owner account masked as `bl***@gmail.com`.

The supplier order list/detail UI loaded, one dev-only pending order was accepted through the browser, and a different dev-only pending order was rejected through the browser. Database verification confirmed the expected status, reservation, stock, idempotency, customer-safe status, and side-effect boundaries.

Later Delivery Phase 2 browser QA reused the accepted development order after delivery arrangement and verified the `delivery_arranged` -> `out_for_delivery` transition through the supplier UI. See `docs/RISELLAR_DELIVERY_PHASE_2_OUT_FOR_DELIVERY_UI_AND_LIVE_QA_REPORT.md`.

## B. Supplier Session Verification

`/auth/qa-profile-sync` confirmed:

- authenticated session
- active profile
- primary role `supplier_owner`

Read-only development Supabase verification confirmed:

- supplier account status active
- supplier verification approved

No profile IDs, supplier IDs, JWTs, cookies, session data, or database identifiers are recorded in this report.

## C. Initial Order List Result

`/supplier/orders` loaded for the signed-in supplier account.

The existing visible pending orders were scoped to the supplier account but had `Reservation unavailable`, so they were not valid S7 accept/reject targets.

Two isolated development-only QA orders were prepared for this supplier account using the supplier-order RPC boundary fixture pattern:

- one accept target
- one reject target

Setup verification confirmed:

- two pending orders created
- both order items were scoped to the signed-in supplier account
- both reservations were active and reserved
- stock baseline had two reserved units
- no delivery quote, commission, or settlement rows were created for the QA orders

## D. Order Detail Privacy Result

Both QA order detail pages showed supplier-safe operational fields:

- product name
- quantity and variant label
- supplier expected amount
- customer total
- Pay on Delivery
- payment not collected
- reservation status
- fulfilment contact snapshot
- safe reseller shop context

No internal/private fields were visible:

- no customer email
- no platform margin
- no reseller margin
- no commission details
- no settlement details
- no risk/internal/admin fields
- no raw database identifiers

## E. Live Accept Result

The accept target was accepted through the browser UI.

The UI required the acknowledgement:

`Confirm that you can fulfil this order. Stock is already reserved.`

After submit and refresh, the detail page showed:

- `Supplier confirmed`
- payment still `Payment not collected`
- reservation still `Stock reserved`
- terminal decision copy: preparation will be added in a later phase

## F. Accept Database Effect

Development database verification confirmed:

- order status became `supplier_confirmed`
- reservation remained `reserved`
- payment collection remained `not_collected`
- accepted reservation quantity remained present
- no delivery quote, commission, or settlement row was created

Accept retry with the same idempotency key did not add a duplicate audit event.

## G. Live Reject Result

The reject target was rejected through the browser UI with reason `unable_to_fulfil`.

After submit and refresh, the detail page showed:

- `Rejected - stock released`
- payment still `Payment not collected`
- reservation `Reservation released`
- terminal decision copy: reserved stock has been released

## H. Reject Database Effect

Development database verification confirmed:

- order status became `supplier_rejected`
- reservation became `released`
- `released_at` was populated
- reserved stock decreased exactly once
- total stock stayed unchanged
- sold stock stayed unchanged
- reserved stock remained non-negative
- no delivery quote, commission, or settlement row was created

Reject retry with the same idempotency key did not add duplicate audit events or a duplicate stock movement.

## I. Supplier List Refresh Result

After refreshing `/supplier/orders`:

- the accepted QA order appeared under Confirmed
- the rejected QA order appeared under Rejected
- neither QA order remained under New orders

## J. Customer-Safe Status Result

Customer-safe read verification confirmed:

- accepted order label: `Supplier confirmed your order`
- rejected order label: `Supplier could not fulfil this order`
- private supplier rejection reason/note was not exposed to the customer-safe read payload

## K. Cross-Role And Cross-Supplier Protection

Automated route-policy tests confirm:

- supplier_owner can access `/supplier/orders`
- customer cannot access supplier orders
- reseller cannot access supplier orders
- admin_staff alone cannot access supplier orders

Development SQL verification under a customer context confirmed customer users cannot call the supplier decision RPC.

Cross-supplier ownership is enforced by the audited supplier order RPC boundary tests and the supplier read/decision implementation, which routes through current supplier context instead of accepting supplier IDs from the client.

## L. Console, Network, And Server Logs

Browser console findings:

- normal React DevTools development notice
- normal Clerk development-key warning
- Fast Refresh logs during local development

No browser console 500 errors, raw RPC errors, Supabase token errors, payment calls, delivery calls, preparation calls, or finance calls were observed.

Server log findings:

- `/supplier/orders` returned 200
- accept detail returned 200
- accept POST returned 303 once
- reject detail returned 200
- reject POST returned 303 once
- final `/supplier/orders` returned 200
- no 500 errors observed

After `next build`, the local development server briefly served stale 404 responses for protected app routes because the production `.next` output collided with the running dev cache. The `.next` directory was moved into ignored `.local-recovery/runtime-cache/` and the local port 400 dev server was restarted. Authenticated browser runtime checks then loaded `/auth/qa-profile-sync` and `/supplier/orders` successfully.

## M. Fixture Cleanup Result

Temporary SQL helper files were kept only under ignored `.local-recovery/s6s7/` for local recovery evidence and are not staged.

The two accepted/rejected development QA orders were retained because they are useful terminal review records for S7 evidence. Temporary setup rows are development-only and marked with `S6S7` names/order numbers.

## N. Commands Run And Results

- `/auth/qa-profile-sync` browser check - passed.
- `/supplier/orders` browser check - passed.
- Dev-only QA order setup SQL - passed.
- Browser accept action - passed.
- Browser reject action - passed.
- Database/idempotency/customer-safe verification SQL - passed.
- `npm test -- tests/supplier-order-ui.test.tsx tests/supplier-order-decision.test.ts tests/supplier-order-read.test.ts tests/phase6.test.tsx` - passed.

Full final verification results will be added after the final command sweep.

- `git diff --check` - passed with Windows line-ending warnings only.
- `npm test` - passed, 35 files and 191 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- `npx tsc --noEmit` - passed.
- Final authenticated browser runtime check - passed for `/auth/qa-profile-sync` and `/supplier/orders`.

## O. Security And Privacy Scan

Passed final scan:

- `.env.local` is ignored and unstaged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored and unstaged.
- `.local-recovery` is ignored and unstaged.
- no real Clerk/Supabase/service-role values were found in docs/source.
- no service role import/use was found in app/components for this flow.
- no bearer tokens, passwords, API secrets, cookies, JWTs, or production data were committed.
- no payment, delivery, preparation, commission, settlement, withdrawal, refund, or cancellation integration was added.

## P. Current Status

S7 browser QA passed, final automated verification passed, and the implementation is safe to commit.
