# Risellar Payment Phase 1 Supplier-Reported UI And Live QA Report

## A. Summary

Connected the supplier order detail UI to the audited `supplier_report_order_payment_received` RPC through a server action. Live browser QA verified the approved development supplier can report Pay on Delivery payment received for a delivered order, and the UI moves the order into the payment-reported state without completing settlement or releasing commission.

## B. Supplier Session Verification

Browser session was refreshed through `/auth/qa-profile-sync`.

Confirmed:

- session authenticated
- profile active
- role signal: `supplier_owner`

Account details are intentionally masked in reports. No profile IDs, supplier IDs, JWTs, cookies, tokens, Clerk session data, or database identifiers are recorded here.

## C. UI Routes Tested

Routes tested:

- `/auth/qa-profile-sync`
- `/supplier/orders`
- `/supplier/orders/[id]`

The supplier order list loaded and showed the relevant delivered Pay on Delivery development order under the Delivered section before reporting.

## D. Payment Report Form

The delivered order detail page showed:

- safe order status
- supplier expected amount
- customer total
- Pay on Delivery payment method
- payment not collected state
- stock reserved state
- delivery timeline
- payment reporting warning
- optional payment reference input
- optional private payment note input
- required acknowledgement checkbox
- `Report payment received` submit button

The UI did not expose editable amount, currency, stock, commission, settlement, completion, withdrawal, payment-provider, or delivery-provider fields.

## E. Live Submit Result

Submitted fake/dev-only QA values through the browser. The server action redirected back with a success message.

Visible result:

- order status: `Payment reported - settlement pending`
- payment status: `Payment reported by supplier`
- reservation status: `Stock committed`
- payment reported timeline step became current
- payment report summary appeared
- platform amount due appeared as pending
- reseller commission due appeared as locked
- settlement status showed pending settlement
- commission status showed locked until settlement verification

The submit button disappeared after the report, preventing a second browser submission from the terminal state.

## F. Database Verification

Read-only development Supabase verification confirmed:

- order status became `payment_reported`
- payment status became `supplier_reported`
- payment reported timestamp was set
- idempotency key was recorded
- supplier payment report count became 1
- settlement due/unverified count became 1
- locked commission count became 1
- reservation became committed
- reserved stock decreased from 1 to 0
- sold stock increased from 0 to 1
- total stock remained unchanged
- sale-committed movement count became 1
- payment-report audit event existed
- withdrawal count stayed 0

No private IDs are included in this report.

## G. Idempotency And Double-Submit

Development-only RPC boundary and concurrency guard scripts passed. They verified same-key retry does not duplicate reports, settlements, commissions, audit events, stock movements, or stock changes, and conflicting retry is blocked.

## H. Customer-Safe Read Verification

Customer-safe read verification passed under simulated customer context:

- customer order label indicates supplier-reported payment
- payment collection label indicates supplier-reported payment
- customer notices say Risellar has not independently verified payment/settlement
- supplier private payment note is not exposed

## I. Runtime Logs

Browser/server runtime checks found:

- no 500 errors
- no raw RPC stack trace exposed
- no token/auth errors during submit
- no payment-provider requests
- no delivery-provider requests
- no preparation/finance-provider requests
- normal Next.js dev compile/HMR output
- expected Clerk development-key warning
- existing Clerk middleware deprecation warning

## J. Security And Scope Checks

Confirmed:

- service role is not used in app/components for this flow
- submit uses server action/server-only helper
- supplier cannot edit financial/stock/status fields from the browser
- customer-safe read hides supplier private payment note
- no order completion was added
- no settlement verification was added
- no commission release was added
- no withdrawal was added
- no online payment provider was connected
- no new delivery provider flow was connected
- no production Supabase connection was used

## K. Commands Run

Commands run so far:

- `npx vitest run tests/supplier-order-payment-reported.test.ts tests/supplier-order-ui.test.tsx` passed after test assertion tightening
- `git diff --check` passed
- `npx supabase --version` returned `2.109.1`
- `npx supabase db push --dry-run` passed
- first `npx supabase db push` stopped on a missing helper reference
- migration fixed to use existing `public.has_admin_role('finance_staff')`
- `npx supabase db push --dry-run` passed again
- `npx supabase db push` succeeded against development
- `npx supabase db query --linked --file scripts/rpc/supplier-order-payment-reported-rpc-tests-dev-only.sql` passed
- `npx supabase db query --linked --file scripts/rpc/supplier-order-payment-reported-concurrency-tests-dev-only.sql` passed
- `git diff --check` passed
- `npm test` passed: 41 test files, 238 tests
- `npm run lint` passed
- `npm run build` passed
- `npm run typecheck` passed
- `npx tsc --noEmit` passed

Full repository verification passed.

## L. Current Status

Live browser QA passed for the supplier payment reporting flow. Automated checks and secret/scope scan passed. Git staging, commit, and push are pending.

## M. Secret And Scope Scan

Confirmed:

- `.env.local` is ignored and not staged
- `supabase/.temp` is ignored
- `.next` is ignored
- `.codex-dev-server.*.log` is ignored
- no app/component service-role usage was found
- no raw credentials, JWTs, cookies, bearer tokens, or production data were added to reports
- no online payment provider, delivery provider, settlement verification, commission release, or withdrawal flow was connected

## N. Whether Safe To Commit

Safe to commit after staging only the intentional Payment Phase 1 source files, SQL scripts, migration, tests, and these two reports.
