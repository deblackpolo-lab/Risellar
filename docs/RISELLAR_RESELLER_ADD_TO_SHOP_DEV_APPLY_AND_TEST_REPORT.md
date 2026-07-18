# Risellar Reseller Add-to-Shop Development Apply and Test Report

Date: 2026-07-18

## A. Development Project Confirmation

The migration was applied only to the confirmed development Supabase project named `Risellar`.

Precheck results:

- Working tree was clean before apply.
- Supabase CLI version: `2.109.1`.
- `.env.local` exists.
- `.env.local` is ignored and was not staged.
- `supabase/.temp` is ignored.
- The linked project ref file exists.
- The linked project ref matched a Supabase project named `Risellar`.

`npx supabase status` was also attempted, but it tried to inspect local Docker container health and failed because Docker was not available from this shell. This did not expose secrets and was not used to apply migrations.

## B. Migration Applied

Applied migration:

- `20260718165000_reseller_add_to_shop_listing_rpc.sql`

Command:

```powershell
npx supabase db push
```

Result:

- Succeeded.
- Supabase showed only the approved migration before applying it.
- No destructive reset command was run.

## C. Reseller Listing RPC Test Result

Command:

```powershell
npx supabase db query --linked --file scripts/rpc/reseller-listing-rpc-tests-dev-only.sql
```

Result:

- Passed with exit code `0`.
- The script returned no rows, which is expected for the rollback-based boundary script.
- No failed assertion/error was reported.

## D. Passed Assertions

The development-only boundary script verified:

- Approved reseller can list an approved active product.
- Server-computed customer price uses supplier base price + platform margin + reseller margin.
- Pending products cannot be listed.
- Rejected products cannot be listed.
- Archived products cannot be listed.
- Customer cannot create a reseller listing.
- Supplier cannot create a reseller listing.
- Reseller cannot update another reseller's listing.
- Reseller cannot archive another reseller's listing.
- Duplicate active listing is blocked.
- Negative margin is blocked.
- Excessive margin is blocked.
- Valid own-margin update succeeds.
- Own listing can be soft archived.
- Archived listing allows a new active listing for the same product.
- No stock reservation was created.
- No order was created.
- No commission was created.
- No settlement was created.
- Audit logs were created for create/update/archive.
- Fixture/test data was rolled back.

## E. Failed Assertion or Error

None.

## F. Failure Classification

Not applicable. The reseller listing RPC boundary tests passed.

## G. Product and Listing Security Protections Verified

Verified by migration behavior and development-only boundary tests:

- Approved reseller requirement is enforced.
- Only approved active supplier products can be listed.
- Unapproved product states are blocked.
- Customer and supplier roles cannot create reseller listings.
- Reseller ownership is enforced for update/archive.
- Margin rules are enforced server-side.
- Supplier base price and platform margin are not client-controlled.
- Customer price is computed server-side.
- Duplicate active listings are blocked.
- Archive is soft only.
- Audited action logging is enforced.
- No order, stock reservation, commission, or settlement side effect is created.

## H. Fixture/Test Data Rollback

The test script is wrapped in a transaction and ends with:

```sql
rollback;
```

Fixture/test data was not permanently committed by the boundary test.

## I. Commands Run and Results

| Command | Result |
| --- | --- |
| `git status --short` | Clean before apply |
| `npx supabase --version` | `2.109.1` |
| `npx supabase status` | Failed on local Docker health inspection; no secrets exposed |
| Linked-project check via `supabase/.temp/project-ref` and `npx supabase projects list` | Matched project named `Risellar` |
| `.env.local` / `supabase/.temp` ignore checks | Passed |
| `npx supabase db push` | Passed; applied `20260718165000_reseller_add_to_shop_listing_rpc.sql` |
| `npx supabase db query --linked --file scripts/rpc/reseller-listing-rpc-tests-dev-only.sql` | Passed |
| `npm test` | Passed: 26 test files, 134 tests |
| `npm run lint` | Passed |
| `npm run build` | Passed |
| `npm run typecheck` | Passed |

## J. Secret and Scope Scan Result

Secret/scope scans confirmed:

- `.env.local` is ignored and was not staged.
- `supabase/.temp` is ignored.
- No real secrets were found in docs/scripts/source.
- Existing `SUPABASE_SERVICE_ROLE_KEY` references are limited to placeholder docs and server-only `lib/supabase/admin.ts`.
- No service-role usage exists in `app/` or `components/`.
- No bearer tokens, passwords, API secrets, or production data were found.
- No reseller listing RPC references were added to checkout/customer/shop/order/payment-like flows.

## K. Current Git Status

Pending local documentation changes after this report update:

- `docs/RISELLAR_RESELLER_ADD_TO_SHOP_DEV_APPLY_AND_TEST_REPORT.md`
- `docs/RISELLAR_RESELLER_ADD_TO_SHOP_BACKEND_FOUNDATION_REPORT.md`

## L. Whether Production Remains Blocked

Production remains blocked.

This migration and boundary test were applied/run only against the confirmed development project. Production should not be considered until a separate production readiness review, production dry-run, backup/rollback plan, and explicit production approval exist.

## M. Whether UI Integration Is Safe to Plan Next

Safe to plan reseller add-to-shop UI integration next, limited to reseller-owned add/update/archive listing calls.

Still out of scope:

- Checkout.
- Customer shop/public shop live data.
- Orders.
- Stock reservation.
- Payments.
- Delivery.
- Settlements.
- Commissions.
- Withdrawals.
- Reseller checkout flow.
