# Risellar Public Reseller Shop Active Listing Browser QA Report

## A. Development Listing Setup

Created one fake/dev-only persistent active public reseller listing in the confirmed DEVELOPMENT Supabase project named Risellar.

The listing was created from an existing fake/dev-only approved supplier product using the already-tested reseller listing RPC path. No production data was used.

Development listing state verified after setup:

- shop slug: `shop-5d2328c9d22f412e8bbb5cc1`
- share slug: `risellar-admin-approval-qa-approve-target-20260718132814-54d1f228-38a626`
- product slug: `risellar-admin-approval-qa-approve-target-20260718132814`
- product name: `Risellar Admin Approval QA Approve Target 20260718132814`
- listing status: `active`
- listing deleted: `false`
- product status: `active`
- product approval status: `approved`
- supplier status: `active`
- supplier verification status: `approved`
- final customer price: `GHS 102.77`

No checkout, order, stock reservation, payment, delivery, settlement, commission, withdrawal, or customer purchase flow was created or connected.

## B. Shop Slug Tested

Browser route tested without auth:

- `/shop/shop-5d2328c9d22f412e8bbb5cc1`

## C. Shop Page Result

Result: passed.

The public shop page loaded without Clerk sign-in and showed the active approved listing.

Visible public-safe content included:

- shop display name
- read-only preview copy
- product name
- category
- low-stock availability label
- final customer price: `GHS 102.77`

Pending, rejected, archived, and deleted listings/products were not shown in this positive browser path.

## D. Product Detail Result

Browser route tested without auth:

- `/shop/shop-5d2328c9d22f412e8bbb5cc1/product/risellar-admin-approval-qa-approve-target-20260718132814-54d1f228-38a626`

Result: passed.

The product detail page loaded without auth and showed the public-safe product detail.

Visible public-safe content included:

- product name
- reseller shop display name
- final customer price: `GHS 102.77`
- description
- category
- brand display value
- currency
- availability label

## E. Public-Safe Fields Visible

Confirmed visible:

- public shop display name
- product name
- category
- description
- brand placeholder/display value
- final customer price
- currency
- stock availability label

## F. Sensitive Fields Hidden

No sensitive supplier/reseller/internal fields were visible in the browser.

Not visible:

- supplier private/base price
- platform margin
- reseller margin
- supplier contact details
- supplier payout data
- supplier internal/admin notes
- supplier risk score
- supplier team data
- settlement data
- commission data
- withdrawal data
- pending/rejected/archived product state

## G. Checkout/Buy Status

Checkout and purchase flow remain disabled/deferred.

Observed browser copy/buttons:

- shop page states checkout, order creation, stock reservation, and payment are not connected yet
- product detail states it does not create orders, reserve stock, collect payments, or start delivery
- `Add to cart planned` button is disabled
- `Buy later` button is disabled

No live checkout, cart, order, payment, delivery, or stock reservation action was available.

## H. Mutation Safety Check

Read-only row count checks after browser QA showed no unwanted business-flow mutations:

- `orders`: 0
- `order_items`: 0
- `stock_reservations`: 0
- `delivery_quotes`: 0
- `settlements`: 0
- `commissions`: 0
- `withdrawals`: 0

There is no `public.payments` table in the current schema.

## I. Commands Run/Results

- `git status --short` - clean before QA report updates
- `npx supabase --version` - `2.109.1`
- `.env.local` / `supabase/.temp` precheck - present/ignored/not staged
- read-only development listing discovery query - found one fake/dev-only archived listing suitable for a new active listing
- development-only listing setup through `create_reseller_product_listing` RPC - passed
- read-only listing verification query - passed after correcting schema column names
- browser checked `/shop/shop-5d2328c9d22f412e8bbb5cc1` - active listing shown without auth
- browser checked product detail route - product detail shown without auth
- read-only business-flow mutation count check - no order/stock/payment/delivery/settlement/commission/withdrawal rows created
- `git diff --check` - passed
- `npm test` - passed: 28 test files, 145 tests
- `npm run lint` - passed
- `npm run build` - passed
- `npm run typecheck` - passed

Notes:

- The first dev-server browser load hit a local Next dev cache/runtime issue. The dev server was restarted and the production build passed afterward.
- A read-only verification query initially used obsolete guessed table/column names and failed safely before being corrected against the actual schema. No data was modified by those failed read-only attempts.

## J. Secret/Scope Scan Result

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No service-role imports or references were found in `app/` or `components/`.
- Secret-pattern scan found only placeholder key names in documentation, `.env.example`, and the existing server-only `lib/supabase/admin.ts` helper.
- No real Clerk/Supabase/service-role values were found.
- No bearer tokens, passwords, API secrets, or production data were found.
- No order, stock reservation, payment, delivery, or listing mutation references were found in scoped public/customer/shop flows.
- No secrets were printed.

## K. Current Git Status

Changed/untracked files after report updates:

- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_ACTIVE_LISTING_BROWSER_QA_REPORT.md`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_BROWSER_QA_REPORT.md`

## L. Whether Safe To Commit

Safe to commit the active-listing public shop browser QA documentation after final `git status --short` review.

