# Risellar Supplier Fulfilment Phase 2 UI And Live QA Report

## A. Summary

Supplier Fulfilment Phase 2 connects the supplier order detail UI to the audited `supplier_start_preparing` RPC.

The UI now supports starting preparation for accepted Pay on Delivery orders only. It does not expose delivery, payment collection, ready-for-delivery, commission, settlement, withdrawal, refund, cancellation, admin transition, or notification controls.

## B. Supplier Session Verification

`/auth/qa-profile-sync` confirmed the browser session was:

- authenticated
- profile active
- primary role `supplier_owner`

The supplier account used for QA is masked as `bl***@gmail.com`.

No profile IDs, supplier IDs, customer IDs, reseller IDs, order IDs, JWTs, cookies, tokens, Clerk session values, or project identifiers are recorded in this report.

## C. Supplier Helper And Server Action

Created:

- `lib/orders/supplier-order-preparation.ts`

Updated:

- `lib/orders/supplier-order-read.ts`
- `app/supplier/orders/actions.ts`

The server action:

- calls `supplier_start_preparing`
- uses Clerk native user-context Supabase auth
- accepts only order id, idempotency key, and acknowledgement
- uses stable idempotency key prefix `supplier-start-preparing:`
- revalidates supplier order list/detail paths
- maps errors safely
- does not use the service role
- does not mutate tables directly

## D. UI Behavior

Updated:

- `/supplier/orders`
- `/supplier/orders/[id]`

List grouping now includes:

- New orders
- Confirmed
- Preparing
- Rejected

Button visibility:

- pending order: Accept/Reject visible, Start preparing hidden
- confirmed order: Start preparing visible, Accept/Reject hidden
- preparing order: no action controls, durable Preparing order state shown
- rejected order: no action controls
- expired/unavailable reservation: Start preparing unavailable

Confirmed-order copy:

- `Start preparing this order only when you are ready to begin fulfilment. Delivery and payment are handled later.`

Acknowledgement:

- `Confirm that you are starting preparation for this order.`

Success:

- `Order preparation started`

Preparing state:

- `You have started preparing this order. Delivery arrangement will be added in a later phase.`

## E. Live Browser QA

The signed-in development supplier_owner opened `/supplier/orders`.

Before action, the selected development QA order showed:

- `Supplier confirmed`
- `Payment not collected`
- `Stock reserved`
- Start preparing visible
- Accept/Reject hidden
- no Ready for delivery control
- no Collect payment control

The Start preparing button was disabled until the acknowledgement checkbox was selected.

After clicking Start preparing once:

- success message appeared
- status changed to `Preparing order`
- Start preparing disappeared
- payment remained `Payment not collected`
- reservation remained `Stock reserved`
- no Ready for delivery control appeared
- no Collect payment control appeared

Refreshing `/supplier/orders` showed:

- Confirmed section no longer contained the QA order
- Preparing section contained the QA order
- Rejected section remained separate

## F. Database Verification

Before live action:

- order status was `supplier_confirmed`
- preparation timestamp absent
- payment status `not_collected`
- reservation status `reserved`
- reservation quantity `1`
- reserved stock `1`
- total stock `20`
- sold stock `0`
- preparation audit events `0`
- delivery quote rows `0`
- commission rows `0`
- settlement rows `0`

After live action:

- order status `supplier_preparing`
- preparation timestamp present
- payment status `not_collected`
- reservation status `reserved`
- reservation quantity `1`
- reserved stock `1`
- total stock `20`
- sold stock `0`
- preparation audit events `1`
- delivery quote rows `0`
- commission rows `0`
- settlement rows `0`

Payments, refunds, cancellations, and preparation sub-record tables are not present in this schema, so those flows remain unimplemented.

## G. Idempotency QA

Retried `supplier_start_preparing` with the same idempotency key under the supplier context.

Result:

- returned `Preparing order`
- payment label remained `Payment not collected`
- reservation label remained `Stock reserved`
- reservation status remained `reserved`
- reserved stock remained `1`
- sold stock remained `0`
- persisted preparation audit count remained `1`

No second transition, audit event, stock change, reservation change, or side effect occurred.

## H. Customer-Safe Status

Customer-safe read RPC verification returned:

- `Supplier is preparing your order`
- `Payment not collected`
- `Delivery not arranged yet`
- `Stock reserved for this order`

No supplier private notes or internal fields are exposed in the customer-safe status.

## I. Role And Ownership Protection

Development SQL boundary tests confirmed:

- cross-supplier calls are blocked
- customer calls are blocked
- reseller calls are blocked
- admin_staff calls are blocked
- anonymous calls are blocked
- missing/unauthorized order behavior is non-enumerating

The UI/server action does not accept supplier ids or other ownership selectors from the browser.

## J. Console, Network, And Runtime Findings

During QA, an older stale `.next` chunk error appeared from the running dev server after prior build activity. The port 400 dev server was stopped and restarted. After restart:

- `/auth/qa-profile-sync` returned 200
- `/supplier/orders` returned 200
- supplier order detail returned 200
- Start preparing POST returned 303 once
- success detail returned 200
- refreshed supplier list returned 200

Browser console after restart showed only expected Clerk development-key warnings. No current HTTP 500, raw RPC errors, token errors, duplicate action requests, delivery requests, payment requests, preparation-subsystem requests, or finance requests were observed.

## K. Targeted Fixes

Implemented targeted source changes only:

- supplier start-preparing RPC wrapper
- server action
- confirmed/preparing UI states
- safe error mapping for preparation states
- status grouping for Preparing orders
- focused automated tests

No unrelated business flows were connected.

## L. Commands Run

- `npx vitest run tests/supplier-order-preparation.test.ts` - passed.
- `npx vitest run tests/supplier-order-ui.test.tsx` - passed.
- `npx supabase db push --dry-run --include-all` - passed.
- `npx supabase db push --include-all` - passed against development.
- `npx supabase db query --linked --file scripts/rpc/supplier-order-start-preparing-rpc-tests-dev-only.sql` - passed.
- `npx supabase db query --linked --file scripts/rpc/supplier-order-start-preparing-concurrency-tests-dev-only.sql` - passed.
- `git diff --check` - passed with Windows line-ending warnings only.
- `npm test` - passed, 36 files / 198 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- `npx tsc --noEmit` - passed.

## M. Secret And Scope Scan

Confirmed:

- `.env.local` not staged
- `.local-recovery/` not staged
- `.next/` not staged
- `supabase/.temp/` not staged
- `.codex-dev-server.*.log` not staged
- no service-role imports in app/components
- no JWTs, cookies, tokens, credentials, project identifiers, private database identifiers, bearer tokens, API secrets, or production data in committed source/report content
- no delivery/payment/finance implementation added

## N. Files Changed

- `app/supplier/orders/[id]/page.tsx`
- `app/supplier/orders/actions.ts`
- `components/supplier/supplier-order-rpc-screens.tsx`
- `lib/orders/supplier-order-preparation.ts`
- `lib/orders/supplier-order-read.ts`
- `lib/orders/supplier-order-shared.ts`
- `scripts/rpc/supplier-order-start-preparing-concurrency-tests-dev-only.sql`
- `scripts/rpc/supplier-order-start-preparing-rpc-tests-dev-only.sql`
- `supabase/migrations/20260730150000_supplier_order_start_preparing_rpc.sql`
- `tests/supplier-order-preparation.test.ts`
- `tests/supplier-order-ui.test.tsx`
- `docs/RISELLAR_SUPPLIER_FULFILMENT_PHASE_2_BACKEND_REPORT.md`
- `docs/RISELLAR_SUPPLIER_FULFILMENT_PHASE_2_UI_AND_LIVE_QA_REPORT.md`

## O. Current Status

Supplier Fulfilment Phase 2 passed backend, UI, live browser, idempotency, customer-safe status, and no-side-effect verification.

It is safe to commit if final verification remains green.

## P. Deferred

Still deferred:

- delivery
- rider assignment
- delivery fees
- Ready for Delivery
- Out for Delivery
- Delivered
- payment collection
- Pay on Delivery collected
- commission release
- settlement
- withdrawals
- refunds
- cancellation
- admin order transitions
- supplier/customer notifications
