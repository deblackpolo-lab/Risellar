# Risellar Delivery Phase 3 Delivered Backend Report

## A. Summary

Delivery Phase 3 adds the audited supplier delivered boundary for Pay on Delivery orders that are already `out_for_delivery`.

The only transition implemented is:

- `out_for_delivery` -> `delivered`

Delivered records that the order reached the customer or approved recipient. It does not confirm payment, complete the order, commit or release stock reservation, increase sold stock, create payment rows, release commission, complete settlement, create withdrawal, create proof-of-delivery media, create GPS/live tracking, call rider/provider APIs, notify users, refund, or cancel.

## B. Schema Audit And Storage Decision

The live status model did not have an active delivered transition for this phase, so a forward migration was created.

The smallest order-level storage model was used:

- `delivered_at`
- `delivered_by_profile_id`
- `delivered_idempotency_key`
- `delivery_confirmation_note`

No proof file, signature, OTP, GPS, provider, rider, notification, or payment confirmation storage was added.

## C. Migration Applied

Created and applied to the confirmed development Supabase project:

- `supabase/migrations/20260730203000_supplier_order_delivered_rpc.sql`

Dry-run result:

- `npx supabase db push --dry-run --include-all` passed
- only `20260730203000_supplier_order_delivered_rpc.sql` was listed

Development apply result:

- first apply attempt failed before SQL execution because the new SQL files had a UTF-8 BOM
- the BOM was removed from the new migration and SQL scripts
- `npx supabase db push --dry-run --include-all` passed again
- `npx supabase db push --include-all` succeeded against development

No production Supabase connection was used.

## D. RPC Created

Created:

- `public.supplier_mark_order_delivered(p_order_id uuid, p_delivery_confirmation_note text default null, p_idempotency_key text default null)`

The RPC:

- requires authentication
- resolves the profile and supplier server-side
- requires an active `supplier_owner` profile
- requires an active approved supplier
- blocks admin staff, customer, reseller, cross-supplier, and anonymous contexts
- locks the target order row
- validates single-supplier ownership through `order_items`
- requires `order_status = out_for_delivery`
- requires dispatch timestamp and delivery arrangement
- requires reserved, unexpired stock reservation state
- requires Pay on Delivery payment state to remain `not_collected`
- accepts only an optional supplier-only delivery note and idempotency key
- updates only delivered order fields and delivery status
- returns the supplier-safe order read result

## E. Validation

The optional delivery note is normalized and guarded:

- trims whitespace
- max 300 characters
- no HTML
- rejects payment/ID/GPS/live-tracking-style sensitive content
- remains supplier-only in this phase

The browser/server action does not accept supplier id, customer id, reseller id, product id, status, stock, reservation, price, payment, delivery quote, commission, settlement, withdrawal, proof, GPS, rider, or provider fields.

## F. Idempotency And Conflict Behavior

Stable key:

- `supplier-delivered:${orderId}`

Idempotency behavior:

- same key and same note returns the durable delivered state
- delivered timestamp is preserved
- no duplicate audit event is created
- reservation, stock, payment, and economics remain unchanged

Conflicting retry behavior:

- a different key or materially different note is blocked with `CONFLICTING_RETRY`
- the original note is preserved
- no partial or mixed state is created

## G. Audit Event

The RPC creates one `supplier_order_delivered` audit event for the first successful delivered transition.

Safe metadata records:

- previous/new status
- arrangement and dispatch recorded flags
- whether a note exists
- whether an idempotency key exists

The audit event does not log the full supplier-only delivery note, customer address, customer phone, courier phone, JWT/session data, private commercial data, settlement data, or commission data.

## H. Safe Read Updates

Supplier-safe reads now expose:

- delivered status label
- `delivered_at`
- supplier-only `delivery_confirmation_note`

Customer-safe reads now expose:

- `delivered_at`
- customer status label `Your order has been delivered`
- payment-not-confirmed delivered notice

Customer-safe reads do not expose:

- supplier-only delivery confirmation note
- actor ids
- idempotency keys
- internal commercial fields
- commission or settlement state
- payment-success or completed wording

## I. Dev-Only RPC Tests

Created:

- `scripts/rpc/supplier-order-delivered-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-delivered-concurrency-tests-dev-only.sql`

Both scripts run inside transactions and end with `rollback`.

The harness normalizes its selected development fixture inside the transaction, including clearing prior delivered audit rows for that chosen fixture, so retained live QA delivered orders do not poison later rollback test runs. This does not alter production data, migrations, RPC logic, RLS, or storage policies.

Passed boundary assertions include:

- supplier can mark own out-for-delivery order delivered
- status becomes delivered
- delivered timestamp is populated
- delivery arrangement and dispatch fields are preserved
- optional supplier-only delivery note is stored
- reservation remains reserved
- reservation quantity is unchanged
- total, reserved, and sold stock are unchanged
- payment remains `not_collected`
- order total and delivery amount are unchanged
- audit event is created once
- same-key duplicate returns delivered without duplicate audit
- conflicting retry is blocked and preserves the original note
- invalid prior statuses are blocked
- missing dispatch, missing arrangement, expired reservation, oversized note, and HTML note are blocked
- customer, reseller, admin staff, and anonymous contexts are blocked
- customer-safe delivered status and payment-not-confirmed notice are visible
- supplier-only note is absent from customer-safe read shape
- no payment, delivery quote, commission, settlement, withdrawal, refund, completed status, proof-of-delivery table, or GPS tracking table is created

Passed concurrency assertions include:

- one status transition
- one delivered timestamp
- one audit event
- one durable note
- no mixed delivery note
- reservation unchanged
- stock unchanged
- payment unchanged

## J. Commands Run And Results

- `git diff --check`: passed with Windows line-ending warnings only
- `npm test`: passed, 40 files and 232 tests
- `npm run lint`: passed with zero warnings
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed
- `npx supabase db push --dry-run --include-all`: passed
- `npx supabase db push --include-all`: succeeded against development
- `npx supabase db query --linked --file scripts/rpc/supplier-order-delivered-rpc-tests-dev-only.sql`: passed
- `npx supabase db query --linked --file scripts/rpc/supplier-order-delivered-concurrency-tests-dev-only.sql`: passed

## K. Secret And Scope Safety

No secrets, credentials, profile ids, supplier ids, JWTs, cookies, tokens, project identifiers, database passwords, or private record identifiers are recorded in this report.

Secret/scope scan result is recorded in the UI/live QA report.

## L. Files Changed

- `supabase/migrations/20260730203000_supplier_order_delivered_rpc.sql`
- `scripts/rpc/supplier-order-delivered-rpc-tests-dev-only.sql`
- `scripts/rpc/supplier-order-delivered-concurrency-tests-dev-only.sql`
- `tests/supplier-order-delivered.test.ts`
- supplier/customer order helpers and UI files

## M. Current Status

Delivery Phase 3 backend migration, delivered RPC, boundary tests, concurrency tests, idempotency/conflict behavior, safe reads, and no-payment/no-finance protections passed in the development environment. Production remains untouched.
