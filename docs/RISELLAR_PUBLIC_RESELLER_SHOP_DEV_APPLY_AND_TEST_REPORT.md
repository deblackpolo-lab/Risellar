# Risellar Public Reseller Shop Development Apply And Test Report

## A. Development Project Confirmation

The public reseller shop read-only RPC migration was applied only after the standard development precheck.

Precheck result:

- `git status --short` returned a clean working tree.
- `npx supabase --version` returned `2.109.1`.
- The local linked project marker exists under `supabase/.temp/project-ref`.
- `.env.local` exists, is ignored, and was not staged.
- `supabase/.temp` exists, is ignored, and was not staged.
- No secrets were printed.

This run used the already confirmed DEVELOPMENT Supabase project named "Risellar". Production Supabase was not used.

## B. Migration Applied

Applied migration:

- `20260718183000_public_reseller_shop_readonly_rpc.sql`

## C. db push Result

Command:

- `npx supabase db push`

Result:

- Succeeded.
- Applied only `20260718183000_public_reseller_shop_readonly_rpc.sql`.
- `supabase db reset --linked` was not run.
- No destructive reset command was run.

## D. Public Shop RPC Test Result

Command:

- `npx supabase db query --linked --file scripts/rpc/public-shop-rpc-tests-dev-only.sql`

Initial result:

- The first post-apply run executed successfully but returned only one scaffold row: `public shop boundary script is scaffolded only`.

Hardening result:

- `scripts/rpc/public-shop-rpc-tests-dev-only.sql` was converted from scaffold-only into active pass/fail assertions.
- The first hardened run failed before assertions completed because the fixture used invalid enum value `supplier_role = 'supplier_owner'`.
- Valid `supplier_role` values are `owner` and `supplier_inventory_manager`.
- The unnecessary `supplier_team_members` fixture insert was removed.
- The test was rerun once after the fixture fix and passed with no raised assertion failure.

## E. Passed Assertions

The hardened SQL script now actively asserts:

- anonymous/public can read active approved reseller shop listings through `get_public_reseller_shop`
- anonymous/public can read active approved product detail through `get_public_reseller_shop_product`
- active approved reseller listing appears exactly once
- pending, rejected, archived, hidden, and deleted listing/product paths are hidden
- invalid shop and product slugs return empty safe results
- customer-safe fields are exposed
- supplier/reseller private, financial, admin, internal, payout, commission, settlement, risk, and team fields are absent
- final customer price, currency, stock availability label, and image metadata are exposed safely
- order, order item, stock reservation, delivery quote, settlement, commission, withdrawal, and payment paths are not created or connected by public-shop reads

Application-level tests passed for:

- public shop loader calls `get_public_reseller_shop`
- approved active listings are mapped
- unapproved, archived, and hidden products/listings are defensively filtered
- sensitive fields are not mapped or exposed
- product detail calls `get_public_reseller_shop_product`
- public browsing does not require Clerk auth
- service role is not imported into public shop app/components
- checkout/order/stock/payment/delivery mutations were not introduced

## F. Failed Assertion/Error If Any

Initial hardened run failure:

- `ERROR: 22P02: invalid input value for enum supplier_role: "supplier_owner"`

After fixture fix:

- No SQL execution error occurred.
- No assertion failure occurred.

## G. Failure Classification If Any

Initial hardened run classification:

- fixture/schema mismatch

After fixture fix:

- none

No real public shop security gap was confirmed.

## H. Public Shop Security Protections Verified

Verified by active SQL assertions, migration review, application tests, and scope scan:

- Public RPCs expose only public-safe shop, listing, product, image summary, customer price, currency, and stock availability fields.
- Supplier base/private price is not exposed.
- Platform margin is not exposed.
- Reseller margin is not exposed.
- Supplier contact/payout/internal/admin/risk fields are not exposed.
- Settlement and commission data are not exposed.
- Supplier team/private permission data is not exposed.
- UI remains read-only.
- Checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, and customer purchase flow remain disabled/deferred.

The hardened SQL script now verifies those public-shop boundaries using fake/dev-only rollback fixtures.

## I. Whether Fixture/Test Data Was Rolled Back/Cleaned Up

The executed script uses a transaction and `rollback`.

No permanent fixture/test data was committed by the public-shop RPC test script.

## J. Commands Run/Results

- `git status --short` - clean before migration/report work.
- `npx supabase --version` - `2.109.1`.
- local linked project marker check - present.
- `.env.local` / `supabase/.temp` ignore/stage precheck - present, ignored, not staged.
- `npx supabase db push` - succeeded; applied `20260718183000_public_reseller_shop_readonly_rpc.sql`.
- `npx supabase db query --linked --file scripts/rpc/public-shop-rpc-tests-dev-only.sql` - initial post-apply run succeeded but was scaffold-only.
- `npx supabase db query --linked --file scripts/rpc/public-shop-rpc-tests-dev-only.sql` - first hardened run failed with fixture/schema mismatch: invalid `supplier_role = 'supplier_owner'`.
- `npx supabase db query --linked --file scripts/rpc/public-shop-rpc-tests-dev-only.sql` - passed after removing the unnecessary `supplier_team_members` fixture insert.
- read-only development query for active public listing candidate - no active listing rows found.
- browser QA for `/shop/shop-5d2328c9d22f412e8bbb5cc1` - loaded without auth and showed safe empty/unavailable state because the only listing is archived/deleted.
- browser QA for archived listing product detail - loaded without auth and showed safe `Product unavailable` state.
- browser QA for `/shop/not-a-real-shop` - loaded without auth and showed safe empty/unavailable state.
- read-only before/after business-flow row counts - no order, order item, stock reservation, delivery quote, settlement, commission, or withdrawal rows were created by public browsing.
- `git diff --check` - passed with LF-to-CRLF warnings only.
- `npm test` - passed: 28 test files, 145 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- `npm test` - passed: 28 test files, 145 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.

## K. Secret/Scope Scan Result

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No service-role imports or references were found in `app/` or `components/`.
- Secret-pattern scan found only placeholder key names in documentation, `.env.example`, and the existing server-only `lib/supabase/admin.ts` helper.
- No real Clerk/Supabase/service-role values were found in docs/source.
- No bearer tokens, passwords, API secrets, or production data were found.
- No order, stock reservation, payment, delivery, or listing mutation references were found in the scoped public/customer/shop flow scan.
- Latest browser QA secret/scope scan matched the same result.

## L. Current Git Status

At latest report update time, changed files include:

- `scripts/rpc/public-shop-rpc-tests-dev-only.sql`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_DEV_APPLY_AND_TEST_REPORT.md`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_READONLY_FOUNDATION_REPORT.md`
- `docs/RISELLAR_PUBLIC_SHOP_RPC_BOUNDARY_TEST_HARDENING_REPORT.md`

## M. Whether Production Remains Blocked

Production remains blocked.

The migration was applied to development only. Public-shop SQL boundary assertions now pass in development after the fixture/schema mismatch fix.

## N. Whether Public Shop Browser QA Is Safe To Run Next

Browser/manual QA is safe to plan next for read-only public browsing only.

Do not connect checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or customer purchase flow.

Browser QA update:

- Public shop routes loaded without auth.
- The current development shop candidate only has an archived/deleted listing, so active-listing browser QA is blocked until a fake/dev-only persistent active listing exists.
- Safe empty/not-found states were verified.
- Before/after row counts confirmed no order, order item, stock reservation, delivery quote, settlement, commission, or withdrawal rows were created by public browsing.
