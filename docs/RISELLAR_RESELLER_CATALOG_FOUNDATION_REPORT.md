# Risellar Reseller Catalog Foundation Report

## A. Summary

Implemented the reseller approved-product catalog foundation for development review.

The reseller product catalog routes now read through a user-context Supabase RPC helper instead of mock catalog data:

- `/reseller/products`
- `/reseller/products/[id]`

The integration is intentionally read-only. It does not create reseller listings, reserve stock, start checkout, connect customer/public catalog pages, or connect orders/payments/delivery flows.

## B. Backend Read Path

Created forward migration:

- `supabase/migrations/20260718150000_reseller_approved_product_catalog_rpc.sql`

The migration adds:

- `public.get_reseller_approved_products()`

The RPC:

- requires an authenticated active profile
- requires `profiles.primary_role = 'reseller'`
- requires an active approved `public.resellers` row
- returns only approved, active supplier products
- requires supplier records to be active and approved
- returns reseller-safe product fields only
- does not expose supplier payout, risk, admin, approval actor, platform margin, internal notes, or private contact fields
- does not write `reseller_products`
- does not reserve stock
- does not create orders

`npx supabase db push --dry-run` passed and showed only this migration would be applied:

- `20260718150000_reseller_approved_product_catalog_rpc.sql`

No real `supabase db push` was run.

## C. UI Connected

Created:

- `lib/reseller/catalog.ts`
- `app/reseller/products/actions.ts`
- `components/reseller/reseller-catalog-rpc-screens.tsx`

Updated:

- `app/reseller/products/page.tsx`
- `app/reseller/products/[id]/page.tsx`

The UI shows:

- approved product list
- product detail
- product name
- category
- supplier display name when available
- reseller cost
- max customer price
- available stock
- image count represented through a safe placeholder
- empty state
- error state

The detail page keeps “Add to shop” disabled with copy: `Add to shop planned`.

## D. Security Protections

Confirmed by code and tests:

- reseller catalog uses `getToken()` through Clerk native Supabase auth
- user-context Supabase client uses the anon key plus Clerk session token
- service role is not imported into reseller product app/components
- `createSupabaseAdminClient` is not used in reseller catalog UI
- no direct insert into `reseller_products`
- no add-to-shop RPC was added
- no profile role mutation was added
- no customer/public shop route was connected to this RPC
- no checkout/order/payment/delivery/stock reservation flow was connected

## E. Tests Added

Created:

- `tests/reseller-catalog.test.ts`

Coverage:

- calls `get_reseller_approved_products`
- maps only approved active products
- excludes pending/rejected/archived products from mapped catalog
- blocks supplier-private/admin-only fields from the UI model
- confirms add-to-shop remains disabled/planned
- confirms service role is absent from reseller product UI
- confirms unrelated customer/shop/checkout paths are not connected

TDD note:

- `npm test -- tests/reseller-catalog.test.ts` failed first because `@/lib/reseller/catalog` did not exist.
- The targeted test passed after implementation.

## F. Dev-Only Boundary Test Script

Created:

- `scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql`

The script is marked development-only, uses fake `example.test` fixture accounts, uses rollback, and tests:

- approved reseller can see approved active product
- pending/archived products are hidden
- customer cannot call reseller catalog RPC
- supplier cannot call reseller catalog RPC

The script was not run because the migration has not been applied to development yet.

## G. Manual QA

Browser/live reseller catalog QA was not completed in this step because the new RPC migration was dry-runed only and not applied.

Manual QA can proceed after explicit approval to apply the migration to the confirmed development Supabase project.

Expected post-apply QA:

- sign in as approved reseller test account
- open `/reseller/products`
- confirm approved active supplier products appear
- open `/reseller/products/[id]`
- confirm detail page renders reseller-safe fields
- confirm add-to-shop remains disabled/planned
- confirm customer/shop/checkout routes remain unaffected

## H. Commands Run / Results

- `git status --short` - working tree dirty with reseller catalog foundation files only.
- `git branch --show-current` - `main`.
- `git log --oneline -3` - latest commit before this work was `7d6ecdee Document admin product approval browser QA`.
- `npm test -- tests/reseller-catalog.test.ts` - failed first; missing `@/lib/reseller/catalog`.
- `npm test -- tests/reseller-catalog.test.ts` - passed after implementation; 5 tests passed.
- `npx supabase db push --dry-run` - passed; would apply only `20260718150000_reseller_approved_product_catalog_rpc.sql`.
- `git diff --check` - passed; only line-ending warnings for touched Next page files.
- `npm test` - passed; 24 files, 131 tests.
- `npm run lint` - passed.
- `npm run build` - first run timed out at 124 seconds; rerun with longer timeout passed.
- `npm run typecheck` - passed.

## I. Secret Scan Result

Result: passed with known safe caveats.

Checked:

- `.env.local` is ignored and not staged.
- `supabase/.temp/` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No real Clerk/Supabase/service-role values were found in changed docs/scripts/source.
- No bearer tokens, passwords, API secrets, or production data were found.
- No service role imports were found in `app/` or `components/`.

Known existing placeholder/reference matches:

- `.env.example` contains empty placeholder key names.
- `lib/supabase/admin.ts` references `SUPABASE_SERVICE_ROLE_KEY` in a server-only helper.
- Historical docs mention secret key names as documentation text.

## J. Files Changed

- `app/reseller/products/actions.ts`
- `app/reseller/products/page.tsx`
- `app/reseller/products/[id]/page.tsx`
- `components/reseller/reseller-catalog-rpc-screens.tsx`
- `lib/reseller/catalog.ts`
- `scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql`
- `supabase/migrations/20260718150000_reseller_approved_product_catalog_rpc.sql`
- `tests/reseller-catalog.test.ts`
- `docs/RISELLAR_RESELLER_CATALOG_FOUNDATION_REPORT.md`

## K. Current Git Status

Working tree is intentionally dirty with the reseller catalog foundation and this report.

No files are staged.

## L. Recommendation

Safe to commit as a code/schema foundation: yes, after the user requests commit.

Safe to apply to development Supabase: yes, with explicit approval. Dry-run passed and showed only the reseller catalog RPC migration.

Safe for production: no. Production remains blocked until separate production planning, approval, and production-specific validation.

Exact next prompt to apply development migration and run boundary tests:

```text
I approve applying the Reseller Catalog RPC foundation migration to the confirmed DEVELOPMENT Supabase project named “Risellar”, then running the development-only reseller catalog RPC boundary tests.

Do NOT connect production Supabase.
Do NOT use production data.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS/RPC/storage policies.
Do NOT connect checkout, customer catalog, public shop, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or reseller shop checkout flows.
Do NOT run npm audit fix --force.

Dry-run passed and showed only this migration would be applied:
20260718150000_reseller_approved_product_catalog_rpc.sql

Run:
git status --short
npx supabase --version
npx supabase db push
npx supabase db query --linked --file scripts/rpc/reseller-catalog-rpc-tests-dev-only.sql
npm test
npm run lint
npm run build
npm run typecheck

Run secret scan and update docs/RISELLAR_RESELLER_CATALOG_FOUNDATION_REPORT.md with the apply/test results.
Do not commit unless asked.
```
