# Risellar Public Reseller Shop Read-Only Foundation Report

## A. Summary

Created a read-only public reseller shop foundation for customer browsing of active approved reseller listings.

No checkout, order creation, stock reservation, payments, delivery, settlements, commissions, withdrawals, or customer purchase flow was connected.

## B. Migration Created

Created forward migration:

- `supabase/migrations/20260718183000_public_reseller_shop_readonly_rpc.sql`

The migration was dry-run only. It was not applied.

## C. RPCs Created

The migration defines:

- `get_public_reseller_shop(p_shop_slug text)`
- `get_public_reseller_shop_product(p_shop_slug text, p_product_slug text)`

The RPCs are `SECURITY DEFINER`, use `set search_path = public`, and grant execute to `anon` and `authenticated`.

## D. Public-Safe Fields Exposed

The RPCs expose only:

- public shop slug
- public shop display name
- shop bio
- active listing id
- product slug
- listing share slug
- product name
- product description
- category
- brand
- final customer price
- currency
- stock availability label
- active public image count
- primary image alt text
- listing/product approval status signals needed for defensive filtering

## E. Sensitive Fields Blocked

The RPC contract does not expose:

- supplier base/private price
- platform margin
- reseller margin
- supplier contact data
- supplier payout data
- admin/internal notes
- risk score
- settlement data
- commission data
- supplier team/private permission data
- pending/rejected/archived products or listings

## F. UI Routes Connected

Connected these existing routes to the read-only public RPC helper:

- `/shop/[shopSlug]`
- `/shop/[shopSlug]/product/[productId]`

Added:

- `lib/public-shop/catalog.ts`
- `components/customer/public-shop-rpc-screens.tsx`

The routes use `createSupabaseServerClient()` with anon-safe Supabase access. They do not require Clerk auth.

## G. Checkout/Buy Button Status

Buy/cart controls remain disabled/planned.

The product page explicitly states that it does not:

- create orders
- reserve stock
- collect payments
- start delivery

## H. Tests Added/Updated

Added:

- `tests/public-shop.test.ts`

Coverage includes:

- public shop loader calls `get_public_reseller_shop`
- active approved listings are mapped
- unapproved/archived/hidden products/listings are defensively filtered
- sensitive fields are not mapped or exposed
- product detail calls `get_public_reseller_shop_product`
- public browsing does not import Clerk auth
- service role is not imported in public shop app/components
- checkout/order/stock/payment mutations are not introduced

Added development-only script:

- `scripts/rpc/public-shop-rpc-tests-dev-only.sql`

The script was not run because the migration has not been applied.

## I. Dry-Run Result

Command:

- `npx supabase db push --dry-run`

Result:

- Passed.
- No migration was applied.
- Would apply only:
  - `20260718183000_public_reseller_shop_readonly_rpc.sql`

## J. Commands Run/Results

- `git status --short` - reviewed before implementation and during validation.
- `npm test -- tests/public-shop.test.ts` - failed first as expected because `lib/public-shop/catalog.ts` did not exist.
- `npm test -- tests/public-shop.test.ts` - passed after the public shop helper/UI implementation.
- `npx supabase db push --dry-run` - passed; no real push; would apply only `20260718183000_public_reseller_shop_readonly_rpc.sql`.
- `git diff --check` - passed. Git reported LF-to-CRLF working-copy warnings for the updated shop route files only.
- `npm test` - passed: 28 test files, 145 tests.
- `npm run lint` - passed.
- `npm run build` - first attempt failed while a local Next dev server was still listening on port 400 with `PageNotFoundError: Cannot find module for page: /admin/dashboard`; the referenced page existed, and rerunning after stopping only the local dev-server Node processes passed.
- `npm run build` - passed after stopping the concurrent local dev server.
- `npm run typecheck` - passed.

## K. Secret/Scope Scan Result

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No service-role imports or references were found in `app/` or `components/`.
- Secret-pattern scan found only placeholder key names in documentation, `.env.example`, and the existing server-only `lib/supabase/admin.ts` helper; no real secret values were found.
- No bearer tokens, passwords, API secrets, or production data were found.
- Scope scan found no order, stock reservation, payment, delivery, or reseller listing mutation references in the public/customer/shop flow scope.

## L. Files Changed

- `supabase/migrations/20260718183000_public_reseller_shop_readonly_rpc.sql`
- `scripts/rpc/public-shop-rpc-tests-dev-only.sql`
- `lib/public-shop/catalog.ts`
- `components/customer/public-shop-rpc-screens.tsx`
- `app/shop/[shopSlug]/page.tsx`
- `app/shop/[shopSlug]/product/[productId]/page.tsx`
- `tests/public-shop.test.ts`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_READONLY_FOUNDATION_REPORT.md`

## M. Current Git Status

Changed/untracked files at validation time:

- `app/shop/[shopSlug]/page.tsx`
- `app/shop/[shopSlug]/product/[productId]/page.tsx`
- `components/customer/public-shop-rpc-screens.tsx`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_READONLY_FOUNDATION_REPORT.md`
- `lib/public-shop/catalog.ts`
- `scripts/rpc/public-shop-rpc-tests-dev-only.sql`
- `supabase/migrations/20260718183000_public_reseller_shop_readonly_rpc.sql`
- `tests/public-shop.test.ts`

## N. Whether Safe To Commit/Apply Migration

The code/docs are safe to commit after final review.

Migration application is not yet approved. The next safe step after commit would be an explicit development-only approval to run `npx supabase db push`, followed by development-only public shop RPC boundary tests.
