# Risellar Ecommerce Typography and Shop Header Polish Report

## A. Summary of Issue Fixed

Polished the customer public shop header and shared ecommerce product-card typography so the storefront and reseller product surfaces feel closer to the approved Risellar mobile references. The work stayed frontend-only and did not change business logic, routes, backend, auth, payments, storage, or integrations.

## B. Scope

- Primary route: `/shop/amas-beauty-plug`
- Supporting customer route: `/shop/amas-beauty-plug/product/nike-air-force-1-07-green-white`
- Reseller catalog and product discovery routes:
  - `/reseller/products`
  - `/reseller/trending`
  - `/reseller/insights/top-selling`
  - `/reseller/insights/high-profit`
  - `/reseller/insights/low-competition`
  - `/reseller/promotions/sponsored-products`
  - `/reseller/shop`
  - `/reseller/my-products`
- Sanity routes:
  - `/preview`
  - `/design-system`
  - `/supplier/products`

## C. Files Changed

- `components/customer/screens.tsx`
- `components/marketplace/ProductCard.tsx`
- `components/marketplace/ProductGridCard.tsx`
- `components/promotions/promotions-insights-screens.tsx`
- `components/reseller/screens.tsx`
- `lib/mock/customer-checkout.ts`
- `tests/phase5.test.tsx`
- `docs/RISELLAR_ECOMMERCE_TYPOGRAPHY_AND_SHOP_HEADER_POLISH_REPORT.md`

## D. Shop Header Fixes

- Kept the hero background on `var(--color-primary)`.
- Reduced the shop name to a max 26px treatment with `font-bold` instead of the heavier extra-bold style.
- Changed the badge copy from `Verified trusted reseller` to `Verified seller`.
- Removed the trust bullet list from inside the green hero card.
- Kept the hero focused on: Risellar Shop, shop name, location, short tagline, and verification badge.
- Left the Pay on Delivery trust message in a separate card below search and filters.
- Added clearer spacing between hero, search, chip row, and trust card.

## E. Product Typography Fixes

- Shared ecommerce grid product titles now use 13px, 600 weight, 18px line-height, and 2-line clamping.
- Category/meta copy now uses 11px compact muted text.
- Prices now use a 17px bold treatment instead of heavier extra-bold styling.
- Reseller cost/profit rows are slightly lighter and more compact.
- Rating and stock copy now use compact 11px text.
- Legacy `ProductCard` was aligned with the same ecommerce title and price sizing.
- Reseller promotions/insights opportunity cards now use the same compact product-title treatment.

## F. Product Grid Notes

- Customer and reseller product grids remain 2-column on mobile.
- Card spacing was tightened without changing routes, product data, pricing logic, or click behavior.
- Product names remain fully available through link `aria-label`s and full product detail pages.

## G. Screens Checked

- `/shop/amas-beauty-plug`
- `/shop/amas-beauty-plug/product/nike-air-force-1-07-green-white`
- `/reseller/products`
- `/reseller/trending`
- `/reseller/insights/top-selling`
- `/reseller/insights/high-profit`
- `/reseller/insights/low-competition`
- `/reseller/promotions/sponsored-products`
- `/reseller/shop`
- `/reseller/my-products`
- `/supplier/products`
- `/preview`
- `/design-system`

## H. Visual QA Notes

- Rendered Chrome checks were run at 360px, 390px, and 414px widths.
- Target customer/reseller/supplier ecommerce routes returned 200 in rendered checks.
- Target ecommerce routes showed no page-level horizontal overflow in rendered checks.
- Chip rows remained horizontally scrollable, with scrollbar hiding still active through `scrollbar-width: none`.
- The shop hero no longer includes the trust bullet list.
- `Verified seller` appears on the public shop page.
- Sample product title computed style at 390px:
  - `/shop/amas-beauty-plug`: `13px / 600 / 18px`
  - `/reseller/products`: `13px / 600 / 18px`

## I. Route Check Results

After restarting the dev server on port 400 and clearing the stale generated `.next` cache:

- `200 /preview`
- `200 /design-system`
- `200 /shop/amas-beauty-plug`
- `200 /shop/amas-beauty-plug/product/nike-air-force-1-07-green-white`
- `200 /reseller/products`
- `200 /reseller/trending`
- `200 /reseller/insights/top-selling`
- `200 /reseller/promotions/sponsored-products`
- `200 /reseller/shop`
- `200 /reseller/my-products`
- `200 /supplier/products`

## J. Commands Run and Results

- `npm test -- tests/phase5.test.tsx tests/product-gallery-grid.test.tsx`
  - Passed: 2 files, 8 tests.
- `npm test`
  - Passed: 16 files, 67 tests.
- `npm run typecheck`
  - Passed.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.
- HTTP route checks on `http://localhost:400`
  - Passed for all requested routes listed above.
- Rendered Chrome mobile QA at 360px, 390px, and 414px
  - Passed for target ecommerce routes.

## K. Remaining Visual Concerns

- `/design-system` still reports some mobile horizontal overflow in rendered QA. This appears isolated to the design-system/gallery surface and was not changed because this task was scoped to customer/reseller ecommerce typography and shop header polish.
- The supplier product list remained route-healthy and chip-row scrollbar behavior remained intact; no supplier layout redesign was made.

## L. Current Git Status

At report creation, the working tree contains only this scoped polish work and this report. No backend, auth, payment, storage, or integration work was started.

