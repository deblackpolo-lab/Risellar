# Risellar Delivery Arrangement Phase 1 UI And Live QA Report

## A. Summary

Connected the supplier order detail UI to the audited `supplier_arrange_order_delivery` RPC. The UI records manual delivery arrangements for ready Pay on Delivery orders and then shows a read-only arrangement summary.

This is not a delivery-provider integration. Checkout, payment, rider assignment, live tracking, order delivery completion, stock commit/release, commissions, settlements, withdrawals, refunds, cancellations, and notifications remain deferred.

## B. UI Routes Connected

Connected:

- `/supplier/orders`
- `/supplier/orders/[id]`
- `/customer/orders/[id]` customer-safe read-only arrangement display

## C. Helper/Action Created

Added app-side delivery arrangement support in:

- `lib/orders/supplier-order-shared.ts`
- `lib/orders/supplier-order-read.ts`
- `app/supplier/orders/actions.ts`
- `app/supplier/orders/[id]/page.tsx`
- `components/supplier/supplier-order-rpc-screens.tsx`
- `lib/orders/customer-order-read.ts`
- `app/customer/orders/[id]/page.tsx`

Server action:

- `arrangeSupplierOrderDeliveryFormAction`

Helper:

- `arrangeSupplierOrderDeliveryWithClient`
- `buildArrangeSupplierOrderDeliveryPayload`

## D. Client Payload Safety

The supplier form sends only:

- order id
- delivery method
- optional agreed fee
- optional expected date
- optional expected time window
- optional courier/rider display name
- optional courier/rider phone
- optional customer instruction
- optional supplier private note
- idempotency key
- acknowledgement

The client does not send supplier IDs, customer IDs, reseller IDs, product IDs, variant IDs, order status, order total, currency override, stock values, reservation values, payment values, commission values, settlement values, or provider/rider/tracking data.

## E. UI Behavior

For `ready_for_delivery` orders, the supplier detail page shows an “Arrange delivery” form with explicit copy that the action:

- records a manual arrangement
- does not book a courier
- does not assign a rider
- does not collect payment
- does not mark the order delivered

For `delivery_arranged` orders, the form is hidden and the supplier sees a read-only summary with:

- method
- agreed fee
- expected date/window
- courier/rider display name and phone
- customer instruction
- supplier private note
- recorded timestamp

The supplier order list now groups arranged orders under “Arranged” and displays `Delivery arranged`.

The customer order detail page shows customer-safe delivery arrangement details and the notice that payment remains Pay on Delivery. Supplier private note is not displayed.

## F. Live Browser QA Result

Development supplier-owner session was verified by opening `/supplier/orders`.

A ready development Pay on Delivery order was opened from the Ready section. The manual arrangement form rendered with the expected controls and safety copy.

Submitted a fake development-only arrangement:

- method: third-party courier
- agreed fee: GHS 25.00
- expected date: August 1, 2026
- expected window: 2 PM - 5 PM
- courier/rider display name: development QA value
- courier/rider phone: development QA value
- customer instruction: development QA value
- supplier private note: development QA value

Browser result:

- success state displayed
- order status became `Delivery arranged`
- save form disappeared
- read-only arrangement summary displayed
- payment remained not collected
- order was not marked delivered
- supplier list moved the order to the Arranged section
- supplier list label patch fixed the initial `Order status unavailable` display issue

## G. Database Verification

Development database verification returned:

- order status is `delivery_arranged`
- payment collection remains `not_collected`
- one delivery arrangement row exists
- method, fee, and currency are server-resolved/stored correctly
- audit log exists
- reservation remains reserved
- no delivery quote rows for the order
- no payment table exists
- no commission rows for the order
- no settlement rows for the order

Same-key idempotency retry:

- arrangement rows stayed at 1
- audit events stayed at 1

Conflicting retry:

- blocked
- arrangement rows stayed at 1
- original method preserved
- audit events stayed at 1

Customer-safe read verification:

- customer order status label: `Delivery arrangement confirmed`
- customer delivery status label: `Delivery was arranged outside Risellar`
- method visible to customer
- customer instruction visible to customer
- customer notice visible
- supplier private note hidden

## H. Cross-Role And Privacy

Backend boundary tests verified customer, reseller, admin-staff, anonymous, and cross-supplier attempts are blocked.

Supplier private note is available only in supplier-safe read and not exposed through customer-safe read.

No service role is used in app/components. No direct table writes are used from client components.

## I. Console/Network/Runtime Findings

Browser console warnings were limited to expected Clerk development-key warnings.

No browser app runtime error was observed during the delivery arrangement submit/result flow.

Server log scan found prior Fast Refresh/auth-middleware warnings, but no delivery-arrangement 500 errors, token errors, raw RPC errors, payment requests, provider delivery requests, preparation requests, or finance requests for this QA path.

## J. Targeted Fixes Made

Live backend/QA found and fixed:

- ambiguous `on conflict (order_id)` in PL/pgSQL via named unique constraint patch
- customer-safe enum label casts via `::text`
- supplier list label support for `delivery_arranged`
- dev-only test harness context cleanup and schema fixture mismatch

## K. Fixture Cleanup

Rollback SQL harnesses clean their fixture changes with `rollback`.

The live browser QA retained one development order in `delivery_arranged` state as useful review evidence. No production or production-like data was used.

## L. Commands Run/Results

Targeted commands already passed:

- `npx vitest run tests/supplier-order-delivery-arrangement.test.ts` - passed
- `npx vitest run tests/supplier-order-ui.test.tsx` - passed
- `npx vitest run tests/customer-order-read.test.ts` - passed
- `npx supabase db query --linked --file scripts/rpc/supplier-order-delivery-arrangement-rpc-tests-dev-only.sql` - passed
- `npx supabase db query --linked --file scripts/rpc/supplier-order-delivery-arrangement-concurrency-tests-dev-only.sql` - passed

Final verification sequence:

- `git diff --check` - passed; only normal Windows LF-to-CRLF warnings were printed
- `npm test` - passed; 38 test files and 216 tests passed
- `npm run lint` - passed
- `npm run build` - passed
- `npm run typecheck` - passed
- `npx tsc --noEmit` - passed

Runtime check:

- The existing local dev server briefly served a stale Next runtime after production build verification. The port 400 dev server was restarted, and `http://localhost:400/` returned HTTP 200.
- A raw unauthenticated request to the protected supplier orders route returned a safe non-500 response after restart; the earlier stale module crash was not reproduced.

## M. Secret/Privacy Scan Result

Passed final scan:

- `.env.local` ignored
- `supabase/.temp` ignored
- `.next` ignored
- `.codex-dev-server.*.log` ignored
- no service role imports or service-role key usage in `app` or `components`
- no bearer tokens, passwords, API secrets, or production data found in delivery changes
- no private profile IDs, supplier IDs, JWTs, cookies, or database identifiers committed in these delivery reports
- broad secret scan hits were limited to older documentation lines that state no bearer tokens were found
- scope scan hits in changed delivery files were limited to negative tests and user-facing safety copy; no delivery-provider, payment, stock-release, finance, refund, cancellation, or notification mutation integration was added

## N. Files Changed

Expected intentional files:

- `supabase/migrations/20260730180000_supplier_order_delivery_arrangement_rpc.sql`
- `supabase/migrations/20260730183000_fix_delivery_arrangement_conflict_target.sql`
- `supabase/migrations/20260730184000_fix_delivery_arrangement_customer_enum_labels.sql`
- `supabase/migrations/20260730185000_fix_delivery_arranged_supplier_list_label.sql`
- `scripts/rpc/supplier-order-delivery-arrangement-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-delivery-arrangement-concurrency-tests-dev-only.sql`
- `lib/orders/supplier-order-shared.ts`
- `lib/orders/supplier-order-read.ts`
- `lib/orders/customer-order-read.ts`
- `app/supplier/orders/actions.ts`
- `app/supplier/orders/[id]/page.tsx`
- `app/customer/orders/[id]/page.tsx`
- `components/supplier/supplier-order-rpc-screens.tsx`
- `tests/supplier-order-delivery-arrangement.test.ts`
- `tests/supplier-order-ui.test.tsx`
- `tests/customer-order-read.test.ts`
- `docs/RISELLAR_DELIVERY_ARRANGEMENT_PHASE_1_BACKEND_REPORT.md`
- `docs/RISELLAR_DELIVERY_ARRANGEMENT_PHASE_1_UI_AND_LIVE_QA_REPORT.md`

## O. Current Git Status

Before staging, intentional delivery-arrangement changes were present in:

- `app/customer/orders/[id]/page.tsx`
- `app/supplier/orders/[id]/page.tsx`
- `app/supplier/orders/actions.ts`
- `components/supplier/supplier-order-rpc-screens.tsx`
- `lib/orders/customer-order-read.ts`
- `lib/orders/supplier-order-read.ts`
- `lib/orders/supplier-order-shared.ts`
- `tests/customer-order-read.test.ts`
- `tests/supplier-order-ui.test.tsx`
- `tests/supplier-order-delivery-arrangement.test.ts`
- `scripts/rpc/supplier-order-delivery-arrangement-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-delivery-arrangement-concurrency-tests-dev-only.sql`
- `supabase/migrations/20260730180000_supplier_order_delivery_arrangement_rpc.sql`
- `supabase/migrations/20260730183000_fix_delivery_arrangement_conflict_target.sql`
- `supabase/migrations/20260730184000_fix_delivery_arrangement_customer_enum_labels.sql`
- `supabase/migrations/20260730185000_fix_delivery_arranged_supplier_list_label.sql`
- `docs/RISELLAR_DELIVERY_ARRANGEMENT_PHASE_1_BACKEND_REPORT.md`
- `docs/RISELLAR_DELIVERY_ARRANGEMENT_PHASE_1_UI_AND_LIVE_QA_REPORT.md`

No-content metadata entries were also visible in git status (`next-env.d.ts`, `package.json`, `package-lock.json`, `tsconfig.json`) but had no file diff and were not part of the intentional staging set.

## P. Safe To Commit

Safe to commit after staging only the intentional Delivery Arrangement Phase 1 files.
