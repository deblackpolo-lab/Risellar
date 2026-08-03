# Risellar Reseller PWA Dashboard Restoration Report

Date: 2026-08-03

## A. Summary

The reseller dashboard PWA shell was restored around the existing live dashboard metrics. The change keeps the real reseller wallet, commission, withdrawal, sales, order, and recent-activity data path intact while replacing the plain report-style presentation with a mobile-first app dashboard structure.

## B. UI Regression Root Cause

Git history shows commit `3d5d4c6` (`Replace dashboard placeholders with live metrics`) replaced the original reseller dashboard shell with `ResellerDashboardMetricsScreen`. That live-metrics component rendered the page as a full financial report using `MobileShell title="Reseller dashboard"`, a large `Sales and wallet dashboard` header card, equal-weight balance cards, and no fixed reseller bottom navigation.

The regression was presentational. The real backend metric helpers in `app/reseller/dashboard/page.tsx` were already correct and were preserved.

## C. Original Layout Behavior

The approved historical reseller UI used a mobile PWA shell with:

- a top app header
- a welcome and balance summary area
- compact quick actions
- dashboard content beneath the summary
- fixed bottom navigation
- bottom padding so content is not hidden behind navigation

That structure has been restored without reintroducing mock dashboard data.

## D. Header Restored

The floating uppercase `RESELLER DASHBOARD` label and the oversized `Sales and wallet dashboard` report card were removed from the reseller metrics screen.

The restored header now shows:

- `Welcome back`
- `Your reseller home`
- a short live-metrics summary
- notification shortcut to `/reseller/notifications`
- profile shortcut to `/reseller/settings`

## E. Bottom Navigation Restored

`components/layout/BottomNav.tsx` now renders the approved reseller tabs:

- Home: `/reseller/dashboard`
- Products: `/reseller/products`
- Orders: `/reseller/orders`
- Wallet: `/reseller/wallet`
- Profile: `/reseller/settings`

The nav remains fixed to the bottom, uses safe-area padding, provides icon and label tap targets, and marks the active tab with `aria-current="page"`.

Legacy active labels are mapped safely:

- `Shop` -> `Products`
- `My products` -> `Products`
- `Account` -> `Profile`
- `Support` -> `Profile`

## F. Real Metrics Preserved

The dashboard route still calls the existing safe live helpers:

- `getResellerDashboardMetricsSafeWithClient`
- `listResellerEarningsHistorySafeWithClient`
- `listResellerWithdrawalHistorySafeWithClient`

No mock imports, hardcoded screenshot values, direct table writes, Supabase migrations, RPC changes, RLS changes, or service-role clients were added.

The restored dashboard still renders:

- available balance
- locked commission
- pending withdrawal
- withdrawn total
- selected-period sales
- commission earned
- orders attributed
- rejected orders
- recent earnings activity
- recent withdrawal activity

## G. Quick Actions

The dashboard now includes compact quick actions to existing real reseller routes:

- Browse products: `/reseller/products`
- View orders: `/reseller/orders`
- Request withdrawal: `/reseller/withdraw`
- View wallet: `/reseller/wallet`

No mock action or unimplemented checkout/business flow was introduced.

## H. Recent Activity

Recent earnings and withdrawal rows remain backed by the live helper data. They were converted from report blocks into compact cards with safe references, amounts/statuses, and links to existing reseller pages.

## I. Responsive Behavior

Static/component verification confirms:

- mobile shell is used
- fixed bottom navigation is rendered
- content includes extra safe bottom padding (`pb-36`)
- dashboard cards use compact, wrapping-safe layout
- no fake phone frame was introduced

Live browser viewport checks are still pending because the current local browser session is not authenticated as a reseller.

## J. Wrong-Role Protection

Focused tests verify `/reseller/dashboard` remains role-enforced:

- reseller: allowed
- customer: blocked
- supplier owner: blocked
- admin staff with customer primary role: blocked from reseller route

The current local HTTP/browser observation also shows non-reseller access to `/reseller/dashboard` is blocked.

## K. Business No-Side-Effect Check

This change is limited to frontend rendering/navigation and a focused test. It does not modify:

- orders
- commissions
- wallet balance calculations
- withdrawals
- finance holds
- reseller liabilities
- products
- stock
- payments
- settlements
- notifications

## L. Tests Added

Added `tests/reseller-pwa-dashboard-restoration.test.tsx`, covering:

- restored reseller PWA heading
- removal of report-style heading text
- live metric rendering
- bottom navigation labels and route targets
- active tab highlight
- legacy active alias behavior
- current-path active tab recovery for older reseller screens that still pass stale labels
- real metric helper preservation
- no mock dashboard import
- no service-role regression
- safe bottom padding
- wrong-role route blocking

Focused regression command passed:

`npm test -- tests/reseller-pwa-dashboard-restoration.test.tsx tests/real-dashboard-metrics-safe-read.test.ts tests/phase3.test.tsx`

Result: 3 test files passed, 16 tests passed.

## M. Commands Run

- `git status --short`: showed reseller restoration files plus unrelated pre-existing D13-C work.
- `npm test -- tests/reseller-pwa-dashboard-restoration.test.tsx tests/real-dashboard-metrics-safe-read.test.ts tests/phase3.test.tsx`: passed after tightening one test assertion and adding route-derived active-tab coverage.
- `npm run lint`: passed.
- `git diff --check`: passed with only line-ending warnings from the Windows working copy.

Full verification:

- `git diff --check`: passed with Windows line-ending warnings only.
- `npm test`: passed, 52 files / 325 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

Secret/scope scan:

- `.env.local`, `supabase/.temp`, `.next`, and `.codex-dev-server.*.log` are ignored.
- No service-role references exist in `app/` or `components/`.
- No real Clerk, Supabase, bearer-token, API-key, password, or production-data values were found in the intentional reseller restoration files.
- No checkout, order, stock, payment, delivery, settlement, commission, withdrawal, or wallet mutation was added by the restoration.

## N. Browser QA

Local browser QA was completed after the approved development reseller account was signed in.

Dashboard result:

- `/reseller/dashboard` loaded for the reseller account.
- Restored PWA shell appeared with `Your reseller home`.
- Fixed bottom navigation was visible.
- Home tab was active.
- Old plain report-only layout text was absent.
- No fake phone-inside-phone frame was present.
- No horizontal overflow was detected.
- No runtime webpack error appeared.

Live metrics result:

- Available balance rendered as `GH₵20.00`.
- Locked commission rendered as `GH₵0.00`.
- Pending withdrawal rendered as `GH₵10.00`.
- Withdrawn total rendered as `GH₵0.00`.
- Selected-period metrics rendered: sales `1`, commission earned `GH₵30.00`, orders attributed `24`, rejected orders `0`.
- Recent activity rendered the development withdrawal QA product, one order reference, and one withdrawal reference.
- No private customer/supplier details, platform margin, reseller margin, profile id, supplier id, payout internals, risk score, or admin notes were visible on the dashboard.

Bottom navigation route result:

- `/reseller/dashboard`: 200, Home active, no overflow.
- `/reseller/products`: 200, Products active, no overflow.
- `/reseller/orders`: 200, Orders active after the shared active-tab hydration fix, no overflow.
- `/reseller/wallet`: 200, Wallet active after the shared active-tab hydration fix, no overflow.
- `/reseller/settings`: 200, Profile active, no overflow.

Viewport result:

- 360px mobile: passed, no overflow, bottom nav fixed, Home active, 48px tap targets, safe bottom padding `144px`.
- 390px mobile: passed, no overflow, bottom nav fixed, Home active, 48px tap targets, safe bottom padding `144px`.
- 430px mobile: passed, no overflow, bottom nav fixed, Home active, 48px tap targets, safe bottom padding `144px`.
- 768px tablet: passed, no overflow, bottom nav fixed, Home active, 48px tap targets, safe bottom padding `144px`.
- 1024px desktop: passed, no overflow, bottom nav fixed, Home active, 48px tap targets, safe bottom padding `144px`.
- 1366px desktop: passed, no overflow, bottom nav fixed, Home active, 48px tap targets, safe bottom padding `144px`.

Console/server findings:

- Browser console showed expected Clerk development-key warnings only.
- A transient Next Fast Refresh webpack runtime error appeared while editing during development, but the final route and viewport passes showed no visible runtime error and all tested reseller routes returned 200.

## O. Files Changed

Intentional reseller restoration files:

- `components/dashboard/real-dashboard-metrics-screens.tsx`
- `components/layout/BottomNav.tsx`
- `tests/reseller-pwa-dashboard-restoration.test.tsx`
- `docs/RISELLAR_RESELLER_PWA_DASHBOARD_RESTORATION_REPORT.md`

Unrelated D13-C work remains present in the working tree and must not be staged with this restoration unless explicitly approved.

## P. Safe To Commit

Yes, after the final requested verification suite passes again. Stage only the reseller restoration files listed above. Do not stage unrelated D13-C customer returns/refunds work.
