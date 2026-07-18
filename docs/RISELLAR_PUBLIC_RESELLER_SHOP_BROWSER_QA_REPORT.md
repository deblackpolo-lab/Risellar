# Risellar Public Reseller Shop Browser QA Report

## A. Summary

Browser/manual QA was run against the read-only public reseller shop routes on `http://localhost:400`.

Initial public shop browser QA confirmed safe empty/unavailable states because the confirmed DEVELOPMENT Supabase project did not yet have an active, non-deleted public listing.

Follow-up positive browser QA created one fake/dev-only active public listing and confirmed the active listing appears safely without auth. Details are documented in:

- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_ACTIVE_LISTING_BROWSER_QA_REPORT.md`

The original available development shop/listing state was:

- shop slug: `shop-5d2328c9d22f412e8bbb5cc1`
- shop status: `active`
- visibility: `private_until_shop_flow`
- listing status: `archived`
- listing deleted: `true`
- product status: `active`
- product approval status: `approved`
- supplier status: `active`
- supplier verification status: `approved`

No checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or customer purchase flow was connected.

## B. Public Shop Route Result

Route checked:

- `/shop/shop-5d2328c9d22f412e8bbb5cc1`

Result:

- Page loaded without auth.
- The page showed a safe `Shop unavailable` / empty state.
- No active products were shown because the only matching development listing is archived/deleted.
- The page displayed read-only copy: checkout, order creation, stock reservation, and payment are not connected yet.

## C. Active Approved Listing Result

Active approved listing browser verification has now passed in a follow-up positive QA pass.

Result:

- A fake/dev-only active listing was created from an existing fake/dev-only approved supplier product through the tested reseller listing RPC path.
- `/shop/shop-5d2328c9d22f412e8bbb5cc1` loaded without auth.
- The active listing appeared.
- Final customer price appeared.
- Sensitive supplier/reseller/internal fields stayed hidden.
- Checkout, order creation, stock reservation, payment, and delivery remained disabled/deferred.

Follow-up report:

- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_ACTIVE_LISTING_BROWSER_QA_REPORT.md`

## D. Product Detail Route Result

Route checked:

- `/shop/shop-5d2328c9d22f412e8bbb5cc1/product/risellar-admin-approval-qa-approve-target-20260718132814-54d1f228`

Result:

- Product detail route loaded without auth.
- Because the underlying listing is archived/deleted, the page showed safe `Product unavailable` copy.
- No buy, checkout, order, stock reservation, payment, or delivery action was exposed.

## E. Sensitive Field Visibility

No sensitive fields were visible in the browser during the safe empty/product-unavailable states.

Not visible:

- supplier contact
- supplier payout data
- supplier internal/admin fields
- supplier risk/private fields
- supplier team data
- reseller margin
- reseller payout/withdrawal/commission data
- settlement data

Full positive-state sensitive-field hiding is covered by the hardened SQL boundary test and app-level mapping tests. It still needs browser QA with a persistent active dev-only listing.

## F. Invalid Route Result

Route checked:

- `/shop/not-a-real-shop`

Result:

- Page loaded without auth.
- Safe `Shop unavailable` / empty state was shown.
- No product data or sensitive data leaked.
- Checkout/order/payment/stock/delivery actions remained unavailable.

## G. Mutation/Business Flow Check

Before and after reloading the shop/product routes, these row counts remained zero:

- `orders`
- `order_items`
- `stock_reservations`
- `delivery_quotes`
- `settlements`
- `commissions`
- `withdrawals`

There is no `public.payments` table in the current schema.

## H. Unrelated Flow Scope

No unrelated live flow was touched or connected:

- checkout not connected
- orders not connected
- stock reservation not connected
- payments not connected
- delivery not connected
- settlements not connected
- commissions not connected
- withdrawals not connected

## I. Issues/Limitations

Resolved follow-up:

- The prior blocker was missing persistent development data for the browser positive path.
- A fake/dev-only active listing was created in development.
- Positive browser QA now passed and is documented separately.

Remaining limitation:

- This remains development-only QA. Production Supabase was not used.

## J. Commands Run/Results

- checked port 400 - local dev server was not running initially
- started `npm run dev` on port 400
- read-only development query for active public listing candidate - returned no active listing rows
- read-only development query for broader shop/listing state - found one archived/deleted listing
- browser checked `/shop/shop-5d2328c9d22f412e8bbb5cc1` - safe empty/unavailable state loaded without auth
- browser checked product detail for archived listing - safe `Product unavailable` state loaded without auth
- browser checked `/shop/not-a-real-shop` - safe empty/unavailable state
- read-only before/after row count checks - no order, order item, stock reservation, delivery quote, settlement, commission, or withdrawal rows were created
- follow-up positive browser QA - active fake/dev-only listing shown without auth; product detail loaded; checkout/order/payment/delivery remained disabled/deferred
- `git status --short` - reviewed before and after QA/report updates
- `git diff --check` - passed with LF-to-CRLF warnings only
- `npm test` - passed: 28 test files, 145 tests
- `npm run lint` - passed
- `npm run build` - passed
- `npm run typecheck` - passed

## K. Secret/Scope Scan Result

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No service-role imports or references were found in `app/` or `components/`.
- Secret-pattern scan found only placeholder key names in documentation, `.env.example`, and the existing server-only `lib/supabase/admin.ts` helper.
- No real Clerk/Supabase/service-role values were found.
- No bearer tokens, passwords, API secrets, or production data were found.
- No order, stock reservation, payment, delivery, or listing mutation references were found in the scoped public/customer/shop flow scan.
- No secrets were printed during browser QA.

## L. Current Git Status

Changed/untracked files after positive active-listing browser QA:

- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_ACTIVE_LISTING_BROWSER_QA_REPORT.md`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_BROWSER_QA_REPORT.md`

## M. Whether Safe To Commit

Safe to commit the active-listing browser QA documentation after final validation.
