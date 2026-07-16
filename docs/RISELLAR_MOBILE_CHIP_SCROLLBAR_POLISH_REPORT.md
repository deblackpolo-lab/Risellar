# Risellar Mobile Chip Scrollbar Polish Report

## A. Summary of Issue Fixed

Several mobile/PWA chip rows used native horizontal scrolling, which exposed browser scrollbars under filter/category chips. The rows now keep horizontal swipe behavior while hiding the scrollbar cross-browser. Long supplier product filter labels also keep a single readable line with consistent chip sizing.

## B. Files Changed

- `app/globals.css`
- `components/ui/Button.tsx`
- `components/ui/ScrollableChipRow.tsx`
- `components/ui/index.ts`
- `components/reseller/screens.tsx`
- `components/customer/screens.tsx`
- `components/supplier/screens.tsx`
- `components/supplier/inventory-screens.tsx`
- `components/supplier/settlement-screens.tsx`
- `components/supplier/team-permissions-screens.tsx`
- `docs/RISELLAR_MOBILE_CHIP_SCROLLBAR_POLISH_REPORT.md`

## C. Shared Class/Component Created or Updated

- Added `.scrollbar-none` in `app/globals.css` using `scrollbar-width: none`, `-ms-overflow-style: none`, and hidden WebKit scrollbars.
- Added `ScrollableChipRow` as the shared horizontal chip row component.
- Updated button base styling with `whitespace-nowrap` so chip labels and other button text do not wrap awkwardly.

## D. Screens Checked

- `/reseller/orders`
- `/supplier/products`
- `/shop/amas-beauty-plug`
- `/reseller/products`
- `/reseller/trending`
- `/customer/orders/rsr-20260713-00021`
- `/supplier/orders`
- `/preview`
- `/design-system`

## E. Visual QA Notes

- Browser QA was run at 360px, 390px, and 414px widths.
- Chip rows retain horizontal swipe/scroll behavior on `/reseller/orders`, `/supplier/products`, `/shop/amas-beauty-plug`, `/reseller/products`, and `/supplier/orders`.
- Native horizontal scrollbars are hidden on chip rows with computed `scrollbar-width: none`, `overflow-x: auto`, and `overflow-y: hidden`.
- Long labels such as "Pending Approval", "Out of Stock", and "Needs Review" remain readable on a single line.
- No checked route produced page-level horizontal overflow.
- `/reseller/trending`, `/customer/orders/rsr-20260713-00021`, and `/admin/operations` were checked for regressions and did not expose chip-row overflow.
- Admin table overflow patterns were not changed.

## F. Commands Run and Results

- `npm test` - passed, 15 test files and 63 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed with `--max-warnings=0`.
- `npm run build` - passed.
- Playwright/Chrome mobile layout QA - passed at 360px, 390px, and 414px.

## G. Route Check Results

- `/reseller/orders` - 200
- `/supplier/products` - 200
- `/shop/amas-beauty-plug` - 200
- `/reseller/products` - 200
- `/reseller/trending` - 200
- `/customer/orders/rsr-20260713-00021` - 200
- `/customer/orders` - 200
- `/supplier/orders` - 200
- `/preview` - 200
- `/design-system` - 200
- `/admin/operations` - 200 during visual QA

## H. Current Git Status

- Modified: `app/globals.css`
- Modified: `components/customer/screens.tsx`
- Modified: `components/reseller/screens.tsx`
- Modified: `components/supplier/inventory-screens.tsx`
- Modified: `components/supplier/screens.tsx`
- Modified: `components/supplier/settlement-screens.tsx`
- Modified: `components/supplier/team-permissions-screens.tsx`
- Modified: `components/ui/Button.tsx`
- Modified: `components/ui/index.ts`
- Modified: `package.json` from the prior port-400 configuration task
- Added: `components/ui/ScrollableChipRow.tsx`
- Added: `docs/RISELLAR_MOBILE_CHIP_SCROLLBAR_POLISH_REPORT.md`
