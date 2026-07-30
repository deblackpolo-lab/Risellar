# Risellar Checkout Phase C C5 Customer Order Read Boundary Report

## A. Executive Summary

Checkout Phase C C5 implemented a customer-safe order read boundary foundation only. Final order confirmation remains disabled. No order creation UI, payment, delivery, supplier preparation, commission, settlement, withdrawal, refund, cancellation, or stock mutation behavior was added.

Outcome classification: C5-B. The existing `checkout_order_safe_row(uuid)` is close but too broad for customer UI because it returns internal linkage identifiers, permits support-admin reads, and does not return contact/address snapshots needed by a durable customer order detail page. A new narrow read-only RPC migration was created and dry-run only.

## B. Baseline Commit And Branch

- Required baseline commit: `90c94d2fa7d561bc6208e56d97c3440263177c7c`
- Confirmed branch: `main`

## C. Existing Read-Contract Audit

Existing function:

`public.checkout_order_safe_row(p_order_id uuid)`

Audit result:

- Input: one order UUID.
- Return type: table row.
- Security: `SECURITY DEFINER`.
- Search path: `public`.
- Grants: revoked from public, granted to authenticated.
- Ownership checks: `public.is_order_participant(o.id)` or `public.has_admin_role('support_staff')`.
- Joined tables: `orders`, `order_items`, `checkout_drafts`, `stock_reservations`.
- Returns one row.
- Supports direct order ID lookup.
- Supports converted checkout drafts through `orders.checkout_draft_id`.
- Missing/unauthorized order returns no row.

Limitations:

- Returns `customer_id`, `reseller_id`, `shop_id`, `reseller_product_id`, and `product_id`.
- Allows support-admin access, which is correct for admin/support contexts but broader than a customer route contract.
- Does not return `customer_contact_snapshot` or `delivery_address_snapshot`.
- Does not return public-safe reseller shop name/slug.

## D. Customer-Safe Return Shape

New planned function:

`public.get_customer_order_safe(p_order_id uuid)`

Customer-safe fields:

- order id
- order number
- created and updated dates
- customer-facing order/status labels
- Pay on Delivery label
- payment not collected label
- delivery not arranged/fee not confirmed labels
- product name and slug snapshot
- product image snapshot
- quantity
- final customer price
- line total
- total payable
- currency
- customer contact snapshot
- delivery address snapshot
- reseller shop display name and slug
- stock reservation label
- optional reservation expiry

Fields intentionally excluded:

- customer id
- reseller id
- supplier id
- shop id
- product id
- variant id
- reseller listing id
- supplier base price
- platform margin
- reseller margin
- reseller cost
- settlement due amount
- commission amount
- risk fields
- admin/internal notes
- payment-provider references
- supplier/reseller private contact or payout data

## E. Ownership And Security Findings

The new read RPC:

- requires an authenticated user via `current_profile_id()`
- resolves an existing active customer row without calling `current_customer_id()`
- requires `profiles.primary_role = 'customer'`
- requires active profile and active customer
- excludes active `admin_staff` rows so admin staff must use admin read routes
- filters by `orders.customer_id = resolved customer id`
- returns no row for missing/unauthorized/non-customer access
- does not reveal whether another customer's order exists

## F. Direct-Table-Read Findings

Current direct SELECT RLS allows order participants to read:

- `orders`
- `order_items`
- `stock_reservations`

Those tables contain internal commercial columns such as supplier base price, platform margin, reseller margin, settlement due amount, and commission amount. Customer UI must not read those tables directly. The safe boundary is the dedicated RPC/helper, not direct client/table reads.

No direct SELECT grants were changed in C5. Any future privilege tightening should be a separately approved migration because those grants may support existing admin, supplier, and reseller read paths.

## G. Existing RPC Sufficiency Decision

Decision: C5-B, small read RPC migration required.

Reason:

- Existing RPC does not leak margin/commission/settlement amounts, but it returns internal linkage IDs and is not customer-only.
- Customer order detail needs contact/address snapshots for safe refresh.
- A narrow customer-only wrapper is cleaner than using the broader participant/support helper directly.

## H. Migration Required Or Not

Migration required: yes.

Created:

- `supabase/migrations/20260730120000_customer_order_safe_read_rpc.sql`

The migration is read-only. It does not create orders, mutate stock, modify payments, create delivery quotes, trigger supplier preparation, release commissions, complete settlements, create withdrawals, or implement refunds.

Dry-run only was executed.

## I. RPC/Helper Implementation

Created server-only helper:

- `lib/orders/customer-order-read.ts`

Helper behavior:

- builds payload with order id only
- calls only `get_customer_order_safe`
- maps returned safe row into a strict TypeScript shape
- maps missing/unauthorized rows to `ORDER_NOT_FOUND`
- maps auth, validation, token, permission, and unknown errors safely
- imports `server-only`
- does not use service role
- contains no write behavior

## J. Order Status Mapping

The RPC maps backend order statuses to customer-facing labels, including:

- `placed_pending_confirmation`: `Placed - waiting for supplier confirmation`
- `customer_confirmed`: `Customer confirmed`
- `delivery_quote_pending`: `Delivery quote pending`
- `delivery_quote_ready`: `Delivery quote ready`
- `delivery_quote_approved`: `Delivery quote approved`
- `supplier_preparing`: `Supplier preparing`
- `ready_for_pickup_or_dispatch`: `Ready for pickup or dispatch`
- `out_for_delivery`: `Out for delivery`
- `delivered_payment_pending`: `Delivered - payment pending`
- `payment_collected`: `Payment collected`
- `completed`: `Completed`
- `cancelled`: `Cancelled`
- `customer_refused`: `Customer refused delivery`
- `failed`: `Failed`
- `disputed`: `Disputed`
- fallback: `Order status unavailable`

## K. Reservation Display Decision

Customer display should use:

- `Stock reserved for this order` for reserved stock
- safe reservation status labels for other states
- optional reservation expiry only as reservation timing, not payment or delivery timing

The RPC does not expose raw stock counts, total stock, competing customer data, or supplier inventory levels.

## L. Payment/Delivery Wording

Payment:

- `Pay on Delivery`
- `Payment not collected`

Delivery:

- `Delivery not arranged yet`
- `Delivery fee not confirmed`

The read boundary does not claim online payment, delivery booking, rider assignment, supplier acceptance, commission release, or settlement completion.

## M. Success-Route Decision

Recommended future success route:

`/customer/orders/[orderId]?placed=1`

Reason:

- durable route works on refresh
- ownership enforced by read RPC regardless of URL
- avoids a separate success page that can drift from order detail
- success can be a banner state on the durable order detail page

## N. Order-Detail Route Decision

C5 did not replace `/customer/orders/[id]` yet because the new RPC has not been applied and boundary-tested in development.

Future route should use the server-only helper and display only the safe return shape from this report.

## O. Order-List Decision

`/customer/orders` remains deferred/placeholder.

Do not convert it into a live list until a dedicated safe list RPC/helper is approved.

## P. Tests Added/Updated

Created:

- `tests/customer-order-read.test.ts`
- `scripts/rpc/customer-order-safe-read-rpc-tests-dev-only.sql`

TypeScript tests cover:

- order-read payload accepts order id only
- helper calls only `get_customer_order_safe`
- missing/unauthorized rows normalize to `ORDER_NOT_FOUND`
- safe error mapping
- typed return shape excludes internal commercial/operational fields
- customer order route policy blocks reseller, supplier, and active admin staff
- no final confirmation, order creation, payment, delivery, preparation, finance, or service-role implementation in read sources

SQL test harness covers the function shape, grants, forbidden returned columns, and no `current_customer_id()` side effect. It was not run because the migration was not applied.

## Q. Dry-Run Result

`npx supabase db push --dry-run --include-all`: passed.

Would apply only:

- `20260730120000_customer_order_safe_read_rpc.sql`

No real db push was run.

## R. Browser QA Result Or Blocker

Browser QA was not run in C5.

Blocker: the new read RPC is not applied or boundary-tested yet, and C5 must not create live orders or enable final confirmation.

## S. Database No-Side-Effect Verification

C5 performed no live read/write test and no real db push.

No source code path was added that creates:

- order
- order item
- stock reservation
- payment
- delivery quote
- commission
- settlement
- withdrawal
- refund

## T. Automated Verification

- `git diff --check`: passed.
- `npx supabase db push --dry-run --include-all`: passed; would apply only `20260730120000_customer_order_safe_read_rpc.sql`.
- `npm test`: passed, 31 test files and 165 tests.
- `npm run lint`: passed with `--max-warnings=0`.
- `npm run build`: passed; 168 static pages generated.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

During development, the new test file first exposed a Vitest-only `server-only` import guard issue and then an overly broad source-scan assertion around safe delivery quote label text. Both were fixed in the test harness only. No app runtime behavior was weakened.

## U. Security/Privacy Scan

- `.env.local`: ignored and not staged.
- `.local-recovery`: ignored and not staged.
- `.next`: ignored and not staged.
- `supabase/.temp`: ignored and not staged.
- `.codex-dev-server.*.log`: ignored.
- Nothing is staged.
- No service-role imports or service-role key usage were found in `app/`, `components/`, or the new customer order read helper.
- No direct customer UI reads from `orders`, `order_items`, `stock_reservations`, or `checkout_drafts` were found.
- No final confirmation button was enabled.
- No `create_order_from_checkout_draft` UI action was added.
- No payment, delivery quote table, commission, settlement, withdrawal, supplier-preparation, refund, or cancellation implementation was added.
- No private UUID-style identifiers were added to this report.
- No production project was accessed.

## V. Files Changed

- `supabase/migrations/20260730120000_customer_order_safe_read_rpc.sql`
- `scripts/rpc/customer-order-safe-read-rpc-tests-dev-only.sql`
- `lib/orders/customer-order-read.ts`
- `tests/customer-order-read.test.ts`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C5_CUSTOMER_ORDER_READ_BOUNDARY_REPORT.md`

The seven C4 planning docs remain untracked from the previous planning task.

## W. Current Git Status

Final status before response:

```text
 M app/supplier/orders/[id]/page.tsx
 M app/supplier/orders/page.tsx
 M next-env.d.ts
 M package-lock.json
 M package.json
 M tsconfig.json
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_CUSTOMER_ORDER_READ_MODEL_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_IMPLEMENTATION_GROUPS.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_ORDER_CONFIRMATION_UI_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_PLANNING_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_RISK_REGISTER.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_TEST_AND_BROWSER_QA_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_UI_COPY_AND_STATES.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C5_CUSTOMER_ORDER_READ_BOUNDARY_REPORT.md
?? lib/orders/
?? scripts/rpc/customer-order-safe-read-rpc-tests-dev-only.sql
?? supabase/migrations/20260730120000_customer_order_safe_read_rpc.sql
?? tests/customer-order-read.test.ts
```

The modified supplier/package/type-config entries continue to show no tracked content diff. The meaningful C5 files are untracked and unstaged.

## X. C5 Outcome Classification

C5-B: small read RPC migration required.

## Y. Whether C5 Is Complete

C5 implementation and dry-run are complete after final validation passes. Development apply and SQL boundary test still require explicit approval.

## Z. Whether Safe To Commit

Safe to commit after final verification and explicit user approval. Do not commit or push from this task.

## AA. Whether C6 Confirmation-Action/UI Work May Begin

Not yet. C6 should wait until the C5 read migration is applied to development and the development-only read RPC boundary tests pass.

## AB. Exact Recommended Next Prompt

Approve applying the Checkout Phase C C5 customer order safe read RPC migration to the confirmed DEVELOPMENT Supabase project named "Risellar", then run the development-only customer order safe read RPC boundary tests. Do not enable final order confirmation, do not connect payment/delivery/preparation/finance flows, do not connect production Supabase, do not print secrets, and do not commit unless asked.
