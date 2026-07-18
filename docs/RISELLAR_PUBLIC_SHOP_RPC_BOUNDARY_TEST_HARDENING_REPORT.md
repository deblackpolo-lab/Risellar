# Risellar Public Shop RPC Boundary Test Hardening Report

## A. Original Failure

The hardened public shop RPC boundary test first failed before assertions completed:

- `ERROR: 22P02: invalid input value for enum supplier_role: "supplier_owner"`

Classification:

- fixture/schema mismatch

The failure was caused by test fixture data, not by the public shop RPC or a confirmed security gap.

## B. Actual supplier_role Values

The applied schema defines `public.supplier_role` as:

- `owner`
- `supplier_inventory_manager`

The invalid fixture value was:

- `supplier_owner`

## C. Fixture Fix Applied

The `supplier_team_members` fixture insert was removed from `scripts/rpc/public-shop-rpc-tests-dev-only.sql`.

Reason:

- The row is not required to test public shop read-only visibility.
- The public shop RPC does not join or expose supplier team member data.
- Removing the row keeps the fixture smaller and avoids unrelated team-role dependencies.

No migration, RPC, RLS policy, storage policy, or production data was changed.

## D. Active Assertions Added

The public shop RPC script now actively asserts:

- anonymous/public can read active approved reseller shop listings through `get_public_reseller_shop`
- anonymous/public can read active approved product detail through `get_public_reseller_shop_product`
- active approved reseller listing appears exactly once
- pending product/listing is hidden
- rejected product/listing is hidden
- archived product/listing is hidden
- hidden reseller listing is hidden
- deleted/archived reseller listing is hidden
- invalid shop slug returns an empty safe result
- invalid product slug returns an empty safe result
- customer-safe fields are present
- sensitive supplier/reseller/private/admin/financial fields are absent
- final customer price, currency, stock label, and image metadata are exposed safely
- order, order item, stock reservation, delivery quote, settlement, commission, and withdrawal row counts do not change
- no `public.payments` table is connected by the read-only public shop RPCs

The final failure block aggregates failed assertion names and details directly in the raised exception.

## E. Test Rerun Result

Command:

- `npx supabase db query --linked --file scripts/rpc/public-shop-rpc-tests-dev-only.sql`

Result:

- Passed.
- No assertion exception was raised.
- The linked query returned no result rows because the script records temporary assertion rows, raises on failure, and then rolls back.

## F. Failed Assertion/Error If Any

None after the fixture fix.

## G. Security Protections Verified

The active SQL assertions verified:

- active approved listings are public-readable
- pending/rejected/archived/hidden/deleted listings and products are hidden
- supplier private/contact/payout/internal/admin/risk/team fields are not exposed
- reseller margin, private payout, commission, withdrawal, and internal fields are not exposed
- final customer price is exposed safely
- checkout, orders, stock reservation, delivery quotes, settlements, commissions, withdrawals, and payments are not created or connected by public-shop reads

## H. Fixture Rollback/Cleanup Result

The script uses `begin` and `rollback`.

All fake/dev-only fixture data is rolled back at the end of the script.

## I. Commands Run/Results

- inspected `supplier_role` enum definition - valid values are `owner` and `supplier_inventory_manager`
- inspected `supplier_team_members` table definition
- inspected existing public-shop test script
- removed unnecessary `supplier_team_members` fixture insert
- `npx supabase db query --linked --file scripts/rpc/public-shop-rpc-tests-dev-only.sql` - passed after fixture fix

Full project validation and secret/scope scan results are recorded in the development apply/test report.

## J. Secret/Scope Scan Result

No secrets were added by the fixture fix.

Full scan result is recorded in `docs/RISELLAR_PUBLIC_RESELLER_SHOP_DEV_APPLY_AND_TEST_REPORT.md`.

## K. Current Git Status

At report creation time, changed files include:

- `scripts/rpc/public-shop-rpc-tests-dev-only.sql`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_DEV_APPLY_AND_TEST_REPORT.md`
- `docs/RISELLAR_PUBLIC_RESELLER_SHOP_READONLY_FOUNDATION_REPORT.md`
- `docs/RISELLAR_PUBLIC_SHOP_RPC_BOUNDARY_TEST_HARDENING_REPORT.md`

## L. Whether Public Shop Browser QA Is Safe To Run Next

Yes, browser/manual QA is safe to run next for read-only public browsing.

Do not connect checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or customer purchase flow.

Browser QA update:

- safe public empty/not-found states were verified without auth
- active-listing browser QA is blocked by missing persistent active development listing data
- SQL boundary tests still verify the active-listing path with rollback fixtures
