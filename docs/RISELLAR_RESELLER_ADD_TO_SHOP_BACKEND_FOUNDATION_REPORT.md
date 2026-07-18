# Risellar Reseller Add-to-Shop Backend Foundation Report

Date: 2026-07-18

## A. Summary

Created the development/code foundation for reseller add-to-shop listing management. This phase adds audited reseller-owned listing RPCs on top of the existing `public.reseller_products` table and keeps customer shop, checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, and public storefront checkout out of scope.

No production Supabase connection was used. No real `supabase db push` was run.

## B. Migration Created

Created:

- `supabase/migrations/20260718165000_reseller_add_to_shop_listing_rpc.sql`

The migration extends the existing schema rather than creating a parallel listing table. It uses the existing:

- `public.reseller_products`
- `public.reseller_shops`
- `public.products`
- `public.suppliers`
- `public.audit_logs`

It also adds a partial unique index for open default listings:

- `reseller_products_one_open_default_listing_idx`

This blocks more than one non-archived default listing for the same reseller/product pair.

## C. RPCs and Functions Created

Created helper functions:

- `public.current_verified_reseller_id()`
- `public.reseller_listing_default_margin_cap()`
- `public.reseller_listing_slug_from_product(uuid, text)`
- `public.reseller_shop_slug_from_reseller(uuid)`
- `public.ensure_reseller_default_shop(uuid)`
- `public.assert_reseller_listing_margin(numeric, numeric)`

Created reseller-facing RPCs:

- `public.create_reseller_product_listing(uuid, numeric)`
- `public.update_reseller_product_listing(uuid, numeric, text)`
- `public.archive_reseller_product_listing(uuid)`
- `public.get_reseller_shop_products()`

Only the four reseller-facing RPCs are granted to `authenticated`. Internal helpers are revoked from public.

## D. Margin Validation Rules

Reseller margin validation is server-side only.

Rules:

- Margin is required.
- Margin is rounded to 2 decimal places.
- Margin must be greater than zero.
- Margin must not exceed the product's `max_reseller_margin_amount` when configured.
- If no product-level max margin is configured yet, the RPC uses a conservative backend default cap of `500.00`.

This default is documented as a temporary backend guardrail until admin-defined category/product/supplier margin rules are implemented.

## E. Pricing Calculation Approach

The server computes:

```text
customer_product_price_amount = base_price_amount + platform_margin_amount + reseller_margin_amount
```

The client cannot submit customer price, supplier base price, platform margin, supplier id, reseller id, stock reservation, commission, or settlement fields.

`get_reseller_shop_products()` returns reseller-safe management fields only. It does not expose supplier base price or platform margin, and it is not a public/customer storefront feed.

## F. Audit Enforcement

The migration writes audit logs for:

- `create_reseller_product_listing`
- `update_reseller_product_listing`
- `archive_reseller_product_listing`

Audit rows are written through `public.create_audit_log_entry`.

## G. RLS and Security Protections

Protections preserved:

- Approved reseller account required.
- Product must be `product_status = active`.
- Product must be `approval_status = approved`.
- Supplier must be active and approved.
- Reseller can update/archive only their own listings.
- Duplicate open default listing is blocked.
- Archive is soft only through `listing_status = archived` and `deleted_at`.
- No direct delete path was added.
- No broad `FOR ALL`, `FOR DELETE`, `USING (true)`, or `WITH CHECK (true)` was added.
- No public write path was added.
- No customer/public read path was connected.
- No service role is used by app/components.

## H. Test Script Created

Created:

- `scripts/rpc/reseller-listing-rpc-tests-dev-only.sql`

The script is marked:

```text
DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
```

It is transaction-wrapped and ends with `rollback`.

Planned coverage:

- Approved reseller can list approved product.
- Customer price is computed as base + platform + reseller margin.
- Pending/rejected/archived products cannot be listed.
- Customer cannot create listing.
- Supplier cannot create reseller listing.
- Reseller cannot update/archive another reseller's listing.
- Duplicate active listing is blocked.
- Valid margin update succeeds.
- Negative/excessive margin is blocked.
- Archive is soft.
- No stock reservation/order/commission/settlement is created.
- Audit logs are created.
- Archived listing allows a new active listing for the same product.

The script was not run because this task is dry-run only and the migration has not been applied to development yet.

## I. Dry-Run Result

Command:

```powershell
npx supabase db push --dry-run
```

Result: passed.

Dry-run output showed only this migration would be applied:

- `20260718165000_reseller_add_to_shop_listing_rpc.sql`

No real `npx supabase db push` was run.

## J. Deferred Items

Deferred until later phases:

- Customer public shop live reads.
- Checkout.
- Orders.
- Stock reservation.
- Payments.
- Delivery.
- Settlements.
- Commissions.
- Withdrawals.
- Public storefront checkout.
- Reseller add-to-shop UI connection.
- Admin-configurable category/product/supplier margin rule UI.
- Customer-facing listing URLs.

## K. Commands Run and Results

| Command | Result |
| --- | --- |
| `git status --short` | Clean before work; later showed only new migration/test/report files |
| `npx supabase db push --dry-run` | Passed; would apply only `20260718165000_reseller_add_to_shop_listing_rpc.sql` |
| `git diff --check` | Passed |
| `npm test` | Passed: 26 test files, 134 tests |
| `npm run lint` | Passed |
| `npm run build` | Passed |
| `npm run typecheck` | First parallel run failed while `.next/types` were being regenerated by build; rerun after build passed |

## L. Secret and Scope Scan Result

Secret/scope scans confirmed:

- `.env.local` is ignored.
- `.env.local` is not tracked.
- `supabase/.temp` is ignored.
- No real Clerk/Supabase/service-role values were found in the new docs/scripts/source.
- Existing `SUPABASE_SERVICE_ROLE_KEY` reference remains isolated to server-only `lib/supabase/admin.ts`.
- No service role references were found in `app/` or `components/`.
- No bearer tokens, passwords, API secrets, or production data were found.
- No reseller listing RPC references were added to checkout/customer/shop flows.
- New SQL/test files contain no broad/delete/truncate/drop patterns.

Expected placeholder/documentation hits still exist in historical docs and `.env.example`.

## M. Files Changed

- `supabase/migrations/20260718165000_reseller_add_to_shop_listing_rpc.sql`
- `scripts/rpc/reseller-listing-rpc-tests-dev-only.sql`
- `docs/RISELLAR_RESELLER_ADD_TO_SHOP_BACKEND_FOUNDATION_REPORT.md`

## N. Current Git Status

Pending local changes:

- New migration.
- New development-only test script.
- New report.

## O. Whether Safe to Apply to Development

Development apply status:

- Applied to the confirmed development Supabase project named `Risellar` on 2026-07-18 after explicit approval.
- Development-only reseller listing RPC boundary tests passed.
- Fixture/test data was rolled back.
- Production remains blocked.

Conditions:

- Do not apply to production.
- Do not connect customer/public shop, checkout, orders, payments, delivery, settlements, commissions, withdrawals, or reseller checkout flows.

See:

- `docs/RISELLAR_RESELLER_ADD_TO_SHOP_DEV_APPLY_AND_TEST_REPORT.md`
