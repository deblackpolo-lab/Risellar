# Risellar Supplier Fulfilment Phase 3 UI And Live QA Report

## Summary

Supplier UI now supports marking a preparing Pay on Delivery order as ready for a future delivery arrangement through the audited `supplier_mark_ready_for_delivery` RPC.

This is not delivery booking, rider assignment, payment collection, stock commitment, commission release, or settlement.

## Supplier Helper And Action

Updated:

- `lib/orders/supplier-order-read.ts`
- `lib/orders/supplier-order-ready-for-delivery.ts`
- `app/supplier/orders/actions.ts`
- `app/supplier/orders/[id]/page.tsx`

The server action accepts only:

- `order_id`
- `idempotency_key`
- `ready_for_delivery_acknowledgement`

It calls only:

- `supplier_mark_ready_for_delivery`

It does not accept or send supplier IDs, customer IDs, product IDs, reservation IDs, stock, price, status, payment, or delivery data.

## Supplier UI

Updated:

- `components/supplier/supplier-order-rpc-screens.tsx`

Control visibility:

- pending: Accept/Reject visible, Mark ready hidden
- confirmed: Start preparing visible, Mark ready hidden
- preparing: Mark ready visible
- ready: no supplier action controls
- rejected: no supplier action controls

The ready control copy says preparation must be complete and delivery arrangement is separate.

The ready terminal copy says the order is prepared and waiting for delivery arrangement, with no rider or delivery fee confirmed.

No Book rider, Assign rider, Set delivery fee, Out for delivery, Mark delivered, Collect payment, Release commission, or settlement control was added.

## Targeted Fix

Focused UI testing found a state-coupling bug where the preparation acknowledgement checkbox state could carry into the ready acknowledgement after rerender.

Fix:

- split ready acknowledgement into its own `readyAcknowledged` state

Regression:

- supplier UI test now confirms the Mark ready button starts disabled and only enables after the ready acknowledgement.

## Live Development QA

Session:

- authenticated approved development supplier_owner account
- report keeps account and private identifiers omitted

Pre-action browser result:

- supplier order detail loaded
- status showed preparing
- Mark ready for delivery visible
- Accept/Reject hidden
- Start preparing hidden
- no delivery/payment/finance controls visible

Pre-action database result:

- status was `supplier_preparing`
- preparation timestamp existed
- ready timestamp absent
- reservation was `reserved`
- payment was `not_collected`
- ready audit event count was zero
- stock counters were unchanged from the retained QA fixture baseline

## Fixture Note

The retained development QA order initially had an expired reservation. The first browser submission correctly failed with `RESERVATION_EXPIRED` and did not transition the order.

Because this was clearly the retained development-only QA fixture, only its reservation expiry was refreshed for QA. No stock, payment, delivery, commission, settlement, withdrawal, refund, or cancellation data was created or changed.

## Live Mark-Ready Result

After refreshing the dev-only fixture reservation:

- browser action submitted through the supplier UI
- database status became `ready_for_delivery`
- ready timestamp was populated
- preparation timestamp remained present
- reservation remained `reserved`
- payment remained `not_collected`
- one ready audit event existed
- total stock unchanged
- reserved stock unchanged
- sold stock unchanged
- no delivery/payment/finance side effects were created

The page was reloaded without the stale error query and showed durable ready state:

- Ready for delivery visible
- Mark ready hidden
- terminal ready copy visible
- payment remained not collected
- no delivery/payment/finance controls visible

## Idempotency QA

Same-key retry through the RPC boundary:

- returned durable ready state
- audit event count remained one
- ready timestamp remained present
- reservation remained reserved
- stock counters remained unchanged

## Customer-Safe Status

Customer-safe RPC verification showed:

- `Your order is ready for delivery arrangement`
- `Payment not collected`
- `Delivery has not been arranged yet`
- stock reserved wording

No supplier private details, ready actor, idempotency key, rider, fee, tracking, or delivery-provider details were exposed.

## Cross-Role And Ownership

SQL boundary tests verified:

- cross-supplier blocked
- customer blocked
- reseller blocked
- admin staff blocked
- anonymous blocked
- missing order remains unavailable/non-enumerating

## Console And Network

Browser console findings:

- expected Clerk development-key warnings only
- no browser runtime errors on the supplier ready page
- no raw RPC error after successful transition
- no payment, delivery, rider, preparation-subrecord, commission, settlement, or finance request observed

## Runtime Route Sweep

Initial result:

- `/`
- `/supplier/orders`
- supplier ready order detail

The first post-build route sweep exposed a stale local dev-server `.next` artifact issue on unrelated routes after `next build`.

Resolution:

- identified the exact Node.js process listening on port 400
- confirmed it was the local Risellar Next development server
- stopped only that PID
- confirmed port 400 was free
- cleared only the ignored `.next` generated cache
- restarted the Risellar dev server on port 400
- confirmed the fresh server reported ready

Final route sweep passed:

- `/`
- `/sign-in`
- `/sign-up`
- known public shop route
- known public product route
- `/supplier/orders`
- supplier ready order detail

Results:

- no stale vendor chunk errors
- no missing module errors
- no RSC manifest errors
- no hydration failure text
- no HTTP 500 responses in fresh server logs for the checked routes
- only expected Clerk development warnings were observed

## Commands Run

- focused Vitest contract and UI tests
- SQL boundary test
- SQL concurrency/idempotency test
- live browser supplier QA
- live DB verification queries
- customer-safe read verification query
- browser console log inspection
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- `npx tsc --noEmit`
- final fresh-server runtime route sweep

## Result

Supplier Fulfilment Phase 3 backend, core supplier ready UI, live browser QA, final automated verification, and final runtime route sweep are implemented and verified.

Safe to commit the intentional Phase 3 files.
